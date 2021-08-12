import { Fixture } from 'ethereum-waffle';
import { ethers, waffle } from 'hardhat';

import { parseEther } from '@ethersproject/units';
import { Wallet } from '@ethersproject/wallet';

import { DPoS, SGN, TestERC20 } from '../../typechain';
import { DPoS__factory, SGN__factory, TestERC20__factory } from '../../typechain';

import * as consts from './constants';

const userPrivKeys = [
  '0x36f2243a51a0f879b1859fff1a663ac04aeebca1bcff4d7dc5a8b38e53211199',
  '0xc0bf10873ddb6d554838f5e4f0c000e85d3307754151add9813ff331b746390d',
  '0x68888cc706520c4d5049d38933e0b502e2863781d75de09c499cf0e4e00ba2de',
  '0x400e64f3b8fe65ecda0bad60627c41fa607172cf0970fbe2551d6d923fd82f78',
  '0xab4c840e48b11840f923a371ba453e4d8884fd23eee1b579f5a3910c9b00a4b6',
  '0x0168ea2aa71023864b1c8eb65997996d726e5068c12b20dea81076ef56380465'
];

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
    accounts.push(new ethers.Wallet(userPrivKeys[i]).connect(ethers.provider));
    await admin.sendTransaction({
      to: accounts[i].address,
      value: parseEther('10')
    });
    for (let j = 0; j < assets.length; j++) {
      await assets[j].transfer(accounts[i].address, parseEther('1000'));
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
