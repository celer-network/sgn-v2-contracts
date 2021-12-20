// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.8.9;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./MultiBridgeToken.sol";

/**
 * @title Canonical token that supports multi-bridge minter and multi-token swap
 */
contract MintSwapCanonicalToken is MultiBridgeToken {
    using SafeERC20 for IERC20;

    // bridge token -> cap of total swapped amount, can be tracked by each bridge token.balanceOf(this)
    mapping(address => uint256) public totalSwapCap;

    event TokenSwapCapUpdated(address token, uint256 cap);

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) MultiBridgeToken(name_, symbol_, decimals_) {}

    // msg.sender has bridge token and want to get canonical token
    function swapBridgeForCanonical(address _bridgeToken, uint256 _amount) external returns (uint256) {
        // move bridge token from msg.sender to canonical token _amount
        IERC20(_bridgeToken).safeTransferFrom(msg.sender, address(this), _amount);
        require(IERC20(_bridgeToken).balanceOf(address(this)) < totalSwapCap[_bridgeToken], "exceed swap cap");
        _mint(msg.sender, _amount);
        return _amount;
    }

    // msg.sender has canonical and want to get bridge token (eg. for cross chain burn)
    function swapCanonicalForBridge(address _bridgeToken, uint256 _amount) external returns (uint256) {
        _burn(msg.sender, _amount);
        IERC20(_bridgeToken).safeTransfer(msg.sender, _amount);
        return _amount;
    }

    // update existing bridge token swap cap or add a new bridge token with swap cap
    // set cap to 0 will disable swapBridgeForCanonical, but swapCanonicalToBridge will still work
    function setBridgeTokenSwapCap(address _bridgeToken, uint256 _swapCap) external onlyOwner {
        totalSwapCap[_bridgeToken] = _swapCap;
        emit TokenSwapCapUpdated(_bridgeToken, _swapCap);
    }
}
