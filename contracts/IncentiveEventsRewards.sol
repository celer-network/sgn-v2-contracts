// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract IncentiveEventsRewards {
    using SafeERC20 for IERC20;

    struct EventReward {
        address addr;
        uint64 expireTime; // UNIX timestamp seconds
        bool claimed;
        uint256 amount;
    }

    mapping(address => EventReward) public rewards;

    address owner;
    IERC20 public immutable celerToken;

    constructor(
        address _celerTokenAddress
    ) {
        owner = msg.sender;
        celerToken = IERC20(_celerTokenAddress);
    }

    /**
     * @dev send bunch of rewards to winners.
     */
    function sendRewards(
        address[] calldata _addrs, uint256[] calldata _amounts, uint64 calldata _expireTime) external {
        require(msg.sender == owner, "must be owner");
        require(_expireTime > block.timestamp, "expireTime invalid");
        for (uint256 i = 0; i < _addrs.length; i++) {
            require(_amounts[i] > 0, "invalid amount");
            rewards[_addrs[i]] = EventReward(
            msg.sender,
            _addrs[i],
            _expireTime,
            false,
            _amounts[i]
            );
        }
    }

    /**
     * @dev user claim reward.
     */
    function claimReward(
        address calldata _addr
    ) external {
        require(rewards[_addr].expireTime < block.timestamp, "reward expired");
        require(!rewards[_addr].claimed, "reward must not be claimed");
        celerToken.safeTransferFrom(msg.sender, address(this), rewards[_addr].amount);
    }

}