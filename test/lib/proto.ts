import { expect } from 'chai';
import {
  AbstractSigner,
  BigNumberish,
  getBytes,
  solidityPacked,
  solidityPackedKeccak256,
  toBeArray,
  Wallet
} from 'ethers';
import protobuf from 'protobufjs';

import { SignerWithAddress } from '@nomicfoundation/hardhat-ethers/signers';

protobuf.common('google/protobuf/descriptor.proto', {});

interface Proto {
  Slash: protobuf.Type;
  StakingReward: protobuf.Type;
  FarmingRewards: protobuf.Type;
  AcctAmtPair: protobuf.Type;
  Relay: protobuf.Type;
  WithdrawMsg: protobuf.Type;
  Mint: protobuf.Type;
}

async function getProtos(): Promise<Proto> {
  const staking = await protobuf.load(`${__dirname}/../../contracts/libraries/proto/staking.proto`);
  const farming = await protobuf.load(`${__dirname}/../../contracts/libraries/proto/farming.proto`);
  const bridge = await protobuf.load(`${__dirname}/../../contracts/libraries/proto/bridge.proto`);
  const pool = await protobuf.load(`${__dirname}/../../contracts/libraries/proto/pool.proto`);
  const pegged = await protobuf.load(`${__dirname}/../../contracts/libraries/proto/pegged.proto`);

  const Slash = staking.lookupType('staking.Slash');
  const StakingReward = staking.lookupType('staking.StakingReward');
  const FarmingRewards = farming.lookupType('farming.FarmingRewards');
  const AcctAmtPair = staking.lookupType('staking.AcctAmtPair');

  const Relay = bridge.lookupType('bridge.Relay');
  const WithdrawMsg = pool.lookupType('pool.WithdrawMsg');
  const Mint = pegged.lookupType('pegged.Mint');

  return {
    Slash,
    StakingReward,
    FarmingRewards,
    AcctAmtPair,
    Relay,
    WithdrawMsg,
    Mint
  };
}

export async function calculateSignatures(signers: AbstractSigner[], hash: Uint8Array): Promise<string[]> {
  const sigs = [];
  for (let i = 0; i < signers.length; i++) {
    const sig = await signers[i].signMessage(hash);
    sigs.push(sig);
  }
  return sigs;
}

export async function getStakingRewardRequest(
  recipient: string,
  cumulativeRewardAmount: BigNumberish,
  signers: Wallet[],
  chainId: number,
  contractAddress: string
): Promise<{ rewardBytes: Uint8Array; sigs: string[] }> {
  const { StakingReward } = await getProtos();
  const reward = {
    recipient: getBytes(recipient),
    cumulativeRewardAmount: toBeArray(cumulativeRewardAmount)
  };
  const rewardProto = StakingReward.create(reward);
  const rewardBytes = StakingReward.encode(rewardProto).finish();

  const domain = solidityPackedKeccak256(['uint256', 'address', 'string'], [chainId, contractAddress, 'StakingReward']);
  const signedData = solidityPacked(['bytes32', 'bytes'], [domain, rewardBytes]);
  const signedDataHash = solidityPackedKeccak256(['bytes'], [signedData]);
  const sigs = await calculateSignatures(signers, getBytes(signedDataHash));

  return { rewardBytes, sigs };
}

export async function getFarmingRewardsRequest(
  recipient: string,
  tokenAddresses: string[],
  cumulativeRewardAmounts: BigNumberish[],
  signers: Wallet[],
  chainId: number,
  contractAddress: string
): Promise<{ rewardBytes: Uint8Array; sigs: string[] }> {
  const { FarmingRewards } = await getProtos();
  const reward = {
    recipient: getBytes(recipient),
    tokenAddresses: tokenAddresses.map((addr) => getBytes(addr)),
    cumulativeRewardAmounts: cumulativeRewardAmounts.map(toBeArray)
  };
  const rewardProto = FarmingRewards.create(reward);
  const rewardBytes = FarmingRewards.encode(rewardProto).finish();

  const domain = solidityPackedKeccak256(
    ['uint256', 'address', 'string'],
    [chainId, contractAddress, 'FarmingRewards']
  );
  const signedData = solidityPacked(['bytes32', 'bytes'], [domain, rewardBytes]);
  const signedDataHash = solidityPackedKeccak256(['bytes'], [signedData]);
  const sigs = await calculateSignatures(signers, getBytes(signedDataHash));

  return { rewardBytes, sigs };
}

