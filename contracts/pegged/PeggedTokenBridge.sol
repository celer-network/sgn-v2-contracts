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

    enum Action {
        Mint,
        Burn
    }
    event LogRecord(Action action, address token, address account, uint256 amount, uint64 nonce);

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
        bytes32 id = keccak256(abi.encodePacked("mint", request.token, request.account, request.amount, request.nonce));
        require(records[id] == false, "record exists");
        records[id] = true;
        PeggedToken(request.token).mint(request.account, request.amount);
        emit LogRecord(Action.Mint, request.token, request.account, request.amount, request.nonce);
    }

    /**
     * @notice burn tokens to trigger withdrawal of locked tokens at the remote chain
     */
    function burn(
        address _token,
        uint256 _amount,
        uint64 _nonce
    ) external {
        bytes32 id = keccak256(abi.encodePacked("burn", _token, msg.sender, _amount, _nonce));
        require(records[id] == false, "record exists");
        records[id] = true;
        PeggedToken(_token).burn(msg.sender, _amount);
        emit LogRecord(Action.Burn, _token, msg.sender, _amount, _nonce);
    }
}
