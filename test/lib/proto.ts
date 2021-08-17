import { expect } from 'chai';
import { keccak256 } from '@ethersproject/solidity';
import { Wallet } from '@ethersproject/wallet';
import { BigNumber } from '@ethersproject/bignumber';

import protobuf from 'protobufjs';
protobuf.common('google/protobuf/descriptor.proto', {});

interface Proto {
  Slash: protobuf.Type;
  Reward: protobuf.Type;
  AccountAmtPair: protobuf.Type;
}

async function getProtos(): Promise<Proto> {
  const staking = await protobuf.load(`${__dirname}/../../contracts/libraries/proto/staking.proto`);

  const Slash = staking.lookupType('staking.Slash');
  const Reward = staking.lookupType('staking.Reward');
  const AccountAmtPair = staking.lookupType('staking.AccountAmtPair');

  return {
    Slash,
    Reward,
    AccountAmtPair
  };
}

function hex2Bytes(hexString: string) {
  const result = [];
  if (hexString.substr(0, 2) === '0x') {
    hexString = hexString.slice(2);
  }
  if (hexString.length % 2 === 1) {
    hexString = '0' + hexString;
  }
  for (let i = 0; i < hexString.length; i += 2) {
    result.push(parseInt(hexString.substr(i, 2), 16));
  }
  return result;
}

function uint2Bytes(x: BigNumber) {
  return hex2Bytes(x.toHexString());
}

async function getAccountAmtPairs(accounts: string[], amounts: BigNumber[]) {
  const { AccountAmtPair } = await getProtos();
  expect(accounts.length).to.equal(amounts.length);
  const pairs = [];
  for (let i = 0; i < accounts.length; i++) {
    const pair = {
      account: hex2Bytes(accounts[i]),
      amt: uint2Bytes(amounts[i])
    };
    const pairProto = AccountAmtPair.create(pair);
    pairs.push(pairProto);
  }
  return pairs;
}

async function calculateSignatures(signers: Wallet[], hash: number[]) {
  const sigs = [];
  for (let i = 0; i < signers.length; i++) {
    const sig = await signers[i].signMessage(hash);
    sigs.push(hex2Bytes(sig));
  }
  return sigs;
}

export async function getRewardRequest(recipient: string, cumulativeReward: BigNumber, signers: Wallet[]) {
  const { Reward } = await getProtos();
  const reward = {
    recipient: hex2Bytes(recipient),
    cumulativeReward: uint2Bytes(cumulativeReward)
  };
  const rewardProto = Reward.create(reward);
  const rewardBytes = Reward.encode(rewardProto).finish();

  const rewardBytesHash = keccak256(['bytes'], [rewardBytes]);
  const sigs = await calculateSignatures(signers, hex2Bytes(rewardBytesHash));

  return { rewardBytes, sigs };
}

export async function getSlashRequest(
  validatorAddr: string,
  nonce: number,
  slashFactor: number,
  infractionBlock: number,
  timeout: number,
  beneficiaryAddrs: string[],
  beneficiaryAmts: BigNumber[],
  signers: Wallet[]
) {
  const { Slash } = await getProtos();

  const beneficiaries = await getAccountAmtPairs(beneficiaryAddrs, beneficiaryAmts);
  const slash = {
    validatorAddr: hex2Bytes(validatorAddr),
    nonce: nonce,
    slashFactor: slashFactor,
    infractionBlock: infractionBlock,
    timeout: timeout,
    beneficiaries: beneficiaries
  };
  const slashProto = Slash.create(slash);
  const slashBytes = Slash.encode(slashProto).finish();

  const slashBytesHash = keccak256(['bytes'], [slashBytes]);
  const sigs = await calculateSignatures(signers, hex2Bytes(slashBytesHash));

  return { slashBytes, sigs };
}
