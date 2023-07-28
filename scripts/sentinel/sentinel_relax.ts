import 'hardhat-deploy';

import * as dotenv from 'dotenv';

import { Sentinel__factory } from '../../typechain';
import { getDeployerSigner, getFeeOverrides } from '../common';

dotenv.config();

async function relax(): Promise<void> {
  const deployerSigner = await getDeployerSigner();
  const feeOverrides = await getFeeOverrides();

  const sentinelAddr = process.env.SENTINEL as string;
  if (!sentinelAddr) {
    return;
  }
  const sentinel = Sentinel__factory.connect(sentinelAddr, deployerSigner);
  await (await sentinel.relax(feeOverrides)).wait();
}

relax();
