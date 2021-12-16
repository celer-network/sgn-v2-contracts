// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >= 0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Canonical token support swap with per-bridge token
 */
contract SwapCanonicalToken is ERC20, Ownable {
    mapping(address => uint256) public bridge_cap; // each bridge address -> mint cap
    mapping(address => uint256) public minted; // how much each bridge has minted

    constructor(
        string memory name_,
        string memory symbol_
    ) ERC20(name_, symbol_) {
    }

    // update existing bridge token mint cap or add a new bridge token with mint cap
    // set cap to 0 will disable swapBridgeForCanonical, but swapCanonicalToBridge will still work
    function setBridgeTokenMintCap(address bridge_token_address, uint256 mint_cap) external onlyOwner {
        bridge_cap[bridge_token_address] = mint_cap;
    }

    // msg.sender has bridge_token and want to get canonical token
    function swapBridgeForCanonical(address bridge_token, uint256 amount) external {
        require(minted[bridge_token]+amount < bridge_cap[bridge_token], "exceed mint cap");
        // move bridge token from msg.sender to canonical token address
        IERC20(bridge_token).transferFrom(msg.sender, address(this), amount);
        _mint(msg.sender, amount);
        minted[bridge_token] += amount;
    }

    // msg.sender has canonical and want to get bridge token (eg. for cross chain burn)
    function swapCanonicalForBridge(address bridge_token, uint256 amount) external {
        _burn(msg.sender, amount);
        minted[bridge_token] -= amount;
        IERC20(bridge_token).transfer(msg.sender, amount);
    }

    // to make compatible with BEP20
    function getOwner() external view returns (address) {
        return owner();
    }
}
