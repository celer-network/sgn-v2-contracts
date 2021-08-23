// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title Governance module for Staking contract
 * @notice Govern contract implements the basic governance logic
 * @dev Staking contract should inherit this contract
 * @dev Some specific functions of governance are defined in Staking contract
 */
contract Govern {
    using SafeERC20 for IERC20;

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

    enum ProposalStatus {
        Uninitiated,
        Voting,
        Closed
    }

    enum VoteOption {
        Null,
        Yes,
        Abstain,
        No
    }

    struct ParamProposal {
        address proposer;
        uint256 deposit;
        uint256 voteDeadline;
        ParamName name;
        uint256 newValue;
        ProposalStatus status;
        mapping(address => VoteOption) votes;
    }

    IERC20 public celerToken;
    // parameters
    mapping(ParamName => uint256) public params;
    mapping(uint256 => ParamProposal) public paramProposals;
    uint256 public nextParamProposalId;

    event CreateParamProposal(
        uint256 proposalId,
        address proposer,
        uint256 deposit,
        uint256 voteDeadline,
        ParamName name,
        uint256 newValue
    );

    event VoteParam(uint256 proposalId, address voter, VoteOption vote);

    event ConfirmParamProposal(uint256 proposalId, bool passed, ParamName name, uint256 newValue);

    /**
     * @notice Govern constructor
     * @dev set celerToken and initialize all parameters
     * @param _celerTokenAddress address of the governance token
     * @param _governProposalDeposit required deposit amount for a governance proposal
     * @param _governVoteTimeout voting timeout for a governance proposal
     * @param _slashTimeout the locking time for funds to be potentially slashed
     * @param _maxBondedValidators the maximum number of bonded validators
     * @param _minValidatorTokens the global minimum token amout requirement for bonded validator
     * @param _minSelfDelegation minimal amount of self-delegated tokens
     * @param _advanceNoticePeriod the time after the announcement and prior to the effective time of an update
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

    /********** Get functions **********/
    /**
     * @notice Get the value of a specific uint parameter
     * @param _name the key of this parameter
     * @return the value of this parameter
     */
    function getParamValue(ParamName _name) public view returns (uint256) {
        return params[_name];
    }

    /**
     * @notice Get the vote type of a voter on a parameter proposal
     * @param _proposalId the proposal id
     * @param _voter the voter address
     * @return the vote type of the given voter on the given parameter proposal
     */
    function getParamProposalVote(uint256 _proposalId, address _voter) public view returns (VoteOption) {
        return paramProposals[_proposalId].votes[_voter];
    }

    /********** Governance functions **********/
    /**
     * @notice Create a parameter proposal
     * @param _name the key of this parameter
     * @param _value the new proposed value of this parameter
     */
    function createParamProposal(ParamName _name, uint256 _value) external {
        ParamProposal storage p = paramProposals[nextParamProposalId];
        nextParamProposalId = nextParamProposalId + 1;
        address msgSender = msg.sender;
        uint256 deposit = params[ParamName.ProposalDeposit];

        p.proposer = msgSender;
        p.deposit = deposit;
        p.voteDeadline = block.number + params[ParamName.GovernVoteTimeout];
        p.name = _name;
        p.newValue = _value;
        p.status = ProposalStatus.Voting;

        celerToken.safeTransferFrom(msgSender, address(this), deposit);

        emit CreateParamProposal(nextParamProposalId - 1, msgSender, deposit, p.voteDeadline, _name, _value);
    }

    /**
     * @notice Internal function to vote for a parameter proposal
     * @dev Must be used in Staking contract
     * @param _proposalId the proposal id
     * @param _voter the voter address
     * @param _vote the vote type
     */
    function internalVoteParam(
        uint256 _proposalId,
        address _voter,
        VoteOption _vote
    ) internal {
        ParamProposal storage p = paramProposals[_proposalId];
        require(p.status == ProposalStatus.Voting, "Invalid proposal status");
        require(block.number < p.voteDeadline, "Vote deadline passed");
        require(p.votes[_voter] == VoteOption.Null, "Voter has voted");

        p.votes[_voter] = _vote;

        emit VoteParam(_proposalId, _voter, _vote);
    }

    /**
     * @notice Internal function to confirm a parameter proposal
     * @dev Must be used in Staking contract
     * @param _proposalId the proposal id
     * @param _passed proposal passed or not
     */
    function internalConfirmParamProposal(uint256 _proposalId, bool _passed) internal {
        ParamProposal storage p = paramProposals[_proposalId];
        require(p.status == ProposalStatus.Voting, "Invalid proposal status");
        require(block.number >= p.voteDeadline, "Vote deadline not reached");

        p.status = ProposalStatus.Closed;
        if (_passed) {
            celerToken.safeTransfer(p.proposer, p.deposit);
            params[p.name] = p.newValue;
        }

        emit ConfirmParamProposal(_proposalId, _passed, p.name, p.newValue);
    }
}
