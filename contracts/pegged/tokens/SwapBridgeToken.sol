// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface ISwapCanoToken {
    function swapBridgeForCanonical(address, uint256) external;

    function swapCanonicalForBridge(address, uint256) external;
}

/**
 * @title Per bridge token support swap with canonical.
 */
contract SwapBridgeToken is ERC20, Ownable {
    address public bridge;
    address public canonical; // canonical token that support swap

    event BridgeUpdated(address bridge);

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
        _mint(address(this), _amount); // add amount to myself so swapBridgeForCanonical can transfer amount
        ISwapCanoToken(canonical).swapBridgeForCanonical(address(this), _amount);
        // now this has canonical token, next step is to transfer to user
        IERC20(canonical).transfer(_to, _amount);
        return true;
    }

    function burn(address _from, uint256 _amount) external onlyBridge returns (bool) {
        IERC20(canonical).transferFrom(_from, address(this), _amount);
        ISwapCanoToken(canonical).swapCanonicalForBridge(address(this), _amount);
        _burn(address(this), _amount);
        return true;
    }

    function updateBridge(address _bridge) external onlyOwner {
        bridge = _bridge;
        emit BridgeUpdated(bridge);
    }

    // approve canonical token so swapBridgeForCanonical can work. or we approve before call it in mint w/ added gas
    function approveCanonical() external onlyOwner {
        approve(canonical, type(uint256).max);
    }

    // to make compatible with BEP20
    function getOwner() external view returns (address) {
        return owner();
    }

    function decimals() public view virtual override returns (uint8) {
        return ERC20(canonical).decimals();
    }
}
