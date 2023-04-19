// SPDX-License-Identifier: GPL-3.0-only

pragma solidity ^0.8.0;

import "./erc20/ERC20.sol";
import "./erc20/ERC20Pausable.sol";
import "./erc20/ERC20Permit.sol";
import "./interfaces/IMintableXC20.sol";

/**
 * @title An ERC-20 token implementing the Polkadot / Moonbeam mintable XC-20 interface.
 */
contract MintableXC20 is IMintableXC20, ERC20Permit, ERC20Pausable {
    address public immutable creator;
    address public owner;
    address public issuer;
    address public admin;
    address public freezer;
    mapping(address => bool) public frozenAccounts;

    uint8 private _decimals;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event TeamSet(address indexed issuer, address indexed admin, address indexed freezer);
    event MetadataSet(string indexed name, string indexed symbol, uint8 indexed decimals);
    event AccountFrozen(address indexed account);
    event AccountThawed(address indexed account);

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address _owner,
        address _issuer,
        address _admin,
        address _freezer
    ) ERC20Permit(name_) ERC20(name_, symbol_) {
        creator = msg.sender;
        owner = _owner;
        issuer = _issuer;
        admin = _admin;
        freezer = _freezer;
        _decimals = decimals_;
    }

    /**
     * @dev Returns the decimals of the token.
     */
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    /**
     * @dev Mint tokens to an address.
     * @custom:selector 40c10f19
     * @param _to The address to which you want to mint tokens
     * @param _value The amount of tokens to be minted
     */
    function mint(address _to, uint256 _value) external override returns (bool) {
        require(msg.sender == owner || msg.sender == issuer, "XC20: only owner or issuer");
        _mint(_to, _value);
        return true;
    }

    /**
     * @dev Burn tokens from an address.
     * Selector: 9dc29fac
     * @param _from The address from which you want to burn tokens
     * @param _value The amount of tokens to be burnt
     */
    function burn(address _from, uint256 _value) external override returns (bool) {
        require(msg.sender == owner || msg.sender == admin, "XC20: only owner or admin");
        _burn(_from, _value);
        return true;
    }

    /**
     * @dev Freeze an account, preventing it from operating with the asset.
     * Selector: 8d1fdf2f
     * @param _account The address that you want to freeze
     */
    function freeze(address _account) external override returns (bool) {
        require(msg.sender == owner || msg.sender == freezer, "XC20: only owner or freezer");
        frozenAccounts[_account] = true;
        emit AccountFrozen(_account);
        return true;
    }

    /**
     * @dev Unfreeze an account, letting it from operating again with the asset.
     * Selector: 5ea20216
     * @param _account The address that you want to unfreeze
     */
    function thaw(address _account) external override returns (bool) {
        require(msg.sender == owner || msg.sender == admin, "XC20: only owner or admin");
        frozenAccounts[_account] = false;
        emit AccountThawed(_account);
        return true;
    }

    /**
     * @dev Freeze the entire asset operations.
     * Selector: 6b8751c1
     */
    function freezeAsset() external override returns (bool) {
        require(msg.sender == owner || msg.sender == freezer, "XC20: only owner or freezer");
        _pause();
        return true;
    }

    /**
     * @dev Unfreeze the entire asset operations.
     * Selector: 1cddec19
     */
    function thawAsset() external override returns (bool) {
        require(msg.sender == owner || msg.sender == admin, "XC20: only owner or admin");
        _unpause();
        return true;
    }

    /**
     * @dev Transfer the ownership of an asset to a new account.
     * @custom:selector f2fde38b
     * @param _newOwner address The address of the new owner
     */
    function transferOwnership(address _newOwner) external override onlyOwner returns (bool) {
        require(_newOwner != address(0), "XC20: new owner is the zero address");
        _transferOwnership(_newOwner);
        return true;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() external onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     * @param _newOwner The new owner.
     */
    function _transferOwnership(address _newOwner) internal virtual {
        address prevOwner = owner;
        owner = _newOwner;
        emit OwnershipTransferred(prevOwner, _newOwner);
    }

    /**
     * @dev Specify the issuer, admin and freezer of an asset.
     * Selector: f8bf8e95
     * @param _issuer address The address capable of issuing tokens
     * @param _admin address The address capable of burning tokens and unfreezing accounts/assets
     * @param _freezer address The address capable of freezing accounts/asset
     */
    function setTeam(
        address _issuer,
        address _admin,
        address _freezer
    ) external override onlyOwner returns (bool) {
        issuer = _issuer;
        admin = _admin;
        freezer = _freezer;
        emit TeamSet(issuer, admin, freezer);
        return true;
    }

    /**
     * @dev Specify the name, symbol and decimals of your asset.
     * Selector: ee5dc1e4
     * @param name_ string The name of the asset
     * @param symbol_ string The symbol of the asset
     * @param decimals_ uint8 The number of decimals of your asset
     */
    function setMetadata(
        string calldata name_,
        string calldata symbol_,
        uint8 decimals_
    ) external override onlyOwner returns (bool) {
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
        emit MetadataSet(name_, symbol_, decimals_);
        return true;
    }

    /**
     * @dev Clear the name, symbol and decimals of your asset.
     * Selector: d3ba4b9e
     */
    function clearMetadata() external override onlyOwner returns (bool) {
        _name = "";
        _symbol = "";
        _decimals = 0;
        emit MetadataSet("", "", 0);
        return true;
    }

    /**
     * @dev Check frozen status before transfer.
     * @param _from The transfer sender
     * @param _to The transfer receiver
     * @param _amount The amount of the transfer
     */
    function _beforeTokenTransfer(
        address _from,
        address _to,
        uint256 _amount
    ) internal virtual override(ERC20, ERC20Pausable) {
        super._beforeTokenTransfer(_from, _to, _amount);

        require(!frozenAccounts[_from], "XC20: from account is frozen");
        require(!frozenAccounts[_to], "XC20: to account is frozen");
    }
}
