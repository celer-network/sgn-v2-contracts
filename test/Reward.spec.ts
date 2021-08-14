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
      await dpos.connect(validators[i]).initializeCandidate(consts.MIN_SELF_STAKE, consts.COMMISSION_RATE);
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

  it('should update the commission rate lock successfully', async function () {
    let newRate = consts.COMMISSION_RATE + 10;
    await expect(dpos.connect(validators[0]).updateCommissionRate(newRate))
      .to.emit(dpos, 'UpdateCommissionRate')
      .withArgs(validators[0].address, newRate);
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
      const r = await getRewardRequest(validators[0].address, parseUnits('10', 'wei'), [validators[0], validators[1]]);
      await expect(dpos.claimReward(r.rewardBytes, r.sigs)).to.be.revertedWith('Not enough signatures');
    });

    it('should fail to claim reward with disordered signatures', async function () {
      const r = await getRewardRequest(validators[0].address, parseUnits('10', 'wei'), validators);
      await expect(dpos.claimReward(r.rewardBytes, [r.sigs[0], r.sigs[1], r.sigs[3], r.sigs[2]])).to.be.revertedWith(
        'Signers not in ascending order'
      );
      await expect(dpos.claimReward(r.rewardBytes, [r.sigs[0], r.sigs[0], r.sigs[1], r.sigs[2]])).to.be.revertedWith(
        'Signers not in ascending order'
      );
    });
  });
});
