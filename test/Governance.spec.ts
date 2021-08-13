import { expect } from 'chai';
import { ethers } from 'hardhat';

import { parseUnits } from '@ethersproject/units';
import { Wallet } from '@ethersproject/wallet';

import { deployContracts, getAccounts, advanceBlockNumber, loadFixture } from './lib/common';
import * as consts from './lib/constants';
import { DPoS, TestERC20 } from '../typechain';

describe('Governance Tests', function () {
  async function fixture([admin]: Wallet[]) {
    const { dpos, celr } = await deployContracts(admin);
    return { admin, dpos, celr };
  }

  let dpos: DPoS;
  let celr: TestERC20;
  let admin: Wallet;
  let validators: Wallet[];

  beforeEach(async () => {
    const res = await loadFixture(fixture);
    dpos = res.dpos;
    celr = res.celr;
    admin = res.admin;
    validators = await getAccounts(res.admin, [celr], 4);
    for (let i = 0; i < 4; i++) {
      await celr.connect(validators[i]).approve(dpos.address, parseUnits('100'));
      await dpos
        .connect(validators[i])
        .initializeCandidate(consts.MIN_SELF_STAKE, consts.COMMISSION_RATE, consts.RATE_LOCK_END_TIME);
      await dpos.connect(validators[i]).delegate(validators[i].address, parseUnits('6'));
      await dpos.connect(validators[i]).claimValidator();
    }
    await celr.approve(dpos.address, parseUnits('100'));
    await advanceBlockNumber(consts.DPOS_GO_LIVE_TIMEOUT);
  });

  it('should createParamProposal successfully', async function () {
    const newSlashTimeout = consts.SLASH_TIMEOUT + 1;
    const blockNumber = await ethers.provider.getBlockNumber();
    await expect(dpos.createParamProposal(consts.ENUM_SLASH_TIMEOUT, newSlashTimeout))
      .to.emit(dpos, 'CreateParamProposal')
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
      await dpos.createParamProposal(paramType, paramValue);
    });

    it('should fail to voteParam if not validator', async function () {
      await expect(dpos.voteParam(proposalId, consts.ENUM_VOTE_TYPE_YES)).to.be.revertedWith(
        'caller is not a validator'
      );
    });

    it('should fail to voteParam for a proposal with an invalid status', async function () {
      await expect(dpos.connect(validators[0]).voteParam(proposalId + 1, consts.ENUM_VOTE_TYPE_YES)).to.be.revertedWith(
        'Invalid proposal status'
      );
    });

    it('should vote successfully as a validator', async function () {
      await expect(dpos.connect(validators[0]).voteParam(proposalId, consts.ENUM_VOTE_TYPE_YES))
        .to.emit(dpos, 'VoteParam')
        .withArgs(proposalId, validators[0].address, consts.ENUM_VOTE_TYPE_YES);
    });

    describe('after a validtor votes successfully', async () => {
      beforeEach(async () => {
        await dpos.connect(validators[0]).voteParam(proposalId, consts.ENUM_VOTE_TYPE_YES);
      });

      it('should fail to vote for the same proposal twice', async function () {
        await expect(dpos.connect(validators[0]).voteParam(proposalId, consts.ENUM_VOTE_TYPE_YES)).to.be.revertedWith(
          'Voter has voted'
        );
      });

      it('should fail to confirmParamProposal before the vote deadline', async function () {
        await expect(dpos.confirmParamProposal(proposalId)).to.be.revertedWith('Vote deadline not reached');
      });

      it('should accept proposal after over 2/3 voted for Yes', async function () {
        await expect(dpos.connect(validators[1]).voteParam(proposalId, consts.ENUM_VOTE_TYPE_YES))
          .to.emit(dpos, 'VoteParam')
          .withArgs(proposalId, validators[1].address, consts.ENUM_VOTE_TYPE_YES);
        await dpos.connect(validators[2]).voteParam(proposalId, consts.ENUM_VOTE_TYPE_YES);
        await advanceBlockNumber(consts.GOVERN_VOTE_TIMEOUT);
        await expect(dpos.confirmParamProposal(proposalId))
          .to.emit(dpos, 'ConfirmParamProposal')
          .withArgs(proposalId, true, paramType, paramValue);
      });

      describe('after passing the vote deadline with less than 2/3 votes', async () => {
        beforeEach(async () => {
          await advanceBlockNumber(consts.GOVERN_VOTE_TIMEOUT);
        });

        it('should fail to vote after the vote deadline', async function () {
          await expect(dpos.connect(validators[2]).voteParam(proposalId, consts.ENUM_VOTE_TYPE_YES)).to.be.revertedWith(
            'Vote deadline passed'
          );
        });

        it('should reject proposal successfully', async function () {
          await expect(dpos.confirmParamProposal(proposalId))
            .to.emit(dpos, 'ConfirmParamProposal')
            .withArgs(proposalId, false, paramType, paramValue);
        });
      });
    });
  });
});
