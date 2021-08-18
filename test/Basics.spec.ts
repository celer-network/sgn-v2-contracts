import { expect } from 'chai';

import { keccak256 } from '@ethersproject/solidity';
import { parseUnits } from '@ethersproject/units';
import { Wallet } from '@ethersproject/wallet';

import { deployContracts, getAccounts, advanceBlockNumber, loadFixture } from './lib/common';
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
  let validator: Wallet;
  let delegator: Wallet;

  beforeEach(async () => {
    const res = await loadFixture(fixture);
    dpos = res.dpos;
    sgn = res.sgn;
    celr = res.celr;
    admin = res.admin;
    const accounts = await getAccounts(res.admin, [celr], 2);
    validator = accounts[0];
    delegator = accounts[1];
    await celr.connect(validator).approve(dpos.address, parseUnits('100'));
    await celr.connect(delegator).approve(dpos.address, parseUnits('100'));
  });

  it('should fail to delegate to an uninitialized validator', async function () {
    await expect(dpos.delegate(validator.address, consts.DELEGATOR_STAKE)).to.be.revertedWith(
      'Validator is not initialized'
    );
  });

  it('should fail to initialize a validator when paused', async function () {
    await dpos.pause();
    await expect(
      dpos.connect(validator).initializeValidator(consts.MIN_SELF_DELEGATION, consts.COMMISSION_RATE)
    ).to.be.revertedWith('Pausable: paused');
  });

  it('should fail to initialize a non-whitelisted validator when whitelist is enabled', async function () {
    await dpos.enableWhitelist();
    await expect(
      dpos.connect(validator).initializeValidator(consts.MIN_SELF_DELEGATION, consts.COMMISSION_RATE)
    ).to.be.revertedWith('caller is not whitelisted');
  });

  it('should initialize a whitelisted validator successfully when whitelist is enabled', async function () {
    await dpos.enableWhitelist();
    await dpos.addWhitelisted(validator.address);
    await expect(dpos.connect(validator).initializeValidator(consts.MIN_SELF_DELEGATION, consts.COMMISSION_RATE))
      .to.emit(dpos, 'ValidatorParamsUpdate')
      .withArgs(validator.address, consts.MIN_SELF_DELEGATION, consts.COMMISSION_RATE);
  });

  it('should initialize a validator and update sidechain address successfully', async function () {
    await expect(dpos.connect(validator).initializeValidator(consts.MIN_SELF_DELEGATION, consts.COMMISSION_RATE))
      .to.emit(dpos, 'ValidatorParamsUpdate')
      .withArgs(validator.address, consts.MIN_SELF_DELEGATION, consts.COMMISSION_RATE);

    const sidechainAddr = keccak256(['string'], ['sgnaddr1']);
    await expect(sgn.connect(validator).updateSgnAddr(sidechainAddr))
      .to.emit(sgn, 'SgnAddrUpdate')
      .withArgs(validator.address, consts.HASHED_NULL, sidechainAddr);
  });

  describe('after one validator finishes initialization', async () => {
    const sidechainAddr = keccak256(['string'], ['sgnaddr']);
    beforeEach(async () => {
      await dpos.connect(validator).initializeValidator(consts.MIN_SELF_DELEGATION, consts.COMMISSION_RATE);
      await sgn.connect(validator).updateSgnAddr(sidechainAddr);
    });

    it('should fail to initialize the same validator twice', async function () {
      await expect(
        dpos.connect(validator).initializeValidator(consts.MIN_SELF_DELEGATION, consts.COMMISSION_RATE)
      ).to.be.revertedWith('Validator is initialized');
    });

    it('should update sidechain address by validator successfully', async function () {
      const newSidechainAddr = keccak256(['string'], ['sgnaddr_new']);
      await expect(sgn.connect(validator).updateSgnAddr(newSidechainAddr))
        .to.emit(sgn, 'SgnAddrUpdate')
        .withArgs(validator.address, sidechainAddr, newSidechainAddr);
    });

    it('should fail to delegate when paused', async function () {
      await dpos.pause();
      await expect(dpos.delegate(validator.address, consts.DELEGATOR_STAKE)).to.be.revertedWith('Pausable: paused');
    });

    it('should delegate to validator by a delegator successfully', async function () {
      await expect(dpos.connect(delegator).delegate(validator.address, consts.DELEGATOR_STAKE))
        .to.emit(dpos, 'DelegationUpdate')
        .withArgs(
          validator.address,
          delegator.address,
          consts.DELEGATOR_STAKE,
          consts.DELEGATOR_STAKE,
          consts.DELEGATOR_STAKE
        );
    });

    it('should fail to bondValidator before delegating enough stake', async function () {
      await dpos.connect(delegator).delegate(validator.address, consts.MIN_STAKING_POOL.sub(1000));
      await expect(dpos.connect(validator).bondValidator()).to.be.revertedWith('Need min required tokens');
    });

    describe('after one delegator delegates enough stake to the validator', async () => {
      beforeEach(async () => {
        await dpos.connect(delegator).delegate(validator.address, consts.DELEGATOR_STAKE);
      });

      it('should fail to bondValidator before self delegating minSelfDelegation', async function () {
        await expect(dpos.connect(validator).bondValidator()).to.be.revertedWith('Insufficient self delegation');
      });

      it('should undelegate from unbonded validator by delegator successfully', async function () {
        await expect(dpos.connect(delegator).undelegate(validator.address, consts.DELEGATOR_STAKE))
          .to.emit(dpos, 'Undelegated')
          .withArgs(validator.address, delegator.address, consts.DELEGATOR_STAKE);
      });

      it('should fail to undelegate from unbonded validator more than it delegated', async function () {
        await expect(
          dpos.connect(delegator).undelegate(validator.address, consts.DELEGATOR_STAKE.add(1000))
        ).to.be.revertedWith('reverted with panic code 0x11');
      });

      it('should fail to undelegate from unbonded validator with amount smaller than 1 share', async function () {
        await expect(dpos.connect(delegator).undelegate(validator.address, 1000)).to.be.revertedWith(
          'Minimal amount is 1 share'
        );
      });

      it('should fail to drain token when not paused', async function () {
        await expect(dpos.drainToken(consts.DELEGATOR_STAKE)).to.be.revertedWith('Pausable: not paused');
      });

      it('should drainToken successfully when paused', async function () {
        await dpos.pause();
        const balanceBefore = await celr.balanceOf(admin.address);
        await dpos.drainToken(consts.DELEGATOR_STAKE);
        const balanceAfter = await celr.balanceOf(admin.address);
        expect(balanceAfter.sub(balanceBefore)).to.equal(consts.DELEGATOR_STAKE);
      });

      describe('after one delegator delegates enough stake to the validator', async () => {
        beforeEach(async () => {
          await dpos.connect(validator).delegate(validator.address, consts.VALIDATOR_STAKE);
        });

        it('should bondValidator successfully', async function () {
          await expect(dpos.connect(validator).bondValidator())
            .to.emit(dpos, 'ValidatorStatusUpdate')
            .withArgs(validator.address, consts.STATUS_BONDED);
        });

        it('should increase min self delegation and bondValidator successfully', async function () {
          const higherMinSelfDelegation = consts.MIN_SELF_DELEGATION.add(1000000);
          await expect(dpos.connect(validator).updateMinSelfDelegation(higherMinSelfDelegation))
            .to.emit(dpos, 'ValidatorParamsUpdate')
            .withArgs(validator.address, higherMinSelfDelegation, consts.COMMISSION_RATE);

          await expect(dpos.connect(validator).bondValidator())
            .to.emit(dpos, 'ValidatorStatusUpdate')
            .withArgs(validator.address, consts.STATUS_BONDED);
        });

        it('should decrease min self delegation and only able to bondValidator after notice period', async function () {
          const lowerMinSelfDelegation = consts.MIN_SELF_DELEGATION.sub(1000000);
          await expect(dpos.connect(validator).updateMinSelfDelegation(lowerMinSelfDelegation))
            .to.emit(dpos, 'ValidatorParamsUpdate')
            .withArgs(validator.address, lowerMinSelfDelegation, consts.COMMISSION_RATE);

          await expect(dpos.connect(validator).bondValidator()).to.be.revertedWith('Not earliest bond time yet');

          await advanceBlockNumber(consts.ADVANCE_NOTICE_PERIOD);
          await expect(dpos.connect(validator).bondValidator())
            .to.emit(dpos, 'ValidatorStatusUpdate')
            .withArgs(validator.address, consts.STATUS_BONDED);
        });

        describe('after one validator bondValidator', async () => {
          beforeEach(async () => {
            await dpos.connect(validator).bondValidator();
          });

          it('should fail to undelegate with amount smaller than 1 share', async function () {
            await expect(dpos.connect(delegator).undelegate(validator.address, 1000)).to.be.revertedWith(
              'Minimal amount is 1 share'
            );
          });

          it('should fail to undelegate more than it delegated', async function () {
            await expect(
              dpos.connect(delegator).undelegate(validator.address, consts.DELEGATOR_STAKE.add(1000))
            ).to.be.revertedWith('reverted with panic code 0x11');
          });

          it('should remove the validator after validator undelegate to become under minSelfDelegation', async function () {
            const undelegateAmt = consts.VALIDATOR_STAKE.sub(consts.MIN_SELF_DELEGATION).add(1000);
            await expect(dpos.connect(validator).undelegate(validator.address, undelegateAmt))
              .to.emit(dpos, 'ValidatorStatusUpdate')
              .withArgs(validator.address, consts.STATUS_UNBONDING);
          });

          it('should remove the validator after delegator undelegate to become under minStakingPool', async function () {
            await expect(dpos.connect(delegator).undelegate(validator.address, consts.DELEGATOR_STAKE))
              .to.emit(dpos, 'ValidatorStatusUpdate')
              .withArgs(validator.address, consts.STATUS_UNBONDING)
              .to.emit(dpos, 'DelegationUpdate')
              .withArgs(
                validator.address,
                delegator.address,
                consts.VALIDATOR_STAKE,
                0,
                parseUnits('0').sub(consts.DELEGATOR_STAKE)
              );
          });

          it('should increase min self delegation successfully', async function () {
            const higherMinSelfDelegation = consts.MIN_SELF_DELEGATION.add(1000000);
            await expect(dpos.connect(validator).updateMinSelfDelegation(higherMinSelfDelegation))
              .to.emit(dpos, 'ValidatorParamsUpdate')
              .withArgs(validator.address, higherMinSelfDelegation, consts.COMMISSION_RATE);
          });

          it('should fail to decrease min self delegation', async function () {
            const lowerMinSelfDelegation = consts.MIN_SELF_DELEGATION.sub(1000000);
            await expect(dpos.connect(validator).updateMinSelfDelegation(lowerMinSelfDelegation)).to.be.revertedWith(
              'Validator is bonded'
            );
          });

          describe('after a delegator undelegate', async () => {
            beforeEach(async () => {
              await dpos.connect(delegator).undelegate(validator.address, parseUnits('2'));
            });

            it('should fail to undelegate with a total more than it delegated', async function () {
              await expect(
                dpos.connect(delegator).undelegate(validator.address, consts.DELEGATOR_STAKE)
              ).to.be.revertedWith('reverted with panic code 0x11');
            });

            it('should completeUndelegate succesfully', async function () {
              // before withdrawTimeout
              await expect(dpos.connect(delegator).completeUndelegate(validator.address)).to.be.revertedWith(
                'no undelegation ready to be completed'
              );

              // after withdrawTimeout
              await advanceBlockNumber(consts.SLASH_TIMEOUT);
              // first completeUndelegate
              await expect(dpos.connect(delegator).completeUndelegate(validator.address))
                .to.emit(dpos, 'Undelegated')
                .withArgs(validator.address, delegator.address, parseUnits('2'));

              // second completeUndelegate
              await expect(dpos.connect(delegator).completeUndelegate(validator.address)).to.be.revertedWith(
                'no undelegation ready to be completed'
              );
            });

            it('should pass with multiple undelegations', async function () {
              await dpos.connect(delegator).undelegate(validator.address, parseUnits('1'));

              let res = await dpos.getDelegatorInfo(validator.address, delegator.address);
              expect(res.shares).to.equal(parseUnits('3'));
              expect(res.undelegations[0].amount).to.equal(parseUnits('2'));
              expect(res.undelegations[1].amount).to.equal(parseUnits('1'));

              await advanceBlockNumber(consts.SLASH_TIMEOUT);
              await dpos.connect(delegator).undelegate(validator.address, parseUnits('1'));

              await expect(dpos.connect(delegator).completeUndelegate(validator.address))
                .to.emit(dpos, 'Undelegated')
                .withArgs(validator.address, delegator.address, parseUnits('3'));

              res = await dpos.getDelegatorInfo(validator.address, delegator.address);
              expect(res.shares).to.equal(parseUnits('2'));
              expect(res.undelegations[0].amount).to.equal(parseUnits('1'));

              await expect(dpos.connect(delegator).completeUndelegate(validator.address)).to.be.revertedWith(
                'no undelegation ready to be completed'
              );

              await advanceBlockNumber(consts.SLASH_TIMEOUT);
              await expect(dpos.connect(delegator).completeUndelegate(validator.address))
                .to.emit(dpos, 'Undelegated')
                .withArgs(validator.address, delegator.address, parseUnits('1'));

              res = await dpos.getDelegatorInfo(validator.address, delegator.address);
              expect(res.shares).to.equal(parseUnits('2'));
              expect(res.undelegations.length).to.equal(0);
            });
          });
        });
      });
    });
  });
});
