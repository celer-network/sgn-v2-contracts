import { expect } from 'chai';
import { BigNumber } from 'ethers';
import { parseUnits } from 'ethers/lib/utils';
import { ethers } from 'hardhat';

import { keccak256 } from '@ethersproject/solidity';
import { Wallet } from '@ethersproject/wallet';

import { Bridge, DummySwap, MessageBus, TestERC20, TransferSwap } from '../typechain';
import { deplayMessageContracts as deployMessageContracts, getAccounts, loadFixture } from './lib/common';

async function swapFixture([admin]: Wallet[]) {
  const res = await deployMessageContracts(admin);
  return { admin, ...res };
}

function computeId(sender: string, srcChainId: number, dstChainId: number, nonce: number, message: string) {
  return keccak256(
    ['address', 'uint64', 'uint64', 'uint64', 'bytes'],
    [sender, srcChainId, dstChainId, nonce, message]
  );
}

function encodeMessage(
  dstSwap: { dex: string; path: string[]; deadline: BigNumber; minRecvAmt: BigNumber },
  receiver: string
) {
  return ethers.utils.defaultAbiCoder.encode(
    ['Swap(address dex, address[] path, uint256 deadline, uint256 minRecvAmt) swap', 'address receiver'],
    [dstSwap, receiver]
  );
}

describe('Cross Chain Swap Tests', function () {
  let bus: MessageBus;
  let tokenA: TestERC20;
  let tokenB: TestERC20;
  let xswap: TransferSwap;
  let dex: DummySwap;
  let bridge: Bridge;
  let accounts: Wallet[];

  beforeEach(async () => {
    const res = await loadFixture(swapFixture);
    bus = res.bus;
    tokenA = res.tokenA;
    tokenB = res.tokenB;
    xswap = res.transferSwap;
    dex = res.swap;
    bridge = res.bridge;
    accounts = await getAccounts(res.admin, [tokenA], 4);

    await xswap.setMsgBus(bus.address);
    console.log('setting dex fake slippage to 5%');
    await dex.setFakeSlippage(parseUnits('5'));
  });

  it('should revert if paths are empty', async function () {
    const amountIn = parseUnits('100');
    const srcSwap = {
      dex: dex.address,
      path: [] as string[],
      deadline: BigNumber.from(0),
      minRecvAmt: amountIn.mul(parseUnits('90')).div(parseUnits('100'))
    };
    const dstSwap = {
      dex: dex.address,
      path: [tokenA.address, tokenB.address],
      deadline: BigNumber.from(0),
      minRecvAmt: amountIn.mul(parseUnits('90')).div(parseUnits('100'))
    };
    const maxBridgeSlippage = parseUnits('1', 6); // 100%
    const dstChainId = 2; // doesn't matter
    const receiver = accounts[1];
    const nonce = 0;

    await expect(
      xswap.transferWithSwap(receiver.address, amountIn, dstChainId, srcSwap, dstSwap, maxBridgeSlippage, nonce)
    ).to.be.revertedWith('empty src swap path');

    srcSwap.path = [tokenA.address, tokenB.address];
    dstSwap.path = [];
    await expect(
      xswap.transferWithSwap(receiver.address, amountIn, dstChainId, srcSwap, dstSwap, maxBridgeSlippage, nonce)
    ).to.be.revertedWith('empty dst swap path');
  });

  it('should revert if path token addresses mismatch', async function () {
    const amountIn = parseUnits('100');
    const srcSwap = {
      dex: dex.address,
      path: [tokenA.address, tokenB.address],
      deadline: BigNumber.from(0),
      minRecvAmt: amountIn.mul(parseUnits('90')).div(parseUnits('100'))
    };
    const dstSwap = srcSwap;
    const maxBridgeSlippage = parseUnits('1', 6); // 100%
    const dstChainId = 2; // doesn't matter
    const receiver = accounts[1];
    const nonce = 0;
    console.log('transferWithSwap');
    await expect(
      xswap.transferWithSwap(receiver.address, amountIn, dstChainId, srcSwap, dstSwap, maxBridgeSlippage, nonce)
    ).to.be.revertedWith('srcSwap.path[len - 1] and dstSwap.path[0] must be the same');
  });

  it('should emit SwapRequestSent and Send event on transferWithSwap', async function () {
    const amountIn = parseUnits('100');
    const srcSwap = {
      dex: dex.address,
      path: [tokenA.address, tokenB.address],
      deadline: BigNumber.from(0),
      minRecvAmt: amountIn.mul(parseUnits('90')).div(parseUnits('100'))
    };
    const dstSwap = srcSwap;
    const maxBridgeSlippage = parseUnits('1', 6); // 100%
    const srcChainId = 1;
    const dstChainId = 2; // doesn't matter
    const sender = accounts[0];
    const receiver = accounts[1];
    const nonce = 0;

    console.log('transferWithSwap');
    const tx = await xswap.transferWithSwap(
      receiver.address,
      amountIn,
      dstChainId,
      srcSwap,
      dstSwap,
      maxBridgeSlippage,
      nonce
    );
    const message = encodeMessage(dstSwap, receiver.address);
    const id = computeId(sender.address, srcChainId, dstChainId, nonce, message);

    // check TransferSwap's SwapRequestSent event
    await expect(tx)
      .to.emit(xswap, 'SwapRequestSent')
      .withArgs(id, dstChainId, amountIn, srcSwap.path[0], dstSwap.path[1]);

    // check Bridge's Send event
    const srcXferId = keccak256(
      ['address', 'address', 'address', 'uint256', 'uint64', 'uint64', 'uint64'],
      [sender.address, receiver.address, tokenB.address, amountIn, dstChainId, nonce, srcChainId]
    );
    const expectedSendAmt = amountIn.mul(parseUnits('95')).div(parseUnits('100'));
    await expect(tx)
      .to.emit(bridge, 'Send')
      .withArgs(
        srcXferId,
        sender.address,
        receiver.address,
        tokenB.address,
        expectedSendAmt,
        dstChainId,
        nonce,
        maxBridgeSlippage
      );
  });

  it('should emit SwapRequestDone on executeMessageWithTransfer', async function () {
    const amount = parseUnits('100');
    const srcChainId = 1;
    const nonce = 0;
    const dstSwap = {
      dex: dex.address,
      path: [tokenA.address, tokenB.address],
      deadline: BigNumber.from(0),
      minRecvAmt: amount.mul(parseUnits('90')).div(parseUnits('100'))
    };
    const message = ethers.utils.defaultAbiCoder.encode(
      ['Swap(address dex, address[] path, uint256 deadline, uint256 minRecvAmt) swap', 'address receiver'],
      [dstSwap, accounts[1]]
    );
    const tx = await xswap.executeMessageWithTransfer(accounts[0].address, tokenB.address, amount, srcChainId, message);

    const id = computeId(accounts[0].address, srcChainId, srcChainId, nonce, message);
    const dstAmount = amount.mul(parseUnits('95')).div(parseUnits('100'));
    await expect(tx).to.emit(xswap, 'SwapRequestDone').withArgs(id, dstAmount);
  });
});
