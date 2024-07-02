import { expect } from 'chai';
import { getBytes, parseUnits, solidityPacked, solidityPackedKeccak256, toNumber, Wallet } from 'ethers';
import { ethers } from 'hardhat';

import { loadFixture } from '@nomicfoundation/hardhat-toolbox/network-helpers';

import { Bridge, PeggedTokenBridge, SingleBridgeToken, TestERC20 } from '../typechain';
import { deployBridgeContracts, getAccounts, getAddrs, getBlockTime } from './lib/common';
import { calculateSignatures, getMintRequest, getRelayRequest, getWithdrawRequest } from './lib/proto';

async function getUpdateSignersSigs(
  triggerTime: number,
  newSignerAddrs: string[],
  newPowers: bigint[],
  currSigners: Wallet[],
  chainId: number,
  contractAddress: string
) {
  const domain = solidityPackedKeccak256(['uint256', 'address', 'string'], [chainId, contractAddress, 'UpdateSigners']);
  const data = solidityPacked(
    ['bytes32', 'uint256', 'address[]', 'uint256[]'],
    [domain, triggerTime, newSignerAddrs, newPowers]
  );
  const hash = solidityPackedKeccak256(['bytes'], [data]);
  const sigs = await calculateSignatures(currSigners, getBytes(hash));
  return sigs;
}

