// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../interfaces/ISigsVerifier.sol";
import "../libraries/PbPegged.sol";

/**
 * @title the vaults to lock original tokens at the source chain
 */
contract OriginalTokenVaults is ReentrancyGuard {
    using SafeERC20 for IERC20;

    ISigsVerifier public immutable sigsVerifier;

    uint64 public mintseq; // ensure unique Mint event, start from 1
    mapping(bytes32 => uint256) public vaults;
    mapping(bytes32 => bool) public withdraws;

    event Deposited(uint64 seqnum, address account, address token, uint256 amount, uint64 mintChainId);
    event Withdrawn(address receiver, address token, uint256 amount, uint64 fromChainId, uint64 nonce);

    constructor(ISigsVerifier _sigsVerifier) {
        sigsVerifier = _sigsVerifier;
    }

    /**
     * @notice Lock original tokens to trigger mint at a remote chain
     * @param _token local token address
     * @param _amount locked token amount
     * @param _mintChainId destination chainId to mint tokens
     */
    function deposit(
        address _token,
        uint256 _amount,
        uint64 _mintChainId
    ) external nonReentrant {
        mintseq += 1;
        bytes32 vaultId = keccak256(abi.encodePacked(_token, _mintChainId));
        vaults[vaultId] += _amount;
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        emit Deposited(mintseq, msg.sender, _token, _amount, _mintChainId);
    }

    /**
     * @notice Withdraw locked tokens triggered by token burn at the remote chain
     */
    function withdraw(
        bytes calldata _request,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers
    ) external {
        sigsVerifier.verifySigs(_request, _sigs, _signers, _powers);
        PbPegged.Withdraw memory request = PbPegged.decWithdraw(_request);
        bytes32 domain = keccak256(abi.encodePacked(block.chainid, address(this), "Withdraw"));
        require(request.domain == domain, "Invalid domain");
        bytes32 wdId = keccak256(
            abi.encodePacked(request.receiver, request.token, request.amount, request.burnChainId, request.nonce)
        );
        require(withdraws[wdId] == false, "Already withdrawn");
        withdraws[wdId] = true;
        bytes32 vaultId = keccak256(abi.encodePacked(request.token, request.burnChainId));
        vaults[vaultId] -= request.amount;
        IERC20(request.token).safeTransfer(request.receiver, request.amount);
        emit Withdrawn(request.receiver, request.token, request.amount, request.burnChainId, request.nonce);
    }
}
