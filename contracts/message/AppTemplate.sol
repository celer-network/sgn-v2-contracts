// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./MessageBus.sol";
import "../Bridge.sol";

abstract contract AppTemplate {
    using SafeERC20 for IERC20;

    Bridge public bridge;
    address public msgBus;
    uint64 nonce;

    mapping(bytes32 => bool) public transfers;

    constructor(address _bridge, address _msgBus) {
        bridge = Bridge(payable(_bridge));
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
        address _dstContract,
        bytes memory _message
    ) internal {
        nonce += 1;
        IERC20(_token).safeIncreaseAllowance(address(bridge), _amount);
        bridge.send(_receiver, _token, _amount, _dstChainId, nonce, _maxSlippage);
        bytes32 srcTransferId = computeSrcTransferId(_receiver, _token, _amount, _dstChainId, nonce);
        MessageBus(msgBus).sendTransferMessage(_dstChainId, _dstContract, address(bridge), srcTransferId, _message);
    }

    // ============== functions on destination chain ==============

    // called by external executor on destination chain
    function executeTransferMessage(
        bytes32 _dstTransferId,
        bytes calldata _message,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers,
        address _sender,
        address _receiver,
        address _token,
        uint256 _amount,
        uint64 _srcChainId,
        bytes32 _srcTransferId
    ) external {
        bytes32 domain = keccak256(abi.encodePacked(block.chainid, address(this), "TransferMessage"));
        bridge.verifySigs(abi.encodePacked(domain, _dstTransferId, _message), _sigs, _signers, _powers);
        bytes32 dstTransferId = computeDstTransferId(_sender, _receiver, _token, _amount, _srcChainId, _srcTransferId);
        require(dstTransferId == _dstTransferId, "dst transfer id not match");
        require(bridge.transfers(dstTransferId) == true, "relay not exist");
        require(_receiver == address(this), "transfer receiver is not this contract");
        require(transfers[dstTransferId] == false, "transfer already processed");
        transfers[dstTransferId] = true;
        handleRelayMessage(_sender, _token, _amount, _srcChainId, _message);
    }

    // internal application logic to handle transfer message
    function handleRelayMessage(
        address _sender,
        address _token,
        uint256 _amount,
        uint64 _srcChainId,
        bytes memory _message
    ) internal virtual;

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
