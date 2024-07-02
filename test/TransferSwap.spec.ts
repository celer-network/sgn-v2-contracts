import { expect } from 'chai';
import { AbiCoder, parseUnits, solidityPackedKeccak256, toNumber, Wallet, ZeroAddress } from 'ethers';
import { ethers } from 'hardhat';
import { Address } from 'hardhat-deploy/types';

import { HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers';
import { loadFixture } from '@nomicfoundation/hardhat-toolbox/network-helpers';

import { Bridge, DummySwap, TestERC20, TransferSwap, WETH } from '../typechain';
import { deploySwapContracts, getAccounts } from './lib/common';

const UINT64_MAX = '9223372036854775807';

const abiCoder = AbiCoder.defaultAbiCoder();

async function swapFixture() {
  const [admin] = await ethers.getSigners();
  const res = await deploySwapContracts(admin);
  return { admin, ...res };
}

function computeId(sender: string, srcChainId: number, dstChainId: number, message: string) {
  return solidityPackedKeccak256(['address', 'uint64', 'uint64', 'bytes'], [sender, srcChainId, dstChainId, message]);
}

function computeDirectSwapId(sender: string, srcChainId: number, receiver: Address, nonce: number, swap: Swap) {
  const swapStruct = [swap.path, swap.dex, swap.deadline, swap.minRecvAmt];
  const encoded = abiCoder.encode(
    ['address', 'uint64', 'address', 'uint64', '(address[], address, uint256, uint256)'],
    [sender, srcChainId, receiver, nonce, swapStruct]
  );
  return solidityPackedKeccak256(['bytes'], [encoded]);
}

function encodeMessage(
  dstSwap: { dex: string; path: string[]; deadline: bigint; minRecvAmt: bigint },
  receiver: string,
  nonce: number,
  nativeOut: boolean
) {
  const encoded = abiCoder.encode(
    ['((address[], address , uint256, uint256), address, uint64, bool)'],
    [[[dstSwap.path, dstSwap.dex, dstSwap.deadline, dstSwap.minRecvAmt], receiver, nonce, nativeOut]]
  );
  return encoded;
}

function slip(amount: bigint, perc: number) {
  const percent = 100 - perc;
  return (amount * parseUnits(percent.toString(), 4)) / parseUnits('100', 4);
}

let tokenA: TestERC20;
let tokenB: TestERC20;
let xswap: TransferSwap;
let dex: DummySwap;
let bridge: Bridge;
let accounts: Wallet[];
let admin: HardhatEthersSigner;
let chainId: number;
let sender: Wallet;
let receiver: Wallet;
let weth: WETH;

let amountIn: bigint;
const maxBridgeSlippage = parseUnits('100', 4); // 100%
const expectNonce = 1;

interface Swap {
  dex: string;
  path: string[];
  deadline: bigint;
  minRecvAmt: bigint;
}
let srcSwap: Swap;
let dstSwap: Swap;

async function prepare() {
  const res = await loadFixture(swapFixture);
  admin = res.admin;
  tokenA = res.tokenA;
  tokenB = res.tokenB;
  weth = res.weth;
  xswap = res.transferSwap;
  dex = res.swap;
  bridge = res.bridge;
  accounts = await getAccounts(res.admin, [tokenA, tokenB], 4);
  chainId = toNumber((await ethers.provider.getNetwork()).chainId);
  sender = accounts[0];
  receiver = accounts[1];
  amountIn = parseUnits('100');

  srcSwap = {
    dex: await dex.getAddress(),
    path: [] as string[],
    deadline: BigInt(UINT64_MAX),
    minRecvAmt: slip(amountIn, 10)
  };
  dstSwap = {
    dex: await dex.getAddress(),
    path: [await tokenA.getAddress(), await tokenB.getAddress()],
    deadline: BigInt(UINT64_MAX),
    minRecvAmt: slip(amountIn, 10)
  };

  await xswap.setMinSwapAmount(tokenA.getAddress(), parseUnits('10'));
  await xswap.setSupportedDex(dex.getAddress(), true);

  await dex.setFakeSlippage(parseUnits('5', 4));

  await tokenA.connect(res.admin).transfer(dex.getAddress(), parseUnits('1000'));
  await tokenB.connect(res.admin).transfer(dex.getAddress(), parseUnits('1000'));
  await weth.connect(res.admin).deposit({ value: parseUnits('100') });
  await weth.connect(res.admin).transfer(dex.getAddress(), parseUnits('100'));
  return { admin, tokenA, tokenB, xswap, dex, bridge, accounts, chainId };
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
    dstSwap.path = [await tokenA.getAddress(), await tokenB.getAddress()];
    await tokenA.connect(sender).approve(xswap.getAddress(), amountIn);
    await expect(
      xswap
        .connect(sender)
        .transferWithSwap(receiver.address, amountIn, dstChainId, srcSwap, dstSwap, maxBridgeSlippage, 1)
    ).to.be.reverted;
  });

  it('should revert if min swap amount is not satisfied', async function () {
    amountIn = parseUnits('5');
    srcSwap.path = [await tokenA.getAddress(), await tokenB.getAddress()];
    dstSwap.path = [await tokenB.getAddress(), await tokenA.getAddress()];
    await tokenA.connect(sender).approve(xswap.getAddress(), amountIn);
    await expect(
      xswap
        .connect(sender)
        .transferWithSwap(receiver.address, amountIn, dstChainId, srcSwap, dstSwap, maxBridgeSlippage, 1)
    ).to.be.revertedWith('amount must be greater than min swap amount');
  });

  it('should swap and send', async function () {
    srcSwap.path = [await tokenA.getAddress(), await tokenB.getAddress()];
    dstSwap.path = [await tokenB.getAddress(), await tokenA.getAddress()];

    await tokenA.connect(sender).approve(xswap.getAddress(), amountIn);
    const tx = await xswap
      .connect(sender)
      .transferWithSwap(receiver.address, amountIn, dstChainId, srcSwap, dstSwap, maxBridgeSlippage, 1);
    const message = encodeMessage(dstSwap, sender.address, expectNonce, false);
    const expectId = computeId(sender.address, srcChainId, dstChainId, message);

    await expect(tx)
      .to.emit(xswap, 'SwapRequestSent')
      .withArgs(expectId, dstChainId, amountIn, srcSwap.path[0], dstSwap.path[1]);

    const expectedSendAmt = slip(amountIn, 5);
    const srcXferId = solidityPackedKeccak256(
      ['address', 'address', 'address', 'uint256', 'uint64', 'uint64', 'uint64'],
      [
        await xswap.getAddress(),
        receiver.address,
        await tokenB.getAddress(),
        expectedSendAmt,
        dstChainId,
        expectNonce,
        srcChainId
      ]
    );
    await expect(tx)
      .to.emit(bridge, 'Send')
      .withArgs(
        srcXferId,
        xswap.getAddress(),
        receiver.address,
        tokenB.getAddress(),
        expectedSendAmt,
        dstChainId,
        expectNonce,
        maxBridgeSlippage
      );
  });

  it('should directly send', async function () {
    srcSwap.path = [await tokenB.getAddress()];
    dstSwap.path = [await tokenB.getAddress(), await tokenA.getAddress()];

    await tokenB.connect(sender).approve(xswap.getAddress(), amountIn);
    const tx = await xswap
      .connect(sender)
      .transferWithSwap(receiver.address, amountIn, dstChainId, srcSwap, dstSwap, maxBridgeSlippage, 1);
    const message = encodeMessage(dstSwap, sender.address, expectNonce, false);
    const id = computeId(sender.address, srcChainId, dstChainId, message);

    await expect(tx)
      .to.emit(xswap, 'SwapRequestSent')
      .withArgs(id, dstChainId, amountIn, srcSwap.path[0], dstSwap.path[1]);

    const srcXferId = solidityPackedKeccak256(
      ['address', 'address', 'address', 'uint256', 'uint64', 'uint64', 'uint64'],
      [
        await xswap.getAddress(),
        receiver.address,
        await tokenB.getAddress(),
        amountIn,
        dstChainId,
        expectNonce,
        srcChainId
      ]
    );
    await expect(tx)
      .to.emit(bridge, 'Send')
      .withArgs(
        srcXferId,
        xswap.getAddress(),
        receiver.address,
        tokenB.getAddress(),
        amountIn,
        dstChainId,
        expectNonce,
        maxBridgeSlippage
      );
  });

  it('should directly swap', async function () {
    srcSwap.path = [await tokenA.getAddress(), await tokenB.getAddress()];
    dstSwap.path = [];

    await tokenA.connect(sender).approve(xswap.getAddress(), amountIn);
    const recvBalBefore = await tokenB.connect(receiver).balanceOf(receiver.address);
    const tx = await xswap
      .connect(sender)
      .transferWithSwap(receiver.address, amountIn, chainId, srcSwap, dstSwap, maxBridgeSlippage, 1);
    const recvBalAfter = await tokenB.connect(receiver).balanceOf(receiver.address);
    const expectId = computeDirectSwapId(sender.address, srcChainId, receiver.address, expectNonce, srcSwap);

    await expect(tx).to.not.emit(xswap, 'SwapRequestSent');
    await expect(tx).to.not.emit(bridge, 'Send');
    await expect(tx)
      .to.emit(xswap, 'DirectSwap')
      .withArgs(expectId, chainId, amountIn, tokenA.getAddress(), slip(amountIn, 5), tokenB.getAddress());
    expect(recvBalAfter).equal(recvBalBefore + slip(amountIn, 5));
  });

  it('should revert if the tx results in a noop', async function () {
    srcSwap.path = [await tokenA.getAddress()];
    dstSwap.path = [];

    await tokenA.connect(sender).approve(xswap.getAddress(), amountIn);
    await expect(
      xswap
        .connect(sender)
        .transferWithSwap(receiver.address, amountIn, chainId, srcSwap, dstSwap, maxBridgeSlippage, 1)
    ).to.be.revertedWith('noop is not allowed');
  });
});

