// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.9;

import "../framework/MsgSenderApp.sol";
import "../framework/MsgReceiverApp.sol";

// sample app to test message passing flow, not for production use

contract BatchTransfer is MsgSenderApp, MsgReceiverApp {
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

    constructor(address _liquidityBridge, address _msgBus) {
        liquidityBridge = _liquidityBridge;
        msgBus = _msgBus;
    }

    // ============== functions and states on source chain ==============

    uint64 nonce;

    struct BatchTransferStatus {
        bytes32 h; // hash(receiver, dstChainId)
        TransferStatus status;
    }
    mapping(uint64 => BatchTransferStatus) public status; // nonce -> BatchTransferStatus

    function batchTransfer(
        address _receiver,
        address _token,
        uint256 _amount,
        uint64 _dstChainId,
        uint32 _maxSlippage,
        address[] calldata _accounts,
        uint256[] calldata _amounts
    ) external {
        uint256 totalAmt;
        for (uint256 i = 0; i < _amounts.length; i++) {
            totalAmt += _amounts[i];
        }
        // comented out the slippage check below to trigger failure case for handleFailedMessageWithTransfer testing
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
        sendMessageWithTransfer(_receiver, _token, _amount, _dstChainId, nonce, _maxSlippage, message);
    }

    // handler function required by MsgReceiverApp
    function executeMessage(
        address _sender,
        uint64 _srcChainId,
        bytes memory _message
    ) external override onlyMessagegBus {
        TransferReceipt memory receipt = abi.decode((_message), (TransferReceipt));
        require(status[receipt.nonce].h == keccak256(abi.encodePacked(_sender, _srcChainId)), "invalid message");
        status[receipt.nonce].status = receipt.status;
    }

    // ============== functions on destination chain ==============

    // handler function required by MsgReceiverApp
    function executeMessageWithTransfer(
        address _sender,
        address _token,
        uint256 _amount,
        uint64 _srcChainId,
        bytes memory _message
    ) external override onlyMessagegBus {
        TransferRequest memory transfer = abi.decode((_message), (TransferRequest));
        uint256 totalAmt;
        for (uint256 i = 0; i < transfer.accounts.length; i++) {
            IERC20(_token).safeTransfer(transfer.accounts[i], transfer.amounts[i]);
            totalAmt += transfer.amounts[i];
        }
        uint256 remainder = _amount - totalAmt;
        if (_amount > totalAmt) {
            IERC20(_token).safeTransfer(transfer.sender, remainder);
        }
        bytes memory message = abi.encode(TransferReceipt({nonce: transfer.nonce, status: TransferStatus.Success}));
        // MsgSenderApp util function
        sendMessage(_sender, _srcChainId, message);
    }

    // handler function required by MsgReceiverApp
    // called only if handleMessageWithTransfer above was reverted
    function executeFailedMessageWithTransfer(
        address _sender,
        address _token,
        uint256 _amount,
        uint64 _srcChainId,
        bytes memory _message
    ) external override onlyMessagegBus {
        TransferRequest memory transfer = abi.decode((_message), (TransferRequest));
        IERC20(_token).safeTransfer(transfer.sender, _amount);
        bytes memory message = abi.encode(TransferReceipt({nonce: transfer.nonce, status: TransferStatus.Fail}));
        sendMessage(_sender, _srcChainId, message);
    }
}
