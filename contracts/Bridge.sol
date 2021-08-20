// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./libraries/PbBridge.sol";

contract Bridge {
    using SafeERC20 for IERC20;

    event Send(
        bytes32 transferId,
        address sender,
        address receiver,
        address token,
        uint256 amount,
        uint64 dstChainId,
        uint64 nonce
    );

    event Relay(
        bytes32 transferId,
        address sender,
        address receiver,
        address token,
        uint256 amount,
        uint64 srcChainId,
        uint64 nonce,
        bytes32 srcTransferId
    );

    mapping(bytes32 => bool) public transfers;

    bytes32 stakingRoot;

    function send(
        address _receiver,
        address _token,
        uint256 _amount,
        uint64 _dstChainId,
        uint64 _nonce
    ) external {
        require(_amount > 0, "invalid amount");
        bytes32 transferId = keccak256(
            abi.encodePacked(msg.sender, _receiver, _token, _amount, _dstChainId, _nonce, block.chainid)
        );
        require(transfers[transferId] == false, "transfer exists");
        transfers[transferId] = true;
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);

        emit Send(transferId, msg.sender, _receiver, _token, _amount, _dstChainId, _nonce);
    }

    function relay(bytes calldata _relayRequest, bytes[] calldata _sigs) external {
        verifySignatures(_relayRequest, _sigs);
        PbBridge.Relay memory request = PbBridge.decRelay(_relayRequest);
        require(request.dstChainId == block.chainid, "dst chainId not match");

        bytes32 transferId = keccak256(
            abi.encodePacked(
                request.sender,
                request.receiver,
                request.token,
                request.amount,
                request.srcChainId,
                request.dstChainId,
                request.srcTransferId,
                request.nonce
            )
        );
        require(transfers[transferId] == false, "transfer exists");
        transfers[transferId] = true;
        IERC20(request.token).safeTransfer(request.receiver, request.amount);

        emit Relay(
            transferId,
            request.sender,
            request.receiver,
            request.token,
            request.amount,
            request.srcChainId,
            request.nonce,
            request.srcTransferId
        );
    }

    function verifySignatures(bytes memory _msg, bytes[] memory _sigs) public view {}
}
