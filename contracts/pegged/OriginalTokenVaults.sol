// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../interfaces/ISigsVerifier.sol";
import "../libraries/PbPegged.sol";
import "../safeguard/Pauser.sol";
import "../safeguard/VolumeControl.sol";
import "../safeguard/DelayedTransfer.sol";

/**
 * @title the vaults to lock original tokens at the source chain
 */
contract OriginalTokenVaults is ReentrancyGuard, Pauser, VolumeControl, DelayedTransfer {
    using SafeERC20 for IERC20;

    ISigsVerifier public immutable sigsVerifier;

    mapping(bytes32 => bool) public records;

    event Deposited(bytes32 depositId, address account, address token, uint256 amount, uint64 mintChainId);
    event Withdrawn(
        bytes32 withdrawId,
        address receiver,
        address token,
        uint256 amount,
        uint64 refChainId,
        bytes32 refId
    );

    constructor(ISigsVerifier _sigsVerifier) {
        sigsVerifier = _sigsVerifier;
    }

    /**
     * @notice Lock original tokens to trigger mint at a remote chain
     * @param _token local token address
     * @param _amount locked token amount
     * @param _mintChainId destination chainId to mint tokens
     * @param _nonce user input to guarantee unique depositId
     */
    function deposit(
        address _token,
        uint256 _amount,
        uint64 _mintChainId,
        uint64 _nonce
    ) external nonReentrant whenNotPaused {
        bytes32 depId = keccak256(
            abi.encodePacked(msg.sender, _token, _amount, _mintChainId, _nonce, uint64(block.chainid))
        );
        require(records[depId] == false, "record exists");
        records[depId] = true;
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        emit Deposited(depId, msg.sender, _token, _amount, _mintChainId);
    }

    /**
     * @notice Withdraw locked tokens triggered by token burn at the remote chain
     */
    function withdraw(
        bytes calldata _request,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers
    ) external whenNotPaused {
        bytes32 domain = keccak256(abi.encodePacked(block.chainid, address(this), "Withdraw"));
        sigsVerifier.verifySigs(abi.encodePacked(domain, _request), _sigs, _signers, _powers);
        PbPegged.Withdraw memory request = PbPegged.decWithdraw(_request);
        bytes32 wdId = keccak256(
            abi.encodePacked(request.receiver, request.token, request.amount, request.refChainId, request.refId)
        );
        require(records[wdId] == false, "record exists");
        records[wdId] = true;
        _updateVolume(request.token, request.amount);
        uint256 delayThreshold = delayThresholds[request.token];
        if (delayThreshold > 0 && request.amount > delayThreshold) {
            _addDelayedTransfer(wdId, request.receiver, request.token, request.amount);
        } else {
            IERC20(request.token).safeTransfer(request.receiver, request.amount);
        }
        emit Withdrawn(wdId, request.receiver, request.token, request.amount, request.refChainId, request.refId);
    }

    function executeDelayedTransfer(bytes32 id) external whenNotPaused {
        delayedTransfer memory transfer = _executeDelayedTransfer(id);
        IERC20(transfer.token).safeTransfer(transfer.receiver, transfer.amount);
    }
}
