import { Fixture } from 'ethereum-waffle';
import { ethers, waffle } from 'hardhat';

import { parseUnits } from '@ethersproject/units';
import { Wallet } from '@ethersproject/wallet';

import { DPoS, SGN, TestERC20 } from '../../typechain';
import { DPoS__factory, SGN__factory, TestERC20__factory } from '../../typechain';

import * as consts from './constants';

// Workaround for https://github.com/nomiclabs/hardhat/issues/849
// TODO: Remove once fixed upstream.
export function loadFixture<T>(fixture: Fixture<T>): Promise<T> {
  const provider = waffle.provider;
  return waffle.createFixtureLoader(provider.getWallets(), provider)(fixture);
}

interface DeploymentInfo {
  dpos: DPoS;
  sgn: SGN;
  celr: TestERC20;
}

export async function deployContracts(admin: Wallet): Promise<DeploymentInfo> {
  const testERC20Factory = (await ethers.getContractFactory('TestERC20')) as TestERC20__factory;
  const celr = await testERC20Factory.deploy();
  await celr.deployed();

  const dposFactory = (await ethers.getContractFactory('DPoS')) as DPoS__factory;
  const dpos = await dposFactory.deploy(
    celr.address,
    consts.GOVERN_PROPOSAL_DEPOSIT,
    consts.GOVERN_VOTE_TIMEOUT,
    consts.SLASH_TIMEOUT,
    consts.MIN_VALIDATOR_NUM,
    consts.MAX_VALIDATOR_NUM,
    consts.MIN_STAKING_POOL,
    consts.ADVANCE_NOTICE_PERIOD,
    consts.DPOS_GO_LIVE_TIMEOUT
  );
  await dpos.deployed();

  const sgnFactory = (await ethers.getContractFactory('SGN')) as SGN__factory;
  const sgn = await sgnFactory.deploy(celr.address, dpos.address);
  await sgn.deployed();

  return { dpos, sgn, celr };
}

export async function getAccounts(admin: Wallet, assets: TestERC20[], num: number): Promise<Wallet[]> {
  const accounts: Wallet[] = [];
  for (let i = 0; i < num; i++) {
    accounts.push(new ethers.Wallet(consts.userPrivKeys[i]).connect(ethers.provider));
    await admin.sendTransaction({
      to: accounts[i].address,
      value: parseUnits('10')
    });
    for (let j = 0; j < assets.length; j++) {
      await assets[j].transfer(accounts[i].address, parseUnits('1000'));
    }
  }
  return accounts;
}

export async function advanceBlockNumber(blknum: number): Promise<void> {
  const promises = [];
  for (let i = 0; i < blknum; i++) {
    promises.push(ethers.provider.send('evm_mine', []));
  }
  await Promise.all(promises);
}

export async function advanceBlockNumberTo(target: number): Promise<void> {
  const blockNumber = await ethers.provider.getBlockNumber();
  const promises = [];
  for (let i = blockNumber; i < target; i++) {
    promises.push(ethers.provider.send('evm_mine', []));
  }
  await Promise.all(promises);
}
