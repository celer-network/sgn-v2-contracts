// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.17;

import "../interfaces/IPeggedToken.sol";
import "../interfaces/IPeggedTokenBurnFrom.sol";
import "../safeguard/Pauser.sol";
import "../safeguard/VolumeControl.sol";
import "../safeguard/DelayedTransfer.sol";

/**
 * @title The bridge contract to mint and burn pegged brc20 tokens
 */
contract PeggedBrc20Bridge is Pauser, VolumeControl, DelayedTransfer {
    address public minter;

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
        bytes depositor
    );
    event Burn(
        bytes32 burnId,
        address token,
        address account,
        uint256 amount,
        uint64 toChainId,
        bytes toAccount,
        uint64 nonce
    );
    event MinBurnUpdated(address token, uint256 amount);
    event MaxBurnUpdated(address token, uint256 amount);
    event SupplyUpdated(address token, uint256 supply);
    event MinterUpdated(address origMinter, address newMinter);

    constructor(address _minter) {
        minter = _minter;
    }

    /**
     * @notice Mint tokens triggered by deposit on BTC chain
     * @param _receiver The receiver address.
     * @param _token The pegged token.
     * @param _amount The amount.
     * @param _depositor The depositor BTC address.
     * @param _refChainId The BTC chain ID.
     * @param _refId Reserved reference ID.
     */
    function mint(
        address _receiver,
        address _token,
        uint256 _amount,
        bytes calldata _depositor,
        uint64 _refChainId,
        bytes32 _refId
    ) external whenNotPaused returns (bytes32) {
        require(msg.sender == minter, "not minter");

        bytes32 mintId = keccak256(
            abi.encodePacked(_receiver, _token, _amount, _depositor, _refChainId, _refId, address(this))
        );
        require(records[mintId] == false, "record exists");
        records[mintId] = true;
        _updateVolume(_token, _amount);
        uint256 delayThreshold = delayThresholds[_token];
        if (delayThreshold > 0 && _amount > delayThreshold) {
            _addDelayedTransfer(mintId, _receiver, _token, _amount);
        } else {
            IPeggedToken(_token).mint(_receiver, _amount);
        }
        supplies[_token] += _amount;
        emit Mint(mintId, _token, _receiver, _amount, _refChainId, _refId, _depositor);
        return mintId;
    }

    /**
     * @notice Burn pegged tokens to trigger a cross-chain withdrawal of the original tokens on the BTC chain.
     * NOTE: This function DOES NOT SUPPORT fee-on-transfer / rebasing tokens.
     * @param _token The pegged token address.
     * @param _amount The amount to burn.
     * @param _toChainId If zero, withdraw from BTC chain; otherwise, the remote chain to mint tokens.
     * @param _toAccount The account to receive tokens on the remote chain
     * @param _nonce A number to guarantee unique depositId. Can be timestamp in practice.
     */
    function burn(
        address _token,
        uint256 _amount,
        uint64 _toChainId,
        bytes calldata _toAccount,
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
        bytes calldata _toAccount,
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
        bytes calldata _toAccount,
        uint64 _nonce
    ) internal returns (bytes32) {
        require(_amount > minBurn[_token], "amount too small");
        require(maxBurn[_token] == 0 || _amount <= maxBurn[_token], "amount too large");
        supplies[_token] -= _amount;
        bytes32 burnId = keccak256(
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

    function setMinter(address _minter) external onlyOwner {
        address origMinter = minter;
        minter = _minter;
        emit MinterUpdated(origMinter, _minter);
    }
}
