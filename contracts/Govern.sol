// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Governance module for DPoS contract
 * @notice Govern contract implements the basic governance logic
 * @dev DPoS contract should inherit this contract
 * @dev Some specific functions of governance are defined in DPoS contract
 */
contract Govern is Ownable {
    using SafeERC20 for IERC20;

    enum ParamNames {
        ProposalDeposit,
        GovernVoteTimeout,
        SlashTimeout,
        MinValidatorNum,
        MaxValidatorNum,
        MinStakeInPool,
        AdvanceNoticePeriod
    }

    enum ProposalStatus {
        Uninitiated,
        Voting,
        Closed
    }

    enum VoteType {
        Unvoted,
        Yes,
        No,
        Abstain
    }

    struct ParamProposal {
        address proposer;
        uint256 deposit;
        uint256 voteDeadline;
        uint256 record;
        uint256 newValue;
        ProposalStatus status;
        mapping(address => VoteType) votes;
    }

    IERC20 public celerToken;
    // parameters
    mapping(uint256 => uint256) public UIntStorage;
    mapping(uint256 => ParamProposal) public paramProposals;
    uint256 public nextParamProposalId;

    event CreateParamProposal(
        uint256 proposalId,
        address proposer,
        uint256 deposit,
        uint256 voteDeadline,
        uint256 record,
        uint256 newValue
    );

    event VoteParam(uint256 proposalId, address voter, VoteType voteType);

    event ConfirmParamProposal(uint256 proposalId, bool passed, uint256 record, uint256 newValue);

    /**
     * @notice Govern constructor
     * @dev set celerToken and initialize all parameters
     * @param _celerTokenAddress address of the governance token
     * @param _governProposalDeposit required deposit amount for a governance proposal
     * @param _governVoteTimeout voting timeout for a governance proposal
     * @param _slashTimeout the locking time for funds to be potentially slashed
     * @param _minValidatorNum the minimum number of validators
     * @param _maxValidatorNum the maximum number of validators
     * @param _minStakeInPool the global minimum requirement of staking pool for each validator
     * @param _advanceNoticePeriod the time after the announcement and prior to the effective time of an update
     */
    constructor(
        address _celerTokenAddress,
        uint256 _governProposalDeposit,
        uint256 _governVoteTimeout,
        uint256 _slashTimeout,
        uint256 _minValidatorNum,
        uint256 _maxValidatorNum,
        uint256 _minStakeInPool,
        uint256 _advanceNoticePeriod
    ) {
        celerToken = IERC20(_celerTokenAddress);

        UIntStorage[uint256(ParamNames.ProposalDeposit)] = _governProposalDeposit;
        UIntStorage[uint256(ParamNames.GovernVoteTimeout)] = _governVoteTimeout;
        UIntStorage[uint256(ParamNames.SlashTimeout)] = _slashTimeout;
        UIntStorage[uint256(ParamNames.MinValidatorNum)] = _minValidatorNum;
        UIntStorage[uint256(ParamNames.MaxValidatorNum)] = _maxValidatorNum;
        UIntStorage[uint256(ParamNames.MinStakeInPool)] = _minStakeInPool;
        UIntStorage[uint256(ParamNames.AdvanceNoticePeriod)] = _advanceNoticePeriod;
    }

    /********** Get functions **********/
    /**
     * @notice Get the value of a specific uint parameter
     * @param _record the key of this parameter
     * @return the value of this parameter
     */
    function getUIntValue(uint256 _record) public view returns (uint256) {
        return UIntStorage[_record];
    }

    /**
     * @notice Get the vote type of a voter on a parameter proposal
     * @param _proposalId the proposal id
     * @param _voter the voter address
     * @return the vote type of the given voter on the given parameter proposal
     */
    function getParamProposalVote(uint256 _proposalId, address _voter) public view returns (VoteType) {
        return paramProposals[_proposalId].votes[_voter];
    }

    /********** Governance functions **********/
    /**
     * @notice Create a parameter proposal
     * @param _record the key of this parameter
     * @param _value the new proposed value of this parameter
     */
    function createParamProposal(uint256 _record, uint256 _value) external {
        ParamProposal storage p = paramProposals[nextParamProposalId];
        nextParamProposalId = nextParamProposalId + 1;
        address msgSender = msg.sender;
        uint256 deposit = UIntStorage[uint256(ParamNames.ProposalDeposit)];

        p.proposer = msgSender;
        p.deposit = deposit;
        p.voteDeadline = block.number + UIntStorage[uint256(ParamNames.GovernVoteTimeout)];
        p.record = _record;
        p.newValue = _value;
        p.status = ProposalStatus.Voting;

        celerToken.safeTransferFrom(msgSender, address(this), deposit);

        emit CreateParamProposal(nextParamProposalId - 1, msgSender, deposit, p.voteDeadline, _record, _value);
    }

    /**
     * @notice Internal function to vote for a parameter proposal
     * @dev Must be used in DPoS contract
     * @param _proposalId the proposal id
     * @param _voter the voter address
     * @param _vote the vote type
     */
    function internalVoteParam(
        uint256 _proposalId,
        address _voter,
        VoteType _vote
    ) internal {
        ParamProposal storage p = paramProposals[_proposalId];
        require(p.status == ProposalStatus.Voting, "Invalid proposal status");
        require(block.number < p.voteDeadline, "Vote deadline passed");
        require(p.votes[_voter] == VoteType.Unvoted, "Voter has voted");

        p.votes[_voter] = _vote;

        emit VoteParam(_proposalId, _voter, _vote);
    }

    /**
     * @notice Internal function to confirm a parameter proposal
     * @dev Must be used in DPoS contract
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
            UIntStorage[p.record] = p.newValue;
        }

        emit ConfirmParamProposal(_proposalId, _passed, p.record, p.newValue);
    }
}