describe('Test transferWithSwapNative', function () {
  let srcChainId: number;
  const dstChainId = 2; // doesn't matter

  const amountIn2 = parseUnits('10');

  beforeEach(async () => {
    await prepare();
    srcChainId = chainId;
  });

  it('should revert if native in does not match amountIn (native in)', async function () {
    srcSwap.path = [await weth.getAddress(), await tokenB.getAddress()];
    dstSwap.path = [await tokenB.getAddress(), await weth.getAddress()];

    await expect(
      xswap
        .connect(sender)
        .transferWithSwapNative(receiver.address, amountIn2, dstChainId, srcSwap, dstSwap, maxBridgeSlippage, 1, true, {
          value: amountIn2 / 2n
        })
    ).to.be.revertedWith('Amount insufficient');
  });

  it('should swap and send (native in)', async function () {
    srcSwap.path = [await weth.getAddress(), await tokenB.getAddress()];
    srcSwap.minRecvAmt = slip(amountIn2, 10);
    dstSwap.path = [await tokenB.getAddress(), await weth.getAddress()];
    dstSwap.minRecvAmt = slip(amountIn2, 10);

    const balBefore = await ethers.provider.getBalance(sender);
    const tx = await xswap
      .connect(sender)
      .transferWithSwapNative(receiver.address, amountIn2, dstChainId, srcSwap, dstSwap, maxBridgeSlippage, 1, true, {
        value: amountIn2
      });

    const balAfter = await ethers.provider.getBalance(sender);
    expect(balAfter <= balBefore - amountIn2);
    const message = encodeMessage(dstSwap, sender.address, expectNonce, true);
    const expectId = computeId(sender.address, srcChainId, dstChainId, message);

    await expect(tx)
      .to.emit(xswap, 'SwapRequestSent')
      .withArgs(expectId, dstChainId, amountIn2, srcSwap.path[0], dstSwap.path[1]);

    const expectedSendAmt = slip(amountIn2, 5);
    const srcXferId = solidityPackedKeccak256(
      ['address', 'address', 'address', 'uint256', 'uint64', 'uint64', 'uint64'],
      [
        await xswap.getAddress(),
        receiver.address,
        await tokenB.getAddress(),
        expectedSendAmt,
        dstChainId,
        expectNonce,
        srcChainId
      ]
    );
    await expect(tx)
      .to.emit(bridge, 'Send')
      .withArgs(
        srcXferId,
        xswap.getAddress(),
        receiver.address,
        tokenB.getAddress(),
        expectedSendAmt,
        dstChainId,
        expectNonce,
        maxBridgeSlippage
      );
  });
});

