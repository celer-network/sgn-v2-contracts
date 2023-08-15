// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.17;

import "./GuardedPauser.sol";
import "./GuardedGovernor.sol";

contract Sentinel is GuardedPauser, GuardedGovernor {
    // NOTE: Comment out for zksync
    constructor(address[] memory _guards, address[] memory _pausers, address[] memory _governors) {
        _initGuards(_guards);
        _initPausers(_pausers);
        _initGovernors(_governors);
    }

    // This is to support upgradable deployment.
    // Only to be called by Proxy via delegateCall as initOwner will require _owner is 0,
    // so calling init on this contract directly will guarantee to fail
    function init(address[] memory _guards, address[] memory _pausers, address[] memory _governors) external {
        initOwner();
        _initGuards(_guards);
        _initPausers(_pausers);
        _initGovernors(_governors);
    }
}
