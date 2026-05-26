import { expect } from 'chai';
import { parseUnits, solidityPackedKeccak256, toNumber, Wallet, ZeroAddress } from 'ethers';
import { ethers } from 'hardhat';

import { HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers';
import { loadFixture } from '@nomicfoundation/hardhat-toolbox/network-helpers';

import { getAccounts, getAddrs } from './lib/common';
import { getMintRequest, getPeggedWithdrawRequest } from './lib/proto';

enum BridgeSendType {
  Null,
  Liquidity,
  PegDeposit,
  PegBurn,
  PegV2Deposit,
  PegV2Burn,
  PegV2BurnFrom
}

describe('BridgeTransferLib Tests', function () {
  async function fixture() {
    const [admin] = await ethers.getSigners();

    const bridgeFactory = await ethers.getContractFactory('Bridge');
    const bridge = await bridgeFactory.deploy();
    await bridge.waitForDeployment();

    const tokenFactory = await ethers.getContractFactory('TestERC20');
    const token = await tokenFactory.deploy();
    await token.waitForDeployment();

    const vaultFactory = await ethers.getContractFactory('OriginalTokenVaultV2');
    const vault = await vaultFactory.deploy(await bridge.getAddress());
    await vault.waitForDeployment();

    const pegBridgeFactory = await ethers.getContractFactory('PeggedTokenBridgeV2');
    const pegBridge = await pegBridgeFactory.deploy(await bridge.getAddress());
    await pegBridge.waitForDeployment();

    const pegTokenFactory = await ethers.getContractFactory('SingleBridgeToken');
    const pegToken = await pegTokenFactory.deploy('PegToken', 'PGT', 18, admin.address);
    await pegToken.waitForDeployment();

    const senderFactory = await ethers.getContractFactory('ContractAsSender');
    const sender = await senderFactory.deploy();
    await sender.waitForDeployment();

    return { admin, bridge, token, vault, pegBridge, pegToken, sender };
  }

  let admin: HardhatEthersSigner;
  let bridge: any;
  let token: any;
  let vault: any;
  let pegBridge: any;
  let pegToken: any;
  let sender: any;
  let signers: Wallet[];
  let powers: bigint[];
  let chainId: number;

  beforeEach(async () => {
    const res = await loadFixture(fixture);
    admin = res.admin;
    bridge = res.bridge;
    token = res.token;
    vault = res.vault;
    pegBridge = res.pegBridge;
    pegToken = res.pegToken;
    sender = res.sender;

    const accounts = await getAccounts(admin, [token], 4);
    signers = [accounts[0], accounts[1], accounts[2]];
    powers = [parseUnits('10'), parseUnits('10'), parseUnits('10')];
    chainId = toNumber((await ethers.provider.getNetwork()).chainId);

    await bridge.resetSigners(getAddrs(signers), powers);
  });

  it('should receive Peg V2 deposit refunds even when the source deposit record exists', async function () {
    const senderAddress = await sender.getAddress();
    const tokenAddress = await token.getAddress();
    const vaultAddress = await vault.getAddress();
    const amount = parseUnits('10');
    const dstChainId = 12345;
    const nonce = 7;
    const remoteReceiver = signers[2].address;

    await sender.setBridgeAddress(BridgeSendType.PegV2Deposit, vaultAddress);
    await token.approve(senderAddress, amount);
    await sender.deposit(tokenAddress, amount);

    const depositId = solidityPackedKeccak256(
      ['address', 'address', 'uint256', 'uint64', 'address', 'uint64', 'uint64', 'address'],
      [senderAddress, tokenAddress, amount, dstChainId, remoteReceiver, nonce, chainId, vaultAddress]
    );

    await expect(
      sender.transfer(remoteReceiver, tokenAddress, amount, dstChainId, nonce, 0, BridgeSendType.PegV2Deposit)
    )
      .to.emit(vault, 'Deposited')
      .withArgs(depositId, senderAddress, tokenAddress, amount, dstChainId, remoteReceiver, nonce);
    expect(await vault.records(depositId)).to.equal(true);
    expect(await token.balanceOf(senderAddress)).to.equal(0n);

    const burnAccount = remoteReceiver;
    const withdrawId = solidityPackedKeccak256(
      ['address', 'address', 'uint256', 'address', 'uint64', 'bytes32', 'address'],
      [senderAddress, tokenAddress, amount, burnAccount, chainId, depositId, vaultAddress]
    );
    const refund = await getPeggedWithdrawRequest(
      tokenAddress,
      senderAddress,
      amount,
      burnAccount,
      chainId,
      depositId,
      signers,
      chainId,
      vaultAddress
    );
    const adminBalanceBefore = await token.balanceOf(admin.address);

    await expect(
      sender.refund(refund.withdrawBytes, refund.sigs, getAddrs(signers), powers, BridgeSendType.PegV2Deposit)
    )
      .to.emit(vault, 'Withdrawn')
      .withArgs(withdrawId, senderAddress, tokenAddress, amount, chainId, depositId, burnAccount);

    expect(await vault.records(withdrawId)).to.equal(true);
    expect(await sender.records(depositId)).to.equal(ZeroAddress);
    expect(await token.balanceOf(admin.address)).to.equal(adminBalanceBefore + amount);
    expect(await token.balanceOf(senderAddress)).to.equal(0n);
  });

  it('should receive Peg V2 burn refunds even when the source burn record exists', async function () {
    const senderAddress = await sender.getAddress();
    const pegTokenAddress = await pegToken.getAddress();
    const pegBridgeAddress = await pegBridge.getAddress();
    const amount = parseUnits('8');
    const dstChainId = 54321;
    const nonce = 11;
    const remoteReceiver = signers[2].address;

    await sender.setBridgeAddress(BridgeSendType.PegV2Burn, pegBridgeAddress);
    await pegToken.mint(senderAddress, amount);
    await pegToken.updateBridge(pegBridgeAddress);
    await pegBridge.setSupply(pegTokenAddress, amount);

    const burnId = solidityPackedKeccak256(
      ['address', 'address', 'uint256', 'uint64', 'address', 'uint64', 'uint64', 'address'],
      [senderAddress, pegTokenAddress, amount, dstChainId, remoteReceiver, nonce, chainId, pegBridgeAddress]
    );

    await expect(
      sender.transfer(remoteReceiver, pegTokenAddress, amount, dstChainId, nonce, 0, BridgeSendType.PegV2Burn)
    )
      .to.emit(pegBridge, 'Burn')
      .withArgs(burnId, pegTokenAddress, senderAddress, amount, dstChainId, remoteReceiver, nonce);
    expect(await pegBridge.records(burnId)).to.equal(true);
    expect(await pegToken.balanceOf(senderAddress)).to.equal(0n);

    const depositor = remoteReceiver;
    const mintId = solidityPackedKeccak256(
      ['address', 'address', 'uint256', 'address', 'uint64', 'bytes32', 'address'],
      [senderAddress, pegTokenAddress, amount, depositor, chainId, burnId, pegBridgeAddress]
    );
    const refund = await getMintRequest(
      pegTokenAddress,
      senderAddress,
      amount,
      depositor,
      chainId,
      burnId,
      signers,
      chainId,
      pegBridgeAddress
    );
    const adminBalanceBefore = await pegToken.balanceOf(admin.address);

    await expect(sender.refund(refund.mintBytes, refund.sigs, getAddrs(signers), powers, BridgeSendType.PegV2Burn))
      .to.emit(pegBridge, 'Mint')
      .withArgs(mintId, pegTokenAddress, senderAddress, amount, chainId, burnId, depositor);

    expect(await pegBridge.records(mintId)).to.equal(true);
    expect(await sender.records(burnId)).to.equal(ZeroAddress);
    expect(await pegToken.balanceOf(admin.address)).to.equal(adminBalanceBefore + amount);
    expect(await pegToken.balanceOf(senderAddress)).to.equal(0n);
  });
});