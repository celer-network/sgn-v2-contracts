// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.6;

abstract contract Whitelist {
    mapping (address => bool) whitelist;
    bool public whitelistEnabled;

    event WhitelistedAdded(address account);
    event WhitelistedRemoved(address account);

    modifier onlyWhitelisted() {
        if (whitelistEnabled) {
            require(isWhitelisted(msg.sender), "caller is not whitelisted");
        }
        _;
    }

    function isWhitelisted(address account) public view virtual returns (bool) {
        return  whitelist[account];
    }

    function _enableWhitelist() internal virtual {
        whitelistEnabled = true;
    }

    function _disableWhitelist() internal virtual {
        whitelistEnabled = false;
    }

    function _addWhitelisted(address account) internal virtual {
        require(!isWhitelisted(account), "already whitelisted");
        whitelist[account] = true;
        emit WhitelistedAdded(account);
    }

    function _removeWhitelisted(address account) internal virtual {
        require(isWhitelisted(account), "not whitelisted");
        whitelist[account] = false;
        emit WhitelistedRemoved(account);
    }
}