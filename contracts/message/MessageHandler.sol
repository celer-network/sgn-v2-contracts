// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.9;

import "../interfaces/IBridge.sol";

abstract contract MessageHandler {
    address public bridge;

    mapping(bytes32 => bool) public handledTransfers;

    struct TransferInfo {
        address sender;
        address token;
        uint256 amount;
        uint64 srcChainId;
        bytes32 srcTransferId;
    }

    constructor(address _bridge) {
        bridge = _bridge;
    }

    function executeMessageWithTransfer(
        bytes calldata _message,
        TransferInfo memory _transfer,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers
    ) external {
        bytes32 domain = keccak256(abi.encodePacked(block.chainid, address(this), "MessageWithTransfer"));
        bytes32 dstTransferId = computeDstTransferId(
            _transfer.sender,
            _transfer.token,
            _transfer.amount,
            _transfer.srcChainId,
            _transfer.srcTransferId
        );
        bytes memory data = abi.encodePacked(domain, dstTransferId, _message);
        IBridge(bridge).verifySigs(data, _sigs, _signers, _powers);
        require(IBridge(bridge).transfers(dstTransferId) == true, "relay not exist");
        require(handledTransfers[dstTransferId] == false, "transfer already handled");
        handledTransfers[dstTransferId] = true;
        handleMessageWithTransfer(_transfer, _message);
    }

    function handleMessageWithTransfer(TransferInfo memory _transfer, bytes memory _message) private {
        handleMessageWithTransfer(_transfer.sender, _transfer.token, _transfer.amount, _transfer.srcChainId, _message);
    }

    // internal application logic to handle transfer message
    function handleMessageWithTransfer(
        address _sender,
        address _token,
        uint256 _amount,
        uint64 _srcChainId,
        bytes memory _message
    ) internal virtual;

    function executeMessage(
        address _sender,
        uint64 _srcChainId,
        bytes calldata _message,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers
    ) external {
        bytes32 domain = keccak256(abi.encodePacked(block.chainid, address(this), "Message"));
        IBridge(bridge).verifySigs(abi.encodePacked(domain, _sender, _srcChainId, _message), _sigs, _signers, _powers);
        handleMessage(_sender, _srcChainId, _message);
    }

    function handleMessage(
        address _sender,
        uint64 _srcChainId,
        bytes memory _message
    ) internal virtual;

    // ============== utils ==============

    function computeDstTransferId(
        address _sender,
        address _token,
        uint256 _amount,
        uint64 _srcChainId,
        bytes32 _srcTransferId
    ) internal view returns (bytes32) {
        bytes32 transferId = keccak256(
            abi.encodePacked(
                _sender,
                address(this),
                _token,
                _amount,
                _srcChainId,
                uint64(block.chainid),
                _srcTransferId
            )
        );
        return transferId;
    }
}
