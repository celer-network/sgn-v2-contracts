import { expect } from 'chai';
import { ethers } from 'hardhat';

import { parseUnits } from '@ethersproject/units';
import { Wallet } from '@ethersproject/wallet';

import { deployContracts, getAccounts, advanceBlockNumber, loadFixture } from './lib/common';
import { getRewardRequestBytes } from './lib/proto';
import * as consts from './lib/constants';
import { DPoS, SGN, TestERC20 } from '../typechain';

describe('Reward Tests', function () {
  async function fixture([admin]: Wallet[]) {
    const { dpos, sgn, celr } = await deployContracts(admin);
    return { admin, dpos, sgn, celr };
  }

  let dpos: DPoS;
  let sgn: SGN;
  let celr: TestERC20;
  let candidate: Wallet;
  let subscriber: Wallet;
  let receiver: Wallet;

  const LARGER_LOCK_END_TIME = 100000;

  beforeEach(async () => {
    const res = await loadFixture(fixture);
    dpos = res.dpos;
    sgn = res.sgn;
    celr = res.celr;
    const accounts = await getAccounts(res.admin, [celr], 3);
    for (let i = 0; i < 3; i++) {
      await celr.connect(accounts[i]).approve(dpos.address, parseUnits('100'));
    }
    candidate = accounts[0];
    subscriber = accounts[1];
    receiver = accounts[2];

    await dpos.registerSidechain(sgn.address);
    await dpos
      .connect(candidate)
      .initializeCandidate(consts.MIN_SELF_STAKE, consts.COMMISSION_RATE, consts.RATE_LOCK_END_TIME);
  });

  it('should fail to initialize a candidate when paused', async function () {
    await dpos.pause();
    await expect(dpos.contributeToMiningPool(100)).to.be.revertedWith('Pausable: paused');
  });

  it('should contribute to mining pool successfully', async function () {
    await expect(dpos.connect(candidate).contributeToMiningPool(100))
      .to.emit(dpos, 'MiningPoolContribution')
      .withArgs(candidate.address, 100, 100);
  });

  it('should increase the commission rate lock end time successfully', async function () {
    await expect(dpos.connect(candidate).nonIncreaseCommissionRate(consts.COMMISSION_RATE, LARGER_LOCK_END_TIME))
      .to.emit(dpos, 'UpdateCommissionRate')
      .withArgs(candidate.address, consts.COMMISSION_RATE, LARGER_LOCK_END_TIME);
  });

  it('should fail to update the commission rate lock end time to an outdated block number', async function () {
    await expect(dpos.connect(candidate).nonIncreaseCommissionRate(consts.COMMISSION_RATE, 1)).to.be.revertedWith(
      'Outdated new lock end time'
    );
  });

  it('should fail to update the commission rate lock end time to an outdated block number', async function () {
    await dpos.connect(candidate).nonIncreaseCommissionRate(consts.COMMISSION_RATE, LARGER_LOCK_END_TIME);
    const blockNumber = await ethers.provider.getBlockNumber();
    await expect(
      dpos.connect(candidate).nonIncreaseCommissionRate(consts.COMMISSION_RATE, blockNumber + 10)
    ).to.be.revertedWith('Invalid new lock end time');
  });

  it('should decrease the commission rate successfully at anytime', async function () {
    let lowerRate = consts.COMMISSION_RATE - 10;
    await expect(dpos.connect(candidate).nonIncreaseCommissionRate(lowerRate, LARGER_LOCK_END_TIME))
      .to.emit(dpos, 'UpdateCommissionRate')
      .withArgs(candidate.address, lowerRate, LARGER_LOCK_END_TIME);

    lowerRate = consts.COMMISSION_RATE - 20;
    await expect(dpos.connect(candidate).nonIncreaseCommissionRate(lowerRate, LARGER_LOCK_END_TIME))
      .to.emit(dpos, 'UpdateCommissionRate')
      .withArgs(candidate.address, lowerRate, LARGER_LOCK_END_TIME);
  });

  it('should announce increase commission rate successfully', async function () {
    const higherRate = consts.COMMISSION_RATE + 10;
    await expect(dpos.connect(candidate).announceIncreaseCommissionRate(higherRate, LARGER_LOCK_END_TIME))
      .to.emit(dpos, 'CommissionRateAnnouncement')
      .withArgs(candidate.address, higherRate, LARGER_LOCK_END_TIME);
  });

  describe('after announceIncreaseCommissionRate', async () => {
    const higherRate = consts.COMMISSION_RATE + 10;
    beforeEach(async () => {
      await dpos.connect(candidate).announceIncreaseCommissionRate(higherRate, LARGER_LOCK_END_TIME);
    });

    it('should fail to confirmIncreaseCommissionRate before new rate can take effect', async function () {
      await expect(dpos.connect(candidate).confirmIncreaseCommissionRate()).to.be.revertedWith(
        'Still in notice period'
      );
    });

    it('should fail to confirmIncreaseCommissionRate after new rate can take effect but before lock end time', async function () {
      await dpos.connect(candidate).nonIncreaseCommissionRate(consts.COMMISSION_RATE, LARGER_LOCK_END_TIME);

      // need to announceIncreaseCommissionRate again because _updateCommissionRate
      // will remove the previous announcement of increasing commission rate
      await dpos.connect(candidate).announceIncreaseCommissionRate(higherRate, LARGER_LOCK_END_TIME);
      await advanceBlockNumber(consts.ADVANCE_NOTICE_PERIOD);
      await expect(dpos.connect(candidate).confirmIncreaseCommissionRate()).to.be.revertedWith(
        'Commission rate is locked'
      );
    });

    it('should confirmIncreaseCommissionRate successfully after new rate takes effect', async function () {
      await advanceBlockNumber(consts.ADVANCE_NOTICE_PERIOD);
      await expect(dpos.connect(candidate).confirmIncreaseCommissionRate())
        .to.emit(dpos, 'UpdateCommissionRate')
        .withArgs(candidate.address, higherRate, LARGER_LOCK_END_TIME);
    });

    describe('after candidate is bonded and DPoS goes live', async () => {
      beforeEach(async () => {
        await dpos.connect(candidate).delegate(candidate.address, consts.MIN_STAKING_POOL);
        await dpos.connect(candidate).claimValidator();
        await advanceBlockNumber(consts.DPOS_GO_LIVE_TIMEOUT);

        // submit subscription fees
        await celr.connect(subscriber).approve(sgn.address, consts.SUB_FEE);
        await sgn.connect(subscriber).subscribe(consts.SUB_FEE);
      });

      it('should fail to redeem reward when paused', async function () {
        await sgn.pause();
        const rewardRequest = await getRewardRequestBytes(receiver.address, parseUnits('100', 'wei'), parseUnits('0'), [
          candidate
        ]);
        await expect(sgn.redeemReward(rewardRequest)).to.be.revertedWith('Pausable: paused');
      });

      it('should redeem reward successfully', async function () {
        await dpos.connect(candidate).contributeToMiningPool(100);

        const miningReward = parseUnits('40', 'wei');
        const serviceReward = parseUnits('60', 'wei');
        const rewardRequest = await getRewardRequestBytes(receiver.address, miningReward, serviceReward, [candidate]);
        await expect(sgn.redeemReward(rewardRequest))
          .to.emit(sgn, 'RedeemReward')
          .withArgs(receiver.address, miningReward, serviceReward, consts.SUB_FEE.sub(serviceReward));
      });

      it('should fail to redeem reward more than amount in mining pool', async function () {
        await dpos.connect(candidate).contributeToMiningPool(100);
        const rewardRequest = await getRewardRequestBytes(receiver.address, parseUnits('101', 'wei'), parseUnits('0'), [
          candidate
        ]);
        await expect(sgn.redeemReward(rewardRequest)).to.be.revertedWith('Mining pool is smaller than new reward');
      });

      it('should fail to redeem reward more than amount in service pool', async function () {
        const rewardRequest = await getRewardRequestBytes(receiver.address, parseUnits('0'), parseUnits('1'), [
          candidate
        ]);
        await expect(sgn.redeemReward(rewardRequest)).to.be.revertedWith(
          'Service pool is smaller than new service reward'
        );
      });
    });
  });
});
