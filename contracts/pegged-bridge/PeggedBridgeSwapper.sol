// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IERC20MintableBurnable is IERC20 {

    function mint(address receiver, uint256 amount) external;

    function burn(uint256 amount) external;
}


/**
 * @title Pegged Bridge Swapper
 * @notice Facilitates cross chain apps by wrapping and unwrapping bridged tokens 1:1.
 */
contract PeggedBridgeSwapper {

    /// @notice Bridge token.
    address public immutable bridge;
    /// @notice Canonical token.
    address public immutable canonical;

    /// @notice Emitted when bridge token is converted to canonical token.
    event Unwrapped(address indexed sender, address indexed receiver, uint256 amount);
    /// @notice Emitted when canonical token is converted to bridge token.
    event Wrapped(address indexed sender, address indexed receiver, uint256 amount);

    /**
     * @notice Constructs the Bridge Swapper contract.
     * @param canonical_ Canonical token.
     * @param bridge_ Bridge token.
     */
    constructor(address canonical_, address bridge_) {
        require(bridge_ != address(0x0), "zero address bridge");
        require(canonical_ != address(0x0), "zero address canonical");
        bridge = bridge_;
        canonical = canonical_;
    }

    /**
     * @notice Converts bridge token to canonical token.
     * @param receiver User that will receive canonical token.
     * @param amountB Amount of bridge token to convert.
     * @return amountC Amount of canonical token sent to receiver.
     */
    function swapBridgeForCanonical(address receiver, uint256 amountB) external returns (uint256 amountC) {
        // pull bridge
        SafeERC20.safeTransferFrom(IERC20(bridge), msg.sender, address(this), amountB);
        // mint canonical
        IERC20MintableBurnable(canonical).mint(receiver, amountB);
        // return
        emit Unwrapped(msg.sender, receiver, amountB);
        return amountB;
    }

    /**
     * @notice Converts canonical token to bridge token.
     * This conversion will fail if there is insufficient bridge liquidity.
     * @param receiver User that will receive bridge token.
     * @param amountC Amount of canonical token to convert.
     * @return amountB Amount of bridge token sent to receiver.
     */
    function swapCanonicalForBridge(address receiver, uint256 amountC) external returns (uint256 amountB) {
        // pull canonical
        SafeERC20.safeTransferFrom(IERC20(canonical), msg.sender, address(this), amountC);
        IERC20MintableBurnable(canonical).burn(amountC);
        // transfer bridge
        IERC20 bridge_ = IERC20(bridge);
        require(bridge_.balanceOf(address(this)) >= amountC, "insufficient bridge liquidity");
        SafeERC20.safeTransfer(bridge_, receiver, amountC);
        // return
        emit Wrapped(msg.sender, receiver, amountC);
        return amountC;
    }
}
