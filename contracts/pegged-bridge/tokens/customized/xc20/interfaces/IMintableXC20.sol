// SPDX-License-Identifier: GPL-3.0-only

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./ILocalAsset.sol";

interface IMintableXC20 is IERC20, ILocalAsset {}
