import { expect } from 'chai';

import { parseUnits } from '@ethersproject/units';
import { Wallet } from '@ethersproject/wallet';

import { deployContracts, getAccounts, loadFixture } from './lib/common';
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
  let delegator: Wallet;
  let validators: Wallet[];

  beforeEach(async () => {
    const res = await loadFixture(fixture);
    dpos = res.dpos;
    celr = res.celr;
    delegator = res.admin;
    validators = await getAccounts(res.admin, [celr], 4);
    await celr.approve(dpos.address, parseUnits('100'));
    for (let i = 0; i < 4; i++) {
      await celr.connect(validators[i]).approve(dpos.address, parseUnits('100'));
      await dpos.connect(validators[i]).initializeValidator(consts.MIN_SELF_DELEGATION, consts.COMMISSION_RATE);
      await dpos.connect(validators[i]).delegate(validators[i].address, consts.VALIDATOR_STAKE);
      await dpos.delegate(validators[i].address, consts.DELEGATOR_STAKE);
      await dpos.connect(validators[i]).bondValidator();
    }
  });

  it('should fail to slash when paused', async function () {
    await dpos.pause();
    const request = await getSlashRequest(
      validators[0].address,
      [],
      1,
      100000000,
      50,
      [consts.ZERO_ADDR, validators[1].address],
      [parseUnits('0.7'), parseUnits('0.8')],
      validators
    );
    await expect(dpos.slash(request.slashBytes, request.sigs)).to.be.revertedWith('Pausable: paused');
  });
});
