import { expect } from 'chai';

import { parseUnits } from '@ethersproject/units';
import { Wallet } from '@ethersproject/wallet';

import { deployContracts, getAccounts, loadFixture } from './lib/common';
import { getRewardRequest } from './lib/proto';
import * as consts from './lib/constants';
import { Staking, TestERC20 } from '../typechain';

describe('Reward Tests', function () {
  async function fixture([admin]: Wallet[]) {
    const { staking, celr } = await deployContracts(admin);
    return { admin, staking, celr };
  }

  let staking: Staking;
  let celr: TestERC20;
  let validators: Wallet[];
  let signers: Wallet[];

  beforeEach(async () => {
    const res = await loadFixture(fixture);
    staking = res.staking;
    celr = res.celr;
    const accounts = await getAccounts(res.admin, [celr], 6);
    validators = [accounts[0], accounts[1], accounts[2], accounts[3]];
    signers = [accounts[0], accounts[1], accounts[4], accounts[5]];
    for (let i = 0; i < 4; i++) {
      await celr.connect(validators[i]).approve(staking.address, parseUnits('100'));
      await staking
        .connect(validators[i])
        .initializeValidator(signers[i].address, consts.MIN_SELF_DELEGATION, consts.COMMISSION_RATE);
      await staking.connect(validators[i]).delegate(validators[i].address, consts.MIN_VALIDATOR_TOKENS);
      await staking.connect(validators[i]).bondValidator();
    }
    await staking.connect(validators[0]).contributeToRewardPool(100);
  });

  it('should fail to contribute to reward pool when paused', async function () {
    await staking.pause();
    await expect(staking.contributeToRewardPool(100)).to.be.revertedWith('Pausable: paused');
  });

  it('should contribute to reward pool successfully', async function () {
    await expect(staking.connect(validators[0]).contributeToRewardPool(100))
      .to.emit(staking, 'RewardPoolContribution')
      .withArgs(validators[0].address, 100, 200);
  });

  it('should update the commission rate lock successfully', async function () {
    let newRate = consts.COMMISSION_RATE + 10;
    await expect(staking.connect(validators[0]).updateCommissionRate(newRate))
      .to.emit(staking, 'ValidatorParamsUpdate')
      .withArgs(validators[0].address, validators[0].address, consts.MIN_SELF_DELEGATION, newRate);
  });

  it('should fail to claim reward when paused', async function () {
    await staking.pause();
    const r = await getRewardRequest(validators[0].address, parseUnits('100', 'wei'), signers);
    await expect(staking.claimReward(r.rewardBytes, r.sigs)).to.be.revertedWith('Pausable: paused');
  });

  it('should claim reward successfully', async function () {
    let r = await getRewardRequest(validators[0].address, parseUnits('40', 'wei'), signers);
    await expect(staking.claimReward(r.rewardBytes, r.sigs))
      .to.emit(staking, 'RewardClaimed')
      .withArgs(validators[0].address, 40, 60);

    r = await getRewardRequest(validators[0].address, parseUnits('90', 'wei'), signers);
    await expect(staking.claimReward(r.rewardBytes, r.sigs))
      .to.emit(staking, 'RewardClaimed')
      .withArgs(validators[0].address, 50, 10);
  });

  it('should fail to claim reward more than amount in reward pool', async function () {
    const r = await getRewardRequest(validators[0].address, parseUnits('101', 'wei'), signers);
    await expect(staking.claimReward(r.rewardBytes, r.sigs)).to.be.revertedWith(
      'Reward pool is smaller than new reward'
    );
  });

  it('should fail to claim reward if there is no new reward', async function () {
    const r = await getRewardRequest(validators[0].address, parseUnits('0'), signers);
    await expect(staking.claimReward(r.rewardBytes, r.sigs)).to.be.revertedWith('No new reward');
  });

  it('should fail to claim reward with insufficient signatures', async function () {
    const r = await getRewardRequest(validators[0].address, parseUnits('10', 'wei'), [signers[0], signers[1]]);
    await expect(staking.claimReward(r.rewardBytes, r.sigs)).to.be.revertedWith('Quorum not reached');
  });

  it('should fail to claim reward with disordered signatures', async function () {
    const r = await getRewardRequest(validators[0].address, parseUnits('10', 'wei'), signers);
    await expect(staking.claimReward(r.rewardBytes, [r.sigs[0], r.sigs[1], r.sigs[3], r.sigs[2]])).to.be.revertedWith(
      'Signers not in ascending order'
    );
    await expect(staking.claimReward(r.rewardBytes, [r.sigs[0], r.sigs[0], r.sigs[1], r.sigs[2]])).to.be.revertedWith(
      'Signers not in ascending order'
    );
  });
});
