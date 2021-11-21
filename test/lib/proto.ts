import { expect } from 'chai';
import protobuf from 'protobufjs';

import { BigNumber } from '@ethersproject/bignumber';
import { keccak256 } from '@ethersproject/solidity';
import { Wallet } from '@ethersproject/wallet';

protobuf.common('google/protobuf/descriptor.proto', {});

interface Proto {
  Slash: protobuf.Type;
  StakingReward: protobuf.Type;
  FarmingRewards: protobuf.Type;
  AcctAmtPair: protobuf.Type;
  Relay: protobuf.Type;
}

async function getProtos(): Promise<Proto> {
  const staking = await protobuf.load(`${__dirname}/../../contracts/libraries/proto/staking.proto`);
  const farming = await protobuf.load(`${__dirname}/../../contracts/libraries/proto/farming.proto`);
  const bridge = await protobuf.load(`${__dirname}/../../contracts/libraries/proto/bridge.proto`);

  const Slash = staking.lookupType('staking.Slash');
  const StakingReward = staking.lookupType('staking.StakingReward');
  const FarmingRewards = farming.lookupType('farming.FarmingRewards');
  const AcctAmtPair = staking.lookupType('staking.AcctAmtPair');

  const Relay = bridge.lookupType('bridge.Relay');

  return {
    Slash,
    StakingReward,
    FarmingRewards,
    AcctAmtPair,
    Relay
  };
}

export function hex2Bytes(hexString: string): number[] {
  let hex = hexString;
  const result = [];
  if (hex.substr(0, 2) === '0x') {
    hex = hex.slice(2);
  }
  if (hex.length % 2 === 1) {
    hex = '0' + hex;
  }
  for (let i = 0; i < hex.length; i += 2) {
    result.push(parseInt(hex.substr(i, 2), 16));
  }
  return result;
}

export function uint2Bytes(x: BigNumber): number[] {
  return hex2Bytes(x.toHexString());
}

export async function calculateSignatures(signers: Wallet[], hash: number[]): Promise<number[][]> {
  const sigs = [];
  for (let i = 0; i < signers.length; i++) {
    const sig = await signers[i].signMessage(hash);
    sigs.push(hex2Bytes(sig));
  }
  return sigs;
}

export async function getStakingRewardRequest(
  recipient: string,
  cumulativeRewardAmount: BigNumber,
  signers: Wallet[],
  contractAddress: string,
  chainId: number
): Promise<{ rewardBytes: Uint8Array; sigs: number[][] }> {
  const { StakingReward } = await getProtos();
  const reward = {
    domain: hex2Bytes(keccak256(['uint256', 'address', 'string'], [chainId, contractAddress, 'StakingReward'])),
    recipient: hex2Bytes(recipient),
    cumulativeRewardAmount: uint2Bytes(cumulativeRewardAmount)
  };
  const rewardProto = StakingReward.create(reward);
  const rewardBytes = StakingReward.encode(rewardProto).finish();
  const rewardBytesHash = keccak256(['bytes'], [rewardBytes]);
  const sigs = await calculateSignatures(signers, hex2Bytes(rewardBytesHash));

  return { rewardBytes, sigs };
}

export async function getFarmingRewardsRequest(
  recipient: string,
  chainId: BigNumber,
  tokenAddresses: string[],
  cumulativeRewardAmounts: BigNumber[],
  signers: Wallet[]
): Promise<{ rewardBytes: Uint8Array; sigs: number[][] }> {
  const { FarmingRewards } = await getProtos();
  const reward = {
    recipient: hex2Bytes(recipient),
    chainId: uint2Bytes(chainId),
    tokenAddresses: tokenAddresses.map(hex2Bytes),
    cumulativeRewardAmounts: cumulativeRewardAmounts.map(uint2Bytes)
  };
  const rewardProto = FarmingRewards.create(reward);
  const rewardBytes = FarmingRewards.encode(rewardProto).finish();
  const rewardBytesHash = keccak256(['bytes'], [rewardBytes]);
  const sigs = await calculateSignatures(signers, hex2Bytes(rewardBytesHash));

  return { rewardBytes, sigs };
}

async function getAcctAmtPairs(accounts: string[], amounts: BigNumber[]): Promise<protobuf.Message[]> {
  const { AcctAmtPair } = await getProtos();
  expect(accounts.length).to.equal(amounts.length);
  const pairs = [];
  for (let i = 0; i < accounts.length; i++) {
    const pair = {
      account: hex2Bytes(accounts[i]),
      amount: uint2Bytes(amounts[i])
    };
    const pairProto = AcctAmtPair.create(pair);
    pairs.push(pairProto);
  }
  return pairs;
}

export async function getSlashRequest(
  validatorAddr: string,
  nonce: number,
  slashFactor: number,
  expireTime: number,
  jailPeriod: number,
  collectorAddrs: string[],
  collectorAmts: BigNumber[],
  signers: Wallet[],
  contractAddress: string,
  chainId: number
): Promise<{ slashBytes: Uint8Array; sigs: number[][] }> {
  const { Slash } = await getProtos();

  const collectors = await getAcctAmtPairs(collectorAddrs, collectorAmts);
  const slash = {
    domain: hex2Bytes(keccak256(['uint256', 'address', 'string'], [chainId, contractAddress, 'Slash'])),
    validator: hex2Bytes(validatorAddr),
    nonce: nonce,
    slashFactor: slashFactor,
    expireTime: expireTime,
    jailPeriod: jailPeriod,
    collectors: collectors
  };
  const slashProto = Slash.create(slash);
  const slashBytes = Slash.encode(slashProto).finish();
  const slashBytesHash = keccak256(['bytes'], [slashBytes]);
  const sigs = await calculateSignatures(signers, hex2Bytes(slashBytesHash));

  return { slashBytes, sigs };
}

export async function getRelayRequest(
  sender: string,
  receiver: string,
  token: string,
  amount: BigNumber,
  srcChainId: number,
  dstChainId: number,
  srcTransferId: string,
  signers: Wallet[]
): Promise<{ relayBytes: Uint8Array; sigs: number[][] }> {
  const { Relay } = await getProtos();
  const relay = {
    sender: hex2Bytes(sender),
    receiver: hex2Bytes(receiver),
    token: hex2Bytes(token),
    amount: uint2Bytes(amount),
    srcChainId: srcChainId,
    dstChainId: dstChainId,
    srcTransferId: hex2Bytes(srcTransferId)
  };
  const relayProto = Relay.create(relay);
  const relayBytes = Relay.encode(relayProto).finish();
  const relayBytesHash = keccak256(['bytes'], [relayBytes]);

  const signerAddrs = [];
  for (let i = 0; i < signers.length; i++) {
    signerAddrs.push(signers[i].address);
  }

  signers.sort((a, b) => (a.address.toLowerCase() > b.address.toLowerCase() ? 1 : -1));
  const sigs = await calculateSignatures(signers, hex2Bytes(relayBytesHash));

  return { relayBytes, sigs };
}
