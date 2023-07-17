import { ethers, getNamedAccounts } from 'hardhat';

import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/dist/src/signer-with-address';

import type { Overrides } from '@ethersproject/contracts';
export async function getDeployerSigner(): Promise<SignerWithAddress> {
  const deployer = (await getNamedAccounts())['deployer'];
  return await ethers.getSigner(deployer);
}

export async function getFeeOverrides(): Promise<Overrides> {
  const feeData = await ethers.provider.getFeeData();
  const network = await ethers.provider.getNetwork();
  if (network.chainId == 59144) {
    // for linea
    return { maxFeePerGas: 5000000000, maxPriorityFeePerGas: 4900000000};
  }
  if (feeData.maxFeePerGas) {
    return { maxFeePerGas: feeData.maxFeePerGas, maxPriorityFeePerGas: feeData.maxPriorityFeePerGas || 0 };
  }
  return { gasPrice: feeData.gasPrice || 0 };
}
