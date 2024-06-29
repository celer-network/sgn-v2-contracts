import { expect } from 'chai';
import { AbiCoder, parseUnits, toNumber, Wallet, ZeroAddress } from 'ethers';
import { ethers } from 'hardhat';

import { loadFixture } from '@nomicfoundation/hardhat-toolbox/network-helpers';

import { FarmingRewards, Staking, TestERC20 } from '../typechain';
import { deployContracts, getAccounts } from './lib/common';
import * as consts from './lib/constants';
import { getFarmingRewardsRequest } from './lib/proto';

describe('FarmingRewards Tests', function () {
  async function fixture() {
    const [admin] = await ethers.getSigners();
    const { staking, farmingRewards, celr } = await deployContracts(admin);
    return { admin, staking, farmingRewards, celr };
  }

  const abiCoder = AbiCoder.defaultAbiCoder();

  let staking: Staking;
  let rewards: FarmingRewards;
  let celr: TestERC20;
  let validators: Wallet[];
  let signers: Wallet[];
  let chainId: number;

  beforeEach(async () => {
    const res = await loadFixture(fixture);
    staking = res.staking;
    rewards = res.farmingRewards;
    celr = res.celr;
    chainId = toNumber((await ethers.provider.getNetwork()).chainId);
    const accounts = await getAccounts(res.admin, [celr], 6);
    validators = [accounts[0], accounts[1], accounts[2], accounts[3]];
    signers = [accounts[0], accounts[1], accounts[4], accounts[5]];
    for (let i = 0; i < 4; i++) {
      await celr.connect(validators[i]).approve(staking.getAddress(), parseUnits('100'));
      await celr.connect(validators[i]).approve(rewards.getAddress(), parseUnits('100'));
      await staking
        .connect(validators[i])
        .initializeValidator(signers[i].address, consts.MIN_SELF_DELEGATION, consts.COMMISSION_RATE);
      await staking.connect(validators[i]).delegate(validators[i].address, consts.MIN_VALIDATOR_TOKENS);
      await staking.connect(validators[i]).bondValidator();
    }
    await rewards.connect(validators[0]).contributeToRewardPool(celr.getAddress(), 100);
  });

  it('should fail to contribute to reward pool when paused', async function () {
    await rewards.pause();
    await expect(rewards.contributeToRewardPool(celr.getAddress(), 100)).to.be.revertedWith('Pausable: paused');
  });

  it('should contribute to reward pool successfully', async function () {
    await expect(rewards.connect(validators[0]).contributeToRewardPool(celr.getAddress(), 100))
      .to.emit(rewards, 'FarmingRewardContributed')
      .withArgs(validators[0].address, celr.getAddress(), 100);
  });

  it('should update the commission rate lock successfully', async function () {
    const newRate = consts.COMMISSION_RATE + 10;
    const data = abiCoder.encode(['uint256'], [newRate]);
    await expect(staking.connect(validators[0]).updateCommissionRate(newRate))
      .to.emit(staking, 'ValidatorNotice')
      .withArgs(validators[0].address, 'commission', data, ZeroAddress);
  });

  it('should fail to claim reward when paused', async function () {
    await rewards.pause();
    const r = await getFarmingRewardsRequest(
      validators[0].address,
      [await celr.getAddress()],
      [parseUnits('100', 'wei')],
      signers,
      chainId,
      await rewards.getAddress()
    );
    await expect(rewards.claimRewards(r.rewardBytes, r.sigs, [], [])).to.be.revertedWith('Pausable: paused');
  });

  it('should claim reward successfully', async function () {
    let r = await getFarmingRewardsRequest(
      validators[0].address,
      [await celr.getAddress()],
      [parseUnits('40', 'wei')],
      signers,
      chainId,
      await rewards.getAddress()
    );
    await expect(rewards.claimRewards(r.rewardBytes, r.sigs, [], []))
      .to.emit(rewards, 'FarmingRewardClaimed')
      .withArgs(validators[0].address, await celr.getAddress(), 40);

    r = await getFarmingRewardsRequest(
      validators[0].address,
      [await celr.getAddress()],
      [parseUnits('90', 'wei')],
      signers,
      chainId,
      await rewards.getAddress()
    );
    await expect(rewards.claimRewards(r.rewardBytes, r.sigs, [], []))
      .to.emit(rewards, 'FarmingRewardClaimed')
      .withArgs(validators[0].address, await celr.getAddress(), 50);
  });

  it('should fail to claim reward more than amount in reward pool', async function () {
    const r = await getFarmingRewardsRequest(
      validators[0].address,
      [await celr.getAddress()],
      [parseUnits('101', 'wei')],
      signers,
      chainId,
      await rewards.getAddress()
    );
    await expect(rewards.claimRewards(r.rewardBytes, r.sigs, [], [])).to.be.revertedWith(
      'ERC20: transfer amount exceeds balance'
    );
  });

  it('should fail to claim reward if there is no new reward', async function () {
    const r = await getFarmingRewardsRequest(
      validators[0].address,
      [await celr.getAddress()],
      [parseUnits('0')],
      signers,
      chainId,
      await rewards.getAddress()
    );
    await expect(rewards.claimRewards(r.rewardBytes, r.sigs, [], [])).to.be.revertedWith('No new reward');
  });

  it('should fail to claim reward with insufficient signatures', async function () {
    const r = await getFarmingRewardsRequest(
      validators[0].address,
      [await celr.getAddress()],
      [parseUnits('10', 'wei')],
      [signers[0], signers[1]],
      chainId,
      await rewards.getAddress()
    );
    await expect(rewards.claimRewards(r.rewardBytes, r.sigs, [], [])).to.be.revertedWith('Quorum not reached');
  });

  it('should fail to claim reward with disordered signatures', async function () {
    const r = await getFarmingRewardsRequest(
      validators[0].address,
      [await celr.getAddress()],
      [parseUnits('10', 'wei')],
      signers,
      chainId,
      await rewards.getAddress()
    );
    await expect(
      rewards.claimRewards(r.rewardBytes, [r.sigs[0], r.sigs[2], r.sigs[1], r.sigs[3]], [], [])
    ).to.be.revertedWith('Signers not in ascending order');
    await expect(
      rewards.claimRewards(r.rewardBytes, [r.sigs[0], r.sigs[0], r.sigs[1], r.sigs[2]], [], [])
    ).to.be.revertedWith('Signers not in ascending order');
  });
});
