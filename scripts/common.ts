import { ethers, getNamedAccounts } from 'hardhat';

import { SignerWithAddress } from '@nomicfoundation/hardhat-ethers/signers';

import type { Overrides } from 'ethers';

export async function getDeployerSigner(): Promise<SignerWithAddress> {
  const deployer = (await getNamedAccounts())['deployer'];
  return await ethers.getSigner(deployer);
}

export async function getFeeOverrides(): Promise<Overrides> {
  const feeData = await ethers.provider.getFeeData();
  // const network = await ethers.provider.getNetwork();
  // if (network.chainId == BigInt(59144)) {
  //   // for Linea
  //   return { maxFeePerGas: 5000000000, maxPriorityFeePerGas: 4900000000 };
  // }
  if (feeData.maxFeePerGas) {
    return { maxFeePerGas: feeData.maxFeePerGas, maxPriorityFeePerGas: feeData.maxPriorityFeePerGas || 0 };
  }
  return { gasPrice: feeData.gasPrice || 0 };
}
