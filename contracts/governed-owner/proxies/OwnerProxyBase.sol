// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.8.0;

import "../SimpleGovernance.sol";

abstract contract OwnerProxyBase {
    SimpleGovernance public gov;
    address private deployer;

    constructor() {
        deployer = msg.sender;
    }

    function initGov(SimpleGovernance _gov) public {
        require(msg.sender == deployer, "only deployer can init");
        require(address(gov) == address(0), "gov addr already set");
        gov = _gov;
    }
}
