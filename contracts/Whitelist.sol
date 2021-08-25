// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.7;

abstract contract Whitelist {
    mapping(address => bool) public whitelist;
    bool public whitelistEnabled;

    event WhitelistedAdded(address account);
    event WhitelistedRemoved(address account);

    modifier onlyWhitelisted() {
        if (whitelistEnabled) {
            require(isWhitelisted(msg.sender), "Caller is not whitelisted");
        }
        _;
    }

    function isWhitelisted(address account) public view virtual returns (bool) {
        return whitelist[account];
    }

    function _setWhitelistEnabled(bool _whitelistEnabled) internal virtual {
        whitelistEnabled = _whitelistEnabled;
    }

    function _addWhitelisted(address account) internal virtual {
        require(!isWhitelisted(account), "Already whitelisted");
        whitelist[account] = true;
        emit WhitelistedAdded(account);
    }

    function _removeWhitelisted(address account) internal virtual {
        require(isWhitelisted(account), "Not whitelisted");
        whitelist[account] = false;
        emit WhitelistedRemoved(account);
    }
}
