import { Fixture } from 'ethereum-waffle/dist/esm';
import { ethers, waffle } from 'hardhat';

import { parseUnits } from '@ethersproject/units';
import { Wallet } from '@ethersproject/wallet';

import {
  SGN,
  SGN__factory,
  Staking,
  Staking__factory,
  Reward,
  Reward__factory,
  Govern,
  Govern__factory,
  Viewer,
  Viewer__factory,
  TestERC20,
  TestERC20__factory
} from '../../typechain';
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
  reward: Reward;
  govern: Govern;
  viewer: Viewer;
  celr: TestERC20;
}

export async function deployContracts(admin: Wallet): Promise<DeploymentInfo> {
  const testERC20Factory = (await ethers.getContractFactory('TestERC20')) as TestERC20__factory;
  const celr = await testERC20Factory.connect(admin).deploy();
  await celr.deployed();

  const stakingFactory = (await ethers.getContractFactory('Staking')) as Staking__factory;
  const staking = await stakingFactory
    .connect(admin)
    .deploy(
      celr.address,
      consts.PROPOSAL_DEPOSIT,
      consts.VOTING_PERIOD,
      consts.UNBONDING_PERIOD,
      consts.MAX_VALIDATOR_NUM,
      consts.MIN_VALIDATOR_TOKENS,
      consts.MIN_SELF_DELEGATION,
      consts.ADVANCE_NOTICE_PERIOD,
      consts.VALIDATOR_BOND_INTERVAL,
      consts.MAX_SLASH_FACTOR
    );
  await staking.deployed();

  const sgnFactory = (await ethers.getContractFactory('SGN')) as SGN__factory;
  const sgn = await sgnFactory.connect(admin).deploy(staking.address);
  await sgn.deployed();

  const rewardFactory = (await ethers.getContractFactory('Reward')) as Reward__factory;
  const reward = await rewardFactory.connect(admin).deploy(staking.address, celr.address);
  await reward.deployed();

  const governFactory = (await ethers.getContractFactory('Govern')) as Govern__factory;
  const govern = await governFactory.connect(admin).deploy(staking.address, celr.address, reward.address);
  await govern.deployed();

  const viewerFactory = (await ethers.getContractFactory('Viewer')) as Viewer__factory;
  const viewer = await viewerFactory.connect(admin).deploy(staking.address);
  await viewer.deployed();

  return { staking, sgn, reward, govern, viewer, celr };
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

export async function advanceBlockNumber(blkNum: number): Promise<void> {
  const promises = [];
  for (let i = 0; i < blkNum; i++) {
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
