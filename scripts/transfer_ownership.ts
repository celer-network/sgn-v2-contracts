import 'hardhat-deploy';

import * as dotenv from 'dotenv';

import { MintSwapCanonicalToken__factory } from '../typechain/factories/MintSwapCanonicalToken__factory';
import { getDeployerSigner, getFeeOverrides } from './common';

dotenv.config();

async function transferOwnership(): Promise<void> {
  const deployerSigner = await getDeployerSigner();
  const feeOverrides = await getFeeOverrides();

  const tokenAddr = process.env.MINT_SWAP_CANONICAL_TOKEN as string;
  if (!tokenAddr) {
    return;
  }
  const newOwner = process.env.MINT_SWAP_CANONICAL_TOKEN_NEW_OWNER as string;
  if (!newOwner) {
    return;
  }
  const mintSwapCanonicalToken = MintSwapCanonicalToken__factory.connect(tokenAddr, deployerSigner);
  await (await mintSwapCanonicalToken.transferOwnership(newOwner, feeOverrides)).wait();
  console.log('transferOwnership', tokenAddr, newOwner);
}

transferOwnership();
