// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.8.9;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../framework/MessageSenderApp.sol";
import "../framework/MessageReceiverApp.sol";
import "../../safeguard/Pauser.sol";

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

    mapping(uint64 => address) public remoteRfqContracts;
    mapping(bytes32 => bool) public unconsumedMsg;
    // pending quotes on src chain
    mapping(bytes32 => bool) public quotes;
    // executed quotes on dst chain
    mapping(bytes32 => bool) public executedQuotes;
    address public treasuryAddr;
    uint32 public feePercGlobal;
    // dstChainId => feePercOverride
    mapping(uint64 => uint32) public feePercOverride;
    // tokenAddr => feeBalance
    mapping(address => uint256) public uncollectedFee;

    event SrcDeposited(bytes32 quoteHash, Quote quote, address liquidityProvider);
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
        require(_submissionDeadline > block.timestamp, "past submission deadline");
        require(
            _quote.receiver != address(0) && _quote.liquidityProvider != address(0),
            "receiver and liquidityProvider should not be 0 address"
        );
        require(_quote.srcChainId == uint64(block.chainid), "mismatch src chainId");
        require(_quote.sender == msg.sender, "mismatch sender");
        bytes32 quoteHash = getQuoteHash(_quote);
        require(quotes[quoteHash] == false, "still pending quote");
        uint256 rfqFee = getRFQFee(_quote.dstChainId, _quote.srcAmount);
        require(rfqFee <= _quote.srcAmount, "too small amount to cover protocol fee");
        address _receiver = remoteRfqContracts[_quote.dstChainId];
        require(_receiver != address(0), "no rfq contract on dst chain");

        bytes memory message = abi.encode(quoteHash);
        sendMessage(_receiver, _quote.dstChainId, message, msg.value);
        IERC20(_quote.srcToken).safeTransferFrom(msg.sender, address(this), _quote.srcAmount);
        quotes[quoteHash] = true;
        emit SrcDeposited(quoteHash, _quote, _quote.liquidityProvider);
        return quoteHash;
    }

    function dstTransfer(Quote calldata _quote) external payable whenNotPaused {
        require(_quote.deadline > block.timestamp, "past release deadline");
        require(_quote.dstChainId == uint64(block.chainid), "mismatch dst chainId");
        bytes32 quoteHash = getQuoteHash(_quote);
        require(executedQuotes[quoteHash] == false, "quote already executed");
        address _receiver = remoteRfqContracts[_quote.srcChainId];
        require(_receiver != address(0), "no rfq contract on src chain");

        bytes memory message = abi.encode(quoteHash);
        sendMessage(_receiver, _quote.srcChainId, message, msg.value);
        IERC20(_quote.dstToken).safeTransferFrom(msg.sender, _quote.receiver, _quote.dstAmount);
        executedQuotes[quoteHash] = true;
        emit DstTransferred(quoteHash);
    }

    function requestRefund(
        Quote calldata _quote,
        bytes calldata _message,
        MsgDataTypes.RouteInfo calldata _route,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers
    ) external payable nonReentrant whenNotPaused {
        require(_quote.deadline < block.timestamp, "not past release deadline");
        bytes32 quoteHash = getQuoteHash(_quote);
        receiveMsgAndCheckHash(_message, _route, _sigs, _signers, _powers, quoteHash);
        require(executedQuotes[quoteHash] == false, "quote already executed");
        delete unconsumedMsg[quoteHash];

        address _receiver = remoteRfqContracts[_quote.srcChainId];
        require(_receiver != address(0), "no rfq contract on src chain");
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
        bytes32 quoteHash = getQuoteHash(_quote);
        receiveMsgAndCheckHash(_message, _route, _sigs, _signers, _powers, quoteHash);
        require(quotes[quoteHash] == true, "incorrect quote hash");
        uint256 fee = getRFQFee(_quote.dstChainId, _quote.srcAmount);
        uncollectedFee[_quote.srcToken] += fee;
        uint256 amount = _quote.srcAmount - fee;
        delete quotes[quoteHash];
        delete unconsumedMsg[quoteHash];
        IERC20(_quote.srcToken).safeTransfer(_quote.liquidityProvider, amount);
        emit SrcReleased(quoteHash, _quote.liquidityProvider, _quote.srcToken, amount);
    }

    function executeRefund(
        Quote calldata _quote,
        bytes calldata _message,
        MsgDataTypes.RouteInfo calldata _route,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers
    ) external nonReentrant whenNotPaused {
        bytes32 quoteHash = getQuoteHash(_quote);
        receiveMsgAndCheckHash(_message, _route, _sigs, _signers, _powers, quoteHash);
        require(quotes[quoteHash] == true, "incorrect quote hash");
        delete quotes[quoteHash];
        delete unconsumedMsg[quoteHash];
        address receiver = (_quote.refundTo == address(0)) ? _quote.sender : _quote.refundTo;
        IERC20(_quote.srcToken).safeTransfer(receiver, _quote.srcAmount);
        emit Refunded(quoteHash, receiver, _quote.srcToken, _quote.srcAmount);
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
        require(_quoteHash == expectedQuoteHash, "mismatch quote hash");
        if (unconsumedMsg[_quoteHash] == false) {
            IMessageBus(messageBus).executeMessage(_message, _route, _sigs, _signers, _powers);
        }
        assert(unconsumedMsg[_quoteHash] == true);
    }

    function collectFee(address _token) external {
        require(treasuryAddr != address(0), "0 treasury address");
        IERC20(_token).safeTransfer(treasuryAddr, uncollectedFee[_token]);
        emit FeeCollected(treasuryAddr, _token, uncollectedFee[_token]);
    }

    //=========================== admin operations ==========================

    function setRemoteRfqContracts(uint64[] calldata _chainIds, address[] calldata _remoteRfqContracts)
        external
        onlyOwner
    {
        require(_chainIds.length == _remoteRfqContracts.length, "mismatch length");
        for (uint256 i = 0; i < _chainIds.length; i++) {
            remoteRfqContracts[_chainIds[i]] = _remoteRfqContracts[i];
        }
        emit RfqContractsUpdated(_chainIds, _remoteRfqContracts);
    }

    function setFeePerc(uint64[] calldata _chainIds, uint32[] calldata _feePercs) external onlyOwner {
        require(_chainIds.length == _feePercs.length, "mismatch length");
        for (uint256 i = 0; i < _chainIds.length; i++) {
            require(_feePercs[i] < 1e6, "too large fee percentage");
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
