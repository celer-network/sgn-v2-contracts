// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./DPoS.sol";
import "./lib/proto/PbSgn.sol";

/**
 * @title Sidechain contract of SGN
 */
contract SGN is Ownable, Pausable {
    using SafeERC20 for IERC20;

    IERC20 public immutable celr;
    DPoS public immutable dpos;
    mapping(address => uint256) public subscriptionDeposits;
    uint256 public servicePool;
    mapping(address => uint256) public redeemedServiceReward;
    mapping(address => bytes) public sidechainAddrMap;

    /* Events */
    event UpdateSidechainAddr(
        address indexed candidate,
        bytes indexed oldSidechainAddr,
        bytes indexed newSidechainAddr
    );
    event AddSubscriptionBalance(address indexed consumer, uint256 amount);
    event RedeemReward(
        address indexed receiver,
        uint256 cumulativeMiningReward,
        uint256 serviceReward,
        uint256 servicePool
    );

    /**
     * @notice SGN constructor
     * @dev Need to deploy DPoS contract first before deploying SGN contract
     * @param _celrAddress address of Celer Token Contract
     * @param _dposAddress address of DPoS Contract
     */
    constructor(address _celrAddress, DPoS _dposAddress) {
        celr = IERC20(_celrAddress);
        dpos = _dposAddress;
    }

    /**
     * @notice Throws if SGN sidechain is not valid
     * @dev Check this before sidechain's operations
     */
    modifier onlyValidSidechain() {
        require(dpos.isValidDPoS(), "DPoS is not valid");
        _;
    }

    /**
     * @notice Update sidechain address
     * @dev Note that the "sidechain address" here means the address in the offchain sidechain system,
         which is different from the sidechain contract address
     * @param _sidechainAddr the new address in the offchain sidechain system
     */
    function updateSidechainAddr(bytes calldata _sidechainAddr) external {
        address msgSender = msg.sender;

        (bool initialized, , , uint256 status, , , ) = dpos.getCandidateInfo(msgSender);
        require(status == uint256(DPoS.CandidateStatus.Unbonded), "msg.sender is not unbonded");
        require(initialized, "Candidate is not initialized");

        bytes memory oldSidechainAddr = sidechainAddrMap[msgSender];
        sidechainAddrMap[msgSender] = _sidechainAddr;

        emit UpdateSidechainAddr(msgSender, oldSidechainAddr, _sidechainAddr);
    }

    /**
     * @notice Subscribe the guardian service
     * @param _amount subscription fee paid along this function call in CELR tokens
     */
    function subscribe(uint256 _amount) external whenNotPaused onlyValidSidechain {
        address msgSender = msg.sender;

        servicePool = servicePool + _amount;
        subscriptionDeposits[msgSender] = subscriptionDeposits[msgSender] + _amount;

        celr.safeTransferFrom(msgSender, address(this), _amount);

        emit AddSubscriptionBalance(msgSender, _amount);
    }

    /**
     * @notice Redeem rewards
     * @dev The rewards include both the service reward and mining reward
     * @dev SGN contract acts as an interface for users to redeem mining rewards
     * @param _rewardRequest reward request bytes coded in protobuf
     */
    function redeemReward(bytes calldata _rewardRequest) external whenNotPaused onlyValidSidechain {
        require(dpos.validateMultiSigMessage(_rewardRequest), "Validator sigs verification failed");

        PbSgn.RewardRequest memory rewardRequest = PbSgn.decRewardRequest(_rewardRequest);
        PbSgn.Reward memory reward = PbSgn.decReward(rewardRequest.reward);
        uint256 newServiceReward = reward.cumulativeServiceReward - redeemedServiceReward[reward.receiver];

        require(servicePool >= newServiceReward, "Service pool is smaller than new service reward");
        redeemedServiceReward[reward.receiver] = reward.cumulativeServiceReward;
        servicePool = servicePool - newServiceReward;

        dpos.redeemMiningReward(reward.receiver, reward.cumulativeMiningReward);
        celr.safeTransfer(reward.receiver, newServiceReward);

        emit RedeemReward(reward.receiver, reward.cumulativeMiningReward, newServiceReward, servicePool);
    }

    /**
     * @notice Owner drains one type of tokens when the contract is paused
     * @dev This is for emergency situations.
     * @param _amount drained token amount
     */
    function drainToken(uint256 _amount) external whenPaused onlyOwner {
        celr.safeTransfer(msg.sender, _amount);
    }
}
