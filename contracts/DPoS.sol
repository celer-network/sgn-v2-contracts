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
    uint256 constant CELR_DECIMAL = 1e18;
    uint256 constant MAX_INT = 2**256 - 1;
    uint256 public constant COMMISSION_RATE_BASE = 10000; // 1 commissionRate means 0.01%

    using SafeERC20 for IERC20;
    using ECDSA for bytes32;

    enum ValidatorStatus {
        Null,
        Unbonded,
        Bonded,
        Unbonding
    }

    struct Undelegation {
        uint256 amount;
        uint256 creationBlock;
    }

    struct Undelegations {
        uint256 sum;
        mapping(uint256 => Undelegation) queue;
        uint32 head;
        uint32 tail;
    }

    struct Delegator {
        uint256 shares;
        Undelegations undelegations;
    }

    struct Validator {
        ValidatorStatus status;
        uint256 tokens; // sum of all delegations to this validator
        mapping(address => Delegator) delegators;
        uint256 unbondTime;
        uint256 commissionRate; // equal to real commission rate * COMMISSION_RATE_BASE
        uint256 minSelfDelegation;
        uint256 earliestBondTime;
    }

    uint256 public rewardPool;
    uint256 public totalBondedTokens;
    address[] public valAddrs;
    address[] public bondedValAddrs; // TODO: deal with set size reduction
    mapping(address => Validator) public validators;
    mapping(address => uint256) public claimedReward;

    bool public slashDisabled;
    mapping(uint256 => bool) public usedPenaltyNonce;

    /* Events */
    // TODO: remove unnecessary event index
    event InitializeValidatorCandidate(address indexed valAddr, uint256 minSelfDelegation, uint256 commissionRate);
    event CommissionRateUpdate(address indexed valAddr, uint256 newRate);
    event MinSelfDelegationUpdate(address indexed valAddr, uint256 minSelfDelegation);
    event ValidatorStatusUpdate(address indexed valAddr, ValidatorStatus indexed status);
    event Undelegate(address indexed delAddr, address indexed valAddr, uint256 amount, uint256 creationBlock);
    event UndelegateCompleted(address indexed delAddr, address indexed valAddr, uint256 amount);
    event DelegationUpdate(
        address indexed delAddr,
        address indexed valAddr,
        uint256 delegatorShares,
        uint256 validatoTokens
    );
    event Slash(address indexed valAddr, address indexed delAddr, uint256 amount);
    event Compensate(address indexed recipient, uint256 amount);
    event RewardClaimed(address indexed recipient, uint256 reward, uint256 rewardPool);
    event MiningPoolContribution(address indexed contributor, uint256 contribution, uint256 rewardPoolSize);

    /**
     * @notice DPoS constructor
     * @dev will initialize parent contract Govern first
     * @param _celerTokenAddress address of Celer Token Contract
     * @param _governProposalDeposit required deposit amount for a governance proposal
     * @param _governVoteTimeout voting timeout for a governance proposal
     * @param _slashTimeout the locking time for funds to be potentially slashed
     * @param _maxBondedValidators the maximum number of bonded validators
     * @param _minValidatorTokens the global minimum token amout requirement for bonded validator
     * @param _advanceNoticePeriod the wait time after the announcement and prior to the effective date of an update
     */
    constructor(
        address _celerTokenAddress,
        uint256 _governProposalDeposit,
        uint256 _governVoteTimeout,
        uint256 _slashTimeout,
        uint256 _maxBondedValidators,
        uint256 _minValidatorTokens,
        uint256 _advanceNoticePeriod
    )
        Govern(
            _celerTokenAddress,
            _governProposalDeposit,
            _governVoteTimeout,
            _slashTimeout,
            _maxBondedValidators,
            _minValidatorTokens,
            _advanceNoticePeriod
        )
    {}

    receive() external payable {}

    /*********************************
     * External and Public Functions *
     *********************************/

    /**
     * @notice Initialize a validator candidate
     * @dev every validator must become a candidate first
     * @param _minSelfDelegation minimal amount of tokens staked by the validator itself
     * @param _commissionRate the self-declaimed commission rate
     */
    function initializeValidatorCandidate(uint256 _minSelfDelegation, uint256 _commissionRate)
        external
        whenNotPaused
        onlyWhitelisted
    {
        Validator storage validator = validators[msg.sender];
        require(validator.status == ValidatorStatus.Null, "Validator is initialized");
        require(_commissionRate <= COMMISSION_RATE_BASE, "Invalid commission rate");
        require(_minSelfDelegation >= CELR_DECIMAL, "Invalid min self delegation");

        validator.status = ValidatorStatus.Unbonded;
        validator.minSelfDelegation = _minSelfDelegation;
        validator.commissionRate = _commissionRate;

        valAddrs.push(msg.sender);

        // TODO: auto self delegate when initialized?
        emit InitializeValidatorCandidate(msg.sender, _minSelfDelegation, _commissionRate);
    }

    /**
     * @notice Candidate claims to become a bonded validator
     */
    function bondValidator() external {
        address msgSender = msg.sender;
        Validator storage validator = validators[msgSender];
        require(
            validator.status == ValidatorStatus.Unbonded || validator.status == ValidatorStatus.Unbonding,
            "Invalid validator status"
        );
        require(block.number >= validator.earliestBondTime, "Not earliest bond time yet");
        require(validator.tokens >= getUIntValue(uint256(ParamNames.MinValidatorTokens)), "Need min required tokens");
        require(validator.delegators[msgSender].shares >= validator.minSelfDelegation, "Insufficient self delegation");

        uint256 maxBondedValidators = getUIntValue(uint256(ParamNames.MaxBondedValidators));
        // if the number of validators has not reached the max_validator_num,
        // add validator directly
        if (bondedValAddrs.length < maxBondedValidators) {
            return _bondValidator(msgSender);
        }
        // if the number of validators has alrady reached the max_validator_num,
        // add validator only if its tokens is more than the current least bonded validator tokens
        uint256 minTokens = MAX_INT;
        uint256 minTokensIndex;
        for (uint256 i = 0; i < maxBondedValidators; i++) {
            if (validators[bondedValAddrs[i]].tokens < minTokens) {
                minTokensIndex = i;
                minTokens = validators[bondedValAddrs[i]].tokens;
                if (minTokens == 0) {
                    break;
                }
            }
        }
        require(validator.tokens > minTokens, "Insufficient tokens");
        _replaceBondedValidator(msgSender, minTokensIndex);
    }

    /**
     * @notice Confirm validator status from Unbonding to Unbonded
     * @param _valAddr the address of the validator
     */
    function confirmUnbondedValidator(address _valAddr) external {
        Validator storage validator = validators[_valAddr];
        require(validator.status == ValidatorStatus.Unbonding, "Validator not unbonding");
        require(block.number >= validator.unbondTime, "Unbond time not reached");

        validator.status = ValidatorStatus.Unbonded;
        delete validator.unbondTime;
        emit ValidatorStatusUpdate(_valAddr, ValidatorStatus.Unbonded);
    }

    /**
     * @notice Delegate CELR tokens to a validator
     * @dev Minimal amount per delegate operation is 1 CELR
     * @param _valAddr validator to delegate
     * @param _amount the amount of delegated CELR tokens
     */
    function delegate(address _valAddr, uint256 _amount) public whenNotPaused {
        require(_amount >= CELR_DECIMAL, "Minimal amount is 1 CELR");
        Validator storage validator = validators[_valAddr];
        require(validator.status != ValidatorStatus.Null, "Validator is not initialized");
        address msgSender = msg.sender;
        _addDelegation(validator, _valAddr, msgSender, _amount);
        celerToken.safeTransferFrom(msgSender, address(this), _amount);
    }

    /**
     * @notice Undelegated tokens from a validator
     * @dev Tokens are delegated by the msgSender to the validator
     * @param _valAddr the address of the validator
     * @param _amount undelegate amount
     */
    function undelegate(address _valAddr, uint256 _amount) external {
        address msgSender = msg.sender;
        require(_amount >= CELR_DECIMAL, "Minimal amount is 1 CELR");
        Validator storage validator = validators[_valAddr];
        require(validator.status != ValidatorStatus.Null, "Validator is not initialized");
        _removeDelegation(validator, _valAddr, msgSender, _amount);
        if (validator.status == ValidatorStatus.Unbonded) {
            celerToken.safeTransfer(msgSender, _amount);
            emit UndelegateCompleted(msgSender, _valAddr, _amount);
            return;
        }

        Delegator storage delegator = validator.delegators[msgSender];
        delegator.undelegations.sum += _amount;
        _validateValidator(_valAddr);

        Undelegation storage undelegation = delegator.undelegations.queue[delegator.undelegations.tail];
        undelegation.amount = _amount;
        undelegation.creationBlock = block.number;
        delegator.undelegations.tail++;

        emit Undelegate(msgSender, _valAddr, _amount, undelegation.creationBlock);
    }

    /**
     * @notice Complete pending undelegations from a validator
     * @param _valAddr the address of the validator
     */
    function completeUndelegate(address _valAddr) external {
        address msgSender = msg.sender;
        Validator storage validator = validators[_valAddr];
        require(validator.status != ValidatorStatus.Null, "Validator is not initialized");
        Delegator storage delegator = validator.delegators[msgSender];

        uint256 slashTimeout = getUIntValue(uint256(ParamNames.SlashTimeout));
        bool isUnbonded = validator.status == ValidatorStatus.Unbonded;
        // for all pending undelegations
        uint32 i;
        for (i = delegator.undelegations.head; i < delegator.undelegations.tail; i++) {
            if (isUnbonded || delegator.undelegations.queue[i].creationBlock + slashTimeout <= block.number) {
                // complete undelegation when the validator becomes unbonded or
                // the slashTimeout for the pending undelegation is up.
                delete delegator.undelegations.queue[i];
                continue;
            }
            break;
        }
        delegator.undelegations.head = i;
        // for all pending undelegations
        uint256 undelegatingTokensWithoutSlash;
        for (; i < delegator.undelegations.tail; i++) {
            undelegatingTokensWithoutSlash += delegator.undelegations.queue[i].amount;
        }

        uint256 undelegateAmt;
        if (delegator.undelegations.sum > undelegatingTokensWithoutSlash) {
            undelegateAmt = delegator.undelegations.sum - undelegatingTokensWithoutSlash;
            delegator.undelegations.sum = undelegatingTokensWithoutSlash;

            celerToken.safeTransfer(msgSender, undelegateAmt);
        }

        emit UndelegateCompleted(msgSender, _valAddr, undelegateAmt);
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
     * @notice Update commission rate
     * @param _newRate new commission rate
     */
    function updateCommissionRate(uint256 _newRate) external {
        Validator storage validator = validators[msg.sender];
        require(validator.status != ValidatorStatus.Null, "Validator is not initialized");
        require(_newRate <= COMMISSION_RATE_BASE, "Invalid new rate");
        validator.commissionRate = _newRate;
        emit CommissionRateUpdate(msg.sender, _newRate);
    }

    /**
     * @notice update minimal self delegation value
     * @param _minSelfDelegation minimal amount of tokens staked by the validator itself
     */
    function updateMinSelfDelegation(uint256 _minSelfDelegation) external {
        Validator storage validator = validators[msg.sender];
        require(validator.status != ValidatorStatus.Null, "Validator is not initialized");
        require(_minSelfDelegation >= CELR_DECIMAL, "Invalid min self delegation");
        if (_minSelfDelegation < validator.minSelfDelegation) {
            require(validator.status != ValidatorStatus.Bonded, "Validator is bonded");
            validator.earliestBondTime = block.number + getUIntValue(uint256(ParamNames.AdvanceNoticePeriod));
        }
        validator.minSelfDelegation = _minSelfDelegation;
        emit MinSelfDelegationUpdate(msg.sender, _minSelfDelegation);
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

        Validator storage validator = validators[penalty.validatorAddress];
        require(validator.status != ValidatorStatus.Unbonded, "Validator unbounded");

        uint256 totalSubAmt;
        for (uint256 i = 0; i < penalty.penalizedDelegators.length; i++) {
            PbSgn.AccountAmtPair memory penalizedDelegator = penalty.penalizedDelegators[i];
            totalSubAmt += penalizedDelegator.amt;
            emit Slash(penalty.validatorAddress, penalizedDelegator.account, penalizedDelegator.amt);

            Delegator storage delegator = validator.delegators[penalizedDelegator.account];
            uint256 _amt;
            if (delegator.shares >= penalizedDelegator.amt) {
                _amt = penalizedDelegator.amt;
            } else {
                uint256 remainingAmt = penalizedDelegator.amt - delegator.shares;
                delegator.undelegations.sum -= remainingAmt;
                _amt = delegator.shares;
            }
            _removeDelegation(validator, penalty.validatorAddress, penalizedDelegator.account, _amt);
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
     * @notice Vote for a parameter proposal with a specific type of vote
     * @param _proposalId the id of the parameter proposal
     * @param _vote the type of vote
     */
    function voteParam(uint256 _proposalId, VoteType _vote) external {
        require(validators[msg.sender].status == ValidatorStatus.Bonded, "Caller is not a bonded validator");
        internalVoteParam(_proposalId, msg.sender, _vote);
    }

    /**
     * @notice Confirm a parameter proposal
     * @param _proposalId the id of the parameter proposal
     */
    function confirmParamProposal(uint256 _proposalId) external {
        // check Yes votes only for now
        uint256 yesVotes;
        for (uint32 i = 0; i < bondedValAddrs.length; i++) {
            if (getParamProposalVote(_proposalId, bondedValAddrs[i]) == VoteType.Yes) {
                yesVotes += validators[bondedValAddrs[i]].tokens;
            }
        }

        bool passed = yesVotes >= getQuorumTokens();
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

    /**************************
     *  Public View Functions *
     **************************/

    /**
     * @notice Validate multi-signed message
     * @param _msg signed message
     * @param _sigs list of validator signatures
     * @return passed the validation or not
     */
    function verifySignatures(bytes memory _msg, bytes[] memory _sigs) public view returns (bool) {
        bytes32 hash = keccak256(_msg).toEthSignedMessageHash();
        address[] memory signers = new address[](_sigs.length);
        uint256 signedTokens;
        address prev = address(0);
        for (uint256 i = 0; i < _sigs.length; i++) {
            signers[i] = hash.recover(_sigs[i]);
            require(signers[i] > prev, "Signers not in ascending order");
            prev = signers[i];
            if (validators[signers[i]].status != ValidatorStatus.Bonded) {
                continue;
            }
            signedTokens += validators[signers[i]].tokens;
        }

        require(signedTokens >= getQuorumTokens(), "Not enough signatures");
        return true;
    }

    /**
     * @notice Get quorum amount of tokens
     * @return the quorum amount
     */
    function getQuorumTokens() public view returns (uint256) {
        return (totalBondedTokens * 2) / 3 + 1;
    }

    /**
     * @notice Get validator info
     * @param _valAddr the address of the validator
     * @return Validator token amount
     */
    function getValidatorTokens(address _valAddr) public view returns (uint256) {
        return validators[_valAddr].tokens;
    }

    /**
     * @notice Get validator info
     * @param _valAddr the address of the validator
     * @return Validator status
     */
    function getValidatorStatus(address _valAddr) public view returns (ValidatorStatus) {
        return validators[_valAddr].status;
    }

    /**
     * @notice Get the minimum staking pool of all bonded validators
     * @return the minimum staking pool of all bonded validators
     */
    function getMinValidatorTokens() public view returns (uint256) {
        uint256 minTokens = validators[bondedValAddrs[0]].tokens;
        for (uint256 i = 1; i < bondedValAddrs.length; i++) {
            if (validators[bondedValAddrs[i]].tokens < minTokens) {
                minTokens = validators[bondedValAddrs[i]].tokens;
                if (minTokens == 0) {
                    return 0;
                }
            }
        }
        return minTokens;
    }

    // used for delegator external view output
    struct DelegatorInfo {
        address valAddr;
        uint256 shares;
        Undelegation[] undelegations;
    }

    /**
     * @notice Get the delegator info of a specific validator
     * @param _valAddr the address of the validator
     * @param _delAddr the address of the delegator
     * @return DelegatorInfo from the given validator
     */
    function getDelegatorInfo(address _valAddr, address _delAddr) public view returns (DelegatorInfo memory) {
        Delegator storage d = validators[_valAddr].delegators[_delAddr];

        uint256 len = d.undelegations.tail - d.undelegations.head;
        Undelegation[] memory undelegations = new Undelegation[](len);
        for (uint256 i = 0; i < len; i++) {
            undelegations[i] = d.undelegations.queue[i + d.undelegations.head];
        }

        return
            DelegatorInfo({
                valAddr: _valAddr,
                shares: d.shares,
                undelegations: undelegations
            });
    }

    /**
     * @notice Get the delegator info of a specific validator
     * @param _delAddr the address of the delegator
     * @return DelegatorInfo from all related validators
     */
    function getDelegatorInfos(address _delAddr) public view returns (DelegatorInfo[] memory) {
        DelegatorInfo[] memory infos = new DelegatorInfo[](valAddrs.length);
        uint32 num = 0;
        for (uint32 i = 0; i < valAddrs.length; i++) {
            Delegator storage d = validators[valAddrs[i]].delegators[_delAddr];
            if (d.shares == 0 && d.undelegations.sum == 0) {
                infos[i] = getDelegatorInfo(valAddrs[i], _delAddr);
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
    function isBondedValidator(address _addr) public view returns (bool) {
        return validators[_addr].status == ValidatorStatus.Bonded;
    }

    /**
     * @notice Get the number of validators
     * @return the number of validators
     */
    function getValidatorNum() public view returns (uint256) {
        return valAddrs.length;
    }

    /**
     * @notice Get the number of bonded validators
     * @return the number of bonded validators
     */
    function getBondedValidatorNum() public view returns (uint256) {
        return bondedValAddrs.length;
    }

    /*********************
     * Private Functions *
     *********************/

    /**
     * @notice Add the delegated tokens of a delegator to an validator
     * @param _validator the validator
     * @param _delAddr the delegator address
     * @param _amount update amount
     */
    function _addDelegation(
        Validator storage _validator,
        address _valAddr,
        address _delAddr,
        uint256 _amount
    ) private {
        Delegator storage delegator = _validator.delegators[_delAddr];
        _validator.tokens += _amount;
        delegator.shares += _amount;
        if (_validator.status == ValidatorStatus.Bonded) {
            totalBondedTokens += _amount;
        }
        emit DelegationUpdate(_delAddr, _valAddr, delegator.shares, _validator.tokens);
    }

    /**
     * @notice Add the delegated tokens of a delegator to an validator
     * @param _validator the validator
     * @param _delAddr the delegator address
     * @param _amount update amount
     */
    function _removeDelegation(
        Validator storage _validator,
        address _valAddr,
        address _delAddr,
        uint256 _amount
    ) private {
        Delegator storage delegator = _validator.delegators[_delAddr];
        delegator.shares -= _amount;
        _validator.tokens -= _amount;
        if (_validator.status == ValidatorStatus.Bonded) {
            totalBondedTokens -= _amount;
        }
        emit DelegationUpdate(_delAddr, _valAddr, delegator.shares, _validator.tokens);
    }

    function _setBondedValidator(address _valAddr) private {
        Validator storage validator = validators[_valAddr];
        validator.status = ValidatorStatus.Bonded;
        delete validator.unbondTime;
        totalBondedTokens += validator.tokens;
        emit ValidatorStatusUpdate(_valAddr, ValidatorStatus.Bonded);
    }

    function _setUnbondingValidator(address _valAddr) private {
        Validator storage validator = validators[_valAddr];
        validator.status = ValidatorStatus.Unbonding;
        validator.unbondTime = block.number + getUIntValue(uint256(ParamNames.SlashTimeout));
        totalBondedTokens -= validator.tokens;
        emit ValidatorStatusUpdate(_valAddr, ValidatorStatus.Unbonding);
    }

    /**
     * @notice Add a validator
     * @param _valAddr the address of the validator
     */
    function _bondValidator(address _valAddr) private {
        bondedValAddrs.push(_valAddr);
        _setBondedValidator(_valAddr);
    }

    /**
     * @notice Add a validator
     * @param _valAddr the address of the new validator
     * @param _index the index of the validator to be replaced
     */
    function _replaceBondedValidator(address _valAddr, uint256 _index) private {
        _setUnbondingValidator(bondedValAddrs[_index]);
        bondedValAddrs[_index] = _valAddr;
        _setBondedValidator(_valAddr);
    }

    /**
     * @notice Remove a validator
     * @param _valAddr validator to be removed
     */
    function _unbondValidator(address _valAddr) private {
        uint256 lastIndex = bondedValAddrs.length - 1;
        for (uint256 i = 0; i < bondedValAddrs.length; i++) {
            if (bondedValAddrs[i] == _valAddr) {
                if (i < lastIndex) {
                    bondedValAddrs[i] = bondedValAddrs[lastIndex];
                }
                bondedValAddrs.pop();
                _setUnbondingValidator(_valAddr);
                return;
            }
        }
        revert("Not bonded validator");
    }

    /**
     * @notice Validate a validator status after delegation change
     * @dev remove this validator if it doesn't meet the requirement of being a validator
     * @param _valAddr the validator address
     */
    function _validateValidator(address _valAddr) private {
        Validator storage v = validators[_valAddr];
        if (v.status != ValidatorStatus.Bonded) {
            // no need to validate the tokens of a non-validator
            return;
        }
        if (
            v.delegators[_valAddr].shares < v.minSelfDelegation ||
            v.tokens < getUIntValue(uint256(ParamNames.MinValidatorTokens))
        ) {
            _unbondValidator(_valAddr);
        }
    }
}
