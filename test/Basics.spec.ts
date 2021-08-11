import { expect } from 'chai';

import { keccak256 } from '@ethersproject/solidity';
import { parseEther } from '@ethersproject/units';
import { Wallet } from '@ethersproject/wallet';

import { deployContracts, getAccounts, loadFixture } from './common';
import * as consts from './constants';
import { DPoS, SGN, TestERC20 } from '../typechain';
import exp from 'constants';

describe('Basic Tests', function () {
  async function fixture([admin]: Wallet[]) {
    const { dpos, sgn, celr } = await deployContracts(admin);
    const accounts = await getAccounts(admin, [celr], 2);
    const candidate = accounts[0];
    const delegator = accounts[1];
    return {
      dpos,
      sgn,
      celr,
      candidate,
      delegator
    };
  }

  let dpos: DPoS;
  let sgn: SGN;
  let celr: TestERC20;
  let candidate: Wallet;
  let delegator: Wallet;

  beforeEach(async () => {
    const res = await loadFixture(fixture);
    dpos = res.dpos;
    sgn = res.sgn;
    celr = res.celr;
    candidate = res.candidate;
    delegator = res.delegator;
  });

  it('should fail to delegate to an uninitialized candidate', async function () {
    expect(dpos.delegate(candidate.address, consts.DELEGATOR_STAKE)).to.be.revertedWith('Candidate is not initialized');
  });

  it('should fail to initialize a candidate when paused', async function () {
    await dpos.pause();
    expect(
      dpos
        .connect(candidate)
        .initializeCandidate(consts.MIN_SELF_STAKE, consts.COMMISSION_RATE, consts.RATE_LOCK_END_TIME)
    ).to.be.revertedWith('Pausable: paused');
  });

  it('should fail to initialize a non-whitelisted candidate when whitelist is enabled', async function () {
    await dpos.enableWhitelist();
    expect(
      dpos
        .connect(candidate)
        .initializeCandidate(consts.MIN_SELF_STAKE, consts.COMMISSION_RATE, consts.RATE_LOCK_END_TIME)
    ).to.be.revertedWith('caller is not whitelisted');
  });

  it('should initialize a whitelisted candidate successfully when whitelist is enabled', async function () {
    await dpos.enableWhitelist();
    await dpos.addWhitelisted(candidate.address);
    await expect(
      dpos
        .connect(candidate)
        .initializeCandidate(consts.MIN_SELF_STAKE, consts.COMMISSION_RATE, consts.RATE_LOCK_END_TIME)
    )
      .to.emit(dpos, 'InitializeCandidate')
      .withArgs(candidate.address, consts.MIN_SELF_STAKE, consts.COMMISSION_RATE, consts.RATE_LOCK_END_TIME);
  });

  it('should initialize a candidate and update sidechain address successfully', async function () {
    await expect(
      dpos
        .connect(candidate)
        .initializeCandidate(consts.MIN_SELF_STAKE, consts.COMMISSION_RATE, consts.RATE_LOCK_END_TIME)
    )
      .to.emit(dpos, 'InitializeCandidate')
      .withArgs(candidate.address, consts.MIN_SELF_STAKE, consts.COMMISSION_RATE, consts.RATE_LOCK_END_TIME);

    const sidechainAddr = keccak256(['address'], [candidate.address]);
    await expect(sgn.connect(candidate).updateSidechainAddr(sidechainAddr))
      .to.emit(sgn, 'UpdateSidechainAddr')
      .withArgs(candidate.address, consts.HASHED_NULL, sidechainAddr);
  });
});
