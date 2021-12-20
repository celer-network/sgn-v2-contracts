// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Canonical token support swap with per-bridge token
 */
contract SwapCanonicalToken is ERC20, Ownable {
    mapping(address => uint256) public mintCap; // each bridge token -> mint cap

    // each bridge token.balanceOf(this) tracks how much that bridge has already minted

    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

    // update existing bridge token mint cap or add a new bridge token with mint cap
    // set cap to 0 will disable swapBridgeForCanonical, but swapCanonicalToBridge will still work
    function setBridgeTokenMintCap(address bridgeToken, uint256 mintCap_) external onlyOwner {
        mintCap[bridgeToken] = mintCap_;
    }

    // msg.sender has bridge_token and want to get canonical token
    function swapBridgeForCanonical(address bridgeToken, uint256 amount) external {
        // move bridge token from msg.sender to canonical token address
        IERC20(bridgeToken).transferFrom(msg.sender, address(this), amount);
        require(IERC20(bridgeToken).balanceOf(address(this)) < mintCap[bridgeToken], "exceed mint cap");
        _mint(msg.sender, amount);
    }

    // msg.sender has canonical and want to get bridge token (eg. for cross chain burn)
    function swapCanonicalForBridge(address bridgeToken, uint256 amount) external {
        _burn(msg.sender, amount);
        IERC20(bridgeToken).transfer(msg.sender, amount);
    }

    // to make compatible with BEP20
    function getOwner() external view returns (address) {
        return owner();
    }
}
