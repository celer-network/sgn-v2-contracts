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

    struct AgreementDetail {
        uint64 srcChainId;
        address srcToken;
        uint256 amount1;
        uint64 dstChainId;
        address dstToken;
        uint256 amount2;
        uint64 releaseDeadline;
        uint64 nonce;
        address usrAddr;
        address dstRecipient;
        address refundTo;
        address srcRecipient;
    }

    mapping(uint64 => address) public apps;
    mapping(bytes32 => bool) public unconsumedMsg;
    mapping(bytes32 => bool) public orderBooks;
    mapping(bytes32 => bool) public filledOrder;
    uint32 public feePercGlobal;
    // dstChainId => feePercOverride
    mapping(uint64 => uint32) public feePercOverride;
    uint64 public safeTime;

    event Msg1Sent(bytes32 hash, AgreementDetail detail, address srcRecipient, uint64 submissionDeadline);
    event Msg2Sent(bytes32 hash);
    event Msg3Sent(bytes32 hash);
    event MessageReceived(bytes32 hash);
    event Msg2Executed(bytes32 hash, address srcRecipient, address srcToken, uint256 amount);
    event Msg3Executed(bytes32 hash, address refundTo, address srcToken, uint256 amount);
    event AppUpdated(uint64 chainId, address app);
    event FeePercUpdated(uint64 chainId, uint32 feePerc);
    event SafeTimeUpdated(uint64 safeTime);

    constructor(address _messageBus) {
        messageBus = _messageBus;
    }

    function sendMessage1(AgreementDetail calldata _agrDetail, uint64 _submissionDeadline)
        external
        payable
        whenNotPaused
        returns (bytes32)
    {
        require(_submissionDeadline > block.timestamp, "past submission deadline");
        require(_agrDetail.releaseDeadline > (block.timestamp + safeTime), "inappropriate release deadline");
        require(
            _agrDetail.dstRecipient != address(0) &&
                _agrDetail.refundTo != address(0) &&
                _agrDetail.srcRecipient != address(0),
            "src/dstRecipient, refundTo should not be 0 address"
        );
        require(_agrDetail.srcChainId == uint64(block.chainid), "mismatch src chainId");
        require(_agrDetail.usrAddr == msg.sender, "mismatch usr addr");

        bytes32 agrHash = getAgrHash(_agrDetail);
        require(orderBooks[agrHash] == false, "still pending order");
        uint256 rfqFee = getRFQFee(_agrDetail.dstChainId, _agrDetail.amount1);
        require(rfqFee <= _agrDetail.amount1, "too small amount to cover protocol fee");
        IERC20(_agrDetail.srcToken).safeTransferFrom(msg.sender, address(this), _agrDetail.amount1);
        orderBooks[agrHash] = true;

        address _receiver = apps[_agrDetail.dstChainId];
        require(_receiver != address(0), "no rfq contract on dst chain");
        bytes memory message = abi.encode(agrHash);
        sendMessage(_receiver, _agrDetail.dstChainId, message, msg.value);
        emit Msg1Sent(agrHash, _agrDetail, _agrDetail.srcRecipient, _submissionDeadline);
        return agrHash;
    }

    function sendMessage2(AgreementDetail calldata _agrDetail) external payable whenNotPaused {
        require(_agrDetail.releaseDeadline > block.timestamp, "past release deadline");
        require(_agrDetail.dstChainId == uint64(block.chainid), "mismatch dst chainId");
        bytes32 agrHash = getAgrHash(_agrDetail);
        require(filledOrder[agrHash] == false, "order already filled");
        IERC20(_agrDetail.dstToken).safeTransferFrom(msg.sender, _agrDetail.dstRecipient, _agrDetail.amount2);
        filledOrder[agrHash] = true;

        address _receiver = apps[_agrDetail.srcChainId];
        require(_receiver != address(0), "no rfq contract on src chain");
        bytes memory message = abi.encode(agrHash);
        sendMessage(_receiver, _agrDetail.srcChainId, message, msg.value);
        emit Msg2Sent(agrHash);
    }

    function executeMsg1AndSendMsg3(
        AgreementDetail calldata _agrDetail,
        bytes calldata _message,
        MsgDataTypes.RouteInfo calldata _route,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers
    ) external payable nonReentrant whenNotPaused {
        require(_agrDetail.releaseDeadline < block.timestamp, "not past release deadline");
        bytes32 agrHash = getAgrHash(_agrDetail);
        receiveMsgAndCheckHash(_message, _route, _sigs, _signers, _powers, agrHash);
        require(filledOrder[agrHash] == false, "order already filled");
        delete unconsumedMsg[agrHash];

        address _receiver = apps[_agrDetail.srcChainId];
        require(_receiver != address(0), "no rfq contract on src chain");
        bytes memory message = abi.encode(agrHash);
        sendMessage(_receiver, _agrDetail.srcChainId, message, msg.value);
        emit Msg3Sent(agrHash);
    }

    function executeMsg2(
        AgreementDetail calldata _agrDetail,
        bytes calldata _message,
        MsgDataTypes.RouteInfo calldata _route,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers
    ) external nonReentrant whenNotPaused {
        bytes32 agrHash = getAgrHash(_agrDetail);
        receiveMsgAndCheckHash(_message, _route, _sigs, _signers, _powers, agrHash);
        require(orderBooks[agrHash] == true, "incorrect agreement hash");
        uint256 amount = _agrDetail.amount1 - getRFQFee(_agrDetail.dstChainId, _agrDetail.amount1);
        delete orderBooks[agrHash];
        delete unconsumedMsg[agrHash];
        IERC20(_agrDetail.srcToken).safeTransfer(_agrDetail.srcRecipient, amount);
        emit Msg2Executed(agrHash, _agrDetail.srcRecipient, _agrDetail.srcToken, amount);
    }

    function executeMsg3(
        AgreementDetail calldata _agrDetail,
        bytes calldata _message,
        MsgDataTypes.RouteInfo calldata _route,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers
    ) external nonReentrant whenNotPaused {
        bytes32 agrHash = getAgrHash(_agrDetail);
        receiveMsgAndCheckHash(_message, _route, _sigs, _signers, _powers, agrHash);
        require(orderBooks[agrHash] == true, "incorrect agreement hash");
        delete orderBooks[agrHash];
        delete unconsumedMsg[agrHash];
        IERC20(_agrDetail.srcToken).safeTransfer(_agrDetail.refundTo, _agrDetail.amount1);
        emit Msg3Executed(agrHash, _agrDetail.refundTo, _agrDetail.srcToken, _agrDetail.amount1);
    }

    function executeMessage(
        address _sender,
        uint64 _srcChainId,
        bytes calldata _message,
        address // executor
    ) external payable override onlyMessageBus returns (ExecutionStatus) {
        address expectedSender = apps[_srcChainId];
        require(expectedSender == _sender, "invalid message sender");

        (bytes32 agrHash) = abi.decode(_message, (bytes32));
        unconsumedMsg[agrHash] = true;

        emit MessageReceived(agrHash);
        return ExecutionStatus.Success;
    }

    //=========================== helper functions ==========================

    function getAgrHash(AgreementDetail calldata _agrDetail) public pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    _agrDetail.srcChainId,
                    _agrDetail.srcToken,
                    _agrDetail.amount1,
                    _agrDetail.dstChainId,
                    _agrDetail.dstToken,
                    _agrDetail.amount2,
                    _agrDetail.releaseDeadline,
                    _agrDetail.nonce,
                    _agrDetail.usrAddr,
                    _agrDetail.dstRecipient,
                    _agrDetail.refundTo,
                    _agrDetail.srcRecipient
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
        bytes32 _agrHash
    ) private {
        (bytes32 expectedAgrHash) = abi.decode(_message, (bytes32));
        require(_agrHash == expectedAgrHash, "mismatch agreement hash");
        if (unconsumedMsg[_agrHash] == false) {
            IMessageBus(messageBus).executeMessage(_message, _route, _sigs, _signers, _powers);
        }
        assert(unconsumedMsg[_agrHash] == true);
    }

    //=========================== admin operations ==========================

    function collectFee(address _token, uint256 _amount) external onlyOwner {
        IERC20(_token).safeTransfer(msg.sender, _amount);
    }

    function setApp(uint64 _chainId, address _app) external onlyOwner {
        apps[_chainId] = _app;
        emit AppUpdated(_chainId, _app);
    }

    function setFeePerc(uint64 _chainId, uint32 _feePerc) external onlyOwner {
        require(_feePerc < 1e6, "too large fee percentage");
        if (_chainId == 0) {
            feePercGlobal = _feePerc;
        } else {
            feePercOverride[_chainId] = _feePerc;
        }
        emit FeePercUpdated(_chainId, _feePerc);
    }

    function setSafeTime(uint64 _safeTime) external onlyOwner {
        safeTime = _safeTime;
        emit SafeTimeUpdated(_safeTime);
    }
}
