// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./lib/proto/PbSgn.sol";
import "./Govern.sol";

/**
 * @title A DPoS contract shared by every sidechain
 * @notice This contract holds the basic logic of DPoS in Celer's coherent sidechain system
 */
contract DPoS is Ownable, Pausable, Govern {
    uint256 constant DECIMALS_MULTIPLIER = 10**18;
    uint256 public constant COMMISSION_RATE_BASE = 10000; // 1 commissionRate means 0.01%

    using SafeERC20 for IERC20;
    using ECDSA for bytes32;

    // Unbonded: not a validator and not responsible for previous validator behaviors if any.
    //   Delegators now are free to withdraw stakes (directly).
    // Bonded: active validator. Delegators have to wait for slashTimeout to withdraw stakes.
    // Unbonding: transitional status from Bonded to Unbonded. Candidate has lost the right of
    //   validator but is still responsible for any misbehaviour done during being validator.
    //   Delegators should wait until candidate's unbondTime to freely withdraw stakes.
    enum CandidateStatus {
        Unbonded,
        Bonded,
        Unbonding
    }

    enum ValidatorChangeType {
        Add,
        Removal
    }

    enum MathOperation {
        Add,
        Sub
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

    struct ValidatorCandidate {
        bool initialized;
        uint256 minSelfStake;
        uint256 stakingPool; // sum of all delegations to this candidate
        mapping(address => Delegator) delegatorProfiles;
        CandidateStatus status;
        uint256 unbondTime;
        uint256 commissionRate; // equal to real commission rate * COMMISSION_RATE_BASE
        uint256 rateLockEndTime; // must be monotonic increasing. Use block number
        // for the announcement of increasing commission rate
        uint256 announcedRate;
        uint256 announcedLockEndTime;
        uint256 announcementTime;
        // for decreasing minSelfStake
        uint256 earliestBondTime;
    }

    mapping(uint256 => address) public validatorSet;
    mapping(uint256 => bool) public usedPenaltyNonce;
    // used in checkValidatorSigs(). mapping has to be storage type.
    mapping(address => bool) public checkedValidators;
    // struct ValidatorCandidate includes a mapping and therefore candidateProfiles can't be public
    mapping(address => ValidatorCandidate) private candidateProfiles;
    mapping(address => uint256) public redeemedMiningReward;

    uint256 public dposGoLiveTime; // used when bootstrapping initial validators
    uint256 public miningPool;
    bool public enableWhitelist;
    bool public enableSlash;

    /* Events */
    event InitializeCandidate(
        address indexed candidate,
        uint256 minSelfStake,
        uint256 commissionRate,
        uint256 rateLockEndTime
    );
    event CommissionRateAnnouncement(address indexed candidate, uint256 announcedRate, uint256 announcedLockEndTime);
    event UpdateCommissionRate(address indexed candidate, uint256 newRate, uint256 newLockEndTime);
    event UpdateMinSelfStake(address indexed candidate, uint256 minSelfStake);
    event Delegate(address indexed delegator, address indexed candidate, uint256 newStake, uint256 stakingPool);
    event ValidatorChange(address indexed ethAddr, ValidatorChangeType indexed changeType);
    event WithdrawFromUnbondedCandidate(address indexed delegator, address indexed candidate, uint256 amount);
    event IntendWithdraw(
        address indexed delegator,
        address indexed candidate,
        uint256 withdrawAmount,
        uint256 proposedTime
    );
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
    event RedeemMiningReward(address indexed receiver, uint256 reward, uint256 miningPool);
    event MiningPoolContribution(address indexed contributor, uint256 contribution, uint256 miningPoolSize);

    /**
     * @notice DPoS constructor
     * @dev will initialize parent contract Govern first
     * @param _celerTokenAddress address of Celer Token Contract
     * @param _governProposalDeposit required deposit amount for a governance proposal
     * @param _governVoteTimeout voting timeout for a governance proposal
     * @param _slashTimeout the locking time for funds to be potentially slashed
     * @param _minValidatorNum the minimum number of validators
     * @param _maxValidatorNum the maximum number of validators
     * @param _minStakeInPool the global minimum requirement of staking pool for each validator
     * @param _advanceNoticePeriod the wait time after the announcement and prior to the effective date of an update
     * @param _dposGoLiveTimeout the timeout for DPoS to go live after contract creation
     */
    constructor(
        address _celerTokenAddress,
        uint256 _governProposalDeposit,
        uint256 _governVoteTimeout,
        uint256 _slashTimeout,
        uint256 _minValidatorNum,
        uint256 _maxValidatorNum,
        uint256 _minStakeInPool,
        uint256 _advanceNoticePeriod,
        uint256 _dposGoLiveTimeout
    )
        Govern(
            _celerTokenAddress,
            _governProposalDeposit,
            _governVoteTimeout,
            _slashTimeout,
            _minValidatorNum,
            _maxValidatorNum,
            _minStakeInPool,
            _advanceNoticePeriod
        )
    {
        dposGoLiveTime = block.number + _dposGoLiveTimeout;
        enableSlash = true;
    }

    /**
     * @notice Throws if given address is zero address
     * @param _addr address to be checked
     */
    modifier onlyNonZeroAddr(address _addr) {
        require(_addr != address(0), "0 address");
        _;
    }

    /**
     * @notice Throws if DPoS is not valid
     * @dev Need to be checked before DPoS's operations
     */
    modifier onlyValidDPoS() {
        require(isValidDPoS(), "DPoS is not valid");
        _;
    }

    /**
     * @notice Throws if msg.sender is not a registered sidechain
     */
    modifier onlyRegisteredSidechains() {
        require(isSidechainRegistered(msg.sender), "Sidechain not registered");
        _;
    }

    /**
     * @notice Check if the sender is in the whitelist
     */
    modifier onlyWhitelist() {
        if (enableWhitelist) {
            // TODO: add back whitelist
            /*
            require(
                isWhitelisted(msg.sender),
                'WhitelistedRole: caller does not have the Whitelisted role'
            );
            */
        }
        _;
    }

    /**
     * @notice Throws if contract in migrating state
     */
    modifier onlyNotMigrating() {
        require(!isMigrating(), "contract migrating");
        _;
    }

    /**
     * @notice Throws if amount is smaller than minimum
     */
    modifier minAmount(uint256 _amount, uint256 _min) {
        require(_amount >= _min, "Amount is smaller than minimum requirement");
        _;
    }

    /**
     * @notice Throws if sender is not validator
     */
    modifier onlyValidator() {
        require(isValidator(msg.sender), "msg sender is not a validator");
        _;
    }

    /**
     * @notice Throws if candidate is not initialized
     */
    modifier isCandidateInitialized() {
        require(candidateProfiles[msg.sender].initialized, "Candidate is not initialized");
        _;
    }

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
        uint256 maxValidatorNum = getUIntValue(uint256(ParamNames.MaxValidatorNum));

        // check Yes votes only now
        uint256 yesVoteStakes;
        for (uint256 i = 0; i < maxValidatorNum; i++) {
            if (getParamProposalVote(_proposalId, validatorSet[i]) == VoteType.Yes) {
                yesVoteStakes = yesVoteStakes + candidateProfiles[validatorSet[i]].stakingPool;
            }
        }

        bool passed = yesVoteStakes >= getMinQuorumStakingPool();
        if (!passed) {
            miningPool = miningPool + paramProposals[_proposalId].deposit;
        }
        internalConfirmParamProposal(_proposalId, passed);
    }

    /**
     * @notice Vote for a sidechain proposal with a specific type of vote
     * @param _proposalId the id of the sidechain proposal
     * @param _vote the type of vote
     */
    function voteSidechain(uint256 _proposalId, VoteType _vote) external onlyValidator {
        internalVoteSidechain(_proposalId, msg.sender, _vote);
    }

    /**
     * @notice Confirm a sidechain proposal
     * @param _proposalId the id of the sidechain proposal
     */
    function confirmSidechainProposal(uint256 _proposalId) external {
        uint256 maxValidatorNum = getUIntValue(uint256(ParamNames.MaxValidatorNum));

        // check Yes votes only now
        uint256 yesVoteStakes;
        for (uint256 i = 0; i < maxValidatorNum; i++) {
            if (getSidechainProposalVote(_proposalId, validatorSet[i]) == VoteType.Yes) {
                yesVoteStakes = yesVoteStakes + candidateProfiles[validatorSet[i]].stakingPool;
            }
        }

        bool passed = yesVoteStakes >= getMinQuorumStakingPool();
        if (!passed) {
            miningPool = miningPool + sidechainProposals[_proposalId].deposit;
        }
        internalConfirmSidechainProposal(_proposalId, passed);
    }

    /**
     * @notice Contribute CELR tokens to the mining pool
     * @param _amount the amount of CELR tokens to contribute
     */
    function contributeToMiningPool(uint256 _amount) external whenNotPaused {
        address msgSender = msg.sender;
        miningPool = miningPool + _amount;
        celerToken.safeTransferFrom(msgSender, address(this), _amount);

        emit MiningPoolContribution(msgSender, _amount, miningPool);
    }

    /**
     * @notice Redeem mining reward
     * @dev The validation of this redeeming operation should be done by the caller, a registered sidechain contract
     * @dev Here we use cumulative mining reward to simplify the logic in sidechain code
     * @param _receiver the receiver of the redeemed mining reward
     * @param _cumulativeReward the latest cumulative mining reward
     */
    function redeemMiningReward(address _receiver, uint256 _cumulativeReward)
        external
        whenNotPaused
        onlyRegisteredSidechains
    {
        uint256 newReward = _cumulativeReward - redeemedMiningReward[_receiver];
        require(miningPool >= newReward, "Mining pool is smaller than new reward");

        redeemedMiningReward[_receiver] = _cumulativeReward;
        miningPool = miningPool - newReward;
        celerToken.safeTransfer(_receiver, newReward);

        emit RedeemMiningReward(_receiver, newReward, miningPool);
    }

    /**
     * @notice Initialize a candidate profile for validator
     * @dev every validator must become a candidate first
     * @param _minSelfStake minimal amount of tokens staked by the validator itself
     * @param _commissionRate the self-declaimed commission rate
     * @param _rateLockEndTime the lock end time of initial commission rate
     */
    function initializeCandidate(
        uint256 _minSelfStake,
        uint256 _commissionRate,
        uint256 _rateLockEndTime
    ) external whenNotPaused onlyWhitelist {
        ValidatorCandidate storage candidate = candidateProfiles[msg.sender];
        require(!candidate.initialized, "Candidate is initialized");
        require(_commissionRate <= COMMISSION_RATE_BASE, "Invalid commission rate");

        candidate.initialized = true;
        candidate.minSelfStake = _minSelfStake;
        candidate.commissionRate = _commissionRate;
        candidate.rateLockEndTime = _rateLockEndTime;

        emit InitializeCandidate(msg.sender, _minSelfStake, _commissionRate, _rateLockEndTime);
    }

    /**
     * @notice Apply non-increase-commission-rate changes to commission rate or lock end time,
     *   including decreasing commission rate and/or changing lock end time
     * @dev It can increase lock end time immediately without waiting
     * @param _newRate new commission rate
     * @param _newLockEndTime new lock end time
     */
    function nonIncreaseCommissionRate(uint256 _newRate, uint256 _newLockEndTime) external isCandidateInitialized {
        ValidatorCandidate storage candidate = candidateProfiles[msg.sender];
        require(_newRate <= candidate.commissionRate, "Invalid new rate");

        _updateCommissionRate(candidate, _newRate, _newLockEndTime);
    }

    /**
     * @notice Announce the intent of increasing the commission rate
     * @param _newRate new commission rate
     * @param _newLockEndTime new lock end time
     */
    function announceIncreaseCommissionRate(uint256 _newRate, uint256 _newLockEndTime) external isCandidateInitialized {
        ValidatorCandidate storage candidate = candidateProfiles[msg.sender];
        require(candidate.commissionRate < _newRate, "Invalid new rate");

        candidate.announcedRate = _newRate;
        candidate.announcedLockEndTime = _newLockEndTime;
        candidate.announcementTime = block.number;

        emit CommissionRateAnnouncement(msg.sender, _newRate, _newLockEndTime);
    }

    /**
     * @notice Confirm the intent of increasing the commission rate
     */
    function confirmIncreaseCommissionRate() external isCandidateInitialized {
        ValidatorCandidate storage candidate = candidateProfiles[msg.sender];
        require(
            block.number > candidate.announcementTime + getUIntValue(uint256(ParamNames.AdvanceNoticePeriod)),
            "Still in notice period"
        );

        _updateCommissionRate(candidate, candidate.announcedRate, candidate.announcedLockEndTime);

        delete candidate.announcedRate;
        delete candidate.announcedLockEndTime;
        delete candidate.announcementTime;
    }

    /**
     * @notice update minimal self stake value
     * @param _minSelfStake minimal amount of tokens staked by the validator itself
     */
    function updateMinSelfStake(uint256 _minSelfStake) external isCandidateInitialized {
        ValidatorCandidate storage candidate = candidateProfiles[msg.sender];
        if (_minSelfStake < candidate.minSelfStake) {
            require(candidate.status != CandidateStatus.Bonded, "Candidate is bonded");
            candidate.earliestBondTime = block.number + getUIntValue(uint256(ParamNames.AdvanceNoticePeriod));
        }
        candidate.minSelfStake = _minSelfStake;
        emit UpdateMinSelfStake(msg.sender, _minSelfStake);
    }

    /**
     * @notice Delegate CELR tokens to a candidate
     * @param _candidateAddr candidate to delegate
     * @param _amount the amount of delegated CELR tokens
     */
    function delegate(address _candidateAddr, uint256 _amount)
        external
        whenNotPaused
        onlyNonZeroAddr(_candidateAddr)
        minAmount(_amount, 1 * DECIMALS_MULTIPLIER) // minimal amount per delegate operation is 1 CELR
    {
        ValidatorCandidate storage candidate = candidateProfiles[_candidateAddr];
        require(candidate.initialized, "Candidate is not initialized");

        address msgSender = msg.sender;
        _updateDelegatedStake(candidate, _candidateAddr, msgSender, _amount, MathOperation.Add);

        celerToken.safeTransferFrom(msgSender, address(this), _amount);

        emit Delegate(msgSender, _candidateAddr, _amount, candidate.stakingPool);
    }

    /**
     * @notice Candidate claims to become a validator
     */
    function claimValidator() external isCandidateInitialized {
        address msgSender = msg.sender;
        ValidatorCandidate storage candidate = candidateProfiles[msgSender];
        require(
            candidate.status == CandidateStatus.Unbonded || candidate.status == CandidateStatus.Unbonding,
            "Invalid candidate status"
        );
        require(block.number >= candidate.earliestBondTime, "Not earliest bond time yet");
        require(candidate.stakingPool >= getUIntValue(uint256(ParamNames.MinStakeInPool)), "Insufficient staking pool");
        require(
            candidate.delegatorProfiles[msgSender].delegatedStake >= candidate.minSelfStake,
            "Not enough self stake"
        );

        uint256 minStakingPoolIndex;
        uint256 minStakingPool = candidateProfiles[validatorSet[0]].stakingPool;
        require(validatorSet[0] != msgSender, "Already in validator set");
        uint256 maxValidatorNum = getUIntValue(uint256(ParamNames.MaxValidatorNum));
        for (uint256 i = 1; i < maxValidatorNum; i++) {
            require(validatorSet[i] != msgSender, "Already in validator set");
            if (candidateProfiles[validatorSet[i]].stakingPool < minStakingPool) {
                minStakingPoolIndex = i;
                minStakingPool = candidateProfiles[validatorSet[i]].stakingPool;
            }
        }
        require(candidate.stakingPool > minStakingPool, "Not larger than smallest pool");

        address removedValidator = validatorSet[minStakingPoolIndex];
        if (removedValidator != address(0)) {
            _removeValidator(minStakingPoolIndex);
        }
        _addValidator(msgSender, minStakingPoolIndex);
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
     * @dev note that the stakes are delegated by the msgSender to the candidate
     * @param _candidateAddr the address of the candidate
     * @param _amount withdrawn amount
     */
    function withdrawFromUnbondedCandidate(address _candidateAddr, uint256 _amount)
        external
        onlyNonZeroAddr(_candidateAddr)
        minAmount(_amount, 1 * DECIMALS_MULTIPLIER)
    {
        ValidatorCandidate storage candidate = candidateProfiles[_candidateAddr];
        require(candidate.status == CandidateStatus.Unbonded || isMigrating(), "invalid status");

        address msgSender = msg.sender;
        _updateDelegatedStake(candidate, _candidateAddr, msgSender, _amount, MathOperation.Sub);
        celerToken.safeTransfer(msgSender, _amount);

        emit WithdrawFromUnbondedCandidate(msgSender, _candidateAddr, _amount);
    }

    /**
     * @notice Intend to withdraw delegated stakes from a candidate
     * @dev note that the stakes are delegated by the msgSender to the candidate
     * @param _candidateAddr the address of the candidate
     * @param _amount withdrawn amount
     */
    function intendWithdraw(address _candidateAddr, uint256 _amount)
        external
        onlyNonZeroAddr(_candidateAddr)
        minAmount(_amount, 1 * DECIMALS_MULTIPLIER)
    {
        address msgSender = msg.sender;

        ValidatorCandidate storage candidate = candidateProfiles[_candidateAddr];
        Delegator storage delegator = candidate.delegatorProfiles[msgSender];

        _updateDelegatedStake(candidate, _candidateAddr, msgSender, _amount, MathOperation.Sub);
        delegator.undelegatingStake = delegator.undelegatingStake + _amount;
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
    function confirmWithdraw(address _candidateAddr) external onlyNonZeroAddr(_candidateAddr) {
        address msgSender = msg.sender;
        Delegator storage delegator = candidateProfiles[_candidateAddr].delegatorProfiles[msgSender];

        uint256 slashTimeout = getUIntValue(uint256(ParamNames.SlashTimeout));
        bool isUnbonded = candidateProfiles[_candidateAddr].status == CandidateStatus.Unbonded;
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
            undelegatingStakeWithoutSlash = undelegatingStakeWithoutSlash + delegator.withdrawIntents[i].amount;
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
     */
    function slash(bytes calldata _penaltyRequest) external whenNotPaused onlyValidDPoS onlyNotMigrating {
        require(enableSlash, "Slash is disabled");
        PbSgn.PenaltyRequest memory penaltyRequest = PbSgn.decPenaltyRequest(_penaltyRequest);
        PbSgn.Penalty memory penalty = PbSgn.decPenalty(penaltyRequest.penalty);

        ValidatorCandidate storage validator = candidateProfiles[penalty.validatorAddress];
        require(validator.status != CandidateStatus.Unbonded, "Validator unbounded");

        bytes32 h = keccak256(penaltyRequest.penalty);
        require(_checkValidatorSigs(h, penaltyRequest.sigs), "Validator sigs verification failed");
        require(block.number < penalty.expireTime, "Penalty expired");
        require(!usedPenaltyNonce[penalty.nonce], "Used penalty nonce");
        usedPenaltyNonce[penalty.nonce] = true;

        uint256 totalSubAmt;
        for (uint256 i = 0; i < penalty.penalizedDelegators.length; i++) {
            PbSgn.AccountAmtPair memory penalizedDelegator = penalty.penalizedDelegators[i];
            totalSubAmt = totalSubAmt + penalizedDelegator.amt;
            emit Slash(penalty.validatorAddress, penalizedDelegator.account, penalizedDelegator.amt);

            Delegator storage delegator = validator.delegatorProfiles[penalizedDelegator.account];
            uint256 _amt;
            if (delegator.delegatedStake >= penalizedDelegator.amt) {
                _amt = penalizedDelegator.amt;
            } else {
                uint256 remainingAmt = penalizedDelegator.amt - delegator.delegatedStake;
                delegator.undelegatingStake = delegator.undelegatingStake - remainingAmt;
                _amt = delegator.delegatedStake;
            }
            _updateDelegatedStake(
                validator,
                penalty.validatorAddress,
                penalizedDelegator.account,
                _amt,
                MathOperation.Sub
            );
        }
        _validateValidator(penalty.validatorAddress);

        uint256 totalAddAmt;
        for (uint256 i = 0; i < penalty.beneficiaries.length; i++) {
            PbSgn.AccountAmtPair memory beneficiary = penalty.beneficiaries[i];
            totalAddAmt = totalAddAmt + beneficiary.amt;

            if (beneficiary.account == address(0)) {
                // address(0) stands for miningPool
                miningPool = miningPool + beneficiary.amt;
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
     * @dev Can't use view here because _checkValidatorSigs is not a view function
     * @param _request a multi-signed message bytes coded in protobuf
     * @return passed the validation or not
     */
    function validateMultiSigMessage(bytes calldata _request) external onlyRegisteredSidechains returns (bool) {
        PbSgn.MultiSigMessage memory request = PbSgn.decMultiSigMessage(_request);
        bytes32 h = keccak256(request.msg);

        return _checkValidatorSigs(h, request.sigs);
    }

    /**
     * @notice Update enableWhitelist
     * @param _enable enable whitelist flag
     */
    function updateEnableWhitelist(bool _enable) external onlyOwner {
        enableWhitelist = _enable;
    }

    /**
     * @notice Update enableSlash
     * @param _enable enable slash flag
     */
    function updateEnableSlash(bool _enable) external onlyOwner {
        enableSlash = _enable;
    }

    /**
     * @notice Owner drains one type of tokens when the contract is paused
     * @dev This is for emergency situations.
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
        uint256 maxValidatorNum = getUIntValue(uint256(ParamNames.MaxValidatorNum));

        uint256 minStakingPool = candidateProfiles[validatorSet[0]].stakingPool;
        for (uint256 i = 0; i < maxValidatorNum; i++) {
            if (validatorSet[i] == address(0)) {
                return 0;
            }
            if (candidateProfiles[validatorSet[i]].stakingPool < minStakingPool) {
                minStakingPool = candidateProfiles[validatorSet[i]].stakingPool;
            }
        }

        return minStakingPool;
    }

    /**
     * @notice Get candidate info
     * @param _candidateAddr the address of the candidate
     * @return initialized whether initialized or not
     * @return minSelfStake minimum self stakes
     * @return stakingPool staking pool
     * @return status candidate status
     * @return unbondTime unbond time
     * @return commissionRate commission rate
     * @return rateLockEndTime commission rate lock end time
     */
    function getCandidateInfo(address _candidateAddr)
        external
        view
        returns (
            bool initialized,
            uint256 minSelfStake,
            uint256 stakingPool,
            uint256 status,
            uint256 unbondTime,
            uint256 commissionRate,
            uint256 rateLockEndTime
        )
    {
        ValidatorCandidate storage c = candidateProfiles[_candidateAddr];

        initialized = c.initialized;
        minSelfStake = c.minSelfStake;
        stakingPool = c.stakingPool;
        status = uint256(c.status);
        unbondTime = c.unbondTime;
        commissionRate = c.commissionRate;
        rateLockEndTime = c.rateLockEndTime;
    }

    /**
     * @notice Get the delegator info of a specific candidate
     * @param _candidateAddr the address of the candidate
     * @param _delegatorAddr the address of the delegator
     * @return delegatedStake delegated stake to this candidate
     * @return undelegatingStake undelegating stakes
     * @return intentAmounts the amounts of withdraw intents
     * @return intentProposedTimes the proposed times of withdraw intents
     */
    function getDelegatorInfo(address _candidateAddr, address _delegatorAddr)
        external
        view
        returns (
            uint256 delegatedStake,
            uint256 undelegatingStake,
            uint256[] memory intentAmounts,
            uint256[] memory intentProposedTimes
        )
    {
        Delegator storage d = candidateProfiles[_candidateAddr].delegatorProfiles[_delegatorAddr];

        uint256 len = d.intentEndIndex - d.intentStartIndex;
        intentAmounts = new uint256[](len);
        intentProposedTimes = new uint256[](len);
        for (uint256 i = 0; i < len; i++) {
            intentAmounts[i] = d.withdrawIntents[i + d.intentStartIndex].amount;
            intentProposedTimes[i] = d.withdrawIntents[i + d.intentStartIndex].proposedTime;
        }

        delegatedStake = d.delegatedStake;
        undelegatingStake = d.undelegatingStake;
    }

    /**
     * @notice Check this DPoS contract is valid or not now
     * @return DPoS is valid or not
     */
    function isValidDPoS() public view returns (bool) {
        return block.number >= dposGoLiveTime && getValidatorNum() >= getUIntValue(uint256(ParamNames.MinValidatorNum));
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
     * @notice Check if the contract is in migrating state
     * @return contract in migrating state or not
     */
    function isMigrating() public view returns (bool) {
        uint256 migrationTime = getUIntValue(uint256(ParamNames.MigrationTime));
        return migrationTime != 0 && block.number >= migrationTime;
    }

    /**
     * @notice Get the number of validators
     * @return the number of validators
     */
    function getValidatorNum() public view returns (uint256) {
        uint256 maxValidatorNum = getUIntValue(uint256(ParamNames.MaxValidatorNum));

        uint256 num;
        for (uint256 i = 0; i < maxValidatorNum; i++) {
            if (validatorSet[i] != address(0)) {
                num++;
            }
        }
        return num;
    }

    /**
     * @notice Get minimum amount of stakes for a quorum
     * @return the minimum amount
     */
    function getMinQuorumStakingPool() public view returns (uint256) {
        return (getTotalValidatorStakingPool() * 2) / 3 + 1;
    }

    /**
     * @notice Get the total amount of stakes in validators' staking pools
     * @return the total amount
     */
    function getTotalValidatorStakingPool() public view returns (uint256) {
        uint256 maxValidatorNum = getUIntValue(uint256(ParamNames.MaxValidatorNum));

        uint256 totalValidatorStakingPool;
        for (uint256 i = 0; i < maxValidatorNum; i++) {
            totalValidatorStakingPool = totalValidatorStakingPool + candidateProfiles[validatorSet[i]].stakingPool;
        }

        return totalValidatorStakingPool;
    }

    /*********************
     * Private Functions *
     *********************/

    /**
     * @notice Update the commission rate of a candidate
     * @param _candidate the candidate to update
     * @param _newRate new commission rate
     * @param _newLockEndTime new lock end time
     */
    function _updateCommissionRate(
        ValidatorCandidate storage _candidate,
        uint256 _newRate,
        uint256 _newLockEndTime
    ) private {
        require(_newRate <= COMMISSION_RATE_BASE, "Invalid new rate");
        require(_newLockEndTime >= block.number, "Outdated new lock end time");

        if (_newRate <= _candidate.commissionRate) {
            require(_newLockEndTime >= _candidate.rateLockEndTime, "Invalid new lock end time");
        } else {
            require(block.number > _candidate.rateLockEndTime, "Commission rate is locked");
        }

        _candidate.commissionRate = _newRate;
        _candidate.rateLockEndTime = _newLockEndTime;

        emit UpdateCommissionRate(msg.sender, _newRate, _newLockEndTime);
    }

    /**
     * @notice Update the delegated stake of a delegator to an candidate
     * @param _candidate the candidate
     * @param _delegatorAddr the delegator address
     * @param _amount update amount
     * @param _op update operation
     */
    function _updateDelegatedStake(
        ValidatorCandidate storage _candidate,
        address _candidateAddr,
        address _delegatorAddr,
        uint256 _amount,
        MathOperation _op
    ) private {
        Delegator storage delegator = _candidate.delegatorProfiles[_delegatorAddr];

        if (_op == MathOperation.Add) {
            _candidate.stakingPool = _candidate.stakingPool + _amount;
            delegator.delegatedStake = delegator.delegatedStake + _amount;
        } else if (_op == MathOperation.Sub) {
            _candidate.stakingPool = _candidate.stakingPool - _amount;
            delegator.delegatedStake = delegator.delegatedStake - _amount;
        } else {
            assert(false);
        }
        emit UpdateDelegatedStake(_delegatorAddr, _candidateAddr, delegator.delegatedStake, _candidate.stakingPool);
    }

    /**
     * @notice Add a validator
     * @param _validatorAddr the address of the validator
     * @param _setIndex the index to put the validator
     */
    function _addValidator(address _validatorAddr, uint256 _setIndex) private {
        require(validatorSet[_setIndex] == address(0), "Validator slot occupied");

        validatorSet[_setIndex] = _validatorAddr;
        candidateProfiles[_validatorAddr].status = CandidateStatus.Bonded;
        delete candidateProfiles[_validatorAddr].unbondTime;
        emit ValidatorChange(_validatorAddr, ValidatorChangeType.Add);
    }

    /**
     * @notice Remove a validator
     * @param _setIndex the index of the validator to be removed
     */
    function _removeValidator(uint256 _setIndex) private {
        address removedValidator = validatorSet[_setIndex];
        if (removedValidator == address(0)) {
            return;
        }

        delete validatorSet[_setIndex];
        candidateProfiles[removedValidator].status = CandidateStatus.Unbonding;
        candidateProfiles[removedValidator].unbondTime = block.number + getUIntValue(uint256(ParamNames.SlashTimeout));
        emit ValidatorChange(removedValidator, ValidatorChangeType.Removal);
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

        bool lowSelfStake = v.delegatorProfiles[_validatorAddr].delegatedStake < v.minSelfStake;
        bool lowStakingPool = v.stakingPool < getUIntValue(uint256(ParamNames.MinStakeInPool));

        if (lowSelfStake || lowStakingPool) {
            _removeValidator(_getValidatorIdx(_validatorAddr));
        }
    }

    /**
     * @notice Check whether validators with more than 2/3 total stakes have signed this hash
     * @param _h signed hash
     * @param _sigs signatures
     * @return whether the signatures are valid or not
     */
    function _checkValidatorSigs(bytes32 _h, bytes[] memory _sigs) private returns (bool) {
        uint256 minQuorumStakingPool = getMinQuorumStakingPool();

        bytes32 hash = _h.toEthSignedMessageHash();
        address[] memory addrs = new address[](_sigs.length);
        uint256 quorumStakingPool;
        bool hasDuplicatedSig;
        for (uint256 i = 0; i < _sigs.length; i++) {
            addrs[i] = hash.recover(_sigs[i]);
            if (checkedValidators[addrs[i]]) {
                hasDuplicatedSig = true;
                break;
            }
            if (candidateProfiles[addrs[i]].status != CandidateStatus.Bonded) {
                continue;
            }

            quorumStakingPool = quorumStakingPool + candidateProfiles[addrs[i]].stakingPool;
            checkedValidators[addrs[i]] = true;
        }

        for (uint256 i = 0; i < _sigs.length; i++) {
            checkedValidators[addrs[i]] = false;
        }

        return !hasDuplicatedSig && quorumStakingPool >= minQuorumStakingPool;
    }

    /**
     * @notice Get validator index
     * @param _addr the validator address
     * @return the index of the validator
     */
    function _getValidatorIdx(address _addr) private view returns (uint256) {
        uint256 maxValidatorNum = getUIntValue(uint256(ParamNames.MaxValidatorNum));

        for (uint256 i = 0; i < maxValidatorNum; i++) {
            if (validatorSet[i] == _addr) {
                return i;
            }
        }

        revert("No such a validator");
    }
}