async function getAcctAmtPairs(accounts: string[], amounts: bigint[]): Promise<protobuf.Message[]> {
  const { AcctAmtPair } = await getProtos();
  expect(accounts.length).to.equal(amounts.length);
  const pairs = [];
  for (let i = 0; i < accounts.length; i++) {
    const pair = {
      account: getBytes(accounts[i]),
      amount: toBeArray(amounts[i])
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
  collectorAmts: bigint[],
  signers: Wallet[],
  chainId: number,
  contractAddress: string
): Promise<{ slashBytes: Uint8Array; sigs: string[] }> {
  const { Slash } = await getProtos();

  const collectors = await getAcctAmtPairs(collectorAddrs, collectorAmts);
  const slash = {
    validator: getBytes(validatorAddr),
    nonce,
    slashFactor,
    expireTime,
    jailPeriod,
    collectors
  };
  const slashProto = Slash.create(slash);
  const slashBytes = Slash.encode(slashProto).finish();

  const domain = solidityPackedKeccak256(['uint256', 'address', 'string'], [chainId, contractAddress, 'Slash']);
  const signedData = solidityPacked(['bytes32', 'bytes'], [domain, slashBytes]);
  const signedDataHash = solidityPackedKeccak256(['bytes'], [signedData]);
  const sigs = await calculateSignatures(signers, getBytes(signedDataHash));

  return { slashBytes, sigs };
}

export async function getRelayRequest(
  sender: string,
  receiver: string,
  token: string,
  amount: bigint,
  srcChainId: number,
  dstChainId: number,
  srcTransferId: string,
  signers: (Wallet | SignerWithAddress)[],
  contractAddress: string
): Promise<{ relayBytes: Uint8Array; sigs: string[] }> {
  const { Relay } = await getProtos();
  const relay = {
    sender: getBytes(sender),
    receiver: getBytes(receiver),
    token: getBytes(token),
    amount: toBeArray(amount),
    srcChainId,
    dstChainId,
    srcTransferId: getBytes(srcTransferId)
  };
  const relayProto = Relay.create(relay);
  const relayBytes = Relay.encode(relayProto).finish();

  const domain = solidityPackedKeccak256(['uint256', 'address', 'string'], [dstChainId, contractAddress, 'Relay']);
  const signedData = solidityPacked(['bytes32', 'bytes'], [domain, relayBytes]);
  const signedDataHash = solidityPackedKeccak256(['bytes'], [signedData]);

  const signerAddrs = [];
  for (let i = 0; i < signers.length; i++) {
    signerAddrs.push(signers[i].address);
  }

  signers.sort((a, b) => (a.address.toLowerCase() > b.address.toLowerCase() ? 1 : -1));
  const sigs = await calculateSignatures(signers, getBytes(signedDataHash));

  return { relayBytes, sigs };
}

export async function getWithdrawRequest(
  chainId: number,
  seqnum: number,
  receiver: string,
  token: string,
  amount: bigint,
  refid: string,
  signers: Wallet[],
  contractAddress: string
): Promise<{ withdrawBytes: Uint8Array; sigs: string[] }> {
  const { WithdrawMsg } = await getProtos();
  const withdraw = {
    chainid: chainId,
    seqnum: seqnum,
    receiver: getBytes(receiver),
    token: getBytes(token),
    amount: toBeArray(amount),
    refid: getBytes(refid)
  };
  const withdrawProto = WithdrawMsg.create(withdraw);
  const withdrawBytes = WithdrawMsg.encode(withdrawProto).finish();

  const domain = solidityPackedKeccak256(['uint256', 'address', 'string'], [chainId, contractAddress, 'WithdrawMsg']);
  const signedData = solidityPacked(['bytes32', 'bytes'], [domain, withdrawBytes]);
  const signedDataHash = solidityPackedKeccak256(['bytes'], [signedData]);

  const signerAddrs = [];
  for (let i = 0; i < signers.length; i++) {
    signerAddrs.push(signers[i].address);
  }

  signers.sort((a, b) => (a.address.toLowerCase() > b.address.toLowerCase() ? 1 : -1));
  const sigs = await calculateSignatures(signers, getBytes(signedDataHash));
  return { withdrawBytes, sigs };
}

export async function getMintRequest(
  token: string,
  account: string,
  amount: bigint,
  depositor: string,
  refChainId: number,
  refId: string,
  signers: Wallet[],
  chainId: number,
  contractAddress: string
): Promise<{ mintBytes: Uint8Array; sigs: string[] }> {
  const { Mint } = await getProtos();
  const mint = {
    token: getBytes(token),
    account: getBytes(account),
    amount: toBeArray(amount),
    depositor: getBytes(depositor),
    refChainId,
    refId: getBytes(refId)
  };
  const mintProto = Mint.create(mint);
  const mintBytes = Mint.encode(mintProto).finish();

  const domain = solidityPackedKeccak256(['uint256', 'address', 'string'], [chainId, contractAddress, 'Mint']);
  const signedData = solidityPacked(['bytes32', 'bytes'], [domain, mintBytes]);
  const signedDataHash = solidityPackedKeccak256(['bytes'], [signedData]);

  const signerAddrs = [];
  for (let i = 0; i < signers.length; i++) {
    signerAddrs.push(signers[i].address);
  }

  signers.sort((a, b) => (a.address.toLowerCase() > b.address.toLowerCase() ? 1 : -1));
  const sigs = await calculateSignatures(signers, getBytes(signedDataHash));
  return { mintBytes, sigs };
}
