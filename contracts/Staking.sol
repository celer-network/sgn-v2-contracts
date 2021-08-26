// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./libraries/PbStaking.sol";
import "./Whitelist.sol";

/**
 * @title A Staking contract shared by all external sidechains and apps
 */
contract Staking is Ownable, Pausable, Whitelist {
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;

    uint256 constant CELR_DECIMAL = 1e18;
    uint256 constant MAX_INT = 2**256 - 1;
    uint256 constant COMMISSION_RATE_BASE = 10000; // 1 commissionRate means 0.01%
    uint256 constant MAX_UNDELEGATION_ENTRIES = 10;
    uint256 constant SLASH_FACTOR_DECIMAL = 1e6;

    enum ValidatorStatus {
        Null,
        Unbonded,
        Unbonding,
        Bonded
    }

    enum ParamName {
        ProposalDeposit,
        GovernVoteTimeout,
        SlashTimeout,
        MaxBondedValidators,
        MinValidatorTokens,
        MinSelfDelegation,
        AdvanceNoticePeriod,
        ValidatorBondInterval,
        MaxSlashFactor
    }

    struct Undelegation {
        uint256 shares;
        uint256 creationBlock;
    }

    struct Undelegations {
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
        address signer;
        uint256 tokens; // sum of all tokens delegated to this validator
        uint256 shares; // sum of all delegation shares
        uint256 undelegationTokens; // tokens being undelegated
        uint256 undelegationShares; // shares of tokens being undelegated
        mapping(address => Delegator) delegators;
        uint256 minSelfDelegation;
        uint64 bondBlock; // cannot become bonded before this block
        uint64 unbondBlock; // cannot become unbonded before this block
        uint64 commissionRate; // equal to real commission rate * COMMISSION_RATE_BASE
    }

    IERC20 public immutable celerToken;
    uint256 public bondedTokens;
    uint256 public nextBondBlock;
    address[] public valAddrs;
    address[] public bondedValAddrs; // TODO: deal with set size reduction
    mapping(address => Validator) public validators; // key is valAddr
    mapping(address => address) public signerVals; // signerAddr -> valAddr
    mapping(uint256 => bool) public slashNonces;

    mapping(ParamName => uint256) public params;
    address public govContract;

    /* Events */
    event ValidatorNotice(address indexed valAddr, string key, bytes data, address from);
    event ValidatorStatusUpdate(address indexed valAddr, ValidatorStatus indexed status);
    event DelegationUpdate(
        address indexed valAddr,
        address indexed delAddr,
        uint256 valTokens,
        uint256 delShares,
        int256 tokenDiff
    );
    event Undelegated(address indexed valAddr, address indexed delAddr, uint256 amount);
    event Slash(address indexed valAddr, uint64 nonce, uint256 slashAmt);
    event SlashAmtCollected(address indexed recipient, uint256 amount);

    /**
     * @notice Staking constructor
     * @param _celerTokenAddress address of Celer Token Contract
     * @param _governProposalDeposit required deposit amount for a governance proposal
     * @param _governVoteTimeout voting timeout for a governance proposal
     * @param _slashTimeout the locking time for funds to be potentially slashed
     * @param _maxBondedValidators the maximum number of bonded validators
     * @param _minValidatorTokens the global minimum token amount requirement for bonded validator
     * @param _minSelfDelegation minimal amount of self-delegated tokens
     * @param _advanceNoticePeriod the wait time after the announcement and prior to the effective date of an update
     * @param _validatorBondInterval min interval between bondValidator
     * @param _maxSlashFactor maximal slashing factor (1e6 = 100%)
     */
    constructor(
        address _celerTokenAddress,
        uint256 _governProposalDeposit,
        uint256 _governVoteTimeout,
        uint256 _slashTimeout,
        uint256 _maxBondedValidators,
        uint256 _minValidatorTokens,
        uint256 _minSelfDelegation,
        uint256 _advanceNoticePeriod,
        uint256 _validatorBondInterval,
        uint256 _maxSlashFactor
    ) {
        celerToken = IERC20(_celerTokenAddress);

        params[ParamName.ProposalDeposit] = _governProposalDeposit;
        params[ParamName.GovernVoteTimeout] = _governVoteTimeout;
        params[ParamName.SlashTimeout] = _slashTimeout;
        params[ParamName.MaxBondedValidators] = _maxBondedValidators;
        params[ParamName.MinValidatorTokens] = _minValidatorTokens;
        params[ParamName.MinSelfDelegation] = _minSelfDelegation;
        params[ParamName.AdvanceNoticePeriod] = _advanceNoticePeriod;
        params[ParamName.ValidatorBondInterval] = _validatorBondInterval;
        params[ParamName.MaxSlashFactor] = _maxSlashFactor;
    }

    receive() external payable {}

    /*********************************
     * External and Public Functions *
     *********************************/

    /**
     * @notice Initialize a validator candidate
     * @param _signer signer address
     * @param _minSelfDelegation minimal amount of tokens staked by the validator itself
     * @param _commissionRate the self-declaimed commission rate
     */
    function initializeValidator(
        address _signer,
        uint256 _minSelfDelegation,
        uint64 _commissionRate
    ) external whenNotPaused onlyWhitelisted {
        address valAddr = msg.sender;
        Validator storage validator = validators[valAddr];
        require(validator.status == ValidatorStatus.Null, "Validator is initialized");
        require(validators[_signer].status == ValidatorStatus.Null, "Signer is other validator");
        require(signerVals[valAddr] == address(0), "Validator is other signer");
        require(signerVals[_signer] == address(0), "Signer already used");
        require(_commissionRate <= COMMISSION_RATE_BASE, "Invalid commission rate");
        require(_minSelfDelegation >= params[ParamName.MinSelfDelegation], "Insufficient min self delegation");
        validator.signer = _signer;
        validator.status = ValidatorStatus.Unbonded;
        validator.minSelfDelegation = _minSelfDelegation;
        validator.commissionRate = _commissionRate;
        valAddrs.push(valAddr);
        signerVals[_signer] = valAddr;

        delegate(valAddr, _minSelfDelegation);
        emit ValidatorNotice(valAddr, "init", abi.encode(_signer, _minSelfDelegation, _commissionRate), address(0));
    }

    /**
     * @notice Update validator signer address
     * @param _signer signer address
     */
    function updateValidatorSigner(address _signer) external {
        address valAddr = msg.sender;
        Validator storage validator = validators[valAddr];
        require(validator.status != ValidatorStatus.Null, "Validator not initialized");
        require(signerVals[_signer] == address(0), "Signer already used");
        if (_signer != valAddr) {
            require(validators[_signer].status == ValidatorStatus.Null, "Signer is other validator");
        }

        delete signerVals[validator.signer];
        validator.signer = _signer;
        signerVals[_signer] = valAddr;

        emit ValidatorNotice(valAddr, "signer", abi.encode(_signer), address(0));
    }

    /**
     * @notice Candidate claims to become a bonded validator
     * @dev caller can be either validator owner or signer
     */
    function bondValidator() external {
        address valAddr = msg.sender;
        if (signerVals[msg.sender] != address(0)) {
            valAddr = signerVals[msg.sender];
        }
        Validator storage validator = validators[valAddr];
        require(
            validator.status == ValidatorStatus.Unbonded || validator.status == ValidatorStatus.Unbonding,
            "Invalid validator status"
        );
        require(block.number >= validator.bondBlock, "Bond block not reached");
        require(block.number >= nextBondBlock, "Too frequent validator bond");
        nextBondBlock = block.number + params[ParamName.ValidatorBondInterval];
        require(hasMinRequiredTokens(valAddr, true), "Not have min tokens");

        uint256 maxBondedValidators = params[ParamName.MaxBondedValidators];
        // if the number of validators has not reached the max_validator_num,
        // add validator directly
        if (bondedValAddrs.length < maxBondedValidators) {
            return _bondValidator(valAddr);
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
        _replaceBondedValidator(valAddr, minTokensIndex);
        _decentralizationCheck(validator.tokens);
    }

    /**
     * @notice Confirm validator status from Unbonding to Unbonded
     * @param _valAddr the address of the validator
     */
    function confirmUnbondedValidator(address _valAddr) external {
        Validator storage validator = validators[_valAddr];
        require(validator.status == ValidatorStatus.Unbonding, "Validator not unbonding");
        require(block.number >= validator.unbondBlock, "Unbond block not reached");

        validator.status = ValidatorStatus.Unbonded;
        delete validator.unbondBlock;
        emit ValidatorStatusUpdate(_valAddr, ValidatorStatus.Unbonded);
    }

    /**
     * @notice Delegate CELR tokens to a validator
     * @dev Minimal amount per delegate operation is 1 CELR
     * @param _valAddr validator to delegate
     * @param _tokens the amount of delegated CELR tokens
     */
    function delegate(address _valAddr, uint256 _tokens) public whenNotPaused {
        address delAddr = msg.sender;
        require(_tokens >= CELR_DECIMAL, "Minimal amount is 1 CELR");

        Validator storage validator = validators[_valAddr];
        require(validator.status != ValidatorStatus.Null, "Validator is not initialized");
        uint256 shares = _tokenToShare(_tokens, validator.tokens, validator.shares);

        Delegator storage delegator = validator.delegators[delAddr];
        delegator.shares += shares;
        validator.shares += shares;
        validator.tokens += _tokens;
        if (validator.status == ValidatorStatus.Bonded) {
            bondedTokens += _tokens;
            _decentralizationCheck(validator.tokens);
        }
        celerToken.safeTransferFrom(delAddr, address(this), _tokens);
        emit DelegationUpdate(_valAddr, delAddr, validator.tokens, delegator.shares, int256(_tokens));
    }

    /**
     * @notice Undelegate tokens from a validator
     * @dev Tokens are delegated by the msgSender to the validator
     * @param _valAddr the address of the validator
     * @param _shares undelegate shares
     */
    function undelegate(address _valAddr, uint256 _shares) external {
        address delAddr = msg.sender;
        require(_shares >= CELR_DECIMAL, "Minimal amount is 1 share");

        Validator storage validator = validators[_valAddr];
        require(validator.status != ValidatorStatus.Null, "Validator is not initialized");
        uint256 tokens = _shareToTokens(_shares, validator.tokens, validator.shares);

        Delegator storage delegator = validator.delegators[delAddr];
        delegator.shares -= _shares;
        validator.shares -= _shares;
        validator.tokens -= tokens;
        if (validator.status == ValidatorStatus.Unbonded) {
            celerToken.safeTransfer(delAddr, tokens);
            emit Undelegated(_valAddr, delAddr, tokens);
            return;
        } else if (validator.status == ValidatorStatus.Bonded) {
            bondedTokens -= tokens;
            if (!hasMinRequiredTokens(_valAddr, delAddr == _valAddr)) {
                _unbondValidator(_valAddr);
            }
        }
        require(
            delegator.undelegations.tail - delegator.undelegations.head < MAX_UNDELEGATION_ENTRIES,
            "Exceed max undelegation entries"
        );

        uint256 undelegationShares = _tokenToShare(tokens, validator.undelegationTokens, validator.undelegationShares);
        validator.undelegationShares += undelegationShares;
        validator.undelegationTokens += tokens;
        Undelegation storage undelegation = delegator.undelegations.queue[delegator.undelegations.tail];
        undelegation.shares = undelegationShares;
        undelegation.creationBlock = block.number;
        delegator.undelegations.tail++;

        emit DelegationUpdate(_valAddr, delAddr, validator.tokens, delegator.shares, -int256(tokens));
    }

    /**
     * @notice Complete pending undelegations from a validator
     * @param _valAddr the address of the validator
     */
    function completeUndelegate(address _valAddr) external {
        address delAddr = msg.sender;
        Validator storage validator = validators[_valAddr];
        require(validator.status != ValidatorStatus.Null, "Validator is not initialized");
        Delegator storage delegator = validator.delegators[delAddr];

        uint256 slashTimeout = params[ParamName.SlashTimeout];
        bool isUnbonded = validator.status == ValidatorStatus.Unbonded;
        // for all pending undelegations
        uint32 i;
        uint256 undelegationShares;
        for (i = delegator.undelegations.head; i < delegator.undelegations.tail; i++) {
            if (isUnbonded || delegator.undelegations.queue[i].creationBlock + slashTimeout <= block.number) {
                // complete undelegation when the validator becomes unbonded or
                // the slashTimeout for the pending undelegation is up.
                undelegationShares += delegator.undelegations.queue[i].shares;
                delete delegator.undelegations.queue[i];
                continue;
            }
            break;
        }
        delegator.undelegations.head = i;

        require(undelegationShares > 0, "No undelegation ready to be completed");
        uint256 tokens = _shareToTokens(undelegationShares, validator.undelegationTokens, validator.undelegationShares);
        validator.undelegationShares -= undelegationShares;
        validator.undelegationTokens -= tokens;
        celerToken.safeTransfer(delAddr, tokens);
        emit Undelegated(_valAddr, delAddr, tokens);
    }

    /**
     * @notice Update commission rate
     * @param _newRate new commission rate
     */
    function updateCommissionRate(uint64 _newRate) external {
        address valAddr = msg.sender;
        Validator storage validator = validators[valAddr];
        require(validator.status != ValidatorStatus.Null, "Validator is not initialized");
        require(_newRate <= COMMISSION_RATE_BASE, "Invalid new rate");
        validator.commissionRate = _newRate;
        emit ValidatorNotice(valAddr, "commission", abi.encode(_newRate), address(0));
    }

    /**
     * @notice Update minimal self delegation value
     * @param _minSelfDelegation minimal amount of tokens staked by the validator itself
     */
    function updateMinSelfDelegation(uint256 _minSelfDelegation) external {
        address valAddr = msg.sender;
        Validator storage validator = validators[valAddr];
        require(validator.status != ValidatorStatus.Null, "Validator is not initialized");
        require(_minSelfDelegation >= params[ParamName.MinSelfDelegation], "Insufficient min self delegation");
        if (_minSelfDelegation < validator.minSelfDelegation) {
            require(validator.status != ValidatorStatus.Bonded, "Validator is bonded");
            validator.bondBlock = uint64(block.number + params[ParamName.AdvanceNoticePeriod]);
        }
        validator.minSelfDelegation = _minSelfDelegation;
        emit ValidatorNotice(valAddr, "min-self-delegation", abi.encode(_minSelfDelegation), address(0));
    }

    /**
     * @notice Slash a validator and its delegators
     * @param _slashRequest slash request bytes coded in protobuf
     * @param _sigs list of validator signatures
     */
    function slash(bytes calldata _slashRequest, bytes[] calldata _sigs) external whenNotPaused {
        PbStaking.Slash memory request = PbStaking.decSlash(_slashRequest);
        verifySignatures(_slashRequest, _sigs);

        require(block.number < request.expireBlock, "Slash expired");
        require(request.slashFactor <= SLASH_FACTOR_DECIMAL, "Invalid slash factor");
        require(request.slashFactor <= params[ParamName.MaxSlashFactor], "Exceed max slash factor");
        require(!slashNonces[request.nonce], "Used slash nonce");
        slashNonces[request.nonce] = true;

        address valAddr = request.validator;
        Validator storage validator = validators[valAddr];
        require(validator.status != ValidatorStatus.Unbonded, "Validator unbounded");

        // slash delegated tokens
        uint256 slashAmt = (validator.tokens * request.slashFactor) / SLASH_FACTOR_DECIMAL;
        validator.tokens -= slashAmt;
        if (validator.status == ValidatorStatus.Bonded) {
            bondedTokens -= slashAmt;
            if (request.jailPeriod > 0 || !hasMinRequiredTokens(valAddr, true)) {
                _unbondValidator(valAddr);
                if (request.jailPeriod > 0) {
                    validator.bondBlock = uint64(block.number + request.jailPeriod);
                }
            }
        }
        emit DelegationUpdate(valAddr, address(0), validator.tokens, 0, -int256(slashAmt));

        // slash pending undelegations
        uint256 slashUndelegation = (validator.undelegationTokens * request.slashFactor) / SLASH_FACTOR_DECIMAL;
        validator.undelegationTokens -= slashUndelegation;
        slashAmt += slashUndelegation;

        uint256 collectAmt;
        for (uint256 i = 0; i < request.collectors.length; i++) {
            PbStaking.AcctAmtPair memory collector = request.collectors[i];
            collectAmt += collector.amount;
            if (collector.account == address(0)) {
                celerToken.safeTransfer(msg.sender, collector.amount);
                emit SlashAmtCollected(msg.sender, collector.amount);
            } else {
                celerToken.safeTransfer(collector.account, collector.amount);
                emit SlashAmtCollected(collector.account, collector.amount);
            }
        }
        require(slashAmt >= collectAmt, "Invalid collectors");
        emit Slash(valAddr, request.nonce, slashAmt);
    }

    /**
     * @notice Validator send notice event
     */
    function validatorNotice(
        address _valAddr,
        string calldata _key,
        bytes calldata _data
    ) external {
        Validator storage validator = validators[_valAddr];
        require(validator.status != ValidatorStatus.Null, "Validator is not initialized");
        emit ValidatorNotice(_valAddr, _key, _data, msg.sender);
    }

    function setParamValue(ParamName _name, uint256 _value) external {
        require(msg.sender == govContract, "Caller is not gov contract");
        params[_name] = _value;
    }

    function setGovContract(address _addr) external onlyOwner {
        require(govContract == address(0), "gov contract already set");
        govContract = _addr;
    }

    /**
     * @notice Set whitelistEnabled
     */
    function setWhitelistEnabled(bool _whitelistEnabled) external onlyOwner {
        _setWhitelistEnabled(_whitelistEnabled);
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
     * @notice Set max slash factor
     */
    function setMaxSlashFactor(uint256 _maxSlashFactor) external onlyOwner {
        params[ParamName.MaxSlashFactor] = _maxSlashFactor;
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

    /**************************
     *  Public View Functions *
     **************************/

    /**
     * @notice Validate if a message is signed by quorum tokens
     * @param _msg signed message
     * @param _sigs list of validator signatures
     */
    function verifySignatures(bytes memory _msg, bytes[] memory _sigs) public view returns (bool) {
        bytes32 hash = keccak256(_msg).toEthSignedMessageHash();
        uint256 signedTokens;
        address prev = address(0);
        for (uint256 i = 0; i < _sigs.length; i++) {
            address signer = hash.recover(_sigs[i]);
            require(signer > prev, "Signers not in ascending order");
            prev = signer;
            Validator storage validator = validators[signerVals[signer]];
            if (validator.status != ValidatorStatus.Bonded) {
                continue;
            }
            signedTokens += validator.tokens;
        }

        require(signedTokens >= getQuorumTokens(), "Quorum not reached");
        return true;
    }

    /**
     * @notice Get quorum amount of tokens
     * @return the quorum amount
     */
    function getQuorumTokens() public view returns (uint256) {
        return (bondedTokens * 2) / 3 + 1;
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

    struct ValidatorTokens {
        address valAddr;
        uint256 tokens;
    }

    function getBondedValidatorsTokens() public view returns (ValidatorTokens[] memory) {
        ValidatorTokens[] memory infos = new ValidatorTokens[](valAddrs.length);
        for (uint256 i = 1; i < bondedValAddrs.length; i++) {
            address valAddr = bondedValAddrs[i];
            infos[i] = ValidatorTokens(valAddr, validators[valAddr].tokens);
        }
        return infos;
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

    /**
     * @notice Check if min token requirements are met
     * @param _valAddr the address of the validator
     * @param _checkSelfDelegation check self delegation
     */
    function hasMinRequiredTokens(address _valAddr, bool _checkSelfDelegation) public view returns (bool) {
        Validator storage v = validators[_valAddr];
        uint256 valTokens = v.tokens;
        if (valTokens < params[ParamName.MinValidatorTokens]) {
            return false;
        }
        if (_checkSelfDelegation) {
            uint256 selfDelegation = _shareToTokens(v.delegators[_valAddr].shares, valTokens, v.shares);
            if (selfDelegation < v.minSelfDelegation) {
                return false;
            }
        }
        return true;
    }

    // used for delegator external view output
    struct DelegatorInfo {
        address valAddr;
        uint256 tokens;
        uint256 shares;
        uint256 undelegationTokens;
        Undelegation[] undelegations;
    }

    /**
     * @notice Get the delegator info of a specific validator
     * @param _valAddr the address of the validator
     * @param _delAddr the address of the delegator
     * @return DelegatorInfo from the given validator
     */
    function getDelegatorInfo(address _valAddr, address _delAddr) public view returns (DelegatorInfo memory) {
        Validator storage validator = validators[_valAddr];
        Delegator storage d = validator.delegators[_delAddr];
        uint256 tokens = _shareToTokens(d.shares, validator.tokens, validator.shares);

        uint256 undelegationShares;
        uint256 len = d.undelegations.tail - d.undelegations.head;
        Undelegation[] memory undelegations = new Undelegation[](len);
        for (uint256 i = 0; i < len; i++) {
            undelegations[i] = d.undelegations.queue[i + d.undelegations.head];
            undelegationShares += d.undelegations.queue[i].shares;
        }
        uint256 undelegationTokens = _shareToTokens(
            undelegationShares,
            validator.undelegationTokens,
            validator.undelegationShares
        );

        return DelegatorInfo(_valAddr, tokens, d.shares, undelegationTokens, undelegations);
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
            if (d.shares == 0 && d.undelegations.head == d.undelegations.tail) {
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
     * @notice Get the value of a specific uint parameter
     * @param _name the key of this parameter
     * @return the value of this parameter
     */
    function getParamValue(ParamName _name) public view returns (uint256) {
        return params[_name];
    }

    /*********************
     * Private Functions *
     *********************/

    /**
     * @notice Set validator to bonded
     * @param _valAddr the address of the validator
     */
    function _setBondedValidator(address _valAddr) private {
        Validator storage validator = validators[_valAddr];
        validator.status = ValidatorStatus.Bonded;
        delete validator.unbondBlock;
        bondedTokens += validator.tokens;
        emit ValidatorStatusUpdate(_valAddr, ValidatorStatus.Bonded);
    }

    /**
     * @notice Set validator to unbonding
     * @param _valAddr the address of the validator
     */
    function _setUnbondingValidator(address _valAddr) private {
        Validator storage validator = validators[_valAddr];
        validator.status = ValidatorStatus.Unbonding;
        validator.unbondBlock = uint64(block.number + params[ParamName.SlashTimeout]);
        bondedTokens -= validator.tokens;
        emit ValidatorStatusUpdate(_valAddr, ValidatorStatus.Unbonding);
    }

    /**
     * @notice Bond a validator
     * @param _valAddr the address of the validator
     */
    function _bondValidator(address _valAddr) private {
        bondedValAddrs.push(_valAddr);
        _setBondedValidator(_valAddr);
    }

    /**
     * @notice Repace a bonded validator
     * @param _valAddr the address of the new validator
     * @param _index the index of the validator to be replaced
     */
    function _replaceBondedValidator(address _valAddr, uint256 _index) private {
        _setUnbondingValidator(bondedValAddrs[_index]);
        bondedValAddrs[_index] = _valAddr;
        _setBondedValidator(_valAddr);
    }

    /**
     * @notice Unbond a validator
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
     * @notice Check if one validator as too much power
     * @param _valTokens token amounts of the validator
     */
    function _decentralizationCheck(uint256 _valTokens) private view {
        uint256 bondedValNum = bondedValAddrs.length;
        if (bondedValNum == 2 || bondedValNum == 3) {
            require(_valTokens < getQuorumTokens(), "Single validator should not have quorum tokens");
        } else if (bondedValNum > 3) {
            require(_valTokens < bondedTokens / 3, "Single validator should not have 1/3 tokens");
        }
    }

    /**
     * @notice Convert token to share
     * TODO: check edge cases when balance is low
     */
    function _tokenToShare(
        uint256 tokens,
        uint256 totalTokens,
        uint256 totalShares
    ) private pure returns (uint256) {
        if (totalTokens == 0) {
            return tokens;
        }
        return (tokens * totalShares) / totalTokens;
    }

    /**
     * @notice Convert share to token
     */
    function _shareToTokens(
        uint256 shares,
        uint256 totalTokens,
        uint256 totalShares
    ) private pure returns (uint256) {
        if (totalShares == 0) {
            return shares;
        }
        return (shares * totalTokens) / totalShares;
    }
}
