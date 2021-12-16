// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.9;

import "../AppTemplate.sol";

contract BatchTransfer is AppTemplate {
    using SafeERC20 for IERC20;

    struct TransferRequest {
        uint64 nonce;
        address[] accounts;
        uint256[] amounts;
        address sender;
    }

    struct TransferReceipt {
        uint64 nonce;
    }

    constructor(address _bridge, address _msgBus) AppTemplate(_bridge, _msgBus) {}

    // ============== functions and states on source chain ==============

    uint64 nonce;

    struct BatchTransferStatus {
        bytes32 h; // hash(receiver, dstChainId)
        bool done;
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
        uint256 minRecv = _amount - (_amount * _maxSlippage) / 1e6;
        require(minRecv > totalAmt, "invalid maxSlippage");
        nonce += 1;
        status[nonce] = BatchTransferStatus({h: keccak256(abi.encodePacked(_receiver, _dstChainId)), done: false});
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        TransferRequest memory transfer = TransferRequest({
            nonce: nonce,
            accounts: _accounts,
            amounts: _amounts,
            sender: msg.sender
        });
        // app template util function
        transferWithMessage(_receiver, _token, _amount, _dstChainId, nonce, _maxSlippage, abi.encode(transfer));
    }

    // handler function required by app template
    function handleMessage(
        address _sender,
        uint64 _srcChainId,
        bytes memory _message
    ) internal override {
        TransferReceipt memory receipt = abi.decode((_message), (TransferReceipt));
        require(status[receipt.nonce].h == keccak256(abi.encodePacked(_sender, _srcChainId)));
        status[receipt.nonce].done = true;
    }

    // ============== functions on destination chain ==============

    // handler function required by app template
    function handleMessageWithTransfer(
        address _sender,
        address _token,
        uint256 _amount,
        uint64 _srcChainId,
        bytes memory _message
    ) internal override {
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
        TransferReceipt memory receipt = TransferReceipt({nonce: transfer.nonce});
        // app template util function
        sendMessage(_sender, _srcChainId, abi.encode(receipt));
    }
}
