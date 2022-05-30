// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


interface IPeggedTokenV3 is IERC20 {

    function mint(address receiver, uint256 amount) external;

    function burn(uint256 amount) external;
}
