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

    // TODO: may remove valuts as records are kept in sgn
    mapping(address => mapping(uint256 => uint256)) public vaults; // token -> chainId -> amount
    mapping(bytes32 => bool) public records;

    event Deposited(
        bytes32 depositId,
        address account,
        address token,
        uint256 amount,
        uint64 mintChainId,
        uint64 nonce
    );
    event Withdrawn(bytes32 redeemId, address receiver, address token, uint256 amount, uint64 refchain, bytes32 refid);

    constructor(ISigsVerifier _sigsVerifier) {
        sigsVerifier = _sigsVerifier;
    }

    /**
     * @notice Lock original tokens to trigger mint at a remote chain
     * @param _token local token address
     * @param _amount locked token amount
     * @param _mintChainId destination chainId to mint tokens
     * @param _nonce user input seq to guarantee uniqueness
     */
    function deposit(
        address _token,
        uint256 _amount,
        uint64 _mintChainId,
        uint64 _nonce
    ) external nonReentrant {
        bytes32 depId = keccak256(
            abi.encodePacked(msg.sender, _token, _amount, _mintChainId, _nonce, uint64(block.chainid), address(this))
        );
        require(records[depId] == false, "record exists");
        records[depId] = true;
        vaults[_token][_mintChainId] += _amount;
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        emit Deposited(depId, msg.sender, _token, _amount, _mintChainId, _nonce);
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
        bytes32 domain = keccak256(abi.encodePacked(block.chainid, address(this), "Withdraw"));
        sigsVerifier.verifySigs(abi.encodePacked(domain, _request), _sigs, _signers, _powers);
        PbPegged.Withdraw memory request = PbPegged.decWithdraw(_request);
        bytes32 wdId = keccak256(
            abi.encodePacked(request.receiver, request.token, request.amount, request.refchain, request.refid)
        );
        require(records[wdId] == false, "record exists");
        records[wdId] = true;
        vaults[request.token][request.refchain] -= request.amount;
        IERC20(request.token).safeTransfer(request.receiver, request.amount);
        emit Withdrawn(wdId, request.receiver, request.token, request.amount, request.refchain, request.refid);
    }
}
