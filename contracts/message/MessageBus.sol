// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.9;

contract MessageBus {
    event TransferMessage(
        address indexed sender,
        uint256 dstChainId,
        address dstContract,
        address bridge,
        bytes32 srcTransferId,
        bytes message
    );

    function sendTransferMessage(
        uint256 _dstChainId,
        address _dstContract,
        address _bridge,
        bytes32 _srcTransferId,
        bytes calldata _message
    ) external {
        emit TransferMessage(msg.sender, _dstChainId, _dstContract, _bridge, _srcTransferId, _message);
    }
}
