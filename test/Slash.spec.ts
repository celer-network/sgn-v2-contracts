import { expect } from 'chai';
import { ethers } from 'hardhat';

import { parseUnits } from '@ethersproject/units';
import { Wallet } from '@ethersproject/wallet';

import { deployContracts, getAccounts, advanceBlockNumber, loadFixture } from './lib/common';
import { getSlashRequest } from './lib/proto';
import * as consts from './lib/constants';
import { DPoS, TestERC20 } from '../typechain';

describe('Slash Tests', function () {
  async function fixture([admin]: Wallet[]) {
    const { dpos, celr } = await deployContracts(admin);
    return { admin, dpos, celr };
  }

  let dpos: DPoS;
  let celr: TestERC20;
  let admin: Wallet;
  let validators: Wallet[];
  let expireBlock: number;

  beforeEach(async () => {
    const res = await loadFixture(fixture);
    dpos = res.dpos;
    celr = res.celr;
    admin = res.admin;
    validators = await getAccounts(res.admin, [celr], 4);
    await celr.approve(dpos.address, parseUnits('100'));
    for (let i = 0; i < 4; i++) {
      await celr.connect(validators[i]).approve(dpos.address, parseUnits('100'));
      await dpos.connect(validators[i]).initializeValidator(consts.MIN_SELF_DELEGATION, consts.COMMISSION_RATE);
      await dpos.connect(validators[i]).delegate(validators[i].address, parseUnits('2.1'));
      await dpos.delegate(validators[i].address, consts.DELEGATOR_STAKE);
      await dpos.connect(validators[i]).bondValidator();
      const blockNumber = await ethers.provider.getBlockNumber();
      expireBlock = blockNumber + 10;
    }
  });

  it('should slash successfully (only once using the same nonce)', async function () {
    const adminBalanceBefore = await celr.balanceOf(admin.address);
    const val1BalanceBefore = await celr.balanceOf(validators[1].address);
    const rewardPoolBefore = await dpos.rewardPool();

    const request = await getSlashRequest(
      validators[0].address,
      1,
      consts.SLASH_FACTOR,
      expireBlock,
      false,
      [validators[1].address, consts.ZERO_ADDR],
      [parseUnits('0.1'), parseUnits('0.005')],
      validators
    );
    await expect(dpos.slash(request.slashBytes, request.sigs))
      .to.emit(dpos, 'DelegationUpdate')
      .withArgs(validators[0].address, consts.ZERO_ADDR, parseUnits('7.695'), 0, parseUnits('-0.405'))
      .to.emit(dpos, 'Slash')
      .withArgs(validators[0].address, 1, parseUnits('0.405'))
      .to.emit(dpos, 'SlashAmtCollected')
      .withArgs(admin.address, parseUnits('0.005'))
      .to.emit(dpos, 'SlashAmtCollected')
      .withArgs(validators[1].address, parseUnits('0.1'));

    const adminBalanceAfter = await celr.balanceOf(admin.address);
    const val1BalanceAfter = await celr.balanceOf(validators[1].address);
    const rewardPoolAfter = await dpos.rewardPool();
    expect(adminBalanceAfter.sub(parseUnits('0.005'))).to.equal(adminBalanceBefore);
    expect(val1BalanceAfter.sub(parseUnits('0.1'))).to.equal(val1BalanceBefore);
    expect(rewardPoolAfter.sub(parseUnits('0.3'))).to.equal(rewardPoolBefore);

    await expect(dpos.slash(request.slashBytes, request.sigs)).to.be.revertedWith('Used slash nonce');
  });

  it('should slash successfully with undelegations and redelegations', async function () {
    await dpos.undelegate(validators[0].address, parseUnits('1'));
    await dpos.undelegate(validators[0].address, parseUnits('2'));
    await dpos.connect(validators[0]).undelegate(validators[0].address, parseUnits('1'));

    const request = await getSlashRequest(
      validators[0].address,
      1,
      consts.SLASH_FACTOR,
      expireBlock,
      false,
      [],
      [],
      validators
    );
    await expect(dpos.slash(request.slashBytes, request.sigs))
      .to.emit(dpos, 'DelegationUpdate')
      .withArgs(validators[0].address, consts.ZERO_ADDR, parseUnits('3.895'), 0, parseUnits('-0.205'))
      .to.emit(dpos, 'Slash')
      .withArgs(validators[0].address, 1, parseUnits('0.405'));

    // check and complete pending undelegations
    const res = await dpos.getDelegatorInfo(validators[0].address, admin.address);
    expect(res.shares).to.equal(parseUnits('3'));
    expect(res.undelegations[0].shares).to.equal(parseUnits('1'));
    expect(res.undelegations[1].shares).to.equal(parseUnits('2'));
    await advanceBlockNumber(consts.SLASH_TIMEOUT);
    await expect(dpos.completeUndelegate(validators[0].address))
      .to.emit(dpos, 'Undelegated')
      .withArgs(validators[0].address, admin.address, parseUnits('2.85'));

    // do additional undelegation
    await expect(dpos.undelegate(validators[0].address, parseUnits('1')))
      .to.emit(dpos, 'DelegationUpdate')
      .withArgs(validators[0].address, admin.address, parseUnits('2.945'), parseUnits('2'), parseUnits('-0.95'));

    // redelegate
    await expect(dpos.delegate(validators[0].address, parseUnits('1')))
      .to.emit(dpos, 'DelegationUpdate')
      .withArgs(
        validators[0].address,
        admin.address,
        parseUnits('3.945'),
        parseUnits('3052631578947368421', 'wei'),
        parseUnits('1')
      );
    // re-undelegate. TODO: see if we can remove the rounding diff
    await expect(dpos.undelegate(validators[0].address, parseUnits('1052631578947368421', 'wei')))
      .to.emit(dpos, 'DelegationUpdate')
      .withArgs(
        validators[0].address,
        admin.address,
        parseUnits('2945000000000000001', 'wei'),
        parseUnits('2'),
        parseUnits('-999999999999999999', 'wei')
      );
  });

  it('should unbond validator due to slash', async function () {
    const request = await getSlashRequest(validators[0].address, 1, 100000000, expireBlock, false, [], [], validators);
    await expect(dpos.slash(request.slashBytes, request.sigs))
      .to.emit(dpos, 'DelegationUpdate')
      .withArgs(validators[0].address, consts.ZERO_ADDR, parseUnits('7.29'), 0, parseUnits('-0.81'))
      .to.emit(dpos, 'Slash')
      .withArgs(validators[0].address, 1, parseUnits('0.81'))
      .to.emit(dpos, 'ValidatorStatusUpdate')
      .withArgs(validators[0].address, consts.STATUS_UNBONDING);
  });

  it('should fail to slash with invalid requests', async function () {
    let request = await getSlashRequest(
      validators[0].address,
      1,
      consts.SLASH_FACTOR,
      expireBlock,
      false,
      [],
      [],
      [validators[1], validators[2]]
    );
    await expect(dpos.slash(request.slashBytes, request.sigs)).to.be.revertedWith('Quorum not reached');

    request = await getSlashRequest(
      validators[0].address,
      1,
      consts.SLASH_FACTOR,
      expireBlock,
      false,
      [consts.ZERO_ADDR],
      [parseUnits('1')],
      validators
    );
    await expect(dpos.slash(request.slashBytes, request.sigs)).to.be.revertedWith('Invalid collectors');

    request = await getSlashRequest(
      validators[0].address,
      1,
      consts.SLASH_FACTOR,
      expireBlock,
      false,
      [],
      [],
      validators
    );
    await advanceBlockNumber(10);
    await expect(dpos.slash(request.slashBytes, request.sigs)).to.be.revertedWith('Slash expired');
  });

  it('should fail to slash when paused or slash disabled', async function () {
    await dpos.pause();
    const request = await getSlashRequest(
      validators[0].address,
      1,
      consts.SLASH_FACTOR,
      expireBlock,
      false,
      [],
      [],
      validators
    );
    await expect(dpos.slash(request.slashBytes, request.sigs)).to.be.revertedWith('Pausable: paused');

    await dpos.unpause();
    await dpos.disableSlash();
    await expect(dpos.slash(request.slashBytes, request.sigs)).to.be.revertedWith('Slash is disabled');
  });
});
