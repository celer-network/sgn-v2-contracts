import { expect } from 'chai';
import { BigNumber } from 'ethers';
import { parseUnits } from 'ethers/lib/utils';
import { ethers } from 'hardhat';

import { keccak256 } from '@ethersproject/solidity';
import { Wallet } from '@ethersproject/wallet';

import { Bridge, DummySwap, MessageBus, TestERC20, TransferSwap } from '../typechain';
import { deplayMessageContracts as deployMessageContracts, getAccounts, loadFixture } from './lib/common';

const UINT64_MAX = '9223372036854775807';

async function swapFixture([admin]: Wallet[]) {
  const res = await deployMessageContracts(admin);
  return { admin, ...res };
}

function computeId(sender: string, srcChainId: number, dstChainId: number, message: string) {
  return keccak256(['address', 'uint64', 'uint64', 'bytes'], [sender, srcChainId, dstChainId, message]);
}

function encodeMessage(
  dstSwap: { dex: string; path: string[]; deadline: BigNumber; minRecvAmt: BigNumber },
  receiver: string,
  nonce: number
) {
  const encoded = ethers.utils.defaultAbiCoder.encode(
    ['(address, address[], uint256, uint256, address, uint64)'],
    [[dstSwap.dex, dstSwap.path, dstSwap.deadline, dstSwap.minRecvAmt, receiver, nonce]]
  );
  return encoded;
}

function slip(amount: BigNumber, perc: number) {
  const percent = 100 - perc;
  return amount.mul(parseUnits(percent.toString(), 4)).div(parseUnits('100', 4));
}

let bus: MessageBus;
let tokenA: TestERC20;
let tokenB: TestERC20;
let xswap: TransferSwap;
let dex: DummySwap;
let bridge: Bridge;
let accounts: Wallet[];
let admin: Wallet;
let chainId: number;
let sender: Wallet;
let receiver: Wallet;

let amountIn: BigNumber;
const maxBridgeSlippage = parseUnits('100', 4); // 100%
interface Swap {
  dex: string;
  path: string[];
  deadline: BigNumber;
  minRecvAmt: BigNumber;
}
let srcSwap: Swap;
let dstSwap: Swap;

async function prepare() {
  const res = await loadFixture(swapFixture);
  admin = res.admin;
  bus = res.bus;
  tokenA = res.tokenA;
  tokenB = res.tokenB;
  xswap = res.transferSwap;
  dex = res.swap;
  bridge = res.bridge;
  accounts = await getAccounts(res.admin, [tokenA, tokenB], 4);
  chainId = (await ethers.provider.getNetwork()).chainId;
  sender = accounts[0];
  receiver = accounts[1];
  amountIn = parseUnits('100');

  srcSwap = {
    dex: dex.address,
    path: [] as string[],
    deadline: BigNumber.from(UINT64_MAX),
    minRecvAmt: slip(amountIn, 10)
  };
  dstSwap = {
    dex: dex.address,
    path: [tokenA.address, tokenB.address],
    deadline: BigNumber.from(UINT64_MAX),
    minRecvAmt: slip(amountIn, 10)
  };

  await xswap.setMsgBus(bus.address);
  await xswap.setLiquidityBridge(bridge.address);
  await xswap.setTokenBridgeType(tokenA.address, 1);
  await xswap.setTokenBridgeType(tokenB.address, 1);
  await xswap.setMinSwapAmount(tokenA.address, parseUnits('10'));

  await dex.setFakeSlippage(parseUnits('5', 4));

  await tokenA.connect(res.admin).transfer(dex.address, parseUnits('1000'));
  await tokenB.connect(res.admin).transfer(dex.address, parseUnits('1000'));
  return { admin, bus, tokenA, tokenB, xswap, dex, bridge, accounts, chainId };
}

