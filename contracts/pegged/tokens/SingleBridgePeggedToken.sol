// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../../interfaces/IPeggedToken.sol";

/**
 * @title Example Pegged ERC20 token
 */
contract SingleBridgePeggedToken is IPeggedToken, ERC20, Ownable {
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
        address _bridge
    ) ERC20(name_, symbol_) {
        _decimals = decimals_;
        bridge = _bridge;
    }

    function mint(address _to, uint256 _amount) external onlyBridge {
        _mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount) external onlyBridge {
        _burn(_from, _amount);
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function updateBridge(address _bridge) external onlyOwner {
        bridge = _bridge;
        emit BridgeUpdated(bridge);
    }
}
