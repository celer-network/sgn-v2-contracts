// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../../interfaces/IPeggedToken.sol";

/**
 * @title Example Multi-Bridge Pegged ERC20 token
 */
contract MultiBridgePeggedToken is IPeggedToken, ERC20, Ownable {
    struct Supply {
        uint256 cap;
        uint256 total;
    }
    mapping(address => Supply) public bridges; // bridge address -> supply

    uint8 private immutable _decimals;

    event BridgeUpdated(address bridge, uint256 supplyCap);

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) ERC20(name_, symbol_) {
        _decimals = decimals_;
    }

    function mint(address _to, uint256 _amount) external {
        Supply storage b = bridges[msg.sender];
        b.total += _amount;
        require(b.total <= b.cap, "exceeds bridge supply cap");
        _mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount) external {
        Supply storage b = bridges[msg.sender];
        b.total -= _amount;
        _burn(_from, _amount);
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function updateBridge(address _bridge, uint256 _cap) external onlyOwner {
        bridges[_bridge].cap = _cap;
        emit BridgeUpdated(_bridge, _cap);
    }
}
