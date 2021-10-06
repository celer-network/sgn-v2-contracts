import '@nomiclabs/hardhat-ethers';

import fs from 'fs';
import path from 'path';

import { ethers } from 'hardhat';

import { keccak256 } from '@ethersproject/solidity';
import { parseUnits } from '@ethersproject/units';
import { Wallet } from '@ethersproject/wallet';

import { Bridge2, TestERC20 } from '../typechain';
import { deployBridge2Contracts, getAccounts, loadFixture } from '../test/lib/common';
import { getRelayRequest } from '../test/lib/proto';
import { BigNumber } from '@ethersproject/bignumber';

const GAS_USAGE_DIR = 'reports/gas_usage/';
const GAS_USAGE_LOG = path.join(GAS_USAGE_DIR, 'relay2.txt');

describe('Relay2 Gas Benchmark', function () {
  if (!fs.existsSync(GAS_USAGE_DIR)) {
    fs.mkdirSync(GAS_USAGE_DIR, { recursive: true });
  }
  fs.rmSync(GAS_USAGE_LOG, { force: true });
  fs.appendFileSync(GAS_USAGE_LOG, '<signer num, quorum sig num, gas cost> for cbr relay tx\n\n');

  async function fixture([admin]: Wallet[]) {
    const { bridge2, token } = await deployBridge2Contracts(admin);
    return { admin, bridge2, token };
  }

  let bridge2: Bridge2;
  let token: TestERC20;
  let admin: Wallet;
  let accounts: Wallet[];

  beforeEach(async () => {
    const res = await loadFixture(fixture);
    bridge2 = res.bridge2;
    token = res.token;
    admin = res.admin;
    accounts = await getAccounts(admin, [token], 21);
    await token.transfer(bridge2.address, parseUnits('1000000'));
  });

  it('benchmark relay gas cost for bridge2', async function () {
    await doBenchmarkBridge2(4, 12, 3);
    await doBenchmarkBridge2(5, 15, 6);
    await doBenchmarkBridge2(10, 21, 10);
    await doBenchmarkBridge2(15, 21, 15);
  });

  async function getPowers(
    accounts: Wallet[],
    num: number,
    quorumSigs: number
  ): Promise<{ signers: Wallet[]; addrs: string[]; powers: BigNumber[]; quorumSigNum: number }> {
    const maxQuorumSigs = (num * 2) / 3 + 1;
    if (quorumSigs > maxQuorumSigs) {
      quorumSigs = maxQuorumSigs | 0;
    }
    const signers: Wallet[] = [];
    const addrs: string[] = [];
    const powers: BigNumber[] = [];
    for (let i = 0; i < num; i++) {
      signers.push(accounts[i]);
      addrs.push(accounts[i].address);
      if (i == quorumSigs - 1) {
        powers.push(parseUnits('100'));
      } else {
        powers.push(parseUnits('1'));
      }
    }
    const quorumSigNum = quorumSigs;
    return { signers, addrs, powers, quorumSigNum };
  }

  async function doBenchmarkBridge2(minNum: number, maxNum: number, quorumSigs: number) {
    fs.appendFileSync(GAS_USAGE_LOG, 'max number of sigs to reach quorum: ' + quorumSigs + '\n');
    let firstCost = 0;
    let lastCost = 0;
    for (let i = minNum; i <= maxNum; i++) {
      const { signers, addrs, powers, quorumSigNum } = await getPowers(accounts, i, quorumSigs);
      await bridge2.notifyResetSigners();
      await bridge2.resetSigners(addrs, powers);

      const sender = accounts[0];
      const receiver = accounts[1];
      const amount = parseUnits('1');
      const chainId = (await ethers.provider.getNetwork()).chainId;
      const srcXferId = keccak256(['uint64'], [Date.now()]); // fake src xfer id
      const { relayBytes, sigs } = await getRelayRequest(
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
      if (i == minNum) {
        firstCost = gasUsed.toNumber();
      }
      if (i == maxNum) {
        lastCost = gasUsed.toNumber();
      }
      fs.appendFileSync(GAS_USAGE_LOG, i.toString() + '\t' + quorumSigNum.toString() + '\t' + gasUsed + '\n');
    }
    const perSigCost = Math.ceil((lastCost - firstCost) / (maxNum - minNum));
    fs.appendFileSync(GAS_USAGE_LOG, 'per signer cost: ' + perSigCost + '\n\n');
  }
});
