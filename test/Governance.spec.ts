import { expect } from 'chai';
import { ethers } from 'hardhat';

import { parseUnits } from '@ethersproject/units';
import { Wallet } from '@ethersproject/wallet';

import { deployContracts, getAccounts, advanceBlockNumber, loadFixture } from './lib/common';
import * as consts from './lib/constants';
import { Staking, TestERC20 } from '../typechain';

describe('Governance Tests', function () {
  async function fixture([admin]: Wallet[]) {
    const { staking, celr } = await deployContracts(admin);
    return { admin, staking, celr };
  }

  let staking: Staking;
  let celr: TestERC20;
  let admin: Wallet;
  let validators: Wallet[];

  beforeEach(async () => {
    const res = await loadFixture(fixture);
    staking = res.staking;
    celr = res.celr;
    admin = res.admin;
    validators = await getAccounts(res.admin, [celr], 4);
    for (let i = 0; i < 4; i++) {
      await celr.connect(validators[i]).approve(staking.address, parseUnits('100'));
      await staking
        .connect(validators[i])
        .initializeValidator(validators[i].address, consts.MIN_SELF_DELEGATION, consts.COMMISSION_RATE);
      await staking.connect(validators[i]).delegate(validators[i].address, parseUnits('6'));
      await staking.connect(validators[i]).bondValidator();
    }
    await celr.approve(staking.address, parseUnits('100'));
  });

  it('should createParamProposal successfully', async function () {
    const newSlashTimeout = consts.SLASH_TIMEOUT + 1;
    const blockNumber = await ethers.provider.getBlockNumber();
    await expect(staking.createParamProposal(consts.ENUM_SLASH_TIMEOUT, newSlashTimeout))
      .to.emit(staking, 'CreateParamProposal')
      .withArgs(
        0,
        admin.address,
        consts.GOVERN_PROPOSAL_DEPOSIT,
        consts.GOVERN_VOTE_TIMEOUT + blockNumber + 1,
        consts.ENUM_SLASH_TIMEOUT,
        newSlashTimeout
      );
  });

  describe('after createParamProposal successfully', async () => {
    const proposalId = 0;
    const paramType = consts.ENUM_MAX_VALIDATOR_NUM;
    const paramValue = 25;

    beforeEach(async () => {
      await staking.createParamProposal(paramType, paramValue);
    });

    it('should fail to voteParam if not validator', async function () {
      await expect(staking.voteParam(proposalId, consts.ENUM_VOTE_OPTION_YES)).to.be.revertedWith(
        'Caller is not a bonded validator'
      );
    });

    it('should fail to voteParam for a proposal with an invalid status', async function () {
      await expect(
        staking.connect(validators[0]).voteParam(proposalId + 1, consts.ENUM_VOTE_OPTION_YES)
      ).to.be.revertedWith('Invalid proposal status');
    });

    it('should vote successfully as a validator', async function () {
      await expect(staking.connect(validators[0]).voteParam(proposalId, consts.ENUM_VOTE_OPTION_YES))
        .to.emit(staking, 'VoteParam')
        .withArgs(proposalId, validators[0].address, consts.ENUM_VOTE_OPTION_YES);
    });

    describe('after a validtor votes successfully', async () => {
      beforeEach(async () => {
        await staking.connect(validators[0]).voteParam(proposalId, consts.ENUM_VOTE_OPTION_YES);
      });

      it('should fail to vote for the same proposal twice', async function () {
        await expect(
          staking.connect(validators[0]).voteParam(proposalId, consts.ENUM_VOTE_OPTION_YES)
        ).to.be.revertedWith('Voter has voted');
      });

      it('should fail to confirmParamProposal before the vote deadline', async function () {
        await expect(staking.confirmParamProposal(proposalId)).to.be.revertedWith('Vote deadline not reached');
      });

      it('should accept proposal after over 2/3 voted for Yes', async function () {
        await expect(staking.connect(validators[1]).voteParam(proposalId, consts.ENUM_VOTE_OPTION_YES))
          .to.emit(staking, 'VoteParam')
          .withArgs(proposalId, validators[1].address, consts.ENUM_VOTE_OPTION_YES);
        await staking.connect(validators[2]).voteParam(proposalId, consts.ENUM_VOTE_OPTION_YES);
        await advanceBlockNumber(consts.GOVERN_VOTE_TIMEOUT);
        await expect(staking.confirmParamProposal(proposalId))
          .to.emit(staking, 'ConfirmParamProposal')
          .withArgs(proposalId, true, paramType, paramValue);
      });

      describe('after passing the vote deadline with less than 2/3 votes', async () => {
        beforeEach(async () => {
          await advanceBlockNumber(consts.GOVERN_VOTE_TIMEOUT);
        });

        it('should fail to vote after the vote deadline', async function () {
          await expect(
            staking.connect(validators[2]).voteParam(proposalId, consts.ENUM_VOTE_OPTION_YES)
          ).to.be.revertedWith('Vote deadline passed');
        });

        it('should reject proposal successfully', async function () {
          await expect(staking.confirmParamProposal(proposalId))
            .to.emit(staking, 'ConfirmParamProposal')
            .withArgs(proposalId, false, paramType, paramValue);
        });
      });
    });
  });
});
