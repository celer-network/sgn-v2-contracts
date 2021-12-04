// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../interfaces/IPeggedToken.sol";

/**
 * @title Pegged ERC20 token
 */
contract PeggedToken is IPeggedToken, ERC20 {
    // controller should be PeggedTokenBridge
    address public immutable controller;

    uint8 private immutable _decimals;

    modifier onlyController() {
        require(msg.sender == controller, "caller is not controller");
        _;
    }

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address _controller
    ) ERC20(name_, symbol_) {
        _decimals = decimals_;
        controller = _controller;
    }

    function mint(address _to, uint256 _amount) external onlyController {
        _mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount) external onlyController {
        _burn(_from, _amount);
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }
}
