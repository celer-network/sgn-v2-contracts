// SPDX-License-Identifier: GPL-3.0-only

import "@openzeppelin/contracts/access/Ownable.sol";

pragma solidity 0.8.9;

abstract contract Addrs is Ownable {
    address public msgBus;
    address public liquidityBridge; // liquidity bridge address
    address public pegBridge; // peg bridge address
    address public pegVault; // peg original vault address

    function setMsgBus(address _addr) public onlyOwner {
        msgBus = _addr;
    }

    function setLiquidityBridge(address _addr) public onlyOwner {
        liquidityBridge = _addr;
    }

    function setPegBridge(address _addr) public onlyOwner {
        pegBridge = _addr;
    }

    function setPegVault(address _addr) public onlyOwner {
        pegVault = _addr;
    }
}
