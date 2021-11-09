import { expect } from 'chai';
import { ethers } from 'hardhat';

import { BigNumber } from '@ethersproject/bignumber';
import { keccak256, pack } from '@ethersproject/solidity';
import { parseUnits } from '@ethersproject/units';
import { Wallet } from '@ethersproject/wallet';

import { Bridge, TestERC20 } from '../typechain';
import {
  deployBridgeContracts,
  getAccounts,
  advanceBlockNumber,
  advanceBlockNumberTo,
  loadFixture
} from './lib/common';
import { getRelayRequest, calculateSignatures, hex2Bytes } from './lib/proto';

describe('Bridge Tests', function () {
  async function fixture([admin]: Wallet[]) {
    const { bridge, token } = await deployBridgeContracts(admin);
    return { admin, bridge, token };
  }

  let bridge: Bridge;
  let token: TestERC20;
  let accounts: Wallet[];

  beforeEach(async () => {
    const res = await loadFixture(fixture);
    bridge = res.bridge;
    token = res.token;
    accounts = await getAccounts(res.admin, [token], 4);
  });

  it('should update signers correctly', async function () {
    await expect(bridge.resetSigners([accounts[0].address], [parseUnits('1')]))
      .to.emit(bridge, 'SignersUpdated')
      .withArgs([accounts[0].address], [parseUnits('1')]);

    let newSigners = [accounts[2], accounts[1], accounts[0], accounts[3]];
    let newPowers = [parseUnits('12'), parseUnits('11'), parseUnits('10'), parseUnits('9')];

    let sigs = await getUpdateSignersSigs(getAddrs(newSigners), newPowers, [accounts[0]]);
    await expect(
      bridge.updateSigners(getAddrs(newSigners), newPowers, sigs, [accounts[0].address], [parseUnits('1')])
    ).to.be.revertedWith('New signers not in ascending order');

    newSigners = [accounts[0], accounts[1], accounts[2], accounts[3]];
    sigs = await getUpdateSignersSigs(getAddrs(newSigners), newPowers, [accounts[0]]);
    await expect(bridge.updateSigners(getAddrs(newSigners), newPowers, sigs, [accounts[0].address], [parseUnits('1')]))
      .to.emit(bridge, 'SignersUpdated')
      .withArgs(getAddrs(newSigners), newPowers);

    await expect(
      bridge.updateSigners(getAddrs(newSigners), newPowers, sigs, [accounts[0].address], [parseUnits('10')])
    ).to.be.revertedWith('Mismatch current signers');

    let curSigners = newSigners;
    let curPowers = newPowers;
    newSigners = [accounts[1], accounts[3]];
    newPowers = [parseUnits('15'), parseUnits('50')];
    sigs = await getUpdateSignersSigs(getAddrs(newSigners), newPowers, curSigners);

    await expect(
      bridge.updateSigners(getAddrs(newSigners), newPowers, [sigs[0], sigs[1]], getAddrs(curSigners), curPowers)
    ).to.be.revertedWith('quorum not reached');

    await expect(
      bridge.updateSigners(getAddrs(newSigners), newPowers, [sigs[1], sigs[0]], getAddrs(curSigners), curPowers)
    ).to.be.revertedWith('signers not in ascending order');

    await expect(
      bridge.updateSigners(
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
    await bridge.setDelayThresholds([token.address], [parseUnits('5')]);
    await bridge.setDelayPeriod(10);
    const signers = [accounts[0], accounts[1], accounts[2]];
    const powers = [parseUnits('10'), parseUnits('10'), parseUnits('10')];
    await expect(bridge.resetSigners(getAddrs(signers), powers))
      .to.emit(bridge, 'SignersUpdated')
      .withArgs(getAddrs(signers), powers);

    const sender = accounts[0];
    const receiver = accounts[1];
    const amount = parseUnits('1');
    const chainId = (await ethers.provider.getNetwork()).chainId;
    const nonce = 0;
    const slippage = 1000;

    const srcXferId = keccak256(
      ['address', 'address', 'address', 'uint256', 'uint64', 'uint64', 'uint64'],
      [sender.address, receiver.address, token.address, amount, chainId, nonce, chainId]
    );

    await token.connect(sender).approve(bridge.address, parseUnits('100'));
    await bridge.connect(sender).addLiquidity(token.address, parseUnits('50'));
    await expect(bridge.connect(sender).send(receiver.address, token.address, amount, chainId, nonce, slippage))
      .to.emit(bridge, 'Send')
      .withArgs(srcXferId, sender.address, receiver.address, token.address, amount, chainId, nonce, slippage);

    let req = await getRelayRequest(
      sender.address,
      receiver.address,
      token.address,
      amount,
      chainId,
      chainId,
      srcXferId,
      signers
    );
    let dstXferId = keccak256(
      ['address', 'address', 'address', 'uint256', 'uint64', 'uint64', 'bytes32'],
      [sender.address, receiver.address, token.address, amount, chainId, chainId, srcXferId]
    );
    await expect(bridge.relay(req.relayBytes, req.sigs, getAddrs(signers), powers))
      .to.emit(bridge, 'Relay')
      .withArgs(dstXferId, sender.address, receiver.address, token.address, amount, chainId, srcXferId);

    const largeAmount = parseUnits('10');
    req = await getRelayRequest(
      sender.address,
      receiver.address,
      token.address,
      largeAmount,
      chainId,
      chainId,
      srcXferId,
      signers
    );
    dstXferId = keccak256(
      ['address', 'address', 'address', 'uint256', 'uint64', 'uint64', 'bytes32'],
      [sender.address, receiver.address, token.address, largeAmount, chainId, chainId, srcXferId]
    );
    await expect(bridge.relay(req.relayBytes, req.sigs, getAddrs(signers), powers))
      .to.emit(bridge, 'Relay')
      .withArgs(dstXferId, sender.address, receiver.address, token.address, largeAmount, chainId, srcXferId);

    await expect(bridge.executeTransfer(dstXferId)).to.be.revertedWith('transfer still locked');
    await ethers.provider.send('evm_increaseTime', [100]);
    await ethers.provider.send('evm_mine', []);
    await expect(bridge.executeTransfer(dstXferId))
      .to.emit(bridge, 'TransferExecuted')
      .withArgs(dstXferId, receiver.address, token.address, largeAmount);
    await expect(bridge.executeTransfer(dstXferId)).to.be.revertedWith('transfer not exist');
  });

  it('should pass volume cap', async function () {
    const signers = [accounts[0], accounts[1], accounts[2]];
    const powers = [parseUnits('10'), parseUnits('10'), parseUnits('10')];
    await expect(bridge.resetSigners(getAddrs(signers), powers))
      .to.emit(bridge, 'SignersUpdated')
      .withArgs(getAddrs(signers), powers);

    const epochLength = 20;
    await bridge.setEpochLength(epochLength);
    await bridge.setEpochVolumeCaps([token.address], [parseUnits('5')]);
    await bridge.setMaxSend([token.address], [parseUnits('5')]);

    const sender = accounts[0];
    const receiver = accounts[1];
    const chainId = (await ethers.provider.getNetwork()).chainId;

    await token.connect(sender).approve(bridge.address, parseUnits('100'));
    await expect(
      bridge.connect(sender).send(receiver.address, token.address, parseUnits('10'), chainId, 0, 10000)
    ).to.be.revertedWith('amount too large');
    await bridge.connect(sender).addLiquidity(token.address, parseUnits('50'));

    let srcXferId = keccak256(['string'], ['srcId']);
    let dstXferId = keccak256(
      ['address', 'address', 'address', 'uint256', 'uint64', 'uint64', 'bytes32'],
      [sender.address, receiver.address, token.address, parseUnits('2'), chainId, chainId, srcXferId]
    );

    let req = await getRelayRequest(
      sender.address,
      receiver.address,
      token.address,
      parseUnits('2'),
      chainId,
      chainId,
      srcXferId,
      signers
    );

    let blockTime = await getBlockTime();
    let epochStartTime = Math.floor(blockTime / epochLength) * epochLength;
    await ethers.provider.send('evm_setNextBlockTimestamp', [epochStartTime + epochLength]);
    await ethers.provider.send('evm_mine', []);
    await expect(bridge.relay(req.relayBytes, req.sigs, getAddrs(signers), powers))
      .to.emit(bridge, 'Relay')
      .withArgs(dstXferId, sender.address, receiver.address, token.address, parseUnits('2'), chainId, srcXferId);

    req = await getRelayRequest(
      sender.address,
      receiver.address,
      token.address,
      parseUnits('4'),
      chainId,
      chainId,
      srcXferId,
      signers
    );
    dstXferId = keccak256(
      ['address', 'address', 'address', 'uint256', 'uint64', 'uint64', 'bytes32'],
      [sender.address, receiver.address, token.address, parseUnits('4'), chainId, chainId, srcXferId]
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
      .withArgs(dstXferId, sender.address, receiver.address, token.address, parseUnits('4'), chainId, srcXferId);

    req = await getRelayRequest(
      sender.address,
      receiver.address,
      token.address,
      parseUnits('3'),
      chainId,
      chainId,
      srcXferId,
      signers
    );
    dstXferId = keccak256(
      ['address', 'address', 'address', 'uint256', 'uint64', 'uint64', 'bytes32'],
      [sender.address, receiver.address, token.address, parseUnits('3'), chainId, chainId, srcXferId]
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
      .withArgs(dstXferId, sender.address, receiver.address, token.address, parseUnits('3'), chainId, srcXferId);
  });
});

function getAddrs(signers: Wallet[]) {
  const addrs: string[] = [];
  for (let i = 0; i < signers.length; i++) {
    addrs.push(signers[i].address);
  }
  return addrs;
}

async function getUpdateSignersSigs(newSignerAddrs: string[], newPowers: BigNumber[], currSigners: Wallet[]) {
  const data = pack(['address[]', 'uint256[]'], [newSignerAddrs, newPowers]);
  const hash = keccak256(['bytes'], [data]);
  const sigs = await calculateSignatures(currSigners, hex2Bytes(hash));
  return sigs;
}

async function getBlockTime() {
  const blockNumber = await ethers.provider.getBlockNumber();
  const block = await ethers.provider.getBlock(blockNumber);
  return block.timestamp;
}
