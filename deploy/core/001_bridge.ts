import * as dotenv from 'dotenv';
import { ethers } from 'hardhat';
import { DeployFunction } from 'hardhat-deploy/types';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { calcEthereumTransactionParams } from '@acala-network/eth-providers';

dotenv.config();

const deployFunc: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const blockNumber = await ethers.provider.getBlockNumber();

  const ethParams = calcEthereumTransactionParams({
    gasLimit: '2100001',
    validUntil: (blockNumber + 100).toString(),
    storageLimit: '64001',
    txFeePerGas,
    storageByteDeposit
  });

  await deploy('Bridge', {
    from: deployer,
    log: true,
    gasLimit: ethParams.txGasLimit, // Mandala
    gasPrice: ethParams.txGasPrice, // Mandala
  });
};

deployFunc.tags = ['Bridge'];
deployFunc.dependencies = [];
export default deployFunc;
