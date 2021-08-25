import { Fixture } from 'ethereum-waffle';
import { ethers, waffle } from 'hardhat';

import { parseUnits } from '@ethersproject/units';
import { BigNumber } from '@ethersproject/bignumber';
import { Wallet } from '@ethersproject/wallet';

import { Staking, SGN, TestERC20 } from '../../typechain';
import { Staking__factory, SGN__factory, TestERC20__factory } from '../../typechain';

import * as consts from './constants';

// Workaround for https://github.com/nomiclabs/hardhat/issues/849
// TODO: Remove once fixed upstream.
export function loadFixture<T>(fixture: Fixture<T>): Promise<T> {
  const provider = waffle.provider;
  return waffle.createFixtureLoader(provider.getWallets(), provider)(fixture);
}

interface DeploymentInfo {
  staking: Staking;
  sgn: SGN;
  celr: TestERC20;
}

export async function deployContracts(admin: Wallet): Promise<DeploymentInfo> {
  const testERC20Factory = (await ethers.getContractFactory('TestERC20')) as TestERC20__factory;
  const celr = await testERC20Factory.deploy();
  await celr.deployed();

  const stakingFactory = (await ethers.getContractFactory('Staking')) as Staking__factory;
  const staking = await stakingFactory.deploy(
    celr.address,
    consts.GOVERN_PROPOSAL_DEPOSIT,
    consts.GOVERN_VOTE_TIMEOUT,
    consts.SLASH_TIMEOUT,
    consts.MAX_VALIDATOR_NUM,
    consts.MIN_VALIDATOR_TOKENS,
    consts.MIN_SELF_DELEGATION,
    consts.ADVANCE_NOTICE_PERIOD,
    consts.VALIDATOR_BOND_INTERVAL,
    consts.MAX_SLASH_FACTOR
  );
  await staking.deployed();

  const sgnFactory = (await ethers.getContractFactory('SGN')) as SGN__factory;
  const sgn = await sgnFactory.deploy(staking.address);
  await sgn.deployed();

  return { staking, sgn, celr };
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
  accounts.sort((a, b) => (a.address.toLowerCase() > b.address.toLowerCase() ? 1 : -1));
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
