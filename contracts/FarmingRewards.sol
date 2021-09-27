// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import {DataTypes as dt} from "./libraries/DataTypes.sol";
import "./interfaces/ISigsVerifier.sol";
import "./libraries/PbFarming.sol";

contract FarmingRewards is Ownable, Pausable {
    using SafeERC20 for IERC20;

    ISigsVerifier public immutable sigsVerifier;

    // recipient => tokenAddress => amount
    mapping(address => mapping(address => uint256)) public claimedRewardAmounts;

    event FarmingRewardClaimed(address indexed recipient, address indexed token, uint256 reward);
    event FarmingRewardContributed(address indexed contributor, address indexed token, uint256 contribution);

    constructor(ISigsVerifier _sigsVerifier) {
        sigsVerifier = _sigsVerifier;
    }

    /**
     * @notice Claim rewards
     * @dev Here we use cumulative reward to make claim process idempotent
     * @param _rewardsRequest rewards request bytes coded in protobuf
     * @param _signers list of signers.
     * @param _sigs list of signer signatures
     */
    function claimRewards(
        bytes calldata _rewardsRequest,
        bytes calldata _signers,
        bytes[] calldata _sigs
    ) external whenNotPaused {
        sigsVerifier.verifySigs(_rewardsRequest, _signers, _sigs);
        PbFarming.FarmingRewards memory rewards = PbFarming.decFarmingRewards(_rewardsRequest);
        require(rewards.chainId == block.chainid, "Chain ID mismatch");
        bool hasNewReward;
        for (uint256 i = 0; i < rewards.tokenAddresses.length; i++) {
            address token = rewards.tokenAddresses[i];
            uint256 cumulativeRewardAmount = rewards.cumulativeRewardAmounts[i];
            uint256 newReward = cumulativeRewardAmount - claimedRewardAmounts[rewards.recipient][token];
            if (newReward > 0) {
                hasNewReward = true;
                claimedRewardAmounts[rewards.recipient][token] = cumulativeRewardAmount;
                IERC20(token).safeTransfer(rewards.recipient, newReward);
                emit FarmingRewardClaimed(rewards.recipient, token, newReward);
            }
        }
        require(hasNewReward, "No new reward");
    }

    /**
     * @notice Contribute reward tokens to the reward pool
     * @param _token the address of the token to contribute
     * @param _amount the amount of the token to contribute
     */
    function contributeToRewardPool(address _token, uint256 _amount) external whenNotPaused {
        address contributor = msg.sender;
        IERC20(_token).safeTransferFrom(contributor, address(this), _amount);

        emit FarmingRewardContributed(contributor, _token, _amount);
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
     * @param _token the address of the token to drain
     * @param _amount drained token amount
     */
    function drainToken(address _token, uint256 _amount) external whenPaused onlyOwner {
        IERC20(_token).safeTransfer(msg.sender, _amount);
    }
}