describe('Bridge Tests', function () {
  async function fixture() {
    const [admin] = await ethers.getSigners();
    const { bridge, token, pegBridge, pegToken } = await deployBridgeContracts(admin);
    return { admin, bridge, token, pegBridge, pegToken };
  }

  let bridge: Bridge;
  let token: TestERC20;
  let pegBridge: PeggedTokenBridge;
  let pegToken: SingleBridgeToken;
  let accounts: Wallet[];
  let chainId: number;

  beforeEach(async () => {
    const res = await loadFixture(fixture);
    bridge = res.bridge;
    token = res.token;
    pegBridge = res.pegBridge;
    pegToken = res.pegToken;
    accounts = await getAccounts(res.admin, [token], 4);
    chainId = toNumber((await ethers.provider.getNetwork()).chainId);
  });

  it('should update signers correctly', async function () {
    await expect(bridge.resetSigners([accounts[0].address], [parseUnits('1')]))
      .to.emit(bridge, 'SignersUpdated')
      .withArgs([accounts[0].address], [parseUnits('1')]);

    let newSigners = [accounts[2], accounts[1], accounts[0], accounts[3]];
    let newPowers = [parseUnits('12'), parseUnits('11'), parseUnits('10'), parseUnits('9')];
    let triggerTime = 1;
    let sigs = await getUpdateSignersSigs(
      triggerTime,
      getAddrs(newSigners),
      newPowers,
      [accounts[0]],
      chainId,
      await bridge.getAddress()
    );
    await expect(
      bridge.updateSigners(triggerTime, getAddrs(newSigners), newPowers, sigs, [accounts[0].address], [parseUnits('1')])
    ).to.be.revertedWith('New signers not in ascending order');

    newSigners = [accounts[0], accounts[1], accounts[2], accounts[3]];
    triggerTime = 2;
    sigs = await getUpdateSignersSigs(
      triggerTime,
      getAddrs(newSigners),
      newPowers,
      [accounts[0]],
      chainId,
      await bridge.getAddress()
    );
    await expect(
      bridge.updateSigners(triggerTime, getAddrs(newSigners), newPowers, sigs, [accounts[0].address], [parseUnits('1')])
    )
      .to.emit(bridge, 'SignersUpdated')
      .withArgs(getAddrs(newSigners), newPowers);

    await expect(
      bridge.updateSigners(
        triggerTime,
        getAddrs(newSigners),
        newPowers,
        sigs,
        [accounts[0].address],
        [parseUnits('10')]
      )
    ).to.be.revertedWith('Trigger time is not increasing');

    await expect(
      bridge.updateSigners(
        parseUnits('1'),
        getAddrs(newSigners),
        newPowers,
        sigs,
        [accounts[0].address],
        [parseUnits('10')]
      )
    ).to.be.revertedWith('Trigger time is too large');

    triggerTime = 3;
    await expect(
      bridge.updateSigners(
        triggerTime,
        getAddrs(newSigners),
        newPowers,
        sigs,
        [accounts[0].address],
        [parseUnits('10')]
      )
    ).to.be.revertedWith('Mismatch current signers');

    const curSigners = newSigners;
    const curPowers = newPowers;
    newSigners = [accounts[1], accounts[3]];
    newPowers = [parseUnits('15'), parseUnits('50')];
    sigs = await getUpdateSignersSigs(
      triggerTime,
      getAddrs(newSigners),
      newPowers,
      curSigners,
      chainId,
      await bridge.getAddress()
    );

    await expect(
      bridge.updateSigners(
        triggerTime,
        getAddrs(newSigners),
        newPowers,
        [sigs[0], sigs[1]],
        getAddrs(curSigners),
        curPowers
      )
    ).to.be.revertedWith('quorum not reached');

    await expect(
      bridge.updateSigners(
        triggerTime,
        getAddrs(newSigners),
        newPowers,
        [sigs[1], sigs[0]],
        getAddrs(curSigners),
        curPowers
      )
    ).to.be.revertedWith('signers not in ascending order');

    await expect(
      bridge.updateSigners(
        triggerTime,
        getAddrs(newSigners),
        newPowers,
        [sigs[0], sigs[1], sigs[2]],
        getAddrs(curSigners),
        curPowers
      )
    )
      .to.emit(bridge, 'SignersUpdated')
      .withArgs(getAddrs(newSigners), newPowers);
  });

  it('should send and relay successfully', async function () {
    await bridge.setDelayThresholds([await token.getAddress()], [parseUnits('5')]);
    await bridge.setDelayPeriod(10);
    const signers = [accounts[0], accounts[1], accounts[2]];
    const powers = [parseUnits('10'), parseUnits('10'), parseUnits('10')];
    await expect(bridge.resetSigners(getAddrs(signers), powers))
      .to.emit(bridge, 'SignersUpdated')
      .withArgs(getAddrs(signers), powers);

    const sender = accounts[0];
    const receiver = accounts[1];
    const amount = parseUnits('1');
    const nonce = 0;
    const slippage = 1000;

    const srcXferId = solidityPackedKeccak256(
      ['address', 'address', 'address', 'uint256', 'uint64', 'uint64', 'uint64'],
      [sender.address, receiver.address, await token.getAddress(), amount, chainId, nonce, chainId]
    );

    await token.connect(sender).approve(await bridge.getAddress(), parseUnits('100'));
    await bridge.connect(sender).addLiquidity(await token.getAddress(), parseUnits('50'));
    await expect(
      bridge.connect(sender).send(receiver.address, await token.getAddress(), amount, chainId, nonce, slippage)
    )
      .to.emit(bridge, 'Send')
      .withArgs(
        srcXferId,
        sender.address,
        receiver.address,
        await token.getAddress(),
        amount,
        chainId,
        nonce,
        slippage
      );

    let req = await getRelayRequest(
      sender.address,
      receiver.address,
      await token.getAddress(),
      amount,
      chainId,
      chainId,
      srcXferId,
      signers,
      await bridge.getAddress()
    );
    let dstXferId = solidityPackedKeccak256(
      ['address', 'address', 'address', 'uint256', 'uint64', 'uint64', 'bytes32'],
      [sender.address, receiver.address, await token.getAddress(), amount, chainId, chainId, srcXferId]
    );
    await expect(bridge.relay(req.relayBytes, req.sigs, getAddrs(signers), powers))
      .to.emit(bridge, 'Relay')
      .withArgs(dstXferId, sender.address, receiver.address, await token.getAddress(), amount, chainId, srcXferId);

    const largeAmount = parseUnits('10');
    req = await getRelayRequest(
      sender.address,
      receiver.address,
      await token.getAddress(),
      largeAmount,
      chainId,
      chainId,
      srcXferId,
      signers,
      await bridge.getAddress()
    );
    dstXferId = solidityPackedKeccak256(
      ['address', 'address', 'address', 'uint256', 'uint64', 'uint64', 'bytes32'],
      [sender.address, receiver.address, await token.getAddress(), largeAmount, chainId, chainId, srcXferId]
    );
    await expect(bridge.relay(req.relayBytes, req.sigs, getAddrs(signers), powers))
      .to.emit(bridge, 'Relay')
      .withArgs(dstXferId, sender.address, receiver.address, await token.getAddress(), largeAmount, chainId, srcXferId)
      .to.emit(bridge, 'DelayedTransferAdded')
      .withArgs(dstXferId);

    await expect(bridge.executeDelayedTransfer(dstXferId)).to.be.revertedWith('delayed transfer still locked');
    await ethers.provider.send('evm_increaseTime', [100]);
    await ethers.provider.send('evm_mine', []);
    await expect(bridge.executeDelayedTransfer(dstXferId))
      .to.emit(bridge, 'DelayedTransferExecuted')
      .withArgs(dstXferId, receiver.address, await token.getAddress(), largeAmount);
    await expect(bridge.executeDelayedTransfer(dstXferId)).to.be.revertedWith('delayed transfer not exist');
  });

  it('should pass risk control tests', async function () {
    const signers = [accounts[0], accounts[1], accounts[2]];
    const powers = [parseUnits('10'), parseUnits('10'), parseUnits('10')];
    await expect(bridge.resetSigners(getAddrs(signers), powers))
      .to.emit(bridge, 'SignersUpdated')
      .withArgs(getAddrs(signers), powers);

    const epochLength = 20;
    await bridge.setEpochLength(epochLength);
    await bridge.setEpochVolumeCaps([await token.getAddress()], [parseUnits('5')]);
    await bridge.setMaxSend([await token.getAddress()], [parseUnits('5')]);

    const sender = accounts[0];
    const receiver = accounts[1];

    await token.connect(sender).approve(await bridge.getAddress(), parseUnits('100'));
    await expect(
      bridge.connect(sender).send(receiver.address, await token.getAddress(), parseUnits('10'), chainId, 0, 10000)
    ).to.be.revertedWith('amount too large');

    await bridge.setMinAdd([await token.getAddress()], [parseUnits('10')]);
    await expect(bridge.connect(sender).addLiquidity(await token.getAddress(), parseUnits('50')))
      .to.emit(bridge, 'LiquidityAdded')
      .withArgs(1, sender.address, await token.getAddress(), parseUnits('50'));
    await expect(bridge.connect(sender).addLiquidity(await token.getAddress(), parseUnits('5'))).to.be.revertedWith(
      'amount too small'
    );

    const srcXferId = solidityPackedKeccak256(['string'], ['srcId']);
    let dstXferId = solidityPackedKeccak256(
      ['address', 'address', 'address', 'uint256', 'uint64', 'uint64', 'bytes32'],
      [sender.address, receiver.address, await token.getAddress(), parseUnits('2'), chainId, chainId, srcXferId]
    );

    let req = await getRelayRequest(
      sender.address,
      receiver.address,
      await token.getAddress(),
      parseUnits('2'),
      chainId,
      chainId,
      srcXferId,
      signers,
      await bridge.getAddress()
    );

    let blockTime = await getBlockTime();
    let epochStartTime = Math.floor(blockTime / epochLength) * epochLength;
    await ethers.provider.send('evm_setNextBlockTimestamp', [epochStartTime + epochLength]);
    await ethers.provider.send('evm_mine', []);
    await expect(bridge.relay(req.relayBytes, req.sigs, getAddrs(signers), powers))
      .to.emit(bridge, 'Relay')
      .withArgs(
        dstXferId,
        sender.address,
        receiver.address,
        await token.getAddress(),
        parseUnits('2'),
        chainId,
        srcXferId
      );

    req = await getRelayRequest(
      sender.address,
      receiver.address,
      await token.getAddress(),
      parseUnits('4'),
      chainId,
      chainId,
      srcXferId,
      signers,
      await bridge.getAddress()
    );
    dstXferId = solidityPackedKeccak256(
      ['address', 'address', 'address', 'uint256', 'uint64', 'uint64', 'bytes32'],
      [sender.address, receiver.address, await token.getAddress(), parseUnits('4'), chainId, chainId, srcXferId]
    );

    await expect(bridge.relay(req.relayBytes, req.sigs, getAddrs(signers), powers)).to.be.revertedWith(
      'volume exceeds cap'
    );
    blockTime = await getBlockTime();
    epochStartTime = Math.floor(blockTime / epochLength) * epochLength;
    await ethers.provider.send('evm_setNextBlockTimestamp', [epochStartTime + epochLength]);
    await ethers.provider.send('evm_mine', []);
    await expect(bridge.relay(req.relayBytes, req.sigs, getAddrs(signers), powers))
      .to.emit(bridge, 'Relay')
      .withArgs(
        dstXferId,
        sender.address,
        receiver.address,
        await token.getAddress(),
        parseUnits('4'),
        chainId,
        srcXferId
      );

    req = await getRelayRequest(
      sender.address,
      receiver.address,
      await token.getAddress(),
      parseUnits('3'),
      chainId,
      chainId,
      srcXferId,
      signers,
      await bridge.getAddress()
    );
    dstXferId = solidityPackedKeccak256(
      ['address', 'address', 'address', 'uint256', 'uint64', 'uint64', 'bytes32'],
      [sender.address, receiver.address, await token.getAddress(), parseUnits('3'), chainId, chainId, srcXferId]
    );
    for (let i = 0; i < 3; i++) {
      await expect(bridge.relay(req.relayBytes, req.sigs, getAddrs(signers), powers)).to.be.revertedWith(
        'volume exceeds cap'
      );
    }

    blockTime = await getBlockTime();
    epochStartTime = Math.floor(blockTime / epochLength) * epochLength;
    await ethers.provider.send('evm_setNextBlockTimestamp', [epochStartTime + epochLength]);
    await ethers.provider.send('evm_mine', []);
    await expect(bridge.relay(req.relayBytes, req.sigs, getAddrs(signers), powers))
      .to.emit(bridge, 'Relay')
      .withArgs(
        dstXferId,
        sender.address,
        receiver.address,
        await token.getAddress(),
        parseUnits('3'),
        chainId,
        srcXferId
      );
  });

  it('should withdraw liquidity correctly', async function () {
    const signers = [accounts[0], accounts[1], accounts[2]];
    const powers = [parseUnits('10'), parseUnits('10'), parseUnits('10')];
    await expect(bridge.resetSigners(getAddrs(signers), powers))
      .to.emit(bridge, 'SignersUpdated')
      .withArgs(getAddrs(signers), powers);

    const account = accounts[0];
    await token.connect(account).approve(await bridge.getAddress(), parseUnits('100'));
    await bridge.connect(account).addLiquidity(await token.getAddress(), parseUnits('50'));

    const refId = solidityPackedKeccak256(['string'], ['random']);
    const seqnum = 1;
    const amount = parseUnits('10');
    const req = await getWithdrawRequest(
      chainId,
      seqnum,
      account.address,
      await token.getAddress(),
      amount,
      refId,
      signers,
      await bridge.getAddress()
    );
    const wdId = solidityPackedKeccak256(
      ['uint64', 'uint64', 'address', 'address', 'uint256'],
      [chainId, seqnum, account.address, await token.getAddress(), amount]
    );
    await expect(bridge.withdraw(req.withdrawBytes, req.sigs, getAddrs(signers), powers))
      .to.emit(bridge, 'WithdrawDone')
      .withArgs(wdId, seqnum, account.address, await token.getAddress(), amount, refId);
  });

  it('should mint successfully', async function () {
    const signers = [accounts[0], accounts[1], accounts[2]];
    const powers = [parseUnits('10'), parseUnits('10'), parseUnits('10')];
    await expect(bridge.resetSigners(getAddrs(signers), powers))
      .to.emit(bridge, 'SignersUpdated')
      .withArgs(getAddrs(signers), powers);

    const account = accounts[0];
    const amount = parseUnits('10');
    const refChainId = 101;
    const refId = solidityPackedKeccak256(['string'], ['random']);
    const req = await getMintRequest(
      await pegToken.getAddress(),
      account.address,
      amount,
      account.address,
      refChainId,
      refId,
      signers,
      chainId,
      await pegBridge.getAddress()
    );

    const mintId = solidityPackedKeccak256(
      ['address', 'address', 'uint256', 'address', 'uint64', 'bytes32'],
      [account.address, await pegToken.getAddress(), amount, account.address, refChainId, refId]
    );

    await expect(pegBridge.mint(req.mintBytes, req.sigs, getAddrs(signers), powers))
      .to.emit(pegBridge, 'Mint')
      .withArgs(mintId, await pegToken.getAddress(), account.address, amount, refChainId, refId, account.address);
  });
});
