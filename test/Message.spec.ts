import { expect } from 'chai';
import { ethers } from 'hardhat';

import { BigNumber } from '@ethersproject/bignumber';
import { keccak256, pack } from '@ethersproject/solidity';
import { parseUnits } from '@ethersproject/units';
import { Wallet } from '@ethersproject/wallet';

import { Bridge, TestERC20, MessageBus, MsgTest } from '../typechain';
import { deployMessageContracts, loadFixture } from './lib/common';
import { calculateSignatures, hex2Bytes } from './lib/proto';

type RouteInfoStruct = {
  sender: string;
  receiver: string;
  srcChainId: number;
  srcTxHash: string;
};

describe('Message Tests', function () {
  async function fixture([admin]: Wallet[]) {
    const { bridge, msgbus, msgtest, token } = await deployMessageContracts(admin);
    await bridge.resetSigners([admin.address], [parseUnits('1')]);
    return { admin, bridge, msgbus, msgtest, token };
  }

  let admin: Wallet;
  let bridge: Bridge;
  let msgbus: MessageBus;
  let msgtest: MsgTest;
  let token: TestERC20;
  let chainId: number;

  beforeEach(async () => {
    const res = await loadFixture(fixture);
    admin = res.admin;
    bridge = res.bridge;
    token = res.token;
    msgbus = res.msgbus;
    msgtest = res.msgtest;
    chainId = (await ethers.provider.getNetwork()).chainId;
  });

  it('should execute msg successfully', async function () {
    const hash = keccak256(['string'], ['hello']);
    const srcChainId = 5;
    const routeInfo = {
      sender: admin.address,
      receiver: msgtest.address,
      srcChainId: srcChainId,
      srcTxHash: hash // fake tx hash
    };
    let nonce = 1;
    let message = ethers.utils.defaultAbiCoder.encode(['uint64', 'bytes'], [nonce, hash]);
    let res = await computeMessageIdAndSigs(chainId, msgbus.address, routeInfo, message, [admin]);
    await expect(msgbus.executeMessage(message, routeInfo, res.sigs, [admin.address], [parseUnits('1')]))
      .to.emit(msgtest, 'MessageReceived')
      .withArgs(admin.address, srcChainId, nonce, hash)
      .to.emit(msgbus, 'Executed')
      .withArgs(1, res.messageId, 1, msgtest.address, srcChainId, hash);

    nonce = 100000000000001;
    message = ethers.utils.defaultAbiCoder.encode(['uint64', 'bytes'], [nonce, hash]);
    res = await computeMessageIdAndSigs(chainId, msgbus.address, routeInfo, message, [admin]);
    await expect(msgbus.executeMessage(message, routeInfo, res.sigs, [admin.address], [parseUnits('1')]))
      .to.emit(msgbus, 'CallReverted')
      .withArgs('invalid nonce')
      .to.emit(msgbus, 'Executed')
      .withArgs(1, res.messageId, 2, msgtest.address, srcChainId, hash);

    nonce = 100000000000002;
    message = ethers.utils.defaultAbiCoder.encode(['uint64', 'bytes'], [nonce, hash]);
    res = await computeMessageIdAndSigs(chainId, msgbus.address, routeInfo, message, [admin]);
    await expect(msgbus.executeMessage(message, routeInfo, res.sigs, [admin.address], [parseUnits('1')]))
      .to.emit(msgbus, 'CallReverted')
      .withArgs('Transaction reverted silently')
      .to.emit(msgbus, 'Executed')
      .withArgs(1, res.messageId, 2, msgtest.address, srcChainId, hash);
  });
});

async function computeMessageIdAndSigs(
  chainId: number,
  msgbus: string,
  route: RouteInfoStruct,
  message: string,
  signers: Wallet[]
) {
  const messageId = keccak256(
    ['uint8', 'address', 'address', 'uint64', 'bytes32', 'uint64', 'bytes'],
    [1, route.sender, route.receiver, route.srcChainId, route.srcTxHash, chainId, message]
  );
  const domain = keccak256(['uint256', 'address', 'string'], [chainId, msgbus, 'Message']);
  const signedData = pack(['bytes32', 'bytes32'], [domain, messageId]);
  const signedDataHash = keccak256(['bytes'], [signedData]);
  const sigs = await calculateSignatures(signers, hex2Bytes(signedDataHash));
  return { messageId, sigs };
}
