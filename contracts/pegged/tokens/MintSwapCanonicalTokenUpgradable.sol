// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.8.9;

import "./MintSwapCanonicalToken.sol";

/**
 * @title Upgradable canonical token that supports multi-bridge minter and multi-token swap
 */

 // To minimize code fork, we just shadow all constructor set states and override their getter funcs
 // When deploy this contract, this contract's state will set proper name, symbol and owner by constructors.
 // decimal isn't saved in state because it's immutable in MultiBridgeToken and will be set in the code binary.
 // when proxy contract uses this as impl, it'll first call init which sets the values in proxy contract state.
 // believe this way is better than changing all contracts and dependencies to those without constructor
 // the downside is we didn't use the private name/symbol/owner states in parent contracts but this has no extra
 // gas cost when calling
contract MintSwapCanonicalTokenUpgradable is MintSwapCanonicalToken {
    string private _name;
    string private _symbol;
    address private _owner;

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) MintSwapCanonicalToken(name_, symbol_, decimals_) {
        // set token contract state to prevent anyone calling init on token contract directly
        _owner = msg.sender;
    }

    // only to be called by Proxy via delegatecall and will modify Proxy state
    function init(
        string memory name_,
        string memory symbol_
    ) external {
        // this is to prevent init is called directly b/c token contract state has owner set in constructor
        require(_owner == address(0), "owner already set");
        _owner = msg.sender; // in delegatecall, msg.sender is original EOA tx sender, not the calling contract addr
        _name = name_;
        _symbol = symbol_;
    }

    // override name, symbol and owner getters
    function name() public view virtual override returns (string memory) {
        return _name;
    }
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }
    function owner() public view virtual override returns (address) {
        return _owner;
    }
}
