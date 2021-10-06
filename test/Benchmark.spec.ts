import fs from 'fs';
import path from 'path';

import { ethers } from 'hardhat';

import { keccak256 } from '@ethersproject/solidity';
import { parseUnits } from '@ethersproject/units';
import { Wallet } from '@ethersproject/wallet';

import { Bridge, Bridge2, TestERC20 } from '../typechain';
import { deployBridgeContracts, deployBridge2Contracts, getAccounts, loadFixture } from './lib/common';
import { getSignersBytes, getRelayRequest } from './lib/proto';
import { BigNumber } from '@ethersproject/bignumber';

const GAS_USAGE_DIR = 'reports/gas_usage/';
const GAS_USAGE_LOG = path.join(GAS_USAGE_DIR, 'relay.txt');

describe('Gas Benchmark', function () {
  if (!fs.existsSync(GAS_USAGE_DIR)) {
    fs.mkdirSync(GAS_USAGE_DIR, { recursive: true });
  }
  fs.rmSync(GAS_USAGE_LOG, { force: true });
  fs.appendFileSync(GAS_USAGE_LOG, '<signer num, gas cost> for cbr relay tx\n\n');

  async function fixture([admin]: Wallet[]) {
    const { bridge, token } = await deployBridgeContracts(admin, []);
    const bridge2 = await deployBridge2Contracts(admin);
    return { admin, bridge, bridge2, token };
  }

  let bridge: Bridge;
  let bridge2: Bridge2;
  let token: TestERC20;
  let admin: Wallet;
  let accounts: Wallet[];

  beforeEach(async () => {
    const res = await loadFixture(fixture);
    bridge = res.bridge;
    bridge2 = res.bridge2;
    token = res.token;
    admin = res.admin;
    accounts = await getAccounts(admin, [token], 21);
  });

  it('benchmark relay gas cost for bridge', async function () {
    await token.transfer(bridge.address, parseUnits('1000000'));
    const maxNum = 21;
    let firstCost = 0;
    let lastCost = 0;
    for (let i = 1; i <= maxNum; i++) {
      const { signers, addrs, powers } = await getPowers(accounts, i);
      const signerBytes = await getSignersBytes(addrs, powers, true);
      await bridge.startResetSigners();
      await bridge.resetSigners(signerBytes);

      const sender = accounts[0];
      const receiver = accounts[1];
      const amount = parseUnits('1');
      const chainId = (await ethers.provider.getNetwork()).chainId;
      const nonce = i;
      const srcXferId = keccak256(['uint64'], [nonce]); // fake src xfer id
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
      const gasUsed = (await (await bridge.relay(relayBytes, curss, sigs)).wait()).gasUsed;
      if (i == 1) {
        firstCost = gasUsed.toNumber();
      }
      if (i == maxNum) {
        lastCost = gasUsed.toNumber();
      }
      fs.appendFileSync(GAS_USAGE_LOG, i.toString() + '\t' + gasUsed + '\n');
    }
    const perSigCost = Math.ceil((lastCost - firstCost) / (maxNum - 1));
    fs.appendFileSync(GAS_USAGE_LOG, '\n');

    fs.appendFileSync(GAS_USAGE_LOG, 'per sig cost: ' + perSigCost + '\n\n');
  });

  it('benchmark relay gas cost for bridge2', async function () {
    await token.transfer(bridge2.address, parseUnits('1000000'));
    const maxNum = 21;
    let firstCost = 0;
    let lastCost = 0;
    for (let i = 1; i <= maxNum; i++) {
      const { signers, addrs, powers } = await getPowers(accounts, i);
      await bridge2.resetSigners(addrs, powers);

      const sender = accounts[0];
      const receiver = accounts[1];
      const amount = parseUnits('1');
      const chainId = (await ethers.provider.getNetwork()).chainId;
      const nonce = i;
      const srcXferId = keccak256(['uint64'], [nonce]); // fake src xfer id
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
      const gasUsed = (await (await bridge2.relay(relayBytes, sigs, addrs, powers)).wait()).gasUsed;
      if (i == 1) {
        firstCost = gasUsed.toNumber();
      }
      if (i == maxNum) {
        lastCost = gasUsed.toNumber();
      }
      fs.appendFileSync(GAS_USAGE_LOG, i.toString() + '\t' + gasUsed + '\n');
    }
    const perSigCost = Math.ceil((lastCost - firstCost) / (maxNum - 1));
    fs.appendFileSync(GAS_USAGE_LOG, '\n');

    fs.appendFileSync(GAS_USAGE_LOG, 'per sig cost: ' + perSigCost + '\n');
  });
});

async function getPowers(
  accounts: Wallet[],
  num: number
): Promise<{ signers: Wallet[]; addrs: string[]; powers: BigNumber[] }> {
  const signers: Wallet[] = [];
  const addrs: string[] = [];
  const powers: BigNumber[] = [];
  signers.push(accounts[0]);
  addrs.push(accounts[0].address);
  powers.push(parseUnits('100'));
  for (let i = 1; i < num; i++) {
    signers.push(accounts[i]);
    addrs.push(accounts[i].address);
    powers.push(parseUnits('1'));
  }
  return { signers, addrs, powers };
}
