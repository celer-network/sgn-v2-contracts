// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Example Pegged ERC20 token
 */
contract SingleBridgeToken is ERC20, Ownable {
    address public bridge;

    uint8 private immutable _decimals;

    event BridgeUpdated(address bridge);

    modifier onlyBridge() {
        require(msg.sender == bridge, "caller is not bridge");
        _;
    }

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address bridge_
    ) ERC20(name_, symbol_) {
        _decimals = decimals_;
        bridge = bridge_;
    }

    function mint(address _to, uint256 _amount) external onlyBridge returns (bool) {
        _mint(_to, _amount);
        return true;
    }

    function burn(address _from, uint256 _amount) external onlyBridge returns (bool) {
        _burn(_from, _amount);
        return true;
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function updateBridge(address _bridge) external onlyOwner {
        bridge = _bridge;
        emit BridgeUpdated(bridge);
    }

    // to make compatible with BEP20
    function getOwner() external view returns (address) {
        return owner();
    }
}
