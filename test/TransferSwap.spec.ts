import { ethers } from 'hardhat';

import { BigNumber } from '@ethersproject/bignumber';
import { keccak256, pack } from '@ethersproject/solidity';
import { Wallet } from '@ethersproject/wallet';

import { MessageBus, TestERC20, TransferSwap } from '../typechain';
import { deplayMessageContracts, getAccounts, loadFixture } from './lib/common';
import { calculateSignatures, hex2Bytes } from './lib/proto';

function getAddrs(signers: Wallet[]) {
  const addrs: string[] = [];
  for (let i = 0; i < signers.length; i++) {
    addrs.push(signers[i].address);
  }
  return addrs;
}

async function getUpdateSignersSigs(
  triggerTime: number,
  newSignerAddrs: string[],
  newPowers: BigNumber[],
  currSigners: Wallet[],
  chainId: number,
  contractAddress: string
) {
  const domain = keccak256(['uint256', 'address', 'string'], [chainId, contractAddress, 'UpdateSigners']);
  const data = pack(['bytes32', 'uint256', 'address[]', 'uint256[]'], [domain, triggerTime, newSignerAddrs, newPowers]);
  const hash = keccak256(['bytes'], [data]);
  const sigs = await calculateSignatures(currSigners, hex2Bytes(hash));
  return sigs;
}

async function getBlockTime() {
  const blockNumber = await ethers.provider.getBlockNumber();
  const block = await ethers.provider.getBlock(blockNumber);
  return block.timestamp;
}

describe('Bridge Tests', function () {
  async function fixture([admin]: Wallet[]) {
    const { bus, token, transferSwap } = await deplayMessageContracts(admin);
    return { admin, bus, token, transferSwap };
  }

  let bus: MessageBus;
  let token: TestERC20;
  let transferSwap: TransferSwap;
  let accounts: Wallet[];
  let chainId: number;

  beforeEach(async () => {
    const res = await loadFixture(fixture);
    bus = res.bus;
    token = res.token;
    transferSwap = res.transferSwap;
    accounts = await getAccounts(res.admin, [token], 4);
    chainId = (await ethers.provider.getNetwork()).chainId;
  });

  it('should transfer with swap', async function () {
    console.log("setting MessageBus address to TransferSwap")
    await transferSwap.setMsgBus(bus.address);
    const swap = {
      dex: 
    }
  });
});
