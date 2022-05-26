// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Pegged Bridge Swapper
 * @notice Facilitates cross chain apps by wrapping and unwrapping bridged tokens 1:1.
 */
interface IPeggedBridgeSwapper {

    /**
     * @notice Converts bridge token to canonical token.
     * @param receiver User that will receive canonical token.
     * @param amountB Amount of bridge token to convert.
     * @return amountC Amount of canonical token sent to receiver.
     */
    function swapBridgeForCanonical(address receiver, uint256 amountB) external returns (uint256 amountC);

    /**
     * @notice Converts canonical token to bridge token.
     * This conversion will fail if there is insufficient bridge liquidity.
     * @param receiver User that will receive bridge token.
     * @param amountC Amount of canonical token to convert.
     * @return amountB Amount of bridge token sent to receiver.
     */
    function swapCanonicalForBridge(address receiver, uint256 amountC) external returns (uint256 amountB);
}

/**
 * @title Per bridge intermediary token that supports swapping with a canonical token.
 */
contract SwapBridgeErc20 is ERC20, Ownable {
    using SafeERC20 for IERC20;

    address public bridge;
    address public bridgeSwapper;
    address public immutable canonical; // canonical token that support swap

    event BridgeUpdated(address bridge);
    event BridgeSwapperUpdated(address bridgeSwapper);

    modifier onlyBridge() {
        require(msg.sender == bridge, "caller is not bridge");
        _;
    }

    constructor(
        string memory name_,
        string memory symbol_,
        address bridge_,
        address canonical_
    ) ERC20(name_, symbol_) {
        bridge = bridge_;
        canonical = canonical_;
    }

    function mint(address _to, uint256 _amount) external onlyBridge returns (bool) {
        require(bridgeSwapper != address(0x0), "bridge swapper not set");
        _mint(address(this), _amount); // add amount to myself so swapBridgeForCanonical can transfer amount
        IPeggedBridgeSwapper(bridgeSwapper).swapBridgeForCanonical(_to, _amount);
        return true;
    }

    function burn(address _from, uint256 _amount) external onlyBridge returns (bool) {
        require(bridgeSwapper != address(0x0), "bridge swapper not set");
        IERC20(canonical).safeTransferFrom(_from, address(this), _amount);
        uint256 amountB = IPeggedBridgeSwapper(bridgeSwapper).swapCanonicalForBridge(address(this), _amount);
        _burn(address(this), amountB);
        return true;
    }

    function updateBridge(address _bridge) external onlyOwner {
        bridge = _bridge;
        emit BridgeUpdated(bridge);
    }

    function updateBridgeSwapper(address _bridgeSwapper) external onlyOwner {
        bridgeSwapper = _bridgeSwapper;
        emit BridgeSwapperUpdated(_bridgeSwapper);
    }

    // approve tokens so swap can work. or we approve before call it in mint w/ added gas
    function approveCanonical() external onlyOwner {
        _approve(address(this), bridgeSwapper, type(uint256).max);
        IERC20(canonical).approve(bridgeSwapper, type(uint256).max);
    }

    function revokeCanonical() external onlyOwner {
        _approve(address(this), bridgeSwapper, 0);
        IERC20(canonical).approve(bridgeSwapper, 0);
    }

    // to make compatible with BEP20
    function getOwner() external view returns (address) {
        return owner();
    }

    function decimals() public view virtual override returns (uint8) {
        return ERC20(canonical).decimals();
    }
}
