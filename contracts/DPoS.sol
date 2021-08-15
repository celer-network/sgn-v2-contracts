// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./libraries/PbSgn.sol";
import "./Govern.sol";
import "./Whitelist.sol";

/**
 * @title A DPoS contract shared by every sidechain
 * @notice This contract holds the basic logic of DPoS in Celer's coherent sidechain system
 */
contract DPoS is Ownable, Pausable, Whitelist, Govern {
    uint256 constant CELR_DECIMAL = 10**18;
    uint256 constant MAX_INT = 2**256 - 1;
    uint256 public constant COMMISSION_RATE_BASE = 10000; // 1 commissionRate means 0.01%

    using SafeERC20 for IERC20;
    using ECDSA for bytes32;

    enum CandidateStatus {
        Null,
        Unbonded,
        Bonded,
        Unbonding
    }

    enum ValidatorChangeType {
        Add,
        Removal
    }

    struct WithdrawIntent {
        uint256 amount;
        uint256 proposedTime;
    }

    struct Delegator {
        uint256 delegatedStake;
        uint256 undelegatingStake;
        mapping(uint256 => WithdrawIntent) withdrawIntents;
        // valid intent range is [intentStartIndex, intentEndIndex)
        uint256 intentStartIndex;
        uint256 intentEndIndex;
    }

    // used for external delegator view output
    struct DelegatorInfo {
        address candidate;
        uint256 delegatedStake;
        uint256 undelegatingStake;
        uint256[] intentAmounts;
        uint256[] intentProposedTimes;
    }

    struct ValidatorCandidate {
        CandidateStatus status;
        uint256 minSelfStake;
        uint256 stakingPool; // sum of all delegations to this candidate
        mapping(address => Delegator) delegators;
        uint256 unbondTime;
        uint256 commissionRate; // equal to real commission rate * COMMISSION_RATE_BASE
        // for decreasing minSelfStake
        uint256 earliestBondTime;
    }

    uint256 public rewardPool;
    uint256 public totalValidatorStake;
    address[] public candidates;
    address[] public validators; // TODO: deal with set size reduction
    mapping(address => ValidatorCandidate) public candidateProfiles;
    mapping(address => uint256) public claimedReward;

    bool public slashDisabled;
    mapping(uint256 => bool) public usedPenaltyNonce;

    /* Events */
    // TODO: remove unnecessary event index
    event InitializeCandidate(address indexed candidate, uint256 minSelfStake, uint256 commissionRate);
    event UpdateCommissionRate(address indexed candidate, uint256 newRate);
    event UpdateMinSelfStake(address indexed candidate, uint256 minSelfStake);
    event ValidatorChange(address indexed ethAddr, ValidatorChangeType indexed changeType);
    event WithdrawFromUnbondedCandidate(address indexed delegator, address indexed candidate, uint256 amount);
    event IntendWithdraw(address indexed delegator, address indexed candidate, uint256 amount, uint256 proposedTime);
    event ConfirmWithdraw(address indexed delegator, address indexed candidate, uint256 amount);
    event Slash(address indexed validator, address indexed delegator, uint256 amount);
    event UpdateDelegatedStake(
        address indexed delegator,
        address indexed candidate,
        uint256 delegatorStake,
        uint256 candidatePool
    );
    event Compensate(address indexed indemnitee, uint256 amount);
    event CandidateUnbonded(address indexed candidate);
    event RewardClaimed(address indexed recipient, uint256 reward, uint256 rewardPool);
    event MiningPoolContribution(address indexed contributor, uint256 contribution, uint256 rewardPoolSize);

    /**
     * @notice DPoS constructor
     * @dev will initialize parent contract Govern first
     * @param _celerTokenAddress address of Celer Token Contract
     * @param _governProposalDeposit required deposit amount for a governance proposal
     * @param _governVoteTimeout voting timeout for a governance proposal
     * @param _slashTimeout the locking time for funds to be potentially slashed
     * @param _maxValidatorNum the maximum number of validators
     * @param _minStakeInPool the global minimum requirement of staking pool for each validator
     * @param _advanceNoticePeriod the wait time after the announcement and prior to the effective date of an update
     */
    constructor(
        address _celerTokenAddress,
        uint256 _governProposalDeposit,
        uint256 _governVoteTimeout,
        uint256 _slashTimeout,
        uint256 _maxValidatorNum,
        uint256 _minStakeInPool,
        uint256 _advanceNoticePeriod
    )
        Govern(
            _celerTokenAddress,
            _governProposalDeposit,
            _governVoteTimeout,
            _slashTimeout,
            _maxValidatorNum,
            _minStakeInPool,
            _advanceNoticePeriod
        )
    {}

    /**
     * @notice Throws if sender is not validator
     */
    modifier onlyValidator() {
        require(isValidator(msg.sender), "caller is not a validator");
        _;
    }

    receive() external payable {}

    /*********************************
     * External and Public Functions *
     *********************************/

    /**
     * @notice Vote for a parameter proposal with a specific type of vote
     * @param _proposalId the id of the parameter proposal
     * @param _vote the type of vote
     */
    function voteParam(uint256 _proposalId, VoteType _vote) external onlyValidator {
        internalVoteParam(_proposalId, msg.sender, _vote);
    }

    /**
     * @notice Confirm a parameter proposal
     * @param _proposalId the id of the parameter proposal
     */
    function confirmParamProposal(uint256 _proposalId) external {
        // check Yes votes only now
        uint256 yesVoteStakes;
        for (uint32 i = 0; i < validators.length; i++) {
            if (getParamProposalVote(_proposalId, validators[i]) == VoteType.Yes) {
                yesVoteStakes += candidateProfiles[validators[i]].stakingPool;
            }
        }

        bool passed = yesVoteStakes >= getQuorumStake();
        if (!passed) {
            rewardPool += paramProposals[_proposalId].deposit;
        }
        internalConfirmParamProposal(_proposalId, passed);
    }

    /**
     * @notice Contribute CELR tokens to the mining pool
     * @param _amount the amount of CELR tokens to contribute
     */
    function contributeToMiningPool(uint256 _amount) external whenNotPaused {
        address msgSender = msg.sender;
        rewardPool += _amount;
        celerToken.safeTransferFrom(msgSender, address(this), _amount);

        emit MiningPoolContribution(msgSender, _amount, rewardPool);
    }

    /**
     * @notice Claim reward
     * @dev Here we use cumulative mining reward to make claim process idempotent
     * @param _rewardRequest reward request bytes coded in protobuf
     * @param _sigs list of validator signatures
     */
    function claimReward(bytes calldata _rewardRequest, bytes[] calldata _sigs) external whenNotPaused {
        verifySignatures(_rewardRequest, _sigs);
        PbSgn.Reward memory reward = PbSgn.decReward(_rewardRequest);

        uint256 newReward = reward.cumulativeReward - claimedReward[reward.recipient];
        require(newReward > 0, "No new reward");
        require(rewardPool >= newReward, "Reward pool is smaller than new reward");

        claimedReward[reward.recipient] = reward.cumulativeReward;
        rewardPool -= newReward;
        celerToken.safeTransfer(reward.recipient, newReward);

        emit RewardClaimed(reward.recipient, newReward, rewardPool);
    }

    /**
     * @notice Initialize a candidate profile for validator
     * @dev every validator must become a candidate first
     * @param _minSelfStake minimal amount of tokens staked by the validator itself
     * @param _commissionRate the self-declaimed commission rate
     */
    function initializeCandidate(uint256 _minSelfStake, uint256 _commissionRate)
        external
        whenNotPaused
        onlyWhitelisted
    {
        ValidatorCandidate storage candidate = candidateProfiles[msg.sender];
        require(candidate.status == CandidateStatus.Null, "Candidate is initialized");
        require(_commissionRate <= COMMISSION_RATE_BASE, "Invalid commission rate");
        require(_minSelfStake >= CELR_DECIMAL, "Invalid minimal self stake");

        candidate.status = CandidateStatus.Unbonded;
        candidate.minSelfStake = _minSelfStake;
        candidate.commissionRate = _commissionRate;

        candidates.push(msg.sender);

        // TODO: auto self delegate when initialized?
        emit InitializeCandidate(msg.sender, _minSelfStake, _commissionRate);
    }

    /**
     * @notice Update commission rate
     * @param _newRate new commission rate
     */
    function updateCommissionRate(uint256 _newRate) external {
        ValidatorCandidate storage candidate = candidateProfiles[msg.sender];
        require(candidate.status != CandidateStatus.Null, "Candidate is not initialized");
        require(_newRate <= COMMISSION_RATE_BASE, "Invalid new rate");
        candidate.commissionRate = _newRate;
        emit UpdateCommissionRate(msg.sender, _newRate);
    }

    /**
     * @notice update minimal self stake value
     * @param _minSelfStake minimal amount of tokens staked by the validator itself
     */
    function updateMinSelfStake(uint256 _minSelfStake) external {
        ValidatorCandidate storage candidate = candidateProfiles[msg.sender];
        require(candidate.status != CandidateStatus.Null, "Candidate is not initialized");
        require(_minSelfStake >= CELR_DECIMAL, "Invalid minimal self stake");
        if (_minSelfStake < candidate.minSelfStake) {
            require(candidate.status != CandidateStatus.Bonded, "Candidate is bonded");
            candidate.earliestBondTime = block.number + getUIntValue(uint256(ParamNames.AdvanceNoticePeriod));
        }
        candidate.minSelfStake = _minSelfStake;
        emit UpdateMinSelfStake(msg.sender, _minSelfStake);
    }

    /**
     * @notice Delegate CELR tokens to a candidate
     * @dev Minimal amount per delegate operation is 1 CELR
     * @param _candidateAddr candidate to delegate
     * @param _amount the amount of delegated CELR tokens
     */
    function delegate(address _candidateAddr, uint256 _amount) public whenNotPaused {
        require(_amount >= CELR_DECIMAL, "Minimal amount is 1 CELR");
        ValidatorCandidate storage candidate = candidateProfiles[_candidateAddr];
        require(candidate.status != CandidateStatus.Null, "Candidate is not initialized");
        address msgSender = msg.sender;
        _addDelegatedStake(candidate, _candidateAddr, msgSender, _amount);
        celerToken.safeTransferFrom(msgSender, address(this), _amount);
    }

    /**
     * @notice Candidate claims to become a validator
     */
    function claimValidator() external {
        address msgSender = msg.sender;
        ValidatorCandidate storage candidate = candidateProfiles[msgSender];
        require(
            candidate.status == CandidateStatus.Unbonded || candidate.status == CandidateStatus.Unbonding,
            "Invalid candidate status"
        );
        require(block.number >= candidate.earliestBondTime, "Not earliest bond time yet");
        require(candidate.stakingPool >= getUIntValue(uint256(ParamNames.MinStakeInPool)), "Insufficient staking pool");
        require(candidate.delegators[msgSender].delegatedStake >= candidate.minSelfStake, "Not enough self stake");

        uint256 maxValidatorNum = getUIntValue(uint256(ParamNames.MaxValidatorNum));
        // if the number of validators has not reached the max_validator_num,
        // add validator directly
        if (validators.length < maxValidatorNum) {
            return _addValidator(msgSender);
        }
        // if the number of validators has alrady reached the max_validator_num,
        // add validator only if its pool size is greater than the current smallest validator staking pool
        uint256 minStakingPool = MAX_INT;
        uint256 minStakingPoolIndex;
        for (uint256 i = 0; i < maxValidatorNum; i++) {
            if (candidateProfiles[validators[i]].stakingPool < minStakingPool) {
                minStakingPoolIndex = i;
                minStakingPool = candidateProfiles[validators[i]].stakingPool;
                if (minStakingPool == 0) {
                    break;
                }
            }
        }
        require(candidate.stakingPool > minStakingPool, "Not larger than smallest pool");
        _replaceValidator(msgSender, minStakingPoolIndex);
    }

    /**
     * @notice Confirm candidate status from Unbonding to Unbonded
     * @param _candidateAddr the address of the candidate
     */
    function confirmUnbondedCandidate(address _candidateAddr) external {
        ValidatorCandidate storage candidate = candidateProfiles[_candidateAddr];
        require(candidate.status == CandidateStatus.Unbonding, "Candidate not unbonding");
        require(block.number >= candidate.unbondTime, "Unbonding time not reached");

        candidate.status = CandidateStatus.Unbonded;
        delete candidate.unbondTime;
        emit CandidateUnbonded(_candidateAddr);
    }

    /**
     * @notice Withdraw delegated stakes from an unbonded candidate
     * @dev Stakes are delegated by the msgSender to the candidate
     * @param _candidateAddr the address of the candidate
     * @param _amount withdrawn amount
     */
    function withdrawFromUnbondedCandidate(address _candidateAddr, uint256 _amount) external {
        require(_amount >= CELR_DECIMAL, "Minimal amount is 1 CELR");
        ValidatorCandidate storage candidate = candidateProfiles[_candidateAddr];
        require(candidate.status == CandidateStatus.Unbonded, "invalid candidate status");

        address msgSender = msg.sender;
        _removeDelegatedStake(candidate, _candidateAddr, msgSender, _amount);
        celerToken.safeTransfer(msgSender, _amount);

        emit WithdrawFromUnbondedCandidate(msgSender, _candidateAddr, _amount);
    }

    /**
     * @notice Intend to withdraw delegated stakes from a candidate
     * @dev Stakes are delegated by the msgSender to the candidate
     * @param _candidateAddr the address of the candidate
     * @param _amount withdrawn amount
     */
    function intendWithdraw(address _candidateAddr, uint256 _amount) external {
        address msgSender = msg.sender;
        require(_amount >= CELR_DECIMAL, "Minimal amount is 1 CELR");
        ValidatorCandidate storage candidate = candidateProfiles[_candidateAddr];
        require(candidate.status != CandidateStatus.Null, "Candidate is not initialized");
        Delegator storage delegator = candidate.delegators[msgSender];

        _removeDelegatedStake(candidate, _candidateAddr, msgSender, _amount);
        delegator.undelegatingStake += _amount;
        _validateValidator(_candidateAddr);

        WithdrawIntent storage withdrawIntent = delegator.withdrawIntents[delegator.intentEndIndex];
        withdrawIntent.amount = _amount;
        withdrawIntent.proposedTime = block.number;
        delegator.intentEndIndex++;

        emit IntendWithdraw(msgSender, _candidateAddr, _amount, withdrawIntent.proposedTime);
    }

    /**
     * @notice Confirm an intent of withdrawing delegated stakes from a candidate
     * @dev note that the stakes are delegated by the msgSender to the candidate
     * @param _candidateAddr the address of the candidate
     */
    function confirmWithdraw(address _candidateAddr) external {
        address msgSender = msg.sender;
        ValidatorCandidate storage candidate = candidateProfiles[_candidateAddr];
        require(candidate.status != CandidateStatus.Null, "Candidate is not initialized");
        Delegator storage delegator = candidate.delegators[msgSender];

        uint256 slashTimeout = getUIntValue(uint256(ParamNames.SlashTimeout));
        bool isUnbonded = candidate.status == CandidateStatus.Unbonded;
        // for all undelegated withdraw intents
        uint256 i;
        for (i = delegator.intentStartIndex; i < delegator.intentEndIndex; i++) {
            if (isUnbonded || delegator.withdrawIntents[i].proposedTime + slashTimeout <= block.number) {
                // withdraw intent is undelegated when the validator becomes unbonded or
                // the slashTimeout for the withdraw intent is up.
                delete delegator.withdrawIntents[i];
                continue;
            }
            break;
        }
        delegator.intentStartIndex = i;
        // for all undelegating withdraw intents
        uint256 undelegatingStakeWithoutSlash;
        for (; i < delegator.intentEndIndex; i++) {
            undelegatingStakeWithoutSlash += delegator.withdrawIntents[i].amount;
        }

        uint256 withdrawAmt;
        if (delegator.undelegatingStake > undelegatingStakeWithoutSlash) {
            withdrawAmt = delegator.undelegatingStake - undelegatingStakeWithoutSlash;
            delegator.undelegatingStake = undelegatingStakeWithoutSlash;

            celerToken.safeTransfer(msgSender, withdrawAmt);
        }

        emit ConfirmWithdraw(msgSender, _candidateAddr, withdrawAmt);
    }

    /**
     * @notice Slash a validator and its delegators
     * @param _penaltyRequest penalty request bytes coded in protobuf
     * @param _sigs list of validator signatures
     */
    function slash(bytes calldata _penaltyRequest, bytes[] calldata _sigs) external whenNotPaused {
        require(!slashDisabled, "Slash is disabled");
        PbSgn.Penalty memory penalty = PbSgn.decPenalty(_penaltyRequest);
        verifySignatures(_penaltyRequest, _sigs);
        require(block.number < penalty.expireTime, "Penalty expired");
        require(!usedPenaltyNonce[penalty.nonce], "Used penalty nonce");
        usedPenaltyNonce[penalty.nonce] = true;

        ValidatorCandidate storage validator = candidateProfiles[penalty.validatorAddress];
        require(validator.status != CandidateStatus.Unbonded, "Validator unbounded");

        uint256 totalSubAmt;
        for (uint256 i = 0; i < penalty.penalizedDelegators.length; i++) {
            PbSgn.AccountAmtPair memory penalizedDelegator = penalty.penalizedDelegators[i];
            totalSubAmt += penalizedDelegator.amt;
            emit Slash(penalty.validatorAddress, penalizedDelegator.account, penalizedDelegator.amt);

            Delegator storage delegator = validator.delegators[penalizedDelegator.account];
            uint256 _amt;
            if (delegator.delegatedStake >= penalizedDelegator.amt) {
                _amt = penalizedDelegator.amt;
            } else {
                uint256 remainingAmt = penalizedDelegator.amt - delegator.delegatedStake;
                delegator.undelegatingStake -= remainingAmt;
                _amt = delegator.delegatedStake;
            }
            _removeDelegatedStake(validator, penalty.validatorAddress, penalizedDelegator.account, _amt);
        }
        _validateValidator(penalty.validatorAddress);

        uint256 totalAddAmt;
        for (uint256 i = 0; i < penalty.beneficiaries.length; i++) {
            PbSgn.AccountAmtPair memory beneficiary = penalty.beneficiaries[i];
            totalAddAmt += beneficiary.amt;

            if (beneficiary.account == address(0)) {
                // address(0) stands for rewardPool
                rewardPool += beneficiary.amt;
            } else if (beneficiary.account == address(1)) {
                // address(1) means beneficiary is msg sender
                celerToken.safeTransfer(msg.sender, beneficiary.amt);
                emit Compensate(msg.sender, beneficiary.amt);
            } else {
                celerToken.safeTransfer(beneficiary.account, beneficiary.amt);
                emit Compensate(beneficiary.account, beneficiary.amt);
            }
        }

        require(totalSubAmt == totalAddAmt, "Amount not match");
    }

    /**
     * @notice Validate multi-signed message
     * @param _msg signed message
     * @param _sigs list of validator signatures
     * @return passed the validation or not
     */
    function verifySignatures(bytes memory _msg, bytes[] memory _sigs) public view returns (bool) {
        bytes32 hash = keccak256(_msg).toEthSignedMessageHash();
        address[] memory signers = new address[](_sigs.length);
        uint256 signedStake;
        address prev = address(0);
        for (uint256 i = 0; i < _sigs.length; i++) {
            signers[i] = hash.recover(_sigs[i]);
            require(signers[i] > prev, "Signers not in ascending order");
            prev = signers[i];
            if (candidateProfiles[signers[i]].status != CandidateStatus.Bonded) {
                continue;
            }
            signedStake += candidateProfiles[signers[i]].stakingPool;
        }

        require(signedStake >= getQuorumStake(), "Not enough signatures");
        return true;
    }

    /**
     * @notice Enable whitelist
     */
    function enableWhitelist() external onlyOwner {
        _enableWhitelist();
    }

    /**
     * @notice Disable whitelist
     */
    function disableWhitelist() external onlyOwner {
        _disableWhitelist();
    }

    /**
     * @notice Add an account to whitelist
     */
    function addWhitelisted(address account) external onlyOwner {
        _addWhitelisted(account);
    }

    /**
     * @notice Remove an account from whitelist
     */
    function removeWhitelisted(address account) external onlyOwner {
        _removeWhitelisted(account);
    }

    /**
     * @notice Enable slash
     */
    function enableSlash() external onlyOwner {
        slashDisabled = false;
    }

    /**
     * @notice Disable slash
     */
    function disableSlash() external onlyOwner {
        slashDisabled = true;
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
     * @notice Owner drains one type of tokens when the contract is paused
     * @dev emergency use only
     * @param _amount drained token amount
     */
    function drainToken(uint256 _amount) external whenPaused onlyOwner {
        celerToken.safeTransfer(msg.sender, _amount);
    }

    /**
     * @notice Get the minimum staking pool of all validators
     * @return the minimum staking pool of all validators
     */
    function getMinStakingPool() external view returns (uint256) {
        uint256 minStakingPool = candidateProfiles[validators[0]].stakingPool;
        for (uint256 i = 0; i < validators.length; i++) {
            if (candidateProfiles[validators[i]].stakingPool < minStakingPool) {
                minStakingPool = candidateProfiles[validators[i]].stakingPool;
                if (minStakingPool == 0) {
                    return 0;
                }
            }
        }

        return minStakingPool;
    }

    /**
     * @notice Get candidate info
     * @param _candidateAddr the address of the candidate
     * @return status candidate status
     * @return minSelfStake minimum self stakes
     * @return stakingPool staking pool
     * @return unbondTime unbond time
     * @return commissionRate commission rate
     */
    function getCandidateInfo(address _candidateAddr)
        external
        view
        returns (
            uint256 status,
            uint256 minSelfStake,
            uint256 stakingPool,
            uint256 unbondTime,
            uint256 commissionRate
        )
    {
        ValidatorCandidate storage c = candidateProfiles[_candidateAddr];
        status = uint256(c.status);
        minSelfStake = c.minSelfStake;
        stakingPool = c.stakingPool;
        unbondTime = c.unbondTime;
        commissionRate = c.commissionRate;
    }

    /**
     * @notice Get the delegator info of a specific candidate
     * @param _candidateAddr the address of the candidate
     * @param _delegatorAddr the address of the delegator
     * @return DelegatorInfo from the given candidate
     */
    function getDelegatorInfo(address _candidateAddr, address _delegatorAddr)
        public
        view
        returns (DelegatorInfo memory)
    {
        Delegator storage d = candidateProfiles[_candidateAddr].delegators[_delegatorAddr];

        uint256 len = d.intentEndIndex - d.intentStartIndex;
        uint256[] memory intentAmounts = new uint256[](len);
        uint256[] memory intentProposedTimes = new uint256[](len);
        for (uint256 i = 0; i < len; i++) {
            intentAmounts[i] = d.withdrawIntents[i + d.intentStartIndex].amount;
            intentProposedTimes[i] = d.withdrawIntents[i + d.intentStartIndex].proposedTime;
        }

        return
            DelegatorInfo({
                candidate: _candidateAddr,
                delegatedStake: d.delegatedStake,
                undelegatingStake: d.undelegatingStake,
                intentAmounts: intentAmounts,
                intentProposedTimes: intentProposedTimes
            });
    }

    /**
     * @notice Get the delegator info of a specific candidate
     * @param _delegatorAddr the address of the delegator
     * @return DelegatorInfo from all related candidates
     */
    function getDelegatorInfos(address _delegatorAddr) external view returns (DelegatorInfo[] memory) {
        DelegatorInfo[] memory infos = new DelegatorInfo[](candidates.length);
        uint32 num = 0;
        for (uint32 i = 0; i < candidates.length; i++) {
            Delegator storage d = candidateProfiles[candidates[i]].delegators[_delegatorAddr];
            if (d.delegatedStake == 0 && d.undelegatingStake == 0 && d.intentEndIndex == d.intentStartIndex) {
                infos[i] = getDelegatorInfo(candidates[i], _delegatorAddr);
                num++;
            }
        }
        DelegatorInfo[] memory delegatorInfos = new DelegatorInfo[](num);
        for (uint32 i = 0; i < num; i++) {
            delegatorInfos[i] = infos[i];
        }
        return delegatorInfos;
    }

    /**
     * @notice Check the given address is a validator or not
     * @param _addr the address to check
     * @return the given address is a validator or not
     */
    function isValidator(address _addr) public view returns (bool) {
        return candidateProfiles[_addr].status == CandidateStatus.Bonded;
    }

    /**
     * @notice Get the number of validators
     * @return the number of validators
     */
    function getValidatorNum() external view returns (uint256) {
        return validators.length;
    }

    /**
     * @notice Get quorum amount of stakes
     * @return the quorum amount
     */
    function getQuorumStake() public view returns (uint256) {
        return (totalValidatorStake * 2) / 3 + 1;
    }

    /*********************
     * Private Functions *
     *********************/

    /**
     * @notice Add the delegated stake of a delegator to an candidate
     * @param _candidate the candidate
     * @param _delegatorAddr the delegator address
     * @param _amount update amount
     */
    function _addDelegatedStake(
        ValidatorCandidate storage _candidate,
        address _candidateAddr,
        address _delegatorAddr,
        uint256 _amount
    ) private {
        Delegator storage delegator = _candidate.delegators[_delegatorAddr];
        _candidate.stakingPool += _amount;
        delegator.delegatedStake += _amount;
        if (_candidate.status == CandidateStatus.Bonded) {
            totalValidatorStake += _amount;
        }
        emit UpdateDelegatedStake(_delegatorAddr, _candidateAddr, delegator.delegatedStake, _candidate.stakingPool);
    }

    /**
     * @notice Add the delegated stake of a delegator to an candidate
     * @param _candidate the candidate
     * @param _delegatorAddr the delegator address
     * @param _amount update amount
     */
    function _removeDelegatedStake(
        ValidatorCandidate storage _candidate,
        address _candidateAddr,
        address _delegatorAddr,
        uint256 _amount
    ) private {
        Delegator storage delegator = _candidate.delegators[_delegatorAddr];
        delegator.delegatedStake -= _amount;
        _candidate.stakingPool -= _amount;
        if (_candidate.status == CandidateStatus.Bonded) {
            totalValidatorStake -= _amount;
        }
        emit UpdateDelegatedStake(_delegatorAddr, _candidateAddr, delegator.delegatedStake, _candidate.stakingPool);
    }

    function _bondValidator(address _vaddr) private {
        ValidatorCandidate storage validator = candidateProfiles[_vaddr];
        validator.status = CandidateStatus.Bonded;
        delete validator.unbondTime;
        totalValidatorStake += validator.stakingPool;
        emit ValidatorChange(_vaddr, ValidatorChangeType.Add);
    }

    function _unbondValidator(address _vaddr) private {
        ValidatorCandidate storage validator = candidateProfiles[_vaddr];
        validator.status = CandidateStatus.Unbonding;
        validator.unbondTime = block.number + getUIntValue(uint256(ParamNames.SlashTimeout));
        totalValidatorStake -= validator.stakingPool;
        emit ValidatorChange(_vaddr, ValidatorChangeType.Removal);
    }

    /**
     * @notice Add a validator
     * @param _vaddr the address of the validator
     */
    function _addValidator(address _vaddr) private {
        validators.push(_vaddr);
        _bondValidator(_vaddr);
    }

    /**
     * @notice Add a validator
     * @param _vaddr the address of the new validator
     * @param _index the index of the validator to be replaced
     */
    function _replaceValidator(address _vaddr, uint256 _index) private {
        _unbondValidator(validators[_index]);
        validators[_index] = _vaddr;
        _bondValidator(_vaddr);
    }

    /**
     * @notice Remove a validator
     * @param _vaddr validator to be removed
     */
    function _removeValidator(address _vaddr) private {
        uint256 lastIndex = validators.length - 1;
        for (uint256 i = 0; i < validators.length; i++) {
            if (validators[i] == _vaddr) {
                if (i < lastIndex) {
                    validators[i] = validators[lastIndex];
                }
                validators.pop();
                _unbondValidator(_vaddr);
                return;
            }
        }
        revert("Not bonded validator");
    }

    /**
     * @notice Validate a validator status after stakes change
     * @dev remove this validator if it doesn't meet the requirement of being a validator
     * @param _validatorAddr the validator address
     */
    function _validateValidator(address _validatorAddr) private {
        ValidatorCandidate storage v = candidateProfiles[_validatorAddr];
        if (v.status != CandidateStatus.Bonded) {
            // no need to validate the stake of a non-validator
            return;
        }
        bool lowSelfStake = v.delegators[_validatorAddr].delegatedStake < v.minSelfStake;
        bool lowStakingPool = v.stakingPool < getUIntValue(uint256(ParamNames.MinStakeInPool));
        if (lowSelfStake || lowStakingPool) {
            _removeValidator(_validatorAddr);
        }
    }
}
