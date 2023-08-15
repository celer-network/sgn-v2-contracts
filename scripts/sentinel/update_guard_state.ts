import 'hardhat-deploy';

import * as dotenv from 'dotenv';

import { Sentinel__factory } from '../../typechain';
import { getDeployerSigner, getFeeOverrides } from '../common';

dotenv.config();

async function updateGuardState(): Promise<void> {
  const deployerSigner = await getDeployerSigner();
  const feeOverrides = await getFeeOverrides();

  const sentinelAddr = process.env.SENTINEL as string;
  if (!sentinelAddr) {
    return;
  }
  const sentinel = Sentinel__factory.connect(sentinelAddr, deployerSigner);
  const guardState = process.env.SENTINEL_GUARD_STATE as string;
   await (await sentinel.updateGuardState(guardState, feeOverrides)).wait();

}

updateGuardState();