describe('Test transferWithSwap', function () {
  let srcChainId: number;
  const dstChainId = 2; // doesn't matter

  beforeEach(async () => {
    await prepare();
    srcChainId = chainId;
  });

  it('should revert if paths are empty', async function () {
    srcSwap.path = [];
    dstSwap.path = [tokenA.address, tokenB.address];

    const maxBridgeSlippage = parseUnits('1', 6); // 100%

    await expect(
      xswap.transferWithSwap(receiver.address, amountIn, dstChainId, srcSwap, dstSwap, maxBridgeSlippage)
    ).to.be.revertedWith('empty src swap path');

    srcSwap.path = [tokenA.address, tokenB.address];
    dstSwap.path = [];
    await expect(
      xswap.transferWithSwap(receiver.address, amountIn, dstChainId, srcSwap, dstSwap, maxBridgeSlippage)
    ).to.be.revertedWith('empty dst swap path');
  });

  it('should revert if path token addresses mismatch', async function () {
    srcSwap.path = [tokenA.address, tokenB.address];
    dstSwap.path = [tokenA.address, tokenB.address];
    await expect(
      xswap.transferWithSwap(receiver.address, amountIn, dstChainId, srcSwap, dstSwap, maxBridgeSlippage)
    ).to.be.revertedWith('srcSwap.path[len - 1] and dstSwap.path[0] must be the same');
  });

  it('should revert if min swap amount is not satisfied', async function () {
    amountIn = parseUnits('5');
    srcSwap.path = [tokenA.address, tokenB.address];
    dstSwap.path = [tokenB.address, tokenA.address];
    await expect(
      xswap.transferWithSwap(receiver.address, amountIn, dstChainId, srcSwap, dstSwap, maxBridgeSlippage)
    ).to.be.revertedWith('amount has to be greateer than min swap amount');
  });

  it('should swap and send', async function () {
    srcSwap.path = [tokenA.address, tokenB.address];
    dstSwap.path = [tokenB.address, tokenA.address];

    await tokenA.connect(sender).approve(xswap.address, amountIn);
    const tx = await xswap
      .connect(sender)
      .transferWithSwap(receiver.address, amountIn, dstChainId, srcSwap, dstSwap, maxBridgeSlippage);
    const expectedNonce = 1;
    const message = encodeMessage(dstSwap, receiver.address, expectedNonce);
    const id = computeId(sender.address, srcChainId, dstChainId, message);

    const expectedSendAmt = slip(amountIn, 5);
    await expect(tx)
      .to.emit(xswap, 'SwapRequestSent')
      .withArgs(id, dstChainId, expectedSendAmt, srcSwap.path[0], dstSwap.path[1]);

    const srcXferId = keccak256(
      ['address', 'address', 'address', 'uint256', 'uint64', 'uint64', 'uint64'],
      [xswap.address, receiver.address, tokenB.address, expectedSendAmt, dstChainId, expectedNonce, srcChainId]
    );
    await expect(tx)
      .to.emit(bridge, 'Send')
      .withArgs(
        srcXferId,
        xswap.address,
        receiver.address,
        tokenB.address,
        expectedSendAmt,
        dstChainId,
        expectedNonce,
        maxBridgeSlippage
      );
  });

  it('should directly send', async function () {
    srcSwap.path = [tokenB.address];
    dstSwap.path = [tokenB.address, tokenA.address];

    await tokenB.connect(sender).approve(xswap.address, amountIn);
    const tx = await xswap
      .connect(sender)
      .transferWithSwap(receiver.address, amountIn, dstChainId, srcSwap, dstSwap, maxBridgeSlippage);
    const expectedNonce = 1;
    const message = encodeMessage(dstSwap, receiver.address, expectedNonce);
    const id = computeId(sender.address, srcChainId, dstChainId, message);

    await expect(tx)
      .to.emit(xswap, 'SwapRequestSent')
      .withArgs(id, dstChainId, amountIn, srcSwap.path[0], dstSwap.path[1]);

    const srcXferId = keccak256(
      ['address', 'address', 'address', 'uint256', 'uint64', 'uint64', 'uint64'],
      [xswap.address, receiver.address, tokenB.address, amountIn, dstChainId, expectedNonce, srcChainId]
    );
    await expect(tx)
      .to.emit(bridge, 'Send')
      .withArgs(
        srcXferId,
        xswap.address,
        receiver.address,
        tokenB.address,
        amountIn,
        dstChainId,
        expectedNonce,
        maxBridgeSlippage
      );
  });
});

describe('Test executeMessageWithTransfer', function () {
  beforeEach(async () => {
    await prepare();
    // impersonate msgbus as admin to gain access to calling executeMessageWithTransfer
    await xswap.connect(admin).setMsgBus(admin.address);
  });

  const srcChainId = 1;
  const nonce = 1;

  it('should swap', async function () {
    dstSwap.path = [tokenA.address, tokenB.address];
    const message = encodeMessage(dstSwap, receiver.address, nonce);

    const bridgeBalBefore = await tokenB.connect(admin).balanceOf(receiver.address);
    await tokenA.connect(admin).transfer(xswap.address, amountIn);
    const tx = await xswap
      .connect(admin)
      .executeMessageWithTransfer(accounts[0].address, tokenA.address, amountIn, srcChainId, message);
    const bridgeBalAfter = await tokenB.connect(admin).balanceOf(receiver.address);

    const id = computeId(accounts[0].address, srcChainId, chainId, message);
    const dstAmount = slip(amountIn, 5);
    await expect(tx).to.emit(xswap, 'SwapRequestDone').withArgs(id, dstAmount);
    await expect(bridgeBalAfter).to.equal(bridgeBalBefore.add(dstAmount));
  });

  it('should directly transfer to receiver', async function () {
    dstSwap.path = [tokenA.address];
    const message = encodeMessage(dstSwap, receiver.address, nonce);
    await tokenA.connect(admin).transfer(xswap.address, amountIn);

    const recvBalBefore = await tokenA.connect(receiver).balanceOf(receiver.address);
    const tx = await xswap
      .connect(admin)
      .executeMessageWithTransfer(accounts[0].address, tokenA.address, amountIn, srcChainId, message);
    const recvBalAfter = await tokenA.connect(receiver).balanceOf(receiver.address);
    const id = computeId(accounts[0].address, srcChainId, chainId, message);
    await expect(tx).to.emit(xswap, 'SwapRequestDone').withArgs(id, amountIn);
    await expect(recvBalAfter).to.equal(recvBalBefore.add(amountIn));
  });
});
