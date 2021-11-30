// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.9;

import "../interfaces/ISigsVerifier.sol";
import "../libraries/PbPegged.sol";
import "./PeggedToken.sol";

/**
 * @title The bridge to mint and burn pegged tokens at this chain
 */
contract PeggedTokenBridge {
    ISigsVerifier public immutable sigsVerifier;

    mapping(bytes32 => bool) public records;

    event Mint(bytes32 mintId, address token, address account, uint256 amount, uint64 refChainId, bytes32 refId);
    event Burn(bytes32 burnId, address token, address account, uint256 amount, uint64 withdrawChainId);

    constructor(ISigsVerifier _sigsVerifier) {
        sigsVerifier = _sigsVerifier;
    }

    /**
     * @notice Mint tokens triggered by token deposit at a remote chain
     */
    function mint(
        bytes calldata _request,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers
    ) external {
        bytes32 domain = keccak256(abi.encodePacked(block.chainid, address(this), "Mint"));
        sigsVerifier.verifySigs(abi.encodePacked(domain, _request), _sigs, _signers, _powers);
        PbPegged.Mint memory request = PbPegged.decMint(_request);
        bytes32 mintId = keccak256(
            abi.encodePacked(request.account, request.token, request.amount, request.refChainId, request.refId)
        );
        require(records[mintId] == false, "record exists");
        records[mintId] = true;
        PeggedToken(request.token).mint(request.account, request.amount);
        emit Mint(mintId, request.token, request.account, request.amount, request.refChainId, request.refId);
    }

    /**
     * @notice burn tokens to trigger redemption of locked tokens at the remote chain
     */
    function burn(
        address _token,
        uint256 _amount,
        uint64 _withdrawChainId,
        uint64 _nonce
    ) external {
        bytes32 burnId = keccak256(
            abi.encodePacked(msg.sender, _token, _amount, _withdrawChainId, _nonce, uint64(block.chainid))
        );
        require(records[burnId] == false, "record exists");
        records[burnId] = true;
        PeggedToken(_token).burn(msg.sender, _amount);
        emit Burn(burnId, _token, msg.sender, _amount, _withdrawChainId);
    }
}
