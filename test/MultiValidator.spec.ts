import { expect } from 'chai';

import { parseUnits } from '@ethersproject/units';
import { Wallet } from '@ethersproject/wallet';

import { deployContracts, getAccounts, advanceBlockNumber, loadFixture } from './lib/common';
import * as consts from './lib/constants';
import { DPoS, TestERC20 } from '../typechain';

describe('Multiple validators Tests', function () {
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
    validators = await getAccounts(res.admin, [celr], 8);
    await celr.approve(dpos.address, parseUnits('100'));
    const stakes = [
      parseUnits('6'),
      parseUnits('2'),
      parseUnits('10'),
      parseUnits('5'),
      parseUnits('7'),
      parseUnits('3'),
      parseUnits('9')
    ];
    for (let i = 0; i < 8; i++) {
      await celr.connect(validators[i]).approve(dpos.address, parseUnits('100'));
      await dpos.connect(validators[i]).initializeValidatorCandidate(consts.MIN_SELF_STAKE, consts.COMMISSION_RATE);
      if (i < 7) {
        await dpos.connect(validators[i]).delegate(validators[i].address, consts.VALIDATOR_STAKE);
        await dpos.delegate(validators[i].address, stakes[i]);
        await dpos.connect(validators[i]).bondValidator();
      }
    }
  });

  it('should getQuorumStake successfully', async function () {
    const quorum = await dpos.getQuorumStake();
    expect(quorum).to.equal(parseUnits('42').add(1));
  });

  it('should fail to bondValidator before delegating enough stake', async function () {
    await dpos.connect(validators[7]).delegate(validators[7].address, consts.MIN_STAKING_POOL);
    await expect(dpos.connect(validators[7]).bondValidator()).to.be.revertedWith('Not larger than smallest pool');
  });

  it('should replace a current validator by calling bondValidator with enough stake', async function () {
    await dpos.connect(validators[7]).delegate(validators[7].address, parseUnits('10'));
    await expect(dpos.connect(validators[7]).bondValidator())
      .to.emit(dpos, 'ValidatorStatusUpdate')
      .withArgs(validators[1].address, consts.STATUS_UNBONDING)
      .to.emit(dpos, 'ValidatorStatusUpdate')
      .withArgs(validators[7].address, consts.STATUS_BONDED);

    const quorum = await dpos.getQuorumStake();
    expect(quorum).to.equal(parseUnits('68').mul(2).div(3).add(1));
  });

  it('should remove validator due to withdrawal and add new validator successfully', async function () {
    await expect(dpos.connect(validators[1]).undelegate(validators[1].address, parseUnits('2')))
      .to.emit(dpos, 'ValidatorStatusUpdate')
      .withArgs(validators[1].address, consts.STATUS_UNBONDING);
    let quorum = await dpos.getQuorumStake();
    expect(quorum).to.equal(parseUnits('58').mul(2).div(3).add(1));

    await dpos.connect(validators[7]).delegate(validators[7].address, parseUnits('10'));
    await expect(dpos.connect(validators[7]).bondValidator())
      .to.emit(dpos, 'ValidatorStatusUpdate')
      .withArgs(validators[7].address, consts.STATUS_BONDED);
    quorum = await dpos.getQuorumStake();
    expect(quorum).to.equal(parseUnits('68').mul(2).div(3).add(1));
  });

  describe('after one validator is replaced', async () => {
    beforeEach(async () => {
      await dpos.connect(validators[7]).delegate(validators[7].address, parseUnits('10'));
      await dpos.connect(validators[7]).bondValidator();
    });

    it('should confirmUnbondedValidator only after unbondTime', async function () {
      const res = await dpos.validators(validators[1].address);
      expect(res.status).to.equal(consts.STATUS_UNBONDING);

      await expect(dpos.confirmUnbondedValidator(validators[1].address)).to.be.revertedWith('Unbond time not reached');

      await advanceBlockNumber(consts.SLASH_TIMEOUT);
      await expect(dpos.confirmUnbondedValidator(validators[1].address))
        .to.emit(dpos, 'ValidatorStatusUpdate')
        .withArgs(validators[1].address, consts.STATUS_UNBONDED);
    });

    it('should replace current min stake validator with the unbonding validator', async function () {
      await dpos.connect(validators[1]).delegate(validators[1].address, parseUnits('5'));
      await expect(dpos.connect(validators[1]).bondValidator())
        .to.emit(dpos, 'ValidatorStatusUpdate')
        .withArgs(validators[5].address, consts.STATUS_UNBONDING)
        .to.emit(dpos, 'ValidatorStatusUpdate')
        .withArgs(validators[1].address, consts.STATUS_BONDED);

      await dpos.delegate(validators[1].address, parseUnits('5'));
      await dpos.delegate(validators[5].address, parseUnits('3'));
      const quorum = await dpos.getQuorumStake();
      expect(quorum).to.equal(parseUnits('77').mul(2).div(3).add(1));
    });
  });
});
