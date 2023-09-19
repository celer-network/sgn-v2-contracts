// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.17;

import "./Freezable.sol";
import "../MintSwapCanonicalToken.sol";

/**
 * @title Canonical token that supports multi-bridge minter and multi-token swap. Support freezable erc20 transfer
 */
contract MintSwapCanonicalTokenFreezable is MintSwapCanonicalToken, Freezable {
    string private _name;
    string private _symbol;

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) MintSwapCanonicalToken(name_, symbol_, decimals_) {}

    // freezable related
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);
        require(!isFrozen(from), "ERC20Freezable: from account is frozen");
        require(!isFrozen(to), "ERC20Freezable: to account is frozen");
    }

    function freeze(address _account) public onlyOwner {
        freezes[_account] = true;
        emit Frozen(_account);
    }

    function unfreeze(address _account) public onlyOwner {
        freezes[_account] = false;
        emit Unfrozen(_account);
    }
}
