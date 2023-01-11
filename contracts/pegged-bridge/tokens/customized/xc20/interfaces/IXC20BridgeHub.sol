// SPDX-License-Identifier: GPL-3.0-only

pragma solidity ^0.8.0;

interface IXC20BridgeHub {
    /**
     * @dev Swaps intermediary bridge token for canonical XC-20 token.
     * @param bridgeToken The intermediary bridge token
     * @param amount The amount to swap
     * @return The canonical token amount
     */
    function swapBridgeForCanonical(address bridgeToken, uint256 amount) external returns (uint256);

    /**
     * @dev Swaps canonical XC-20 token for intermediary bridge token.
     * @param bridgeToken The intermediary bridge token
     * @param amount The amount to swap
     * @return The bridge token amount
     */
    function swapCanonicalForBridge(address bridgeToken, uint256 amount) external returns (uint256);
}
