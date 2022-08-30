// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.9;

import "../../framework/MessageSenderApp.sol";
import "../../framework/MessageReceiverApp.sol";

/** @title Sample app to test message passing flow, not for production use */
contract BatchTransfer is MessageSenderApp, MessageReceiverApp {
    using SafeERC20 for IERC20;

    struct TransferRequest {
        uint64 nonce;
        address[] accounts;
        uint256[] amounts;
        address sender;
    }

    enum TransferStatus {
        Null,
        Success,
        Fail
    }

    struct TransferReceipt {
        uint64 nonce;
        TransferStatus status;
    }

    constructor(address _messageBus) {
        messageBus = _messageBus;
    }

    // ============== functions and states on source chain ==============

    uint64 nonce;

    struct BatchTransferStatus {
        bytes32 h; // hash(receiver, dstChainId)
        TransferStatus status;
    }
    mapping(uint64 => BatchTransferStatus) public status; // nonce -> BatchTransferStatus

    modifier onlyEOA() {
        require(msg.sender == tx.origin, "Not EOA");
        _;
    }

    function batchTransfer(
        address _receiver,
        address _token,
        uint256 _amount,
        uint64 _dstChainId,
        uint32 _maxSlippage,
        MsgDataTypes.BridgeSendType _bridgeSendType,
        address[] calldata _accounts,
        uint256[] calldata _amounts
    ) external payable onlyEOA {
        uint256 totalAmt;
        for (uint256 i = 0; i < _amounts.length; i++) {
            totalAmt += _amounts[i];
        }
        // commented out the slippage check below to trigger failure case for handleFailedMessageWithTransfer testing
        // uint256 minRecv = _amount - (_amount * _maxSlippage) / 1e6;
        // require(minRecv > totalAmt, "invalid maxSlippage");
        nonce += 1;
        status[nonce] = BatchTransferStatus({
            h: keccak256(abi.encodePacked(_receiver, _dstChainId)),
            status: TransferStatus.Null
        });
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        bytes memory message = abi.encode(
            TransferRequest({nonce: nonce, accounts: _accounts, amounts: _amounts, sender: msg.sender})
        );
        // MsgSenderApp util function
        sendMessageWithTransfer(
            _receiver,
            _token,
            _amount,
            _dstChainId,
            nonce,
            _maxSlippage,
            message,
            _bridgeSendType,
            msg.value
        );
    }

    // called on source chain for handling of bridge failures (bad liquidity, bad slippage, etc...)
    function executeMessageWithTransferRefund(
        address _token,
        uint256 _amount,
        bytes calldata _message,
        address // executor
    ) external payable override onlyMessageBus returns (ExecutionStatus) {
        TransferRequest memory transfer = abi.decode((_message), (TransferRequest));
        IERC20(_token).safeTransfer(transfer.sender, _amount);
        return ExecutionStatus.Success;
    }

    // ============== functions on destination chain ==============

    // handler function required by MsgReceiverApp
    function executeMessage(
        address _sender,
        uint64 _srcChainId,
        bytes memory _message,
        address // executor
    ) external payable override onlyMessageBus returns (ExecutionStatus) {
        TransferReceipt memory receipt = abi.decode((_message), (TransferReceipt));
        require(status[receipt.nonce].h == keccak256(abi.encodePacked(_sender, _srcChainId)), "invalid message");
        status[receipt.nonce].status = receipt.status;
        return ExecutionStatus.Success;
    }

    // handler function required by MsgReceiverApp
    function executeMessageWithTransfer(
        address _sender,
        address _token,
        uint256 _amount,
        uint64 _srcChainId,
        bytes memory _message,
        address // executor
    ) external payable override onlyMessageBus returns (ExecutionStatus) {
        TransferRequest memory transfer = abi.decode((_message), (TransferRequest));
        uint256 totalAmt;
        for (uint256 i = 0; i < transfer.accounts.length; i++) {
            IERC20(_token).safeTransfer(transfer.accounts[i], transfer.amounts[i]);
            totalAmt += transfer.amounts[i];
        }
        uint256 remainder = _amount - totalAmt;
        if (_amount > totalAmt) {
            // transfer the remainder of the money to sender as fee for executing this transfer
            IERC20(_token).safeTransfer(transfer.sender, remainder);
        }
        bytes memory message = abi.encode(TransferReceipt({nonce: transfer.nonce, status: TransferStatus.Success}));
        // MsgSenderApp util function
        sendMessage(_sender, _srcChainId, message, msg.value);
        return ExecutionStatus.Success;
    }

    // handler function required by MsgReceiverApp
    // called only if handleMessageWithTransfer above was reverted
    function executeMessageWithTransferFallback(
        address _sender,
        address _token,
        uint256 _amount,
        uint64 _srcChainId,
        bytes memory _message,
        address // executor
    ) external payable override onlyMessageBus returns (ExecutionStatus) {
        TransferRequest memory transfer = abi.decode((_message), (TransferRequest));
        IERC20(_token).safeTransfer(transfer.sender, _amount);
        bytes memory message = abi.encode(TransferReceipt({nonce: transfer.nonce, status: TransferStatus.Fail}));
        sendMessage(_sender, _srcChainId, message, msg.value);
        return ExecutionStatus.Success;
    }
}
