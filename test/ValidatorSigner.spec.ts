import { expect } from 'chai';
import { AbiCoder, parseUnits, solidityPackedKeccak256, Wallet, ZeroAddress } from 'ethers';
import { ethers } from 'hardhat';

import { HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers';
import { loadFixture } from '@nomicfoundation/hardhat-toolbox/network-helpers';

import { SGN, Staking, TestERC20 } from '../typechain';
import { deployContracts, getAccounts } from './lib/common';
import * as consts from './lib/constants';

describe('Validator Signer Tests', function () {
  async function fixture() {
    const [admin] = await ethers.getSigners();
    const { staking, sgn, celr } = await deployContracts(admin);
    return { admin, staking, sgn, celr };
  }

  const abiCoder = AbiCoder.defaultAbiCoder();

  let staking: Staking;
  let sgn: SGN;
  let celr: TestERC20;
  let admin: HardhatEthersSigner;
  let validators: Wallet[];
  let signers: Wallet[];

  beforeEach(async () => {
    const res = await loadFixture(fixture);
    staking = res.staking;
    sgn = res.sgn;
    celr = res.celr;
    admin = res.admin;
    const accounts = await getAccounts(res.admin, [celr], 4);
    validators = [accounts[0], accounts[1]];
    signers = [accounts[2], accounts[3]];
    const stakingAddress = await staking.getAddress();
    await celr.connect(validators[0]).approve(stakingAddress, parseUnits('100'));
    await celr.connect(validators[1]).approve(stakingAddress, parseUnits('100'));
    await staking
      .connect(validators[0])
      .initializeValidator(signers[0].address, consts.MIN_VALIDATOR_TOKENS, consts.COMMISSION_RATE);
  });

  it('should fail to initialize a validator using another validator as signer', async function () {
    await expect(
      staking
        .connect(validators[1])
        .initializeValidator(validators[0].address, consts.MIN_VALIDATOR_TOKENS, consts.COMMISSION_RATE)
    ).to.be.revertedWith('Signer is other validator');
  });

  it('should fail to initialize a validator using a signer being used by another validator', async function () {
    await expect(
      staking
        .connect(validators[1])
        .initializeValidator(signers[0].address, consts.MIN_VALIDATOR_TOKENS, consts.COMMISSION_RATE)
    ).to.be.revertedWith('Signer already used');
  });

  it('should be able to bond validator using signer address', async function () {
    await expect(staking.connect(signers[0]).bondValidator())
      .to.emit(staking, 'ValidatorStatusUpdate')
      .withArgs(validators[0].address, consts.STATUS_BONDED);
  });

  it('should update sgn address using signer address', async function () {
    const sgnAddr = solidityPackedKeccak256(['string'], ['sgnaddr1']);
    await expect(sgn.connect(signers[0]).updateSgnAddr(sgnAddr))
      .to.emit(sgn, 'SgnAddrUpdate')
      .withArgs(validators[0].address, '0x', sgnAddr)
      .to.emit(staking, 'ValidatorNotice')
      .withArgs(validators[0].address, 'sgn-addr', sgnAddr, sgn.getAddress());
  });

  describe('after both validators are bonded', async () => {
    beforeEach(async () => {
      await staking
        .connect(validators[1])
        .initializeValidator(signers[1].address, consts.MIN_VALIDATOR_TOKENS, consts.COMMISSION_RATE);
      await staking.connect(validators[0]).bondValidator();
      await staking.connect(validators[1]).bondValidator();
    });

    it('should update signer correctly', async function () {
      let data = abiCoder.encode(['address'], [admin.address]);

      await expect(staking.connect(validators[0]).updateValidatorSigner(admin.address))
        .to.emit(staking, 'ValidatorNotice')
        .withArgs(validators[0].address, 'signer', data, ZeroAddress);

      data = abiCoder.encode(['address'], [validators[0].address]);
      await expect(staking.connect(validators[0]).updateValidatorSigner(validators[0].address))
        .to.emit(staking, 'ValidatorNotice')
        .withArgs(validators[0].address, 'signer', data, ZeroAddress);
    });

    it('should fail to update signer with invalid inputs', async function () {
      await expect(staking.connect(validators[0]).updateValidatorSigner(signers[0].address)).to.be.revertedWith(
        'Signer already used'
      );
      await expect(staking.connect(validators[0]).updateValidatorSigner(signers[1].address)).to.be.revertedWith(
        'Signer already used'
      );
      await expect(staking.connect(validators[0]).updateValidatorSigner(validators[1].address)).to.be.revertedWith(
        'Signer is other validator'
      );
    });
  });
});
