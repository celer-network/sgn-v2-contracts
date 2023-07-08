// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.17;

import "../Ownable.sol";

abstract contract Guard is Ownable {
    enum GuardState {
        None,
        Guarded,
        Relaxed
    }

    bool public relaxed;
    uint256 public relaxedGuards;
    uint256 public relaxThreshold;
    address[] public guards;
    mapping(address => GuardState) public guardStates;

    event GuardUpdated(address account, GuardState state);
    event RelaxStatusUpdated(bool relaxed);
    event RelaxThresholdUpdated(uint256 threshold, uint256 total);

    constructor(address[] memory _guards) {
        for (uint256 i = 0; i < _guards.length; i++) {
            _addGuard(_guards[i]);
        }
        _setRelaxThreshold(guards.length);
    }

    function updateGuardState(GuardState _state) external {
        GuardState current = guardStates[msg.sender];
        require(current != GuardState.None, "caller is not guard");
        require(current != _state, "same with current state");
        guardStates[msg.sender] = _state;
        if (_state == GuardState.Guarded) {
            relaxedGuards--;
        } else if (_state == GuardState.Relaxed) {
            relaxedGuards++;
        } else {
            revert("invalid update");
        }
        _checkRelaxed();
        emit GuardUpdated(msg.sender, _state);
    }

    function addGuard(address _account, bool _incrementThreshold) external onlyOwner {
        _addGuard(_account);
        if (_incrementThreshold) {
            relaxThreshold++;
            _checkRelaxed();
        }
    }

    function _addGuard(address _account) private {
        require(guardStates[_account] == GuardState.None, "account is already guard");
        guards.push(_account);
        guardStates[_account] = GuardState.Guarded;
        emit GuardUpdated(_account, GuardState.Guarded);
    }

    function removeGuard(address _account, bool _decrementThreshold) external onlyOwner {
        GuardState state = guardStates[_account];
        require(state != GuardState.None, "account is not guard");
        if (state == GuardState.Relaxed) {
            relaxedGuards--;
        }
        if (_decrementThreshold) {
            relaxThreshold--;
        }
        _checkRelaxed();
        uint256 lastIndex = guards.length - 1;
        for (uint256 i = 0; i < guards.length; i++) {
            if (guards[i] == _account) {
                if (i < lastIndex) {
                    guards[i] = guards[lastIndex];
                }
                guards.pop();
                guardStates[_account] = GuardState.None;
                emit GuardUpdated(_account, GuardState.None);
                return;
            }
        }
        revert("guard not found"); // this should never happen
    }

    function setRelaxThreshold(uint256 _threshold) external onlyOwner {
        _setRelaxThreshold(_threshold);
    }

    function _setRelaxThreshold(uint256 _threshold) private {
        relaxThreshold = _threshold;
        emit RelaxThresholdUpdated(_threshold, guards.length);
    }

    function _checkRelaxed() private {
        bool _relaxed = (relaxedGuards >= relaxThreshold) ? true : false;
        if (relaxed != _relaxed) {
            relaxed = _relaxed;
            emit RelaxStatusUpdated(relaxed);
        }
    }

    function guardNum() public view returns (uint256) {
        return guards.length;
    }
}
