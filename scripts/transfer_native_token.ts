import 'hardhat-deploy';

import * as dotenv from 'dotenv';

import { getDeployerSigner, getFeeOverrides } from './common';

dotenv.config();

async function transferNativeToken(): Promise<void> {
  const deployerSigner = await getDeployerSigner();
  const feeOverrides = await getFeeOverrides();

  const to = process.env.TRANSFER_TO as string;
  if (!to) {
    console.error('Please set TRANSFER_TO in .env');
    return;
  }

  const amount = process.env.TRANSFER_AMOUNT as string;
  if (!amount) {
    console.error('Please set TRANSFER_AMOUNT in .env');
    return;
  }

  const txReceipt = await deployerSigner.sendTransaction({
    to,
    value: BigInt(parseFloat(amount) * 1e18), // assume ETH decimals
    ...feeOverrides,
  });
  await txReceipt.wait();
  console.log('Transfer native token to:', to, 'amount:', amount);
}

transferNativeToken();
