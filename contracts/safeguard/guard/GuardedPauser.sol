// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.17;

import "./Guard.sol";

interface IPauser {
    function pause() external;

    function unpause() external;
}

// GuardedPauser inherits Guard, meaning that it is both guard and pauser
contract GuardedPauser is Guard {
    enum PauserRole {
        None,
        Full,
        PauseOnly
    }

    uint64 public numPausers;
    mapping(address => PauserRole) public pausers;

    event PauserUpdated(address account, PauserRole role);

    constructor(address[] memory _guards, address[] memory _pausers) Guard(_guards) {
        for (uint256 i = 0; i < _pausers.length; i++) {
            _addPauser(_pausers[i], PauserRole.Full);
        }
    }

    function pause(address _target) public {
        require(pausers[msg.sender] != PauserRole.None, "invalid caller");
        IPauser(_target).pause();
    }

    function unpause(address _target) public {
        require(pausers[msg.sender] == PauserRole.Full, "invalid caller");
        require(relaxed, "not in relaxed mode");
        IPauser(_target).unpause();
    }

    function addPausers(address[] calldata _accounts, PauserRole[] calldata _roles) external onlyOwner {
        for (uint256 i = 0; i < _accounts.length; i++) {
            _addPauser(_accounts[i], _roles[i]);
        }
    }

    function _addPauser(address _account, PauserRole _role) private {
        require(pausers[_account] == PauserRole.None, "account is already pauser");
        require(_role == PauserRole.Full || _role == PauserRole.PauseOnly, "invalid role");
        pausers[_account] = _role;
        numPausers++;
        emit PauserUpdated(_account, _role);
    }

    function removePausers(address[] calldata _accounts) external onlyOwner {
        for (uint256 i = 0; i < _accounts.length; i++) {
            _removePauser(_accounts[i]);
        }
    }

    function _removePauser(address _account) private {
        require(pausers[_account] != PauserRole.None, "account is not pauser");
        pausers[_account] = PauserRole.None;
        numPausers--;
        emit PauserUpdated(_account, PauserRole.None);
    }

    function setPausers(address[] calldata _accounts, PauserRole[] calldata _roles) external onlyOwner {
        for (uint256 i = 0; i < _accounts.length; i++) {
            _setPauser(_accounts[i], _roles[i]);
        }
    }

    function _setPauser(address _account, PauserRole _role) private {
        require(pausers[_account] != PauserRole.None, "account is not pauser");
        require(_role == PauserRole.Full || _role == PauserRole.PauseOnly, "invalid role");
        pausers[_account] = _role;
        emit PauserUpdated(_account, _role);
    }
}
