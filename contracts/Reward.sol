// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import {DataTypes as dt} from "./libraries/DataTypes.sol";
import "./Staking.sol";

contract Reward is Ownable, Pausable {
    using SafeERC20 for IERC20;

    Staking public immutable staking;
    IERC20 public immutable celerToken;

    mapping(address => uint256) public claimedReward;

    event RewardClaimed(address indexed recipient, uint256 reward);
    event RewardPoolContribution(address indexed contributor, uint256 contribution);

    constructor(Staking _staking, address _celerTokenAddress) {
        staking = _staking;
        celerToken = IERC20(_celerTokenAddress);
    }

    /**
     * @notice Claim reward
     * @dev Here we use cumulative reward to make claim process idempotent
     * @param _rewardRequest reward request bytes coded in protobuf
     * @param _sigs list of validator signatures
     */
    function claimReward(bytes calldata _rewardRequest, bytes[] calldata _sigs) external whenNotPaused {
        staking.verifySignatures(_rewardRequest, _sigs);
        PbStaking.Reward memory reward = PbStaking.decReward(_rewardRequest);

        uint256 newReward = reward.cumulativeReward - claimedReward[reward.recipient];
        require(newReward > 0, "No new reward");

        claimedReward[reward.recipient] = reward.cumulativeReward;
        celerToken.safeTransfer(reward.recipient, newReward);

        emit RewardClaimed(reward.recipient, newReward);
    }

    /**
     * @notice Contribute CELR tokens to the reward pool
     * @param _amount the amount of CELR tokens to contribute
     */
    function contributeToRewardPool(uint256 _amount) external whenNotPaused {
        address contributor = msg.sender;
        celerToken.safeTransferFrom(contributor, address(this), _amount);

        emit RewardPoolContribution(contributor, _amount);
    }

    /**
     * @notice Called by the owner to pause contract
     * @dev emergency use only
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Called by the owner to unpause contract
     * @dev emergency use only
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Owner drains tokens when the contract is paused
     * @dev emergency use only
     * @param _amount drained token amount
     */
    function drainToken(uint256 _amount) external whenPaused onlyOwner {
        celerToken.safeTransfer(msg.sender, _amount);
    }
}
