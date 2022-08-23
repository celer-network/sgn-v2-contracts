// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.8.9;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../framework/MessageSenderApp.sol";
import "../framework/MessageReceiverApp.sol";
import "../../safeguard/Pauser.sol";
import "../../safeguard/Governor.sol";
import "../../message/interfaces/IMessageBus.sol";
import "../../interfaces/IWETH.sol";

/** @title rfq contract */
contract RFQ is MessageSenderApp, MessageReceiverApp, Pauser, Governor, ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct Quote {
        uint64 srcChainId;
        address srcToken;
        uint256 srcAmount;
        uint64 dstChainId;
        address dstToken;
        uint256 dstAmount;
        uint64 deadline;
        uint64 nonce;
        address sender;
        address receiver;
        address refundTo;
        address liquidityProvider;
    }

    enum QuoteStatus {
        Null,
        Deposited, // sender deposited                                    || location: src chain
        Released, // released non-native token to liquidityProvider       || location: src chain
        ReleasedNative, // released native token to liquidityProvider     || location: src chain
        Refunded, // refunded non-native token to refundTo/Sender         || location: src chain
        RefundedNative, // refunded native token to refundTo/Sender       || location: src chain
        RefundInitiated, // refund initiated                              || location: dst chain
        Executed, // transferred non-native token to receiver             || location: dst chain
        ExecutedNative // transferred native token to reciever            || location: dst chain
    }

    enum MessageType {
        Null,
        Release,
        Refund
    }

    address public nativeWrap;
    mapping(uint64 => address) public remoteRfqContracts;
    // quoteHsh => bool
    mapping(bytes32 => MessageType) public unconsumedMsg;
    // quoteHash => QuoteStatus
    mapping(bytes32 => QuoteStatus) public quotes;

    address public treasuryAddr;
    uint32 public feePercGlobal;
    // chainId => feePercOverride, support override fee perc of this chain
    mapping(uint64 => uint32) public feePercOverride;
    // tokenAddr => feeBalance
    mapping(address => uint256) public uncollectedFee;

    event SrcDeposited(bytes32 quoteHash, Quote quote);
    event DstTransferred(bytes32 quoteHash, address receiver, address dstToken, uint256 amount);
    event RefundInitiated(bytes32 quoteHash);
    event MessageReceived(bytes32 quoteHash);
    event SrcReleased(bytes32 quoteHash, address liquidityProvider, address srcToken, uint256 amount);
    event Refunded(bytes32 quoteHash, address refundTo, address srcToken, uint256 amount);
    event RfqContractsUpdated(uint64[] chainIds, address[] remoteRfqContracts);
    event FeePercUpdated(uint64[] chainIds, uint32[] feePercs);
    event TreasuryAddrUpdated(address treasuryAddr);
    event FeeCollected(address treasuryAddr, address token, uint256 amount);

    constructor(address _messageBus) {
        messageBus = _messageBus;
    }

    function srcDeposit(Quote calldata _quote, uint64 _submissionDeadline)
        external
        payable
        whenNotPaused
        returns (bytes32)
    {
        bytes32 quoteHash = _srcDeposit(_quote, _submissionDeadline);
        IERC20(_quote.srcToken).safeTransferFrom(msg.sender, address(this), _quote.srcAmount);
        emit SrcDeposited(quoteHash, _quote);
        return quoteHash;
    }

    function srcDepositNative(Quote calldata _quote, uint64 _submissionDeadline)
        external
        payable
        whenNotPaused
        returns (bytes32)
    {
        require(nativeWrap != address(0), "Rfq: native wrap not set");
        require(_quote.srcToken == nativeWrap, "Rfq: src token mismatch");
        require(msg.value >= _quote.srcAmount, "Rfq: insufficient amount");
        bytes32 quoteHash = _srcDeposit(_quote, _submissionDeadline);
        IWETH(nativeWrap).deposit{value: _quote.srcAmount}();
        emit SrcDeposited(quoteHash, _quote);
        return quoteHash;
    }

    function _srcDeposit(Quote calldata _quote, uint64 _submissionDeadline) private returns (bytes32) {
        require(_submissionDeadline > block.timestamp, "Rfq: submission deadline passed");
        require(
            _quote.receiver != address(0) && _quote.liquidityProvider != address(0),
            "Rfq: invalid receiver or liquidityProvider"
        );
        require(_quote.srcChainId == uint64(block.chainid), "Rfq: src chainId mismatch");
        require(_quote.sender == msg.sender, "Rfq: sender mismatch");
        bytes32 quoteHash = getQuoteHash(_quote);
        require(quotes[quoteHash] == QuoteStatus.Null, "Rfq: quote hash exists");

        quotes[quoteHash] = QuoteStatus.Deposited;
        if (_quote.srcChainId != _quote.dstChainId) {
            address msgReceiver = remoteRfqContracts[_quote.dstChainId];
            require(msgReceiver != address(0), "Rfq: dst contract not set");
            bytes memory message = abi.encode(quoteHash);
            sendMessage(msgReceiver, _quote.dstChainId, message, msg.value);
        }
        return quoteHash;
    }

    function dstTransfer(Quote calldata _quote) external payable whenNotPaused {
        (bytes32 quoteHash, address msgReceiver) = _dstTransferCheck(_quote);
        quotes[quoteHash] = QuoteStatus.Executed;
        bytes memory message = bytes.concat(quoteHash, bytes1(uint8(MessageType.Release)));
        sendMessage(msgReceiver, _quote.srcChainId, message, msg.value);
        IERC20(_quote.dstToken).safeTransferFrom(msg.sender, _quote.receiver, _quote.dstAmount);
        emit DstTransferred(quoteHash, _quote.receiver, _quote.dstToken, _quote.dstAmount);
    }

    function dstTransferNative(Quote calldata _quote) external payable whenNotPaused {
        require(nativeWrap != address(0), "Rfq: native wrap not set");
        require(_quote.dstToken == nativeWrap, "Rfq: dst token mismatch");
        require(msg.value >= _quote.dstAmount, "Rfq: insufficient amount");
        (bytes32 quoteHash, address msgReceiver) = _dstTransferCheck(_quote);
        quotes[quoteHash] = QuoteStatus.ExecutedNative;
        bytes memory message = bytes.concat(quoteHash, bytes1(uint8(MessageType.Release)));
        sendMessage(msgReceiver, _quote.srcChainId, message, msg.value - _quote.dstAmount);
        {
            (bool sent, ) = _quote.receiver.call{value: _quote.dstAmount, gas: 50000}("");
            require(sent, "Rfq: failed to send native token");
        }
        emit DstTransferred(quoteHash, _quote.receiver, _quote.dstToken, _quote.dstAmount);
    }

    function sameChainTransfer(Quote calldata _quote, bool _releaseNative) external payable whenNotPaused {
        require(_quote.srcChainId == _quote.dstChainId, "Rfq: not same chain swap");
        (bytes32 quoteHash, ) = _dstTransferCheck(_quote);
        IERC20(_quote.dstToken).safeTransferFrom(msg.sender, _quote.receiver, _quote.dstAmount);
        _srcRelease(_quote, quoteHash, _releaseNative);
        emit DstTransferred(quoteHash, _quote.receiver, _quote.dstToken, _quote.dstAmount);
    }

    function sameChainTransferNative(Quote calldata _quote, bool _releaseNative) external payable whenNotPaused {
        require(_quote.srcChainId == _quote.dstChainId, "Rfq: not same chain swap");
        require(nativeWrap != address(0), "Rfq: native wrap not set");
        require(_quote.dstToken == nativeWrap, "Rfq: dst token mismatch");
        require(msg.value >= _quote.dstAmount, "Rfq: insufficient amount");
        (bytes32 quoteHash, ) = _dstTransferCheck(_quote);
        {
            (bool sent, ) = _quote.receiver.call{value: _quote.dstAmount, gas: 50000}("");
            require(sent, "Rfq: failed to send native token");
        }
        _srcRelease(_quote, quoteHash, _releaseNative);
        emit DstTransferred(quoteHash, _quote.receiver, _quote.dstToken, _quote.dstAmount);
    }

    function _dstTransferCheck(Quote calldata _quote) private view returns (bytes32, address) {
        require(_quote.deadline > block.timestamp, "Rfq: transfer deadline passed");
        require(_quote.dstChainId == uint64(block.chainid), "Rfq: dst chainId mismatch");
        bytes32 quoteHash = getQuoteHash(_quote);
        address msgReceiver = remoteRfqContracts[_quote.srcChainId];
        if (_quote.srcChainId != _quote.dstChainId) {
            require(quotes[quoteHash] == QuoteStatus.Null, "Rfq: quote already executed");
            require(msgReceiver != address(0), "Rfq: dst rfq contract not set");
        } else {
            require(quotes[quoteHash] == QuoteStatus.Deposited, "Rfq: no deposit on same chain");
        }
        return (quoteHash, msgReceiver);
    }

    function _srcRelease(
        Quote calldata _quote,
        bytes32 _quoteHash,
        bool _releaseNative
    ) private {
        uint256 amount = _deductAndAccumulateFee(_quote);
        if (_releaseNative) {
            quotes[_quoteHash] = QuoteStatus.ReleasedNative;
            IWETH(_quote.srcToken).withdraw(amount);
            {
                (bool sent, ) = _quote.liquidityProvider.call{value: amount, gas: 50000}("");
                require(sent, "failed to send native token");
            }
        } else {
            quotes[_quoteHash] = QuoteStatus.Released;
            IERC20(_quote.srcToken).safeTransfer(_quote.liquidityProvider, amount);
        }
        emit SrcReleased(_quoteHash, _quote.liquidityProvider, _quote.srcToken, amount);
    }

    function requestRefund(Quote calldata _quote) external payable whenNotPaused {
        require(_quote.deadline < block.timestamp, "Rfq: transfer deadline not passed");
        require(_quote.dstChainId == uint64(block.chainid), "Rfq: dst chainId mismatch");
        address _receiver = remoteRfqContracts[_quote.srcChainId];
        require(_receiver != address(0), "Rfq: src rfq contract not set");
        bytes32 quoteHash = getQuoteHash(_quote);
        require(quotes[quoteHash] == QuoteStatus.Null, "Rfq: quote already executed");

        quotes[quoteHash] = QuoteStatus.RefundInitiated;
        bytes memory message = bytes.concat(quoteHash, bytes1(uint8(MessageType.Refund)));
        sendMessage(_receiver, _quote.srcChainId, message, msg.value);
        emit RefundInitiated(quoteHash);
    }

    function srcRelease(
        Quote calldata _quote,
        bytes calldata _message,
        MsgDataTypes.RouteInfo calldata _route,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers
    ) external nonReentrant whenNotPaused {
        bytes32 quoteHash = _srcReleaseCheck(_quote, _message, _route, _sigs, _signers, _powers);
        _srcRelease(_quote, quoteHash, false);
    }

    function srcReleaseNative(
        Quote calldata _quote,
        bytes calldata _message,
        MsgDataTypes.RouteInfo calldata _route,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers
    ) external nonReentrant whenNotPaused {
        require(nativeWrap != address(0), "Rfq: native wrap not set");
        require(_quote.srcToken == nativeWrap, "Rfq: src token mismatch");
        bytes32 quoteHash = _srcReleaseCheck(_quote, _message, _route, _sigs, _signers, _powers);
        _srcRelease(_quote, quoteHash, true);
    }

    function _srcReleaseCheck(
        Quote calldata _quote,
        bytes calldata _message,
        MsgDataTypes.RouteInfo calldata _route,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers
    ) private returns (bytes32) {
        bytes32 quoteHash = getQuoteHash(_quote);
        require(quotes[quoteHash] == QuoteStatus.Deposited, "Rfq: incorrect quote hash");
        receiveMsgAndCheckHash(_message, _route, _sigs, _signers, _powers, quoteHash);
        require(unconsumedMsg[quoteHash] == MessageType.Release, "Rfq: message type mismatch");
        delete unconsumedMsg[quoteHash];
        return quoteHash;
    }

    function _deductAndAccumulateFee(Quote calldata _quote) private returns (uint256) {
        uint256 fee = getRfqFee(_quote.dstChainId, _quote.srcAmount);
        uncollectedFee[_quote.srcToken] += fee;
        return _quote.srcAmount - fee;
    }

    function executeRefund(
        Quote calldata _quote,
        bytes calldata _message,
        MsgDataTypes.RouteInfo calldata _route,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers
    ) external nonReentrant whenNotPaused {
        bytes32 quoteHash = _executeRefund(_quote, _message, _route, _sigs, _signers, _powers);
        quotes[quoteHash] = QuoteStatus.Refunded;
        address receiver = (_quote.refundTo == address(0)) ? _quote.sender : _quote.refundTo;
        IERC20(_quote.srcToken).safeTransfer(receiver, _quote.srcAmount);
        emit Refunded(quoteHash, receiver, _quote.srcToken, _quote.srcAmount);
    }

    function executeRefundNative(
        Quote calldata _quote,
        bytes calldata _message,
        MsgDataTypes.RouteInfo calldata _route,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers
    ) external nonReentrant whenNotPaused {
        require(nativeWrap != address(0), "Rfq: native wrap not set");
        require(_quote.srcToken == nativeWrap, "Rfq: src token mismatch");
        bytes32 quoteHash = _executeRefund(_quote, _message, _route, _sigs, _signers, _powers);
        quotes[quoteHash] = QuoteStatus.RefundedNative;
        address receiver = (_quote.refundTo == address(0)) ? _quote.sender : _quote.refundTo;
        IWETH(_quote.srcToken).withdraw(_quote.srcAmount);
        {
            (bool sent, ) = _quote.liquidityProvider.call{value: _quote.srcAmount, gas: 50000}("");
            require(sent, "failed to send native token");
        }
        emit Refunded(quoteHash, receiver, _quote.srcToken, _quote.srcAmount);
    }

    function _executeRefund(
        Quote calldata _quote,
        bytes calldata _message,
        MsgDataTypes.RouteInfo calldata _route,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers
    ) private returns (bytes32) {
        bytes32 quoteHash = getQuoteHash(_quote);
        require(quotes[quoteHash] == QuoteStatus.Deposited, "Rfq: incorrect quote hash");
        if (_quote.srcChainId != _quote.dstChainId) {
            receiveMsgAndCheckHash(_message, _route, _sigs, _signers, _powers, quoteHash);
            require(unconsumedMsg[quoteHash] == MessageType.Refund, "Rfq: message type mismatch");
            delete unconsumedMsg[quoteHash];
        } else {
            require(_quote.deadline < block.timestamp, "Rfq: transfer deadline not passed");
        }
        return quoteHash;
    }

    function executeMessage(
        address _sender,
        uint64 _srcChainId,
        bytes calldata _message,
        address // executor
    ) external payable override onlyMessageBus returns (ExecutionStatus) {
        require(_message.length == 33, "Rfq: incorrect message length");
        address expectedSender = remoteRfqContracts[_srcChainId];
        if (expectedSender != _sender) {
            return ExecutionStatus.Retry;
        }

        bytes32 quoteHash = bytes32(_message);
        MessageType msgType = abi.decode(_message[32:], (MessageType));
        require(msgType != MessageType.Null, "Rfq: invalid message type");
        unconsumedMsg[quoteHash] = msgType;

        emit MessageReceived(quoteHash);
        return ExecutionStatus.Success;
    }

    function collectFee(address _token) external {
        require(treasuryAddr != address(0), "Rfq: treasury address not set");
        uint256 feeAmount = uncollectedFee[_token];
        uncollectedFee[_token] = 0;
        IERC20(_token).safeTransfer(treasuryAddr, feeAmount);
        emit FeeCollected(treasuryAddr, _token, feeAmount);
    }

    //=========================== helper functions ==========================

    function getQuoteHash(Quote calldata _quote) public pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    _quote.srcChainId,
                    _quote.srcToken,
                    _quote.srcAmount,
                    _quote.dstChainId,
                    _quote.dstToken,
                    _quote.dstAmount,
                    _quote.deadline,
                    _quote.nonce,
                    _quote.sender,
                    _quote.receiver,
                    _quote.refundTo,
                    _quote.liquidityProvider
                )
            );
    }

    function getRfqFee(uint64 _chainId, uint256 _amount) public view returns (uint256) {
        uint32 feePerc = feePercOverride[_chainId];
        if (feePerc == 0) {
            feePerc = feePercGlobal;
        }
        return (_amount * feePerc) / 1e6;
    }

    function getMsgFee(bytes calldata _message) public view returns (uint256) {
        return IMessageBus(messageBus).calcFee(_message);
    }

    function receiveMsgAndCheckHash(
        bytes calldata _message,
        MsgDataTypes.RouteInfo calldata _route,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers,
        bytes32 _quoteHash
    ) private {
        bytes32 expectedQuoteHash = bytes32(_message);
        require(_quoteHash == expectedQuoteHash, "Rfq: quote hash mismatch");
        if (unconsumedMsg[_quoteHash] == MessageType.Null) {
            IMessageBus(messageBus).executeMessage(_message, _route, _sigs, _signers, _powers);
        }
        assert(unconsumedMsg[_quoteHash] != MessageType.Null);
    }

    //=========================== admin operations ==========================

    function setRemoteRfqContracts(uint64[] calldata _chainIds, address[] calldata _remoteRfqContracts)
        external
        onlyOwner
    {
        require(_chainIds.length == _remoteRfqContracts.length, "Rfq: length mismatch");
        for (uint256 i = 0; i < _chainIds.length; i++) {
            remoteRfqContracts[_chainIds[i]] = _remoteRfqContracts[i];
        }
        emit RfqContractsUpdated(_chainIds, _remoteRfqContracts);
    }

    function setFeePerc(uint64[] calldata _chainIds, uint32[] calldata _feePercs) external onlyGovernor {
        require(_chainIds.length == _feePercs.length, "Rfq: length mismatch");
        for (uint256 i = 0; i < _chainIds.length; i++) {
            require(_feePercs[i] < 1e6, "Rfq: fee percentage too large");
            if (_chainIds[i] == 0) {
                feePercGlobal = _feePercs[i];
            } else {
                feePercOverride[_chainIds[i]] = _feePercs[i];
            }
        }
        emit FeePercUpdated(_chainIds, _feePercs);
    }

    function setTreasuryAddr(address _treasuryAddr) external onlyOwner {
        treasuryAddr = _treasuryAddr;
        emit TreasuryAddrUpdated(_treasuryAddr);
    }
}
