// SPDX-License-Identifier: GPL-3.0-only
// Modified based on openzeppelin

pragma solidity 0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract Pausable is Ownable {
    mapping(address => bool) public pausers;
    bool public paused;

    event Paused(address account);
    event Unpaused(address account);
    event PauserAdded(address account);
    event PauserRemoved(address account);

    /**
     * @dev Initializes the contract in unpaused state.
     */
    constructor() {
        paused = false;
        _addPauser(msg.sender);
    }

    modifier onlyPauser() {
        require(isPauser(msg.sender), "Caller is not pauser");
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     */
    modifier whenPaused() {
        require(paused, "Pausable: not paused");
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     */
    modifier whenNotPaused() {
        require(!paused, "Pausable: paused");
        _;
    }

    /**
     * @dev Triggers paused state.
     */
    function pause() public onlyPauser whenNotPaused {
        paused = true;
        emit Paused(msg.sender);
    }

    /**
     * @dev Returns to normal state.
     */
    function unpause() public onlyPauser whenPaused {
        paused = false;
        emit Unpaused(msg.sender);
    }

    function isPauser(address account) public view returns (bool) {
        return pausers[account];
    }

    function renouncePauser() public {
        _removePauser(msg.sender);
    }

    function addPauser(address account) public onlyOwner {
        _addPauser(account);
    }

    function removePauser(address account) public onlyOwner {
        _removePauser(account);
    }

    function _addPauser(address account) private {
        require(!isPauser(account), "Caller is pauser already");
        pausers[account] = true;
        emit PauserAdded(account);
    }

    function _removePauser(address account) private {
        require(isPauser(account), "Caller is not pauser");
        pausers[account] = false;
        emit PauserRemoved(account);
    }
}
