// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.17;

import "./BVN.sol";

contract DelegatorOptIn {
    BVN public immutable bvn;

    mapping(address => mapping(address => uint256)) optedIn; // delegator -> validator -> opted in timestamp

    event DelegatorOptedIn(address indexed delegator, address indexed validator, uint256 timestamp);

    constructor(BVN _bvn) {
        bvn = _bvn;
    }

    function delegatorOptIn(address validator) external {
        _delegatorOptIn(msg.sender, validator);
    }

    function delegatorOptIn(address[] memory validators) external {
        for (uint256 i = 0; i < validators.length; i++) {
            _delegatorOptIn(msg.sender, validators[i]);
        }
    }

    function _delegatorOptIn(address delegator, address validator) private {
        require(optedIn[delegator][validator] == 0, "Delegator already opted in");
        require(bvn.isRegisteredValidator(validator), "Validator not registered in BVN");
        optedIn[delegator][validator] = block.timestamp;
        emit DelegatorOptedIn(delegator, validator, block.timestamp);
    }

    function getOptedInTimestamp(address delegator, address validator) external view returns (uint256) {
        return optedIn[delegator][validator];
    }
}