import 'hardhat-deploy';

import * as dotenv from 'dotenv';
import { ethers, getNamedAccounts } from 'hardhat';

import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/dist/src/signer-with-address';

import { Bridge__factory } from '../typechain/factories/Bridge__factory';
import { OriginalTokenVault__factory } from '../typechain/factories/OriginalTokenVault__factory';
import { PeggedTokenBridge__factory } from '../typechain/factories/PeggedTokenBridge__factory';

dotenv.config();

async function getDeployerSigner(): Promise<SignerWithAddress> {
  const deployer = (await getNamedAccounts())['deployer'];
  return await ethers.getSigner(deployer);
}

async function setBridgeBasics(): Promise<void> {
  const deployerSigner = await getDeployerSigner();

  const bridgeAddr = process.env.BRIDGE as string;
  if (!bridgeAddr) {
    return;
  }
  const bridge = Bridge__factory.connect(bridgeAddr, deployerSigner);
  const pausers = (process.env.BRIDGE_PAUSERS as string).split(',');
  for (let i = 0; i < pausers.length; i++) {
    const pauser = pausers[i];
    await (await bridge.addPauser(pauser)).wait();
    console.log('addPauser', pauser);
  }
  const governors = (process.env.BRIDGE_GOVERNORS as string).split(',');
  for (let i = 0; i < governors.length; i++) {
    const governor = governors[i];
    await (await bridge.addGovernor(governor)).wait();
    console.log('addGovernor', governor);
  }
  const delayPeriod = process.env.BRIDGE_DELAY_PERIOD as string;
  if (delayPeriod) {
    await (await bridge.setDelayPeriod(delayPeriod)).wait();
    console.log('setDelayPeriod', delayPeriod);
  }
  const epochLength = process.env.BRIDGE_EPOCH_LENGTH as string;
  if (epochLength) {
    await (await bridge.setEpochLength(epochLength)).wait();
    console.log('setEpochLength', epochLength);
  }
  const minimalMaxSlippage = process.env.BRIDGE_MINIMAL_MAX_SLIPPAGE as string;
  if (minimalMaxSlippage) {
    await (await bridge.setMinimalMaxSlippage(minimalMaxSlippage)).wait();
    console.log('setMinimalMaxSlippage', minimalMaxSlippage);
  }
  const weth = process.env.BRIDGE_WETH as string;
  if (weth) {
    await (await bridge.setWrap(weth)).wait();
    console.log('setWrap', weth);
  }
}

async function setPeggedTokenBridgeBasics(): Promise<void> {
  const deployerSigner = await getDeployerSigner();

  const peggedTokenBridgeAddr = process.env.PEGGED_TOKEN_BRIDGE as string;
  if (!peggedTokenBridgeAddr) {
    return;
  }
  const peggedTokenBridge = PeggedTokenBridge__factory.connect(peggedTokenBridgeAddr, deployerSigner);
  const pausers = (process.env.PEGGED_TOKEN_BRIDGE_PAUSERS as string).split(',');
  for (let i = 0; i < pausers.length; i++) {
    const pauser = pausers[i];
    await (await peggedTokenBridge.addPauser(pauser)).wait();
    console.log('addPauser', pauser);
  }
  const governors = (process.env.PEGGED_TOKEN_BRIDGE_GOVERNORS as string).split(',');
  for (let i = 0; i < governors.length; i++) {
    const governor = governors[i];
    await (await peggedTokenBridge.addGovernor(governor)).wait();
    console.log('addGovernor', governor);
  }
  const delayPeriod = process.env.PEGGED_TOKEN_BRIDGE_DELAY_PERIOD as string;
  if (delayPeriod) {
    await (await peggedTokenBridge.setDelayPeriod(delayPeriod)).wait();
    console.log('setDelayPeriod', delayPeriod);
  }
  const epochLength = process.env.PEGGED_TOKEN_BRIDGE_EPOCH_LENGTH as string;
  if (epochLength) {
    await (await peggedTokenBridge.setEpochLength(epochLength)).wait();
    console.log('setEpochLength', epochLength);
  }
}

async function setOriginalTokenVaultBasics(): Promise<void> {
  const deployerSigner = await getDeployerSigner();

  const originalTokenVaultAddr = process.env.ORIGINAL_TOKEN_VAULT as string;
  if (!originalTokenVaultAddr) {
    return;
  }
  const originalTokenVault = OriginalTokenVault__factory.connect(originalTokenVaultAddr, deployerSigner);
  const pausers = (process.env.ORIGINAL_TOKEN_VAULT_PAUSERS as string).split(',');
  for (let i = 0; i < pausers.length; i++) {
    const pauser = pausers[i];
    await (await originalTokenVault.addPauser(pauser)).wait();
    console.log('addPauser', pauser);
  }
  const governors = (process.env.ORIGINAL_TOKEN_VAULT_GOVERNORS as string).split(',');
  for (let i = 0; i < governors.length; i++) {
    const governor = governors[i];
    await (await originalTokenVault.addGovernor(governor)).wait();
    console.log('addGovernor', governor);
  }
  const delayPeriod = process.env.ORIGINAL_TOKEN_VAULT_DELAY_PERIOD as string;
  if (delayPeriod) {
    await (await originalTokenVault.setDelayPeriod(delayPeriod)).wait();
    console.log('setDelayPeriod', delayPeriod);
  }
  const epochLength = process.env.ORIGINAL_TOKEN_VAULT_EPOCH_LENGTH as string;
  if (epochLength) {
    await (await originalTokenVault.setEpochLength(epochLength)).wait();
    console.log('setEpochLength', epochLength);
  }
  const weth = process.env.ORIGINAL_TOKEN_VAULT_WETH as string;
  if (weth) {
    await (await originalTokenVault.setWrap(weth)).wait();
    console.log('setWrap', weth);
  }
}

async function setBasics(): Promise<void> {
  await setBridgeBasics();
  await setOriginalTokenVaultBasics();
  await setPeggedTokenBridgeBasics();
}

setBasics();
