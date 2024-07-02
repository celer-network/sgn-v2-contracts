import { parseUnits, Wallet, ZeroAddress } from 'ethers';
import { ethers } from 'hardhat';

import {
  Bridge,
  Bridge__factory,
  DummySwap,
  DummySwap__factory,
  FarmingRewards,
  FarmingRewards__factory,
  Govern,
  Govern__factory,
  GovernedOwnerProxy,
  GovernedOwnerProxy__factory,
  MessageBus,
  MessageBus__factory,
  MsgTest,
  MsgTest__factory,
  PeggedTokenBridge,
  PeggedTokenBridge__factory,
  Sentinel,
  Sentinel__factory,
  SGN,
  SGN__factory,
  SimpleGovernance,
  SimpleGovernance__factory,
  SingleBridgeToken,
  SingleBridgeToken__factory,
  Staking,
  Staking__factory,
  StakingReward,
  StakingReward__factory,
  TestERC20,
  TestERC20__factory,
  TransferSwap,
  TransferSwap__factory,
  Viewer,
  Viewer__factory,
  WETH,
  WETH__factory
} from '../../typechain';
import * as consts from './constants';

import type { AbstractSigner, AddressLike, ContractRunner } from 'ethers';
interface DeploymentInfo {
  staking: Staking;
  sgn: SGN;
  stakingReward: StakingReward;
  farmingRewards: FarmingRewards;
  govern: Govern;
  viewer: Viewer;
  celr: TestERC20;
}

