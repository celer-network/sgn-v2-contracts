// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.9;

import "../interfaces/ISigsVerifier.sol";
import "../interfaces/IPeggedToken.sol";
import "../interfaces/IPeggedTokenBurnFrom.sol";
import "../libraries/PbPegged.sol";
import "../safeguard/Pauser.sol";
import "../safeguard/VolumeControl.sol";
import "../safeguard/DelayedTransfer.sol";

/**
 * @title The bridge contract to mint and burn pegged tokens
 * @dev Work together with OriginalTokenVault deployed at remote chains.
 */
contract PeggedTokenBridgeV2 is Pauser, VolumeControl, DelayedTransfer {
    ISigsVerifier public immutable sigsVerifier;

    mapping(bytes32 => bool) public records;
    mapping(address => uint256) public supplies;

    mapping(address => uint256) public minBurn;
    mapping(address => uint256) public maxBurn;

    event Mint(
        bytes32 mintId,
        address token,
        address account,
        uint256 amount,
        // ref_chain_id defines the reference chain ID, taking values of:
        // 1. The common case: the chain ID on which the remote corresponding deposit or burn happened;
        // 2. Refund for wrong burn: this chain ID on which the burn happened
        uint64 refChainId,
        // ref_id defines a unique reference ID, taking values of:
        // 1. The common case of deposit/burn-mint: the deposit or burn ID on the remote chain;
        // 2. Refund for wrong burn: the burn ID on this chain
        bytes32 refId,
        address depositor
    );
    event Burn(
        bytes32 burnId,
        address token,
        address account,
        uint256 amount,
        uint64 toChainId,
        address toAccount,
        uint64 nonce
    );
    event MinBurnUpdated(address token, uint256 amount);
    event MaxBurnUpdated(address token, uint256 amount);
    event SupplyUpdated(address token, uint256 supply);

    constructor(ISigsVerifier _sigsVerifier) {
        sigsVerifier = _sigsVerifier;
    }

    /**
     * @notice Mint tokens triggered by deposit at a remote chain's OriginalTokenVault.
     * @param _request The serialized Mint protobuf.
     * @param _sigs The list of signatures sorted by signing addresses in ascending order. A relay must be signed-off by
     * +2/3 of the sigsVerifier's current signing power to be delivered.
     * @param _signers The sorted list of signers.
     * @param _powers The signing powers of the signers.
     */
    function mint(
        bytes calldata _request,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers
    ) external whenNotPaused returns (bytes32) {
        bytes32 domain = keccak256(abi.encodePacked(block.chainid, address(this), "Mint"));
        sigsVerifier.verifySigs(abi.encodePacked(domain, _request), _sigs, _signers, _powers);
        PbPegged.Mint memory request = PbPegged.decMint(_request);
        bytes32 mintId = keccak256(
            // len = 20 + 20 + 32 + 20 + 8 + 32 + 20 = 152
            abi.encodePacked(
                request.account,
                request.token,
                request.amount,
                request.depositor,
                request.refChainId,
                request.refId,
                address(this)
            )
        );
        require(records[mintId] == false, "record exists");
        records[mintId] = true;
        _updateVolume(request.token, request.amount);
        uint256 delayThreshold = delayThresholds[request.token];
        if (delayThreshold > 0 && request.amount > delayThreshold) {
            _addDelayedTransfer(mintId, request.account, request.token, request.amount);
        } else {
            IPeggedToken(request.token).mint(request.account, request.amount);
        }
        supplies[request.token] += request.amount;
        emit Mint(
            mintId,
            request.token,
            request.account,
            request.amount,
            request.refChainId,
            request.refId,
            request.depositor
        );
        return mintId;
    }

    /**
     * @notice Burn pegged tokens to trigger a cross-chain withdrawal of the original tokens at a remote chain's
     * OriginalTokenVault, or mint at another remote chain
     * NOTE: This function DOES NOT SUPPORT fee-on-transfer / rebasing tokens.
     * @param _token The pegged token address.
     * @param _amount The amount to burn.
     * @param _toChainId If zero, withdraw from original vault; otherwise, the remote chain to mint tokens.
     * @param _toAccount The account to receive tokens on the remote chain
     * @param _nonce A number to guarantee unique depositId. Can be timestamp in practice.
     */
    function burn(
        address _token,
        uint256 _amount,
        uint64 _toChainId,
        address _toAccount,
        uint64 _nonce
    ) external whenNotPaused returns (bytes32) {
        bytes32 burnId = _burn(_token, _amount, _toChainId, _toAccount, _nonce);
        IPeggedToken(_token).burn(msg.sender, _amount);
        return burnId;
    }

    // same with `burn` above, use openzeppelin ERC20Burnable interface
    function burnFrom(
        address _token,
        uint256 _amount,
        uint64 _toChainId,
        address _toAccount,
        uint64 _nonce
    ) external whenNotPaused returns (bytes32) {
        bytes32 burnId = _burn(_token, _amount, _toChainId, _toAccount, _nonce);
        IPeggedTokenBurnFrom(_token).burnFrom(msg.sender, _amount);
        return burnId;
    }

    function _burn(
        address _token,
        uint256 _amount,
        uint64 _toChainId,
        address _toAccount,
        uint64 _nonce
    ) private returns (bytes32) {
        require(_amount > minBurn[_token], "amount too small");
        require(maxBurn[_token] == 0 || _amount <= maxBurn[_token], "amount too large");
        supplies[_token] -= _amount;
        bytes32 burnId = keccak256(
            // len = 20 + 20 + 32 + 8 + 20 + 8 + 8 + 20 = 136
            abi.encodePacked(
                msg.sender,
                _token,
                _amount,
                _toChainId,
                _toAccount,
                _nonce,
                uint64(block.chainid),
                address(this)
            )
        );
        require(records[burnId] == false, "record exists");
        records[burnId] = true;
        emit Burn(burnId, _token, msg.sender, _amount, _toChainId, _toAccount, _nonce);
        return burnId;
    }

    function executeDelayedTransfer(bytes32 id) external whenNotPaused {
        delayedTransfer memory transfer = _executeDelayedTransfer(id);
        IPeggedToken(transfer.token).mint(transfer.receiver, transfer.amount);
    }

    function setMinBurn(address[] calldata _tokens, uint256[] calldata _amounts) external onlyGovernor {
        require(_tokens.length == _amounts.length, "length mismatch");
        for (uint256 i = 0; i < _tokens.length; i++) {
            minBurn[_tokens[i]] = _amounts[i];
            emit MinBurnUpdated(_tokens[i], _amounts[i]);
        }
    }

    function setMaxBurn(address[] calldata _tokens, uint256[] calldata _amounts) external onlyGovernor {
        require(_tokens.length == _amounts.length, "length mismatch");
        for (uint256 i = 0; i < _tokens.length; i++) {
            maxBurn[_tokens[i]] = _amounts[i];
            emit MaxBurnUpdated(_tokens[i], _amounts[i]);
        }
    }

    function setSupply(address _token, uint256 _supply) external onlyOwner {
        supplies[_token] = _supply;
        emit SupplyUpdated(_token, _supply);
    }

    function increaseSupply(address _token, uint256 _delta) external onlyOwner {
        supplies[_token] += _delta;
        emit SupplyUpdated(_token, supplies[_token]);
    }

    function decreaseSupply(address _token, uint256 _delta) external onlyOwner {
        supplies[_token] -= _delta;
        emit SupplyUpdated(_token, supplies[_token]);
    }
}
