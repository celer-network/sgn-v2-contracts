// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.8.9;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../framework/MessageSenderApp.sol";
import "../framework/MessageReceiverApp.sol";
import "../../safeguard/Pauser.sol";

interface INativeWrap {
    function deposit() external payable;

    function withdraw(uint256) external;
}

/** @title rfq contract */
contract RFQ is MessageSenderApp, MessageReceiverApp, Pauser, ReentrancyGuard {
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
        DepositedNormal, // sender deposited non-native token               || location: src chain
        DepositedNative, // sender deposited native token                   || location: src chain
        ReleasedNormal, // released non-native token to liquidityProvider  || location: src chain
        ReleasedNative, // released native token to liquidityProvider      || location: src chain
        RefundedNormal, // refunded non-native token to refundTo/Sender    || location: src chain
        RefundedNative, // refunded native token to refundTo/Sender        || location: src chain
        ExecutedNormal, // transferred non-native token to receiver        || location: dst chain
        ExecutedNative // transferred native token to reciever            || location: dst chain
    }

    address public nativeWrap;
    mapping(uint64 => address) public remoteRfqContracts;
    // quoteHsh => bool
    mapping(bytes32 => bool) public unconsumedMsg;
    // quoteHash => QuoteStatus
    mapping(bytes32 => QuoteStatus) public quotes;

    address public treasuryAddr;
    uint32 public feePercGlobal;
    // dstChainId => feePercOverride
    mapping(uint64 => uint32) public feePercOverride;
    // tokenAddr => feeBalance
    mapping(address => uint256) public uncollectedFee;

    event SrcDeposited(bytes32 quoteHash, Quote quote);
    event DstTransferred(bytes32 quoteHash);
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
        (bytes32 quoteHash, address msgReceiver) = _srcDepositCheck(_quote, _submissionDeadline);
        quotes[quoteHash] = QuoteStatus.DepositedNormal;
        bytes memory message = abi.encode(quoteHash);
        sendMessage(msgReceiver, _quote.dstChainId, message, msg.value);
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
        require(_quote.srcToken == nativeWrap, "Rfq: mismatch src token");
        require(msg.value >= _quote.srcAmount, "Rfq: insufficient amount");
        (bytes32 quoteHash, address msgReceiver) = _srcDepositCheck(_quote, _submissionDeadline);
        quotes[quoteHash] = QuoteStatus.DepositedNative;
        bytes memory message = abi.encode(quoteHash);
        sendMessage(msgReceiver, _quote.dstChainId, message, msg.value - _quote.srcAmount);
        INativeWrap(nativeWrap).deposit{value: _quote.srcAmount}();
        emit SrcDeposited(quoteHash, _quote);
        return quoteHash;
    }

    function _srcDepositCheck(Quote calldata _quote, uint64 _submissionDeadline)
        private
        view
        returns (bytes32, address)
    {
        require(_submissionDeadline > block.timestamp, "Rfq: past submission deadline");
        require(
            _quote.receiver != address(0) && _quote.liquidityProvider != address(0),
            "Rfq: receiver and liquidityProvider should not be 0 address"
        );
        require(_quote.srcChainId == uint64(block.chainid), "Rfq: mismatch src chainId");
        require(_quote.sender == msg.sender, "Rfq: mismatch sender");
        bytes32 quoteHash = getQuoteHash(_quote);
        require(quotes[quoteHash] == QuoteStatus.Null, "Rfq: quote hash exists");
        uint256 rfqFee = getRFQFee(_quote.dstChainId, _quote.srcAmount);
        require(rfqFee <= _quote.srcAmount, "Rfq: too small amount to cover protocol fee");
        address msgReciever = remoteRfqContracts[_quote.dstChainId];
        require(msgReciever != address(0), "Rfq: no rfq contract on dst chain");
        return (quoteHash, msgReciever);
    }

    function dstTransfer(Quote calldata _quote) external payable whenNotPaused {
        (bytes32 quoteHash, address msgReceiver) = _dstTransferCheck(_quote);
        quotes[quoteHash] = QuoteStatus.ExecutedNormal;
        bytes memory message = abi.encode(quoteHash);
        sendMessage(msgReceiver, _quote.srcChainId, message, msg.value);
        IERC20(_quote.dstToken).safeTransferFrom(msg.sender, _quote.receiver, _quote.dstAmount);
        emit DstTransferred(quoteHash);
    }

    function dstTransferNative(Quote calldata _quote) external payable whenNotPaused {
        require(nativeWrap != address(0), "Rfq: native wrap not set");
        require(_quote.dstToken == nativeWrap, "Rfq: mismatch dst token");
        require(msg.value >= _quote.dstAmount, "Rfq: insufficient amount");
        (bytes32 quoteHash, address msgReceiver) = _dstTransferCheck(_quote);
        quotes[quoteHash] = QuoteStatus.ExecutedNative;
        bytes memory message = abi.encode(quoteHash);
        sendMessage(msgReceiver, _quote.srcChainId, message, msg.value - _quote.dstAmount);
        {
            (bool sent, ) = _quote.receiver.call{value: _quote.dstAmount, gas: 50000}("");
            require(sent, "Rfq: failed to send native token");
        }
        emit DstTransferred(quoteHash);
    }

    function _dstTransferCheck(Quote calldata _quote) private view returns (bytes32, address) {
        require(_quote.deadline > block.timestamp, "Rfq: past release deadline");
        require(_quote.dstChainId == uint64(block.chainid), "Rfq: mismatch dst chainId");
        bytes32 quoteHash = getQuoteHash(_quote);
        require(quotes[quoteHash] == QuoteStatus.Null, "Rfq: quote already executed");
        address msgReceiver = remoteRfqContracts[_quote.srcChainId];
        require(msgReceiver != address(0), "Rfq: no rfq contract on src chain");
        return (quoteHash, msgReceiver);
    }

    function requestRefund(
        Quote calldata _quote,
        bytes calldata _message,
        MsgDataTypes.RouteInfo calldata _route,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers
    ) external payable nonReentrant whenNotPaused {
        require(_quote.deadline < block.timestamp, "Rfq: not past release deadline");
        bytes32 quoteHash = getQuoteHash(_quote);
        receiveMsgAndCheckHash(_message, _route, _sigs, _signers, _powers, quoteHash);
        require(quotes[quoteHash] == QuoteStatus.Null, "Rfq: quote already executed");
        delete unconsumedMsg[quoteHash];

        address _receiver = remoteRfqContracts[_quote.srcChainId];
        require(_receiver != address(0), "Rfq: no rfq contract on src chain");
        bytes memory message = abi.encode(quoteHash);
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
        (bytes32 quoteHash, uint256 amount) = _srcRelease(_quote, _message, _route, _sigs, _signers, _powers);
        quotes[quoteHash] = QuoteStatus.ReleasedNormal;
        IERC20(_quote.srcToken).safeTransfer(_quote.liquidityProvider, amount);
        emit SrcReleased(quoteHash, _quote.liquidityProvider, _quote.srcToken, amount);
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
        require(_quote.srcToken == nativeWrap, "Rfq: mismatch src token");
        (bytes32 quoteHash, uint256 amount) = _srcRelease(_quote, _message, _route, _sigs, _signers, _powers);
        quotes[quoteHash] = QuoteStatus.ReleasedNative;
        INativeWrap(_quote.srcToken).withdraw(amount);
        {
            (bool sent, ) = _quote.liquidityProvider.call{value: amount, gas: 50000}("");
            require(sent, "failed to send native token");
        }
        emit SrcReleased(quoteHash, _quote.liquidityProvider, _quote.srcToken, amount);
    }

    function _srcRelease(
        Quote calldata _quote,
        bytes calldata _message,
        MsgDataTypes.RouteInfo calldata _route,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers
    ) private returns (bytes32, uint256) {
        bytes32 quoteHash = getQuoteHash(_quote);
        receiveMsgAndCheckHash(_message, _route, _sigs, _signers, _powers, quoteHash);
        require(
            quotes[quoteHash] == QuoteStatus.DepositedNormal || quotes[quoteHash] == QuoteStatus.DepositedNative,
            "Rfq: incorrect quote hash"
        );
        uint256 amount = _deductAndAccumulateFee(_quote);
        delete unconsumedMsg[quoteHash];
        return (quoteHash, amount);
    }

    function _deductAndAccumulateFee(Quote calldata _quote) private returns (uint256) {
        uint256 fee = getRFQFee(_quote.dstChainId, _quote.srcAmount);
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
        quotes[quoteHash] = QuoteStatus.RefundedNormal;
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
        require(_quote.srcToken == nativeWrap, "Rfq: mismatch src token");
        bytes32 quoteHash = _executeRefund(_quote, _message, _route, _sigs, _signers, _powers);
        quotes[quoteHash] = QuoteStatus.RefundedNative;
        address receiver = (_quote.refundTo == address(0)) ? _quote.sender : _quote.refundTo;
        INativeWrap(_quote.srcToken).withdraw(_quote.srcAmount);
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
        receiveMsgAndCheckHash(_message, _route, _sigs, _signers, _powers, quoteHash);
        require(
            quotes[quoteHash] == QuoteStatus.DepositedNormal || quotes[quoteHash] == QuoteStatus.DepositedNative,
            "Rfq: incorrect quote hash"
        );
        delete unconsumedMsg[quoteHash];
        return quoteHash;
    }

    function executeMessage(
        address _sender,
        uint64 _srcChainId,
        bytes calldata _message,
        address // executor
    ) external payable override onlyMessageBus returns (ExecutionStatus) {
        address expectedSender = remoteRfqContracts[_srcChainId];
        if (expectedSender != _sender) {
            return ExecutionStatus.Retry;
        }

        bytes32 quoteHash = abi.decode(_message, (bytes32));
        unconsumedMsg[quoteHash] = true;

        emit MessageReceived(quoteHash);
        return ExecutionStatus.Success;
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

    function getRFQFee(uint64 _dstChainId, uint256 _amount) public view returns (uint256) {
        uint32 feePerc = feePercOverride[_dstChainId];
        if (feePerc == 0) {
            feePerc = feePercGlobal;
        }
        return (_amount * feePerc) / 1e6;
    }

    function receiveMsgAndCheckHash(
        bytes calldata _message,
        MsgDataTypes.RouteInfo calldata _route,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers,
        bytes32 _quoteHash
    ) private {
        bytes32 expectedQuoteHash = abi.decode(_message, (bytes32));
        require(_quoteHash == expectedQuoteHash, "Rfq: mismatch quote hash");
        if (unconsumedMsg[_quoteHash] == false) {
            IMessageBus(messageBus).executeMessage(_message, _route, _sigs, _signers, _powers);
        }
        assert(unconsumedMsg[_quoteHash] == true);
    }

    function collectFee(address _token) external {
        require(treasuryAddr != address(0), "Rfq: 0 treasury address");
        IERC20(_token).safeTransfer(treasuryAddr, uncollectedFee[_token]);
        emit FeeCollected(treasuryAddr, _token, uncollectedFee[_token]);
    }

    //=========================== admin operations ==========================

    function setRemoteRfqContracts(uint64[] calldata _chainIds, address[] calldata _remoteRfqContracts)
        external
        onlyOwner
    {
        require(_chainIds.length == _remoteRfqContracts.length, "Rfq: mismatch length");
        for (uint256 i = 0; i < _chainIds.length; i++) {
            remoteRfqContracts[_chainIds[i]] = _remoteRfqContracts[i];
        }
        emit RfqContractsUpdated(_chainIds, _remoteRfqContracts);
    }

    function setFeePerc(uint64[] calldata _chainIds, uint32[] calldata _feePercs) external onlyOwner {
        require(_chainIds.length == _feePercs.length, "Rfq: mismatch length");
        for (uint256 i = 0; i < _chainIds.length; i++) {
            require(_feePercs[i] < 1e6, "Rfq: too large fee percentage");
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
