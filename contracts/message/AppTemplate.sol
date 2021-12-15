// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IBridge.sol";
import "../libraries/PbBridge.sol";
import "./MessageBus.sol";

abstract contract AppTemplate {
    using SafeERC20 for IERC20;

    address public bridge;
    address public msgBus;
    uint64 transferNonce;

    mapping(bytes32 => bool) public transfers;

    constructor(address _bridge, address _msgBus) {
        bridge = _bridge;
        msgBus = _msgBus;
    }

    // ============== functions on source chain ==============

    // called by application logic on source chain
    function transferWithMessage(
        address _receiver,
        address _token,
        uint256 _amount,
        uint64 _dstChainId,
        uint32 _maxSlippage,
        bytes memory _message
    ) internal {
        transferNonce += 1;
        IERC20(_token).safeIncreaseAllowance(address(bridge), _amount);
        IBridge(bridge).send(_receiver, _token, _amount, _dstChainId, transferNonce, _maxSlippage);
        bytes32 srcTransferId = computeSrcTransferId(_receiver, _token, _amount, _dstChainId, transferNonce);
        MessageBus(msgBus).sendMessageWithTransfer(_receiver, _dstChainId, bridge, srcTransferId, _message);
    }

    function sendMessage(
        address _receiver,
        uint64 _dstChainId,
        bytes memory _message
    ) internal {
        MessageBus(msgBus).sendMessage(_receiver, _dstChainId, _message);
    }

    // ============== functions on destination chain ==============

    // called by external executor on destination chain
    function executeMessageWithTransfer(
        bytes calldata _message,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers,
        bytes calldata _relayTransfer
    ) external {
        bytes32 domain = keccak256(abi.encodePacked(block.chainid, address(this), "MessageWithTransfer"));
        PbBridge.Relay memory relay = PbBridge.decRelay(_relayTransfer);
        bytes32 dstTransferId = computeDstTransferId(
            relay.sender,
            relay.receiver,
            relay.token,
            relay.amount,
            relay.srcChainId,
            relay.srcTransferId
        );
        bytes memory data = abi.encodePacked(domain, dstTransferId, _message);
        IBridge(bridge).verifySigs(data, _sigs, _signers, _powers);
        require(IBridge(bridge).transfers(dstTransferId) == true, "relay not exist");
        require(relay.receiver == address(this), "transfer receiver is not this contract");
        require(transfers[dstTransferId] == false, "transfer already processed");
        transfers[dstTransferId] = true;
        handleMessageWithTransfer(relay, _message);
    }

    // avoid stack too deep
    function handleMessageWithTransfer(PbBridge.Relay memory _relay, bytes calldata _message) private {
        handleMessageWithTransfer(_relay.sender, _relay.token, _relay.amount, _relay.srcChainId, _message);
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
    ) internal virtual {}

    // ============== private utils ==============

    function computeSrcTransferId(
        address _receiver,
        address _token,
        uint256 _amount,
        uint64 _dstChainId,
        uint64 _nonce
    ) private view returns (bytes32) {
        bytes32 transferId = keccak256(
            abi.encodePacked(address(this), _receiver, _token, _amount, _dstChainId, _nonce, uint64(block.chainid))
        );
        return transferId;
    }

    function computeDstTransferId(
        address _sender,
        address _receiver,
        address _token,
        uint256 _amount,
        uint64 _srcChainId,
        bytes32 _srcTransferId
    ) private view returns (bytes32) {
        bytes32 transferId = keccak256(
            abi.encodePacked(_sender, _receiver, _token, _amount, _srcChainId, uint64(block.chainid), _srcTransferId)
        );
        return transferId;
    }
}
