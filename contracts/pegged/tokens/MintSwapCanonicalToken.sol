// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.8.9;

import "./MultiBridgeToken.sol";

/**
 * @title Canonical token that supports multi-bridge minter and multi-token swap
 */
contract MintSwapCanonicalToken is MultiBridgeToken {
    // each bridge token.balanceOf(this) tracks how much that bridge has already swapped
    mapping(address => uint256) public tokenSwapCap; // each bridge token -> swap cap

    event TokenSwapCapUpdated(address token, uint256 cap);

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) MultiBridgeToken(name_, symbol_, decimals_) {}

    // msg.sender has bridge token and want to get canonical token
    function swapBridgeForCanonical(address _bridgeToken, uint256 _amount) external {
        // move bridge token from msg.sender to canonical token _amount
        IERC20(_bridgeToken).transferFrom(msg.sender, address(this), _amount);
        require(IERC20(_bridgeToken).balanceOf(address(this)) < tokenSwapCap[_bridgeToken], "exceed swap cap");
        _mint(msg.sender, _amount);
    }

    // msg.sender has canonical and want to get bridge token (eg. for cross chain burn)
    function swapCanonicalForBridge(address _bridgeToken, uint256 _amount) external {
        _burn(msg.sender, _amount);
        IERC20(_bridgeToken).transfer(msg.sender, _amount);
    }

    // update existing bridge token swap cap or add a new bridge token with swap cap
    // set cap to 0 will disable swapBridgeForCanonical, but swapCanonicalToBridge will still work
    function setBridgeTokenSwapCap(address _bridgeToken, uint256 _swapCap) external onlyOwner {
        tokenSwapCap[_bridgeToken] = _swapCap;
        emit TokenSwapCapUpdated(_bridgeToken, _swapCap);
    }
}
