// SPDX-License-Identifier: GPL-3.0-only

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IXC20BridgeHub.sol";

/**
 * @title Intermediary bridge token that supports swapping with the XC-20 bridge hub.
 * NOTE: XC-20 bridge hub is NOT the canonical token itself.
 */
contract XC20BridgeToken is ERC20, Ownable {
    using SafeERC20 for IERC20;

    // The pegged token bridge
    address public bridge;
    // XC20 bridge hub for swapping
    address public immutable bridgeHub;
    // The canonical token
    address public immutable canonicalToken;

    event BridgeUpdated(address bridge);

    modifier onlyBridge() {
        require(msg.sender == bridge, "XC20BridgeToken: caller is not bridge");
        _;
    }

    constructor(
        string memory name_,
        string memory symbol_,
        address _bridge,
        address _bridgeHub,
        address _canonicalToken
    ) ERC20(name_, symbol_) {
        bridge = _bridge;
        bridgeHub = _bridgeHub;
        canonicalToken = _canonicalToken;
    }

    function mint(address _to, uint256 _amount) external onlyBridge returns (bool) {
        _mint(address(this), _amount); // Mint to this contract to be transferred to the hub
        _approve(address(this), bridgeHub, _amount);
        IXC20BridgeHub(bridgeHub).swapBridgeForCanonical(address(this), _amount);
        // Now this has canonical token, next step is to transfer to user.
        IERC20(canonicalToken).safeTransfer(_to, _amount);
        return true;
    }

    function burn(address _from, uint256 _amount) external onlyBridge returns (bool) {
        IERC20(canonicalToken).safeTransferFrom(_from, address(this), _amount);
        IERC20(canonicalToken).safeIncreaseAllowance(address(bridgeHub), _amount);
        IXC20BridgeHub(bridgeHub).swapCanonicalForBridge(address(this), _amount);
        _burn(address(this), _amount);
        return true;
    }

    function updateBridge(address _bridge) external onlyOwner {
        bridge = _bridge;
        emit BridgeUpdated(bridge);
    }

    function decimals() public view virtual override returns (uint8) {
        return ERC20(canonicalToken).decimals();
    }

    // For compatibility with BEP20
    function getOwner() external view returns (address) {
        return owner();
    }

    // This account has to hold some amount of native currency in order to be eligible
    // to receive canonical x20 assets per Astar rule
    receive() external payable {}
}
