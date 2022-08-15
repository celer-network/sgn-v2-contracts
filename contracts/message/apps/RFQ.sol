// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.8.9;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../framework/MessageSenderApp.sol";
import "../framework/MessageReceiverApp.sol";

/** @title rfq contract */
contract RFQ is MessageSenderApp, MessageReceiverApp {
    using SafeERC20 for IERC20;

    struct AgreementDetail {
        uint64 srcChainId;
        address srcToken;
        uint256 amount1;
        uint64 dstChainId;
        address dstToken;
        uint256 amount2;
        uint64 submissionDeadline;
        uint64 releaseDeadline;
        uint64 nonce;
    }

    struct AssetDetail {
        address token;
        uint256 amount;
        address recipient;
    }

    mapping(uint64 => address) public apps;
    mapping(bytes32 => bool) public records;
    mapping(bytes32 => AssetDetail) public vault;
    uint32 public feePercGlobal;
    mapping(uint64 => uint32) public feePercOverride;

    event MessageReceivedWithTransfer(
        address token,
        uint256 amount,
        address sender,
        uint64 srcChainId,
        address receiver,
        bytes message
    );
    event Refunded(address receiver, address token, uint256 amount, bytes message);
    event MessageReceived(address sender, uint64 srcChainId, uint64 nonce, bytes message);
    event Message2Received(bytes sender, uint64 srcChainId, uint64 nonce, bytes message);
    event AppUpdated(uint64 chainId, address app);

    constructor(address _messageBus) {
        messageBus = _messageBus;
    }

    function sendMessage1(
        AgreementDetail calldata _agrDetail,
        address _dstRecipient,
        address _refundTo,
        address _srcRecipient
    ) external payable {
        require(_agrDetail.submissionDeadline > block.timestamp, "past submission deadline");
        bytes32 memory agrHash = getAgrHash(_agrDetail, msg.sender, _dstRecipient);
        require(!records[agrHash], "agreement hash already existed");



        bytes memory message = abi.encode(nonce, _message);
        sendMessage(_receiver, _dstChainId, message, msg.value);
    }

    function getAgrHash(
        AgreementDetail calldata _agrDetail,
        address _usr,
        address _dstRecipient
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(
                keccak256(abi.encodePacked(
                    _agrDetail.srcChainId,
                    _agrDetail.srcToken,
                    _agrDetail.amount1,
                    _agrDetail.dstChainId,
                    _agrDetail.dstToken,
                    _agrDetail.amount2,
                    _agrDetail.submissionDeadline,
                    _agrDetail.releaseDeadline,
                    _agrDetail.nonce)),
                _usr,
                _dstRecipient
            ));
    }

    function getRFQFee(
        uint64 _srcChainId,
        uint64 _dstChainId,
        uint256 _amount
    ) public view returns (uint256) {
        return ;
    }

    function sendMessage(
        bytes calldata _receiver,
        uint64 _dstChainId,
        bytes calldata _message
    ) external payable {
        bytes memory message = abi.encode(nonce, _message);
        nonce++;
        sendMessage(_receiver, _dstChainId, message, msg.value);
    }

    function sendMessages(
        address _receiver,
        uint64 _dstChainId,
        bytes[] calldata _messages,
        uint256[] calldata _fees
    ) external payable {
        for (uint256 i = 0; i < _messages.length; i++) {
            bytes memory message = abi.encode(nonce, _messages[i]);
            nonce++;
            sendMessage(_receiver, _dstChainId, message, _fees[i]);
        }
    }

    function sendMessageWithNonce(
        address _receiver,
        uint64 _dstChainId,
        bytes calldata _message,
        uint64 _nonce
    ) external payable {
        bytes memory message = abi.encode(_nonce, _message);
        sendMessage(_receiver, _dstChainId, message, msg.value);
    }

    function executeMessage(
        address _sender,
        uint64 _srcChainId,
        bytes calldata _message,
        address // executor
    ) external payable override onlyMessageBus returns (ExecutionStatus) {
        (uint64 n, bytes memory message) = abi.decode((_message), (uint64, bytes));
        require(n != 100000000000001, "invalid nonce"); // test revert with reason
        if (n == 100000000000002) {
            // test revert without reason
            revert();
        } else if (n == 100000000000003) {
            return ExecutionStatus.Retry;
        }
        emit MessageReceived(_sender, _srcChainId, n, message);
        return ExecutionStatus.Success;
    }

    function executeMessage(
        bytes calldata _sender,
        uint64 _srcChainId,
        bytes calldata _message,
        address // executor
    ) external payable override onlyMessageBus returns (ExecutionStatus) {
        (uint64 n, bytes memory message) = abi.decode((_message), (uint64, bytes));
        emit Message2Received(_sender, _srcChainId, n, message);
        return ExecutionStatus.Success;
    }

    function drainToken(address _token, uint256 _amount) external onlyOwner {
        IERC20(_token).safeTransfer(msg.sender, _amount);
    }

    function registerApp(uint64 _chainId, address _app) external onlyOwner {
        apps[_chainId] = _app;
        emit AppUpdated(_chainId, _app);
    }
}
