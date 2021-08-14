import { expect } from 'chai';
import { ethers } from 'hardhat';

import { keccak256 } from '@ethersproject/solidity';
import { parseUnits } from '@ethersproject/units';
import { Wallet } from '@ethersproject/wallet';

import { deployContracts, getAccounts, advanceBlockNumber, loadFixture } from './lib/common';
import { getPenaltyRequest } from './lib/proto';
import * as consts from './lib/constants';
import { DPoS, SGN, TestERC20 } from '../typechain';

describe('Basic Tests', function () {
  async function fixture([admin]: Wallet[]) {
    const { dpos, sgn, celr } = await deployContracts(admin);
    return { admin, dpos, sgn, celr };
  }

  let dpos: DPoS;
  let sgn: SGN;
  let celr: TestERC20;
  let admin: Wallet;
  let candidate: Wallet;
  let delegator: Wallet;

  beforeEach(async () => {
    const res = await loadFixture(fixture);
    dpos = res.dpos;
    sgn = res.sgn;
    celr = res.celr;
    admin = res.admin;
    const accounts = await getAccounts(res.admin, [celr], 2);
    candidate = accounts[0];
    delegator = accounts[1];
    await celr.connect(candidate).approve(dpos.address, parseUnits('100'));
    await celr.connect(delegator).approve(dpos.address, parseUnits('100'));
  });

  it('should fail to delegate to an uninitialized candidate', async function () {
    await expect(dpos.delegate(candidate.address, consts.DELEGATOR_STAKE)).to.be.revertedWith(
      'Candidate is not initialized'
    );
  });

  it('should fail to initialize a candidate when paused', async function () {
    await dpos.pause();
    await expect(
      dpos.connect(candidate).initializeCandidate(consts.MIN_SELF_STAKE, consts.COMMISSION_RATE)
    ).to.be.revertedWith('Pausable: paused');
  });

  it('should fail to initialize a non-whitelisted candidate when whitelist is enabled', async function () {
    await dpos.enableWhitelist();
    await expect(
      dpos.connect(candidate).initializeCandidate(consts.MIN_SELF_STAKE, consts.COMMISSION_RATE)
    ).to.be.revertedWith('caller is not whitelisted');
  });

  it('should initialize a whitelisted candidate successfully when whitelist is enabled', async function () {
    await dpos.enableWhitelist();
    await dpos.addWhitelisted(candidate.address);
    await expect(dpos.connect(candidate).initializeCandidate(consts.MIN_SELF_STAKE, consts.COMMISSION_RATE))
      .to.emit(dpos, 'InitializeCandidate')
      .withArgs(candidate.address, consts.MIN_SELF_STAKE, consts.COMMISSION_RATE);
  });

  it('should initialize a candidate and update sidechain address successfully', async function () {
    await expect(dpos.connect(candidate).initializeCandidate(consts.MIN_SELF_STAKE, consts.COMMISSION_RATE))
      .to.emit(dpos, 'InitializeCandidate')
      .withArgs(candidate.address, consts.MIN_SELF_STAKE, consts.COMMISSION_RATE);

    const sidechainAddr = keccak256(['string'], ['sgnaddr1']);
    await expect(sgn.connect(candidate).updateSidechainAddr(sidechainAddr))
      .to.emit(sgn, 'UpdateSidechainAddr')
      .withArgs(candidate.address, consts.HASHED_NULL, sidechainAddr);
  });

  describe('after one candidate finishes initialization', async () => {
    const sidechainAddr = keccak256(['string'], ['sgnaddr']);
    beforeEach(async () => {
      await dpos.connect(candidate).initializeCandidate(consts.MIN_SELF_STAKE, consts.COMMISSION_RATE);
      await sgn.connect(candidate).updateSidechainAddr(sidechainAddr);
    });

    it('should fail to initialize the same candidate twice', async function () {
      await expect(
        dpos.connect(candidate).initializeCandidate(consts.MIN_SELF_STAKE, consts.COMMISSION_RATE)
      ).to.be.revertedWith('Candidate is initialized');
    });

    it('should update sidechain address by candidate successfully', async function () {
      const newSidechainAddr = keccak256(['string'], ['sgnaddr_new']);
      await expect(sgn.connect(candidate).updateSidechainAddr(newSidechainAddr))
        .to.emit(sgn, 'UpdateSidechainAddr')
        .withArgs(candidate.address, sidechainAddr, newSidechainAddr);
    });

    it('should fail to delegate when paused', async function () {
      await dpos.pause();
      await expect(dpos.delegate(candidate.address, consts.DELEGATOR_STAKE)).to.be.revertedWith('Pausable: paused');
    });

    it('should delegate to candidate by a delegator successfully', async function () {
      await expect(dpos.connect(delegator).delegate(candidate.address, consts.DELEGATOR_STAKE))
        .to.emit(dpos, 'Delegate')
        .withArgs(delegator.address, candidate.address, consts.DELEGATOR_STAKE, consts.DELEGATOR_STAKE);
    });

    it('should fail to claimValidator before delegating enough stake', async function () {
      await dpos.connect(delegator).delegate(candidate.address, consts.MIN_STAKING_POOL.sub(1000));
      await expect(dpos.connect(candidate).claimValidator()).to.be.revertedWith('Insufficient staking pool');
    });

    describe('after one delegator delegates enough stake to the candidate', async () => {
      beforeEach(async () => {
        await dpos.connect(delegator).delegate(candidate.address, consts.DELEGATOR_STAKE);
      });

      it('should fail to claimValidator before self delegating minSelfStake', async function () {
        await expect(dpos.connect(candidate).claimValidator()).to.be.revertedWith('Not enough self stake');
      });

      it('should withdrawFromUnbondedCandidate by delegator successfully', async function () {
        await expect(dpos.connect(delegator).withdrawFromUnbondedCandidate(candidate.address, consts.DELEGATOR_STAKE))
          .to.emit(dpos, 'WithdrawFromUnbondedCandidate')
          .withArgs(delegator.address, candidate.address, consts.DELEGATOR_STAKE);
      });

      it('should fail to withdrawFromUnbondedCandidate more than it delegated', async function () {
        await expect(
          dpos.connect(delegator).withdrawFromUnbondedCandidate(candidate.address, consts.DELEGATOR_STAKE.add(1000))
        ).to.be.revertedWith('reverted with panic code 0x11');
      });

      it('should fail to withdrawFromUnbondedCandidate with amount smaller than 1 CELR', async function () {
        await expect(dpos.connect(delegator).withdrawFromUnbondedCandidate(candidate.address, 1000)).to.be.revertedWith(
          'Amount is smaller than minimum requirement'
        );
      });

      it('should fail to drain token when not paused', async function () {
        await expect(dpos.drainToken(consts.DELEGATOR_STAKE)).to.be.revertedWith('Pausable: not paused');
      });

      it('should drainToken successfully when paused', async function () {
        await dpos.pause();
        let balanceBefore = await celr.balanceOf(admin.address);
        await dpos.drainToken(consts.DELEGATOR_STAKE);
        let balanceAfter = await celr.balanceOf(admin.address);
        expect(balanceAfter.sub(balanceBefore)).to.equal(consts.DELEGATOR_STAKE);
      });

      describe('after one delegator delegates enough stake to the candidate', async () => {
        beforeEach(async () => {
          await dpos.connect(candidate).delegate(candidate.address, consts.CANDIDATE_STAKE);
        });

        it('should claimValidator successfully', async function () {
          await expect(dpos.connect(candidate).claimValidator())
            .to.emit(dpos, 'ValidatorChange')
            .withArgs(candidate.address, consts.TYPE_VALIDATOR_ADD);
        });

        it('should increase min self stake and claimValidator successfully', async function () {
          const higherMinSelfStake = consts.MIN_SELF_STAKE.add(1000000);
          await expect(dpos.connect(candidate).updateMinSelfStake(higherMinSelfStake))
            .to.emit(dpos, 'UpdateMinSelfStake')
            .withArgs(candidate.address, higherMinSelfStake);

          await expect(dpos.connect(candidate).claimValidator())
            .to.emit(dpos, 'ValidatorChange')
            .withArgs(candidate.address, consts.TYPE_VALIDATOR_ADD);
        });

        it('should decrease min self stake and only able to claimValidator after notice period', async function () {
          const lowerMinSelfStake = consts.MIN_SELF_STAKE.sub(1000000);
          await expect(dpos.connect(candidate).updateMinSelfStake(lowerMinSelfStake))
            .to.emit(dpos, 'UpdateMinSelfStake')
            .withArgs(candidate.address, lowerMinSelfStake);

          await expect(dpos.connect(candidate).claimValidator()).to.be.revertedWith('Not earliest bond time yet');

          await advanceBlockNumber(consts.ADVANCE_NOTICE_PERIOD);
          await expect(dpos.connect(candidate).claimValidator())
            .to.emit(dpos, 'ValidatorChange')
            .withArgs(candidate.address, consts.TYPE_VALIDATOR_ADD);
        });

        describe('after one candidate claimValidator', async () => {
          beforeEach(async () => {
            await dpos.connect(candidate).claimValidator();
          });

          it('should fail withdrawFromUnbondedCandidate', async function () {
            await expect(
              dpos.connect(delegator).withdrawFromUnbondedCandidate(candidate.address, consts.DELEGATOR_STAKE)
            ).to.be.revertedWith('invalid status');
          });

          it('should fail to intendWithdraw with amount smaller than 1 CELR', async function () {
            await expect(dpos.connect(delegator).intendWithdraw(candidate.address, 1000)).to.be.revertedWith(
              'Amount is smaller than minimum requirement'
            );
          });

          it('should fail to intendWithdraw more than it delegated', async function () {
            await expect(
              dpos.connect(delegator).intendWithdraw(candidate.address, consts.DELEGATOR_STAKE.add(1000))
            ).to.be.revertedWith('reverted with panic code 0x11');
          });

          it('should remove the validator after validator intendWithdraw to become under minSelfStake', async function () {
            const withdrawAmt = consts.CANDIDATE_STAKE.sub(consts.MIN_SELF_STAKE).add(1000);
            const blockNumber = await ethers.provider.getBlockNumber();
            await expect(dpos.connect(candidate).intendWithdraw(candidate.address, withdrawAmt))
              .to.emit(dpos, 'ValidatorChange')
              .withArgs(candidate.address, consts.TYPE_VALIDATOR_REMOVAL)
              .to.emit(dpos, 'IntendWithdraw')
              .withArgs(candidate.address, candidate.address, withdrawAmt, blockNumber + 1);
          });

          it('should remove the validator after delegator intendWithdraw to become under minStakingPool', async function () {
            const blockNumber = await ethers.provider.getBlockNumber();
            await expect(dpos.connect(delegator).intendWithdraw(candidate.address, consts.DELEGATOR_STAKE))
              .to.emit(dpos, 'ValidatorChange')
              .withArgs(candidate.address, consts.TYPE_VALIDATOR_REMOVAL)
              .to.emit(dpos, 'IntendWithdraw')
              .withArgs(delegator.address, candidate.address, consts.DELEGATOR_STAKE, blockNumber + 1);
          });

          it('should increase min self stake successfully', async function () {
            const higherMinSelfStake = consts.MIN_SELF_STAKE.add(1000000);
            await expect(dpos.connect(candidate).updateMinSelfStake(higherMinSelfStake))
              .to.emit(dpos, 'UpdateMinSelfStake')
              .withArgs(candidate.address, higherMinSelfStake);
          });

          it('should fail to decrease min self stake', async function () {
            const lowerMinSelfStake = consts.MIN_SELF_STAKE.sub(1000000);
            await expect(dpos.connect(candidate).updateMinSelfStake(lowerMinSelfStake)).to.be.revertedWith(
              'Candidate is bonded'
            );
          });

          describe('after a delegator intendWithdraw', async () => {
            beforeEach(async () => {
              await dpos.connect(delegator).intendWithdraw(candidate.address, parseUnits('2'));
            });

            it('should fail to intendWithdraw with a total more than it delegated', async function () {
              await expect(
                dpos.connect(delegator).intendWithdraw(candidate.address, consts.DELEGATOR_STAKE)
              ).to.be.revertedWith('reverted with panic code 0x11');
            });

            it('should confirmWithdraw succesfully', async function () {
              // before withdrawTimeout
              await expect(dpos.connect(delegator).confirmWithdraw(candidate.address))
                .to.emit(dpos, 'ConfirmWithdraw')
                .withArgs(delegator.address, candidate.address, 0);

              // after withdrawTimeout
              await advanceBlockNumber(consts.SLASH_TIMEOUT);
              // first confirmWithdraw
              await expect(dpos.connect(delegator).confirmWithdraw(candidate.address))
                .to.emit(dpos, 'ConfirmWithdraw')
                .withArgs(delegator.address, candidate.address, parseUnits('2'));

              // second confirmWithdraw
              await expect(dpos.connect(delegator).confirmWithdraw(candidate.address))
                .to.emit(dpos, 'ConfirmWithdraw')
                .withArgs(delegator.address, candidate.address, 0);
            });

            it('should pass with multiple withdrawal intents', async function () {
              await dpos.connect(delegator).intendWithdraw(candidate.address, parseUnits('1'));

              let res = await dpos.getDelegatorInfo(candidate.address, delegator.address);
              expect(res.delegatedStake).to.equal(parseUnits('3'));
              expect(res.undelegatingStake).to.equal(parseUnits('3'));
              expect(res.intentAmounts[0]).to.equal(parseUnits('2'));
              expect(res.intentAmounts[1]).to.equal(parseUnits('1'));

              await advanceBlockNumber(consts.SLASH_TIMEOUT);
              await dpos.connect(delegator).intendWithdraw(candidate.address, parseUnits('1'));

              await expect(dpos.connect(delegator).confirmWithdraw(candidate.address))
                .to.emit(dpos, 'ConfirmWithdraw')
                .withArgs(delegator.address, candidate.address, parseUnits('3'));

              res = await dpos.getDelegatorInfo(candidate.address, delegator.address);
              expect(res.delegatedStake).to.equal(parseUnits('2'));
              expect(res.undelegatingStake).to.equal(parseUnits('1'));
              expect(res.intentAmounts[0]).to.equal(parseUnits('1'));

              await expect(dpos.connect(delegator).confirmWithdraw(candidate.address))
                .to.emit(dpos, 'ConfirmWithdraw')
                .withArgs(delegator.address, candidate.address, 0);

              await advanceBlockNumber(consts.SLASH_TIMEOUT);
              await expect(dpos.connect(delegator).confirmWithdraw(candidate.address))
                .to.emit(dpos, 'ConfirmWithdraw')
                .withArgs(delegator.address, candidate.address, parseUnits('1'));

              res = await dpos.getDelegatorInfo(candidate.address, delegator.address);
              expect(res.delegatedStake).to.equal(parseUnits('2'));
              expect(res.undelegatingStake).to.equal(0);
            });

            it('should pass with multiple withdrawal intents', async function () {
              const slashAmt = consts.DELEGATOR_STAKE.sub(parseUnits('1'));
              await advanceBlockNumber(consts.DPOS_GO_LIVE_TIMEOUT);
              const request = await getPenaltyRequest(
                1,
                1000000,
                candidate.address,
                [delegator.address],
                [slashAmt],
                [consts.ZERO_ADDR],
                [slashAmt],
                [candidate]
              );
              await dpos.slash(request.penaltyBytes, request.sigs);

              await advanceBlockNumber(consts.SLASH_TIMEOUT);
              await expect(dpos.connect(delegator).confirmWithdraw(candidate.address))
                .to.emit(dpos, 'ConfirmWithdraw')
                .withArgs(delegator.address, candidate.address, parseUnits('1'));
            });

            it('should confirm withdrawal zero amt due to all stakes being slashed', async function () {
              await advanceBlockNumber(consts.DPOS_GO_LIVE_TIMEOUT);
              const request = await getPenaltyRequest(
                1,
                1000000,
                candidate.address,
                [delegator.address],
                [consts.DELEGATOR_STAKE],
                [consts.ZERO_ADDR],
                [consts.DELEGATOR_STAKE],
                [candidate]
              );
              await dpos.slash(request.penaltyBytes, request.sigs);

              await advanceBlockNumber(consts.SLASH_TIMEOUT);
              await expect(dpos.connect(delegator).confirmWithdraw(candidate.address))
                .to.emit(dpos, 'ConfirmWithdraw')
                .withArgs(delegator.address, candidate.address, 0);
            });
          });
        });
      });
    });
  });
});
