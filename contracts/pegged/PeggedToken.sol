// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract PeggedToken is ERC20 {
    address public immutable controller;

    modifier onlyController() {
        require(msg.sender == controller, "caller is not controller");
        _;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        address _controller
    ) ERC20(_name, _symbol) {
        controller = _controller;
    }

    function mint(address _to, uint256 _amount) external onlyController {
        _mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount) external onlyController {
        _burn(_from, _amount);
    }
}