describe('Test executeMessageWithTransfer', function () {
  beforeEach(async () => {
    await prepare();
    // impersonate MessageBus as admin to gain access to calling executeMessageWithTransfer
    await xswap.connect(admin).setMessageBus(admin.address);
  });

  const srcChainId = 1;

  it('should swap', async function () {
    dstSwap.path = [await tokenA.getAddress(), await tokenB.getAddress()];
    const message = encodeMessage(dstSwap, receiver.address, expectNonce, false);

    const balB1 = await tokenB.connect(admin).balanceOf(receiver.address);
    await tokenA.connect(admin).transfer(xswap.getAddress(), amountIn);
    const tx = await xswap
      .connect(admin)
      .executeMessageWithTransfer(ZeroAddress, tokenA.getAddress(), amountIn, srcChainId, message, ZeroAddress);
    const balB2 = await tokenB.connect(admin).balanceOf(receiver.address);
    const id = computeId(receiver.address, srcChainId, chainId, message);
    const dstAmount = slip(amountIn, 5);
    const expectStatus = 1; // SwapStatus.Succeeded
    await expect(tx).to.emit(xswap, 'SwapRequestDone').withArgs(id, dstAmount, expectStatus);
    expect(balB2).to.equal(balB1 + dstAmount);
  });

  it('should swap and send native', async function () {
    dstSwap.path = [await tokenA.getAddress(), await weth.getAddress()];
    const amountIn2 = parseUnits('10');
    dstSwap.minRecvAmt = slip(amountIn2, 10);
    const message = encodeMessage(dstSwap, receiver.address, expectNonce, true);
    const bal1 = await ethers.provider.getBalance(receiver);
    await tokenA.connect(admin).transfer(xswap.getAddress(), amountIn2);
    const tx = await xswap
      .connect(admin)
      .executeMessageWithTransfer(ZeroAddress, tokenA.getAddress(), amountIn2, srcChainId, message, ZeroAddress);
    const bal2 = await ethers.provider.getBalance(receiver);
    const id = computeId(receiver.address, srcChainId, chainId, message);
    const dstAmount = slip(amountIn2, 5);
    const expectStatus = 1; // SwapStatus.Succeeded
    await expect(tx).to.emit(xswap, 'SwapRequestDone').withArgs(id, dstAmount, expectStatus);
    expect(bal2 == bal1 + dstAmount);
  });

  it('should send bridge token to receiver if no dst swap specified', async function () {
    dstSwap.path = [await tokenA.getAddress()];
    const message = encodeMessage(dstSwap, receiver.address, expectNonce, false);
    await tokenA.connect(admin).transfer(xswap.getAddress(), amountIn);

    const balA1 = await tokenA.connect(receiver).balanceOf(receiver.address);
    const tx = await xswap
      .connect(admin)
      .executeMessageWithTransfer(ZeroAddress, tokenA.getAddress(), amountIn, srcChainId, message, ZeroAddress);
    const balA2 = await tokenA.connect(receiver).balanceOf(receiver.address);
    const id = computeId(receiver.address, srcChainId, chainId, message);
    const expectStatus = 1; // SwapStatus.Succeeded
    await expect(tx).to.emit(xswap, 'SwapRequestDone').withArgs(id, amountIn, expectStatus);
    expect(balA2).to.equal(balA1 + amountIn);
  });

  it('should send bridge token to receiver if swap fails on dst chain', async function () {
    srcSwap.path = [await tokenA.getAddress(), await tokenB.getAddress()];
    dstSwap.path = [await tokenB.getAddress(), await tokenA.getAddress()];
    const bridgeAmount = slip(amountIn, 5);
    dstSwap.minRecvAmt = bridgeAmount; // dst chain swap should fail due to slippage
    const msg = encodeMessage(dstSwap, receiver.address, expectNonce, false);
    const balA1 = await tokenA.balanceOf(receiver.address);
    const balB1 = await tokenB.balanceOf(receiver.address);
    await tokenB.connect(admin).transfer(xswap.getAddress(), bridgeAmount);
    const tx = xswap
      .connect(admin)
      .executeMessageWithTransfer(ZeroAddress, tokenB.getAddress(), bridgeAmount, srcChainId, msg, ZeroAddress);
    const expectId = computeId(receiver.address, srcChainId, chainId, msg);
    const expectStatus = 3; // SwapStatus.Fallback
    await expect(tx).to.emit(xswap, 'SwapRequestDone').withArgs(expectId, slip(amountIn, 5), expectStatus);
    const balA2 = await tokenA.balanceOf(receiver.address);
    const balB2 = await tokenB.balanceOf(receiver.address);
    expect(balA2, 'balance A after').equals(balA1);
    expect(balB2, 'balance B after').equals(balB1 + bridgeAmount);
  });
});
