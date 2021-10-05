import { expect } from 'chai';
import { ethers } from 'hardhat';

import { keccak256 } from '@ethersproject/solidity';
import { parseUnits } from '@ethersproject/units';
import { Wallet } from '@ethersproject/wallet';

import { Bridge, TestERC20 } from '../typechain';
import { deployBridgeContracts, getAccounts, loadFixture } from './lib/common';
import { getSignersBytes, getUpdateSignersRequest, getRelayRequest } from './lib/proto';

describe('Bridge Tests', function () {
  async function fixture([admin]: Wallet[]) {
    const { bridge, token } = await deployBridgeContracts(admin, []);
    return { admin, bridge, token };
  }

  let bridge: Bridge;
  let token: TestERC20;
  let admin: Wallet;
  let accounts: Wallet[];

  beforeEach(async () => {
    const res = await loadFixture(fixture);
    bridge = res.bridge;
    token = res.token;
    admin = res.admin;
    accounts = await getAccounts(res.admin, [token], 3);
  });

  it('should update signers correctly', async function () {
    const initSignersBytes = await getSignersBytes([admin.address], [parseUnits('1')], true);
    await expect(bridge.setInitSigners(initSignersBytes))
      .to.emit(bridge, 'SignersUpdated')
      .withArgs('0x' + Buffer.from(initSignersBytes).toString('hex'));

    let req = await getUpdateSignersRequest(
      [admin.address, accounts[0].address, accounts[1].address, accounts[2].address],
      [parseUnits('10'), parseUnits('10'), parseUnits('10'), parseUnits('10')],
      [admin],
      [parseUnits('1')],
      false
    );

    await expect(bridge.updateSigners(req.newSignersBytes, req.currSignersBytes, req.sigs)).to.be.revertedWith(
      'New signers not in ascending order'
    );

    req = await getUpdateSignersRequest(
      [admin.address, accounts[0].address, accounts[1].address, accounts[2].address],
      [parseUnits('12'), parseUnits('11'), parseUnits('10'), parseUnits('9')],
      [admin],
      [parseUnits('1')],
      true
    );

    await expect(bridge.updateSigners(req.newSignersBytes, req.currSignersBytes, req.sigs))
      .to.emit(bridge, 'SignersUpdated')
      .withArgs('0x' + Buffer.from(req.newSignersBytes).toString('hex'));

    await expect(bridge.updateSigners(req.newSignersBytes, req.currSignersBytes, req.sigs)).to.be.revertedWith(
      'Mismatch current signers'
    );

    req = await getUpdateSignersRequest(
      [admin.address, accounts[0].address],
      [parseUnits('15'), parseUnits('50')],
      [admin, accounts[0], accounts[1], accounts[2]],
      [parseUnits('12'), parseUnits('11'), parseUnits('10'), parseUnits('9')],
      true
    );

    await expect(
      bridge.updateSigners(req.newSignersBytes, req.currSignersBytes, [req.sigs[0], req.sigs[1]])
    ).to.be.revertedWith('Quorum not reached');

    await expect(
      bridge.updateSigners(req.newSignersBytes, req.currSignersBytes, [req.sigs[1], req.sigs[0]])
    ).to.be.revertedWith('Signers not in ascending order');

    await expect(
      bridge.updateSigners(req.newSignersBytes, req.currSignersBytes, [req.sigs[0], req.sigs[1], req.sigs[3]])
    )
      .to.emit(bridge, 'SignersUpdated')
      .withArgs('0x' + Buffer.from(req.newSignersBytes).toString('hex'));
  });

  it('should send and successfully', async function () {
    const signers = [accounts[0], accounts[1], accounts[2]];
    const signersAddrs = [accounts[0].address, accounts[1].address, accounts[2].address];
    const powers = [parseUnits('10'), parseUnits('10'), parseUnits('10')];
    const initSignersBytes = await getSignersBytes(signersAddrs, powers, true);
    await expect(bridge.setInitSigners(initSignersBytes))
      .to.emit(bridge, 'SignersUpdated')
      .withArgs('0x' + Buffer.from(initSignersBytes).toString('hex'));

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
    await expect(bridge.connect(sender).send(receiver.address, token.address, amount, chainId, nonce, slippage))
      .to.emit(bridge, 'Send')
      .withArgs(srcXferId, sender.address, receiver.address, token.address, amount, chainId, nonce, slippage);

    const { relayBytes, curss, sigs } = await getRelayRequest(
      sender.address,
      receiver.address,
      token.address,
      amount,
      chainId,
      chainId,
      srcXferId,
      signers,
      powers
    );

    const dstXferId = keccak256(
      ['address', 'address', 'address', 'uint256', 'uint64', 'uint64', 'bytes32'],
      [sender.address, receiver.address, token.address, amount, chainId, chainId, srcXferId]
    );

    await expect(bridge.relay(relayBytes, curss, sigs))
      .to.emit(bridge, 'Relay')
      .withArgs(dstXferId, sender.address, receiver.address, token.address, amount, chainId, srcXferId);
  });
});
