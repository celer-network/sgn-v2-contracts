import 'hardhat-deploy';

import * as dotenv from 'dotenv';
import { ethers, getNamedAccounts } from 'hardhat';

import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/dist/src/signer-with-address';

import { Bridge__factory } from '../typechain/factories/Bridge__factory';

dotenv.config();

async function getDeployerSigner(): Promise<SignerWithAddress> {
  const deployer = (await getNamedAccounts())['deployer'];
  return await ethers.getSigner(deployer);
}

async function resetSigners(): Promise<void> {
  const deployerSigner = await getDeployerSigner();

  const bridgeAddr = process.env.BRIDGE as string;
  if (!bridgeAddr) {
    return;
  }
  const bridge = Bridge__factory.connect(bridgeAddr, deployerSigner);
  const signers = (process.env.BRIDGE_SIGNERS as string).split(',');
  const powers = (process.env.BRIDGE_POWERS as string).split(',');
  await (await bridge.resetSigners(signers, powers)).wait();
  console.log('resetSigners', signers, powers);
}

resetSigners();
