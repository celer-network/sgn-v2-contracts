import { expect } from 'chai';
import { parseUnits, toNumber, Wallet, ZeroAddress } from 'ethers';
import { ethers } from 'hardhat';

import { HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers';
import { loadFixture } from '@nomicfoundation/hardhat-toolbox/network-helpers';

import { Staking, StakingReward, TestERC20 } from '../typechain';
import { advanceBlockNumber, deployContracts, getAccounts } from './lib/common';
import * as consts from './lib/constants';
import { getSlashRequest } from './lib/proto';

describe('Slash Tests', function () {
  async function fixture() {
    const [admin] = await ethers.getSigners();
    const { staking, stakingReward, celr } = await deployContracts(admin);
    return { admin, staking, stakingReward, celr };
  }

  let staking: Staking;
  let reward: StakingReward;
  let celr: TestERC20;
  let admin: HardhatEthersSigner;
  let validators: Wallet[];
  let signers: Wallet[];
  let expireTime: number;
  let chainId: number;

  beforeEach(async () => {
    const res = await loadFixture(fixture);
    staking = res.staking;
    reward = res.stakingReward;
    celr = res.celr;
    admin = res.admin;
    const accounts = await getAccounts(res.admin, [celr], 7);
    validators = [accounts[0], accounts[1], accounts[2], accounts[3]];
    signers = [accounts[0], accounts[4], accounts[5], accounts[6]];
    await staking.setRewardContract(reward.getAddress());
    await celr.approve(staking.getAddress(), parseUnits('100'));
    for (let i = 0; i < 4; i++) {
      await celr.connect(validators[i]).approve(staking.getAddress(), parseUnits('100'));
      await staking
        .connect(validators[i])
        .initializeValidator(signers[i].address, consts.MIN_SELF_DELEGATION, consts.COMMISSION_RATE);
      await staking.delegate(validators[i].address, consts.DELEGATOR_STAKE);
      await staking.connect(validators[i]).bondValidator();
      const blockNumber = await ethers.provider.getBlockNumber();
      const blockTime = (await ethers.provider.getBlock(blockNumber))!.timestamp;
      expireTime = blockTime + 100;
      chainId = toNumber((await ethers.provider.getNetwork()).chainId);
    }
  });

  it('should slash successfully (only once using the same nonce)', async function () {
    const adminBalanceBefore = await celr.balanceOf(admin.address);
    const val1BalanceBefore = await celr.balanceOf(validators[1].address);
    const rewardPoolBefore = await celr.balanceOf(reward.getAddress());

    const request = await getSlashRequest(
      validators[0].address,
      1,
      consts.SLASH_FACTOR,
      expireTime,
      0,
      [validators[1].address, ZeroAddress],
      [parseUnits('0.1'), parseUnits('0.01')],
      signers,
      chainId,
      await staking.getAddress()
    );
    await expect(staking.slash(request.slashBytes, request.sigs))
      .to.emit(staking, 'DelegationUpdate')
      .withArgs(validators[0].address, ZeroAddress, parseUnits('7.6'), 0, parseUnits('-0.4'))
      .to.emit(staking, 'Slash')
      .withArgs(validators[0].address, 1, parseUnits('0.4'))
      .to.emit(staking, 'SlashAmtCollected')
      .withArgs(admin.address, parseUnits('0.01'))
      .to.emit(staking, 'SlashAmtCollected')
      .withArgs(validators[1].address, parseUnits('0.1'));

    await staking.collectForfeiture();
    const adminBalanceAfter = await celr.balanceOf(admin.address);
    const val1BalanceAfter = await celr.balanceOf(validators[1].address);
    const rewardPoolAfter = await celr.balanceOf(reward.getAddress());
    expect(adminBalanceAfter - parseUnits('0.01')).to.equal(adminBalanceBefore);
    expect(val1BalanceAfter - parseUnits('0.1')).to.equal(val1BalanceBefore);
    expect(rewardPoolAfter - parseUnits('0.29')).to.equal(rewardPoolBefore);

    await expect(staking.slash(request.slashBytes, request.sigs)).to.be.revertedWith('Used slash nonce');
  });

  it('should slash successfully with undelegations and redelegations', async function () {
    await staking.undelegateShares(validators[0].address, parseUnits('1'));
    await staking.undelegateTokens(validators[0].address, parseUnits('2'));
    await staking.connect(validators[0]).undelegateShares(validators[0].address, parseUnits('1'));

    const request = await getSlashRequest(
      validators[0].address,
      1,
      consts.SLASH_FACTOR,
      expireTime,
      0,
      [],
      [],
      signers,
      chainId,
      await staking.getAddress()
    );
    await expect(staking.slash(request.slashBytes, request.sigs))
      .to.emit(staking, 'DelegationUpdate')
      .withArgs(validators[0].address, ZeroAddress, parseUnits('3.8'), 0, parseUnits('-0.2'))
      .to.emit(staking, 'Slash')
      .withArgs(validators[0].address, 1, parseUnits('0.4'));

    // check and complete pending undelegations
    let dinfo = await staking.getDelegatorInfo(validators[0].address, admin.address);
    expect(dinfo.tokens).to.equal(parseUnits('2.85'));
    expect(dinfo.shares).to.equal(parseUnits('3'));
    expect(dinfo.undelegations[0].shares).to.equal(parseUnits('1'));
    expect(dinfo.undelegations[1].shares).to.equal(parseUnits('2'));
    await advanceBlockNumber(consts.UNBONDING_PERIOD);
    await expect(staking.completeUndelegate(validators[0].address))
      .to.emit(staking, 'Undelegated')
      .withArgs(validators[0].address, admin.address, parseUnits('2.85'));

    // do additional undelegation
    await expect(staking.undelegateShares(validators[0].address, parseUnits('1')))
      .to.emit(staking, 'DelegationUpdate')
      .withArgs(validators[0].address, admin.address, parseUnits('2.85'), parseUnits('2'), parseUnits('-0.95'));
    await advanceBlockNumber(consts.UNBONDING_PERIOD);
    await expect(staking.completeUndelegate(validators[0].address))
      .to.emit(staking, 'Undelegated')
      .withArgs(validators[0].address, admin.address, parseUnits('0.95'));

    // redelegate
    await expect(staking.delegate(validators[0].address, parseUnits('1')))
      .to.emit(staking, 'DelegationUpdate')
      .withArgs(
        validators[0].address,
        admin.address,
        parseUnits('3.85'),
        parseUnits('3052631578947368421', 'wei'),
        parseUnits('1')
      );

    await expect(staking.undelegateShares(validators[0].address, parseUnits('1052631578947368419', 'wei')))
      .to.emit(staking, 'DelegationUpdate')
      .withArgs(
        validators[0].address,
        admin.address,
        parseUnits('2850000000000000002', 'wei'),
        parseUnits('2000000000000000002', 'wei'),
        parseUnits('-999999999999999998', 'wei')
      );

    await expect(staking.undelegateTokens(validators[0].address, parseUnits('1'))).to.be.revertedWith(
      'not enough remaining shares'
    );

    await expect(staking.undelegateTokens(validators[0].address, parseUnits('1900000000000000001', 'wei')))
      .to.emit(staking, 'DelegationUpdate')
      .withArgs(
        validators[0].address,
        admin.address,
        parseUnits('950000000000000001', 'wei'),
        0,
        parseUnits('-1900000000000000001', 'wei')
      );

    dinfo = await staking.getDelegatorInfo(validators[0].address, admin.address);
    expect(dinfo.tokens).to.equal(0);
    expect(dinfo.shares).to.equal(0);
  });

  it('should unbond validator due to slash', async function () {
    const request = await getSlashRequest(
      validators[0].address,
      1,
      1e5,
      expireTime,
      0,
      [],
      [],
      signers,
      chainId,
      await staking.getAddress()
    );
    await expect(staking.slash(request.slashBytes, request.sigs))
      .to.emit(staking, 'DelegationUpdate')
      .withArgs(validators[0].address, ZeroAddress, parseUnits('7.2'), 0, parseUnits('-0.8'))
      .to.emit(staking, 'Slash')
      .withArgs(validators[0].address, 1, parseUnits('0.8'))
      .to.emit(staking, 'ValidatorStatusUpdate')
      .withArgs(validators[0].address, consts.STATUS_UNBONDING);
  });

  it('should unbond validator due to slash with jail period', async function () {
    const request = await getSlashRequest(
      validators[0].address,
      1,
      0,
      expireTime,
      10,
      [],
      [],
      signers,
      chainId,
      await staking.getAddress()
    );
    await expect(staking.slash(request.slashBytes, request.sigs))
      .to.emit(staking, 'ValidatorStatusUpdate')
      .withArgs(validators[0].address, consts.STATUS_UNBONDING)
      .to.emit(staking, 'DelegationUpdate')
      .withArgs(validators[0].address, ZeroAddress, parseUnits('8'), 0, 0)
      .to.emit(staking, 'Slash')
      .withArgs(validators[0].address, 1, 0);

    await expect(staking.connect(validators[0]).bondValidator()).to.be.revertedWith('Bond block not reached');
    await advanceBlockNumber(10);
    await expect(staking.connect(validators[0]).bondValidator())
      .to.emit(staking, 'ValidatorStatusUpdate')
      .withArgs(validators[0].address, consts.STATUS_BONDED);
  });

  it('should fail to slash with invalid requests', async function () {
    let request = await getSlashRequest(
      validators[0].address,
      1,
      consts.SLASH_FACTOR,
      expireTime,
      0,
      [],
      [],
      [signers[1], signers[2]],
      chainId,
      await staking.getAddress()
    );
    await expect(staking.slash(request.slashBytes, request.sigs)).to.be.revertedWith('Quorum not reached');

    request = await getSlashRequest(
      validators[0].address,
      1,
      consts.SLASH_FACTOR,
      0,
      0,
      [],
      [],
      signers,
      chainId,
      await staking.getAddress()
    );
    await expect(staking.slash(request.slashBytes, request.sigs)).to.be.revertedWith('Slash expired');
  });

  it('should fail to slash when paused or slash disabled', async function () {
    await staking.pause();
    const request = await getSlashRequest(
      validators[0].address,
      1,
      consts.SLASH_FACTOR,
      expireTime,
      0,
      [],
      [],
      signers,
      chainId,
      await staking.getAddress()
    );
    await expect(staking.slash(request.slashBytes, request.sigs)).to.be.revertedWith('Pausable: paused');
    await staking.unpause();

    await staking.setMaxSlashFactor(0);
    await expect(staking.slash(request.slashBytes, request.sigs)).to.be.revertedWith('Exceed max slash factor');
  });
});
