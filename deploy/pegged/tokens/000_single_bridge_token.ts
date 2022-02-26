import * as dotenv from 'dotenv';
import { DeployFunction } from 'hardhat-deploy/types';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { ethers } from 'hardhat';
import { calcEthereumTransactionParams } from '@acala-network/eth-providers';

dotenv.config();

const deployFunc: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const blockNumber = await ethers.provider.getBlockNumber();
  const storageByteDeposit = '100000000000000';
  const txFeePerGas = '199999946752';

  console.log(storageByteDeposit, txFeePerGas)
  const ethParams = calcEthereumTransactionParams({
    gasLimit: '21000000',
    validUntil: (blockNumber + 100).toString(),
    storageLimit: '64001',
    txFeePerGas,
    storageByteDeposit,
  });

  await deploy('SingleBridgeToken', {
    from: deployer,
    log: true,
    gasLimit: ethParams.txGasLimit, // Mandala
    gasPrice: ethParams.txGasPrice, // Mandala
    args: [
      process.env.SINGLE_BRIDGE_TOKEN_NAME,
      process.env.SINGLE_BRIDGE_TOKEN_SYMBOL,
      process.env.SINGLE_BRIDGE_TOKEN_DECIMALS,
      process.env.SINGLE_BRIDGE_TOKEN_BRIDGE
    ]
  });
};

deployFunc.tags = ['SingleBridgeToken'];
deployFunc.dependencies = [];
export default deployFunc;
