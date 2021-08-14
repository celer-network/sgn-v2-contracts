import { expect } from 'chai';
import { ethers } from 'hardhat';

import { parseUnits } from '@ethersproject/units';
import { Wallet } from '@ethersproject/wallet';

import { deployContracts, getAccounts, advanceBlockNumber, loadFixture } from './lib/common';
import { getRewardRequest } from './lib/proto';
import * as consts from './lib/constants';
import { DPoS, TestERC20 } from '../typechain';

describe('Reward Tests', function () {
  async function fixture([admin]: Wallet[]) {
    const { dpos, sgn, celr } = await deployContracts(admin);
    return { admin, dpos, sgn, celr };
  }

  let dpos: DPoS;
  let celr: TestERC20;
  let validators: Wallet[];

  const LARGER_LOCK_END_TIME = 100000;

  beforeEach(async () => {
    const res = await loadFixture(fixture);
    dpos = res.dpos;
    celr = res.celr;
    validators = await getAccounts(res.admin, [celr], 4);
    for (let i = 0; i < 4; i++) {
      await celr.connect(validators[i]).approve(dpos.address, parseUnits('100'));
      await dpos
        .connect(validators[i])
        .initializeCandidate(consts.MIN_SELF_STAKE, consts.COMMISSION_RATE, consts.RATE_LOCK_END_TIME);
    }
  });

  it('should fail to initialize a candidate when paused', async function () {
    await dpos.pause();
    await expect(dpos.contributeToMiningPool(100)).to.be.revertedWith('Pausable: paused');
  });

  it('should contribute to mining pool successfully', async function () {
    await expect(dpos.connect(validators[0]).contributeToMiningPool(100))
      .to.emit(dpos, 'MiningPoolContribution')
      .withArgs(validators[0].address, 100, 100);
  });

  it('should increase the commission rate lock end time successfully', async function () {
    await expect(dpos.connect(validators[0]).nonIncreaseCommissionRate(consts.COMMISSION_RATE, LARGER_LOCK_END_TIME))
      .to.emit(dpos, 'UpdateCommissionRate')
      .withArgs(validators[0].address, consts.COMMISSION_RATE, LARGER_LOCK_END_TIME);
  });

  it('should fail to update the commission rate lock end time to an outdated block number', async function () {
    await expect(dpos.connect(validators[0]).nonIncreaseCommissionRate(consts.COMMISSION_RATE, 1)).to.be.revertedWith(
      'Outdated new lock end time'
    );
  });

  it('should fail to update the commission rate lock end time to an outdated block number', async function () {
    await dpos.connect(validators[0]).nonIncreaseCommissionRate(consts.COMMISSION_RATE, LARGER_LOCK_END_TIME);
    const blockNumber = await ethers.provider.getBlockNumber();
    await expect(
      dpos.connect(validators[0]).nonIncreaseCommissionRate(consts.COMMISSION_RATE, blockNumber + 10)
    ).to.be.revertedWith('Invalid new lock end time');
  });

  it('should decrease the commission rate successfully at anytime', async function () {
    let lowerRate = consts.COMMISSION_RATE - 10;
    await expect(dpos.connect(validators[0]).nonIncreaseCommissionRate(lowerRate, LARGER_LOCK_END_TIME))
      .to.emit(dpos, 'UpdateCommissionRate')
      .withArgs(validators[0].address, lowerRate, LARGER_LOCK_END_TIME);

    lowerRate = consts.COMMISSION_RATE - 20;
    await expect(dpos.connect(validators[0]).nonIncreaseCommissionRate(lowerRate, LARGER_LOCK_END_TIME))
      .to.emit(dpos, 'UpdateCommissionRate')
      .withArgs(validators[0].address, lowerRate, LARGER_LOCK_END_TIME);
  });

  it('should announce increase commission rate successfully', async function () {
    const higherRate = consts.COMMISSION_RATE + 10;
    await expect(dpos.connect(validators[0]).announceIncreaseCommissionRate(higherRate, LARGER_LOCK_END_TIME))
      .to.emit(dpos, 'CommissionRateAnnouncement')
      .withArgs(validators[0].address, higherRate, LARGER_LOCK_END_TIME);
  });

  describe('after announceIncreaseCommissionRate', async () => {
    const higherRate = consts.COMMISSION_RATE + 10;
    beforeEach(async () => {
      await dpos.connect(validators[0]).announceIncreaseCommissionRate(higherRate, LARGER_LOCK_END_TIME);
    });

    it('should fail to confirmIncreaseCommissionRate before new rate can take effect', async function () {
      await expect(dpos.connect(validators[0]).confirmIncreaseCommissionRate()).to.be.revertedWith(
        'Still in notice period'
      );
    });

    it('should fail to confirmIncreaseCommissionRate after new rate can take effect but before lock end time', async function () {
      await dpos.connect(validators[0]).nonIncreaseCommissionRate(consts.COMMISSION_RATE, LARGER_LOCK_END_TIME);

      // need to announceIncreaseCommissionRate again because _updateCommissionRate
      // will remove the previous announcement of increasing commission rate
      await dpos.connect(validators[0]).announceIncreaseCommissionRate(higherRate, LARGER_LOCK_END_TIME);
      await advanceBlockNumber(consts.ADVANCE_NOTICE_PERIOD);
      await expect(dpos.connect(validators[0]).confirmIncreaseCommissionRate()).to.be.revertedWith(
        'Commission rate is locked'
      );
    });

    it('should confirmIncreaseCommissionRate successfully after new rate takes effect', async function () {
      await advanceBlockNumber(consts.ADVANCE_NOTICE_PERIOD);
      await expect(dpos.connect(validators[0]).confirmIncreaseCommissionRate())
        .to.emit(dpos, 'UpdateCommissionRate')
        .withArgs(validators[0].address, higherRate, LARGER_LOCK_END_TIME);
    });

    describe('after candidate is bonded and DPoS goes live', async () => {
      beforeEach(async () => {
        for (let i = 0; i < 4; i++) {
          await dpos.connect(validators[i]).delegate(validators[i].address, consts.MIN_STAKING_POOL);
          await dpos.connect(validators[i]).claimValidator();
        }
        await dpos.connect(validators[0]).contributeToMiningPool(100);
        await advanceBlockNumber(consts.DPOS_GO_LIVE_TIMEOUT);
      });

      it('should fail to claim reward when paused', async function () {
        await dpos.pause();
        const r = await getRewardRequest(validators[0].address, parseUnits('100', 'wei'), validators);
        await expect(dpos.claimReward(r.rewardBytes, r.sigs)).to.be.revertedWith('Pausable: paused');
      });

      it('should claim reward successfully', async function () {
        let r = await getRewardRequest(validators[0].address, parseUnits('40', 'wei'), validators);
        await expect(dpos.claimReward(r.rewardBytes, r.sigs))
          .to.emit(dpos, 'RewardClaimed')
          .withArgs(validators[0].address, 40, 60);

        r = await getRewardRequest(validators[0].address, parseUnits('90', 'wei'), validators);
        await expect(dpos.claimReward(r.rewardBytes, r.sigs))
          .to.emit(dpos, 'RewardClaimed')
          .withArgs(validators[0].address, 50, 10);
      });

      it('should fail to claim reward more than amount in mining pool', async function () {
        const r = await getRewardRequest(validators[0].address, parseUnits('101', 'wei'), validators);
        await expect(dpos.claimReward(r.rewardBytes, r.sigs)).to.be.revertedWith(
          'Reward pool is smaller than new reward'
        );
      });

      it('should fail to claim reward if there is no new reward', async function () {
        const r = await getRewardRequest(validators[0].address, parseUnits('0'), validators);
        await expect(dpos.claimReward(r.rewardBytes, r.sigs)).to.be.revertedWith('No new reward');
      });

      it('should fail to claim reward with insufficient signatures', async function () {
        const r = await getRewardRequest(validators[0].address, parseUnits('10', 'wei'), [
          validators[0],
          validators[1]
        ]);
        await expect(dpos.claimReward(r.rewardBytes, r.sigs)).to.be.revertedWith('Invalid validator sigs');
      });

      it('should fail to claim reward with duplicated signatures', async function () {
        const r = await getRewardRequest(validators[0].address, parseUnits('10', 'wei'), [
          validators[0],
          validators[1],
          validators[1]
        ]);
        await expect(dpos.claimReward(r.rewardBytes, r.sigs)).to.be.revertedWith('Invalid validator sigs');
      });
    });
  });
});
