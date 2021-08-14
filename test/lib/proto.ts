import { expect } from 'chai';
import { keccak256 } from '@ethersproject/solidity';
import { Wallet } from '@ethersproject/wallet';
import { BigNumber, BigNumberish } from '@ethersproject/bignumber';

import protobuf from 'protobufjs';
protobuf.common('google/protobuf/descriptor.proto', {});

interface Proto {
  Penalty: protobuf.Type;
  Reward: protobuf.Type;
  AccountAmtPair: protobuf.Type;
}

async function getProtos(): Promise<Proto> {
  const sgn = await protobuf.load(`${__dirname}/../../contracts/libraries/proto/sgn.proto`);

  const Penalty = sgn.lookupType('sgn.Penalty');
  const Reward = sgn.lookupType('sgn.Reward');
  const AccountAmtPair = sgn.lookupType('sgn.AccountAmtPair');

  return {
    Penalty,
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

export async function getPenaltyRequest(
  nonce: number,
  expireTime: number,
  validatorAddr: string,
  delegatorAddrs: string[],
  delegatorAmts: BigNumber[],
  beneficiaryAddrs: string[],
  beneficiaryAmts: BigNumber[],
  signers: Wallet[]
) {
  const { Penalty } = await getProtos();

  const penalizedDelegators = await getAccountAmtPairs(delegatorAddrs, delegatorAmts);
  const beneficiaries = await getAccountAmtPairs(beneficiaryAddrs, beneficiaryAmts);
  const penalty = {
    nonce: nonce,
    expireTime: expireTime,
    validatorAddress: hex2Bytes(validatorAddr),
    penalizedDelegators: penalizedDelegators,
    beneficiaries: beneficiaries
  };
  const penaltyProto = Penalty.create(penalty);
  const penaltyBytes = Penalty.encode(penaltyProto).finish();

  const penaltyBytesHash = keccak256(['bytes'], [penaltyBytes]);
  const sigs = await calculateSignatures(signers, hex2Bytes(penaltyBytesHash));

  return { penaltyBytes, sigs };
}