export async function deployContracts(admin: ContractRunner): Promise<DeploymentInfo> {
  const testERC20Factory = new TestERC20__factory();
  const celr = await testERC20Factory.connect(admin).deploy();
  const celrAddress = await celr.getAddress();

  const stakingFactory = new Staking__factory();
  const staking = await stakingFactory
    .connect(admin)
    .deploy(
      celrAddress,
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
  const stakingAddress = await staking.getAddress();

  const sgnFactory = new SGN__factory();
  const sgn = await sgnFactory.connect(admin).deploy(stakingAddress);

  const stakingRewardFactory = new StakingReward__factory();
  const stakingReward = await stakingRewardFactory.connect(admin).deploy(stakingAddress);
  const stakingRewardAddress = await stakingReward.getAddress();

  const farmingRewardsFactory = new FarmingRewards__factory();
  const farmingRewards = await farmingRewardsFactory.connect(admin).deploy(stakingAddress);

  const governFactory = new Govern__factory();
  const govern = await governFactory.connect(admin).deploy(stakingAddress, celrAddress, stakingRewardAddress);

  const viewerFactory = new Viewer__factory();
  const viewer = await viewerFactory.connect(admin).deploy(stakingAddress);

  return { staking, sgn, stakingReward, farmingRewards, govern, viewer, celr };
}

interface BridgeInfo {
  bridge: Bridge;
  token: TestERC20;
  pegBridge: PeggedTokenBridge;
  pegToken: SingleBridgeToken;
}

export async function deployBridgeContracts(admin: ContractRunner): Promise<BridgeInfo> {
  const testERC20Factory = new TestERC20__factory();
  const token = await testERC20Factory.connect(admin).deploy();
  await token.waitForDeployment();

  const bridgeFactory = new Bridge__factory();
  const bridge = await bridgeFactory.connect(admin).deploy();
  await bridge.waitForDeployment();

  const pegBridgeFactory = new PeggedTokenBridge__factory();
  const pegBridge = await pegBridgeFactory.connect(admin).deploy(bridge.getAddress());
  await pegBridge.waitForDeployment();

  const pegTokenFactory = new SingleBridgeToken__factory();
  const pegToken = await pegTokenFactory.connect(admin).deploy('PegToken', 'PGT', 18, pegBridge.getAddress());
  await pegToken.waitForDeployment();

  return { bridge, token, pegBridge, pegToken };
}

interface MessageInfo {
  bridge: Bridge;
  msgBus: MessageBus;
  msgTest: MsgTest;
  token: TestERC20;
}

export async function deployMessageContracts(admin: ContractRunner): Promise<MessageInfo> {
  const testERC20Factory = new TestERC20__factory();
  const token = await testERC20Factory.connect(admin).deploy();

  const bridgeFactory = new Bridge__factory();
  const bridge = await bridgeFactory.connect(admin).deploy();
  const bridgeAddress = await bridge.getAddress();

  const msgBusFactory = new MessageBus__factory();
  const msgBus = await msgBusFactory
    .connect(admin)
    .deploy(bridgeAddress, bridgeAddress, ZeroAddress, ZeroAddress, ZeroAddress, ZeroAddress);

  const msgTestFactory = new MsgTest__factory();
  const msgTest = await msgTestFactory.connect(admin).deploy(msgBus.getAddress());

  return { bridge, msgBus, msgTest, token };
}

interface GovernedOwnerInfo {
  gov: SimpleGovernance;
  proxy: GovernedOwnerProxy;
}

export async function deployGovernedOwner(
  admin: ContractRunner & AddressLike,
  initVoterNum: number
): Promise<GovernedOwnerInfo> {
  const proxyFactory = new GovernedOwnerProxy__factory();
  const proxy = await proxyFactory.connect(admin).deploy(admin);

  const voters: string[] = [];
  const powers: number[] = [];
  for (let i = 0; i < initVoterNum; i++) {
    const voter = new Wallet(consts.userPrivKeys[i]).connect(ethers.provider);
    voters.push(voter.address);
    powers.push(100);
  }

  const govFactory = new SimpleGovernance__factory();
  const gov = await govFactory.connect(admin).deploy(voters, powers, [proxy.getAddress()], 3600, 60, 40);

  await proxy.initGov(gov.getAddress());

  return { gov, proxy };
}

export async function deploySentinel(admin: ContractRunner): Promise<Sentinel> {
  const factory = new Sentinel__factory();
  const sentinel = await factory.connect(admin).deploy([], [], []);
  return sentinel;
}

interface SwapInfo {
  transferSwap: TransferSwap;
  tokenA: TestERC20;
  tokenB: TestERC20;
  bridge: Bridge;
  swap: DummySwap;
  weth: WETH;
}

export async function deploySwapContracts(admin: ContractRunner): Promise<SwapInfo> {
  const testERC20FactoryA = new TestERC20__factory();
  const tokenA = await testERC20FactoryA.connect(admin).deploy();

  const testERC20FactoryB = new TestERC20__factory();
  const tokenB = await testERC20FactoryB.connect(admin).deploy();

  const bridgeFactory = new Bridge__factory();
  const bridge = await bridgeFactory.connect(admin).deploy();
  const bridgeAddress = await bridge.getAddress();

  const busFactory = new MessageBus__factory();
  const bus = await busFactory
    .connect(admin)
    .deploy(bridgeAddress, bridgeAddress, ZeroAddress, ZeroAddress, ZeroAddress, ZeroAddress);

  const swapFactory = new DummySwap__factory();
  const swap = await swapFactory.connect(admin).deploy(parseUnits('5')); // 5% fixed fake slippage

  const wethFactory = new WETH__factory();
  const weth = await wethFactory.connect(admin).deploy();

  const transferSwapFactory = new TransferSwap__factory();
  const transferSwap = await transferSwapFactory
    .connect(admin)
    .deploy(bus.getAddress(), swap.getAddress(), weth.getAddress());

  return { tokenA, tokenB, transferSwap, swap, bridge, weth };
}

export async function getAccounts(admin: AbstractSigner, assets: TestERC20[], num: number): Promise<Wallet[]> {
  const accounts: Wallet[] = [];
  for (let i = 0; i < num; i++) {
    accounts.push(new ethers.Wallet(consts.userPrivKeys[i]).connect(ethers.provider));
    await admin.sendTransaction({
      to: accounts[i].address,
      value: parseUnits('11')
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

export async function getBlockTime() {
  const blockNumber = await ethers.provider.getBlockNumber();
  const block = await ethers.provider.getBlock(blockNumber);
  if (block) {
    return block.timestamp;
  }
  throw Error('invalid block number');
}

export async function advanceBlockTime(blkTime: number) {
  const currBlkTime = await getBlockTime();
  await ethers.provider.send('evm_setNextBlockTimestamp', [currBlkTime + blkTime]);
  await ethers.provider.send('evm_mine', []);
}

export function getAddrs(signers: Wallet[]) {
  const addrs: string[] = [];
  for (let i = 0; i < signers.length; i++) {
    addrs.push(signers[i].address);
  }
  return addrs;
}
