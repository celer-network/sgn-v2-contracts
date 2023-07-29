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
    uint256 public numRelaxedGuards;
    uint256 public relaxThreshold;
    address[] public guards;
    mapping(address => GuardState) public guardStates; // guard address -> guard state

    event GuardUpdated(address account, GuardState state);
    event RelaxStatusUpdated(bool relaxed);
    event RelaxThresholdUpdated(uint256 threshold, uint256 total);

    function _initGuards(address[] memory _guards) internal {
        require(guards.length == 0, "guards already initiated");
        for (uint256 i = 0; i < _guards.length; i++) {
            _addGuard(_guards[i]);
        }
        _setRelaxThreshold(guards.length);
    }

    // change GuardState of msg.sender from relaxed to guarded
    function guard() external {
        require(guardStates[msg.sender] == GuardState.Relaxed, "invalid caller");
        guardStates[msg.sender] = GuardState.Guarded;
        numRelaxedGuards--;
        _updateRelaxed();
        emit GuardUpdated(msg.sender, GuardState.Guarded);
    }

    // change GuardState of msg.sender from guarded to relaxed
    function relax() external {
        require(guardStates[msg.sender] == GuardState.Guarded, "invalid caller");
        guardStates[msg.sender] = GuardState.Relaxed;
        numRelaxedGuards++;
        _updateRelaxed();
        emit GuardUpdated(msg.sender, GuardState.Relaxed);
    }

    function updateGuards(
        address[] calldata _add,
        address[] calldata _remove,
        uint256 _newRelaxThreshold
    ) external onlyOwner {
        for (uint256 i = 0; i < _remove.length; i++) {
            _removeGuard(_remove[i]);
        }
        for (uint256 i = 0; i < _add.length; i++) {
            _addGuard(_add[i]);
        }
        _setRelaxThreshold(_newRelaxThreshold);
    }

    function _addGuard(address _account) private {
        require(guardStates[_account] == GuardState.None, "account is already guard");
        guards.push(_account);
        guardStates[_account] = GuardState.Guarded;
        emit GuardUpdated(_account, GuardState.Guarded);
    }

    function _removeGuard(address _account) private {
        GuardState state = guardStates[_account];
        require(state != GuardState.None, "account is not guard");
        if (state == GuardState.Relaxed) {
            numRelaxedGuards--;
        }
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
        require(_threshold <= guards.length, "invalid threshold");
        relaxThreshold = _threshold;
        _updateRelaxed();
        emit RelaxThresholdUpdated(_threshold, guards.length);
    }

    function _updateRelaxed() private {
        bool _relaxed = numRelaxedGuards >= relaxThreshold;
        if (relaxed != _relaxed) {
            relaxed = _relaxed;
            emit RelaxStatusUpdated(relaxed);
        }
    }

    function numGuards() public view returns (uint256) {
        return guards.length;
    }
}
