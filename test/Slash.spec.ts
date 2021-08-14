import { expect } from 'chai';

import { parseUnits } from '@ethersproject/units';
import { Wallet } from '@ethersproject/wallet';

import { deployContracts, getAccounts, advanceBlockNumber, loadFixture } from './lib/common';
import { getPenaltyRequest } from './lib/proto';
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
      await dpos
        .connect(validators[i])
        .initializeCandidate(consts.MIN_SELF_STAKE, consts.COMMISSION_RATE, consts.RATE_LOCK_END_TIME);
      await dpos.connect(validators[i]).delegate(validators[i].address, consts.CANDIDATE_STAKE);
      await dpos.delegate(validators[i].address, consts.DELEGATOR_STAKE);
      await dpos.connect(validators[i]).claimValidator();
    }
    await advanceBlockNumber(consts.DPOS_GO_LIVE_TIMEOUT);
  });

  it('should fail to slash when paused', async function () {
    await dpos.pause();
    const request = await getPenaltyRequest(
      1,
      1000000,
      validators[0].address,
      [validators[0].address, delegator.address],
      [parseUnits('0.5'), parseUnits('1')],
      [consts.ZERO_ADDR, validators[1].address],
      [parseUnits('0.7'), parseUnits('0.8')],
      validators
    );
    await expect(dpos.slash(request.penaltyBytes, request.sigs)).to.be.revertedWith('Pausable: paused');
  });
});
