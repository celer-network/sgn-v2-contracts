import { expect } from 'chai';

import { parseUnits } from '@ethersproject/units';
import { Wallet } from '@ethersproject/wallet';

import { deployContracts, getAccounts, loadFixture } from './lib/common';
import { getRewardRequest } from './lib/proto';
import * as consts from './lib/constants';
import { DPoS, TestERC20 } from '../typechain';

describe('Reward Tests', function () {
  async function fixture([admin]: Wallet[]) {
    const { dpos, celr } = await deployContracts(admin);
    return { admin, dpos, celr };
  }

  let dpos: DPoS;
  let celr: TestERC20;
  let validators: Wallet[];

  beforeEach(async () => {
    const res = await loadFixture(fixture);
    dpos = res.dpos;
    celr = res.celr;
    validators = await getAccounts(res.admin, [celr], 4);
    for (let i = 0; i < 4; i++) {
      await celr.connect(validators[i]).approve(dpos.address, parseUnits('100'));
      await dpos
        .connect(validators[i])
        .initializeValidator(validators[i].address, consts.MIN_SELF_DELEGATION, consts.COMMISSION_RATE);
      await dpos.connect(validators[i]).delegate(validators[i].address, consts.MIN_VALIDATOR_TOKENS);
      await dpos.connect(validators[i]).bondValidator();
    }
    await dpos.connect(validators[0]).contributeToMiningPool(100);
  });

  it('should fail to contribute to mining poole when paused', async function () {
    await dpos.pause();
    await expect(dpos.contributeToMiningPool(100)).to.be.revertedWith('Pausable: paused');
  });

  it('should contribute to mining pool successfully', async function () {
    await expect(dpos.connect(validators[0]).contributeToMiningPool(100))
      .to.emit(dpos, 'MiningPoolContribution')
      .withArgs(validators[0].address, 100, 200);
  });

  it('should update the commission rate lock successfully', async function () {
    let newRate = consts.COMMISSION_RATE + 10;
    await expect(dpos.connect(validators[0]).updateCommissionRate(newRate))
      .to.emit(dpos, 'ValidatorParamsUpdate')
      .withArgs(validators[0].address, validators[0].address, consts.MIN_SELF_DELEGATION, newRate);
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
    await expect(dpos.claimReward(r.rewardBytes, r.sigs)).to.be.revertedWith('Reward pool is smaller than new reward');
  });

  it('should fail to claim reward if there is no new reward', async function () {
    const r = await getRewardRequest(validators[0].address, parseUnits('0'), validators);
    await expect(dpos.claimReward(r.rewardBytes, r.sigs)).to.be.revertedWith('No new reward');
  });

  it('should fail to claim reward with insufficient signatures', async function () {
    const r = await getRewardRequest(validators[0].address, parseUnits('10', 'wei'), [validators[0], validators[1]]);
    await expect(dpos.claimReward(r.rewardBytes, r.sigs)).to.be.revertedWith('Quorum not reached');
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
