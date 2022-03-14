import 'hardhat-deploy';

import * as dotenv from 'dotenv';
import { ethers, getNamedAccounts } from 'hardhat';

import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/dist/src/signer-with-address';

import { MintSwapCanonicalToken__factory } from '../typechain/factories/MintSwapCanonicalToken__factory';

dotenv.config();

async function getDeployerSigner(): Promise<SignerWithAddress> {
  const deployer = (await getNamedAccounts())['deployer'];
  return await ethers.getSigner(deployer);
}

async function updateBridgeSupplyCap(): Promise<void> {
  const deployerSigner = await getDeployerSigner();

  const tokenAddr = process.env.MINT_SWAP_CANONICAL_TOKEN as string;
  if (!tokenAddr) {
    return;
  }
  const bridgeAddr = process.env.MINT_SWAP_CANONICAL_TOKEN_BRIDGE as string;
  if (!bridgeAddr) {
    return;
  }
  const mintSwapCanonicalToken = MintSwapCanonicalToken__factory.connect(tokenAddr, deployerSigner);
  const cap = process.env.MINT_SWAP_CANONICAL_TOKEN_CAP as string;
  await (await mintSwapCanonicalToken.updateBridgeSupplyCap(bridgeAddr, cap)).wait();
  console.log('updateBridgeSupplyCap', tokenAddr, bridgeAddr, cap);
}

updateBridgeSupplyCap();
