import { expect } from 'chai';

import { parseUnits } from '@ethersproject/units';
import { Wallet } from '@ethersproject/wallet';

import { deployContracts, getAccounts, loadFixture } from './lib/common';
import * as consts from './lib/constants';
import { DPoS, TestERC20 } from '../typechain';

describe('Signer Tests', function () {
  async function fixture([admin]: Wallet[]) {
    const { dpos, celr } = await deployContracts(admin);
    return { admin, dpos, celr };
  }

  let dpos: DPoS;
  let celr: TestERC20;
  let admin: Wallet;
  let validators: Wallet[];
  let signers: Wallet[];

  beforeEach(async () => {
    const res = await loadFixture(fixture);
    dpos = res.dpos;
    celr = res.celr;
    admin = res.admin;
    const accounts = await getAccounts(res.admin, [celr], 4);
    validators = [accounts[0], accounts[1]];
    signers = [accounts[2], accounts[3]];
    await celr.connect(validators[0]).approve(dpos.address, parseUnits('100'));
    await celr.connect(validators[1]).approve(dpos.address, parseUnits('100'));
    await dpos
      .connect(validators[0])
      .initializeValidator(signers[0].address, consts.MIN_VALIDATOR_TOKENS, consts.COMMISSION_RATE);
  });

  it('should fail to initialize a validator using another validator as signer', async function () {
    await expect(
      dpos
        .connect(validators[1])
        .initializeValidator(validators[0].address, consts.MIN_VALIDATOR_TOKENS, consts.COMMISSION_RATE)
    ).to.be.revertedWith('Signer is other validator');
  });

  it('should fail to initialize a validator using a signer being used by another validator', async function () {
    await expect(
      dpos
        .connect(validators[1])
        .initializeValidator(signers[0].address, consts.MIN_VALIDATOR_TOKENS, consts.COMMISSION_RATE)
    ).to.be.revertedWith('Signer already used');
  });

  it('should be able to bond validator using signer address', async function () {
    await expect(dpos.connect(signers[0]).bondValidator())
      .to.emit(dpos, 'ValidatorStatusUpdate')
      .withArgs(validators[0].address, consts.STATUS_BONDED);
  });

  describe('after both validators are bonded', async () => {
    beforeEach(async () => {
      await dpos
        .connect(validators[1])
        .initializeValidator(signers[1].address, consts.MIN_VALIDATOR_TOKENS, consts.COMMISSION_RATE);
      await dpos.connect(validators[0]).bondValidator();
      await dpos.connect(validators[1]).bondValidator();
    });

    it('should update signer correctly', async function () {
      await expect(dpos.connect(validators[0]).updateValidatorSigner(admin.address))
        .to.emit(dpos, 'ValidatorParamsUpdate')
        .withArgs(validators[0].address, admin.address, consts.MIN_VALIDATOR_TOKENS, consts.COMMISSION_RATE);

      await expect(dpos.connect(validators[0]).updateValidatorSigner(validators[0].address))
        .to.emit(dpos, 'ValidatorParamsUpdate')
        .withArgs(validators[0].address, validators[0].address, consts.MIN_VALIDATOR_TOKENS, consts.COMMISSION_RATE);
    });

    it('should fail to update signer with invalid inputs', async function () {
      await expect(dpos.connect(validators[0]).updateValidatorSigner(signers[0].address)).to.be.revertedWith(
        'Signer already used'
      );
      await expect(dpos.connect(validators[0]).updateValidatorSigner(signers[1].address)).to.be.revertedWith(
        'Signer already used'
      );
      await expect(dpos.connect(validators[0]).updateValidatorSigner(validators[1].address)).to.be.revertedWith(
        'Signer is other validator'
      );
    });
  });
});
