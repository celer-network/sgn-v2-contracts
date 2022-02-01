import * as dotenv from 'dotenv';
import { ethers } from 'hardhat';
import { DeployFunction } from 'hardhat-deploy/types';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { calcEthereumTransactionParams } from '@acala-network/eth-providers';
import { ApiPromise, WsProvider } from '@polkadot/api';

dotenv.config();

const deployFunc: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const blockNumber = await ethers.provider.getBlockNumber();
  const wsProvider = new WsProvider('wss://node-6870830370282213376.rz.onfinality.io/ws?apikey=0f273197-e4d5-45e2-b23e-03b015cb7000');
  const api = await ApiPromise.create({ provider: wsProvider });
  const storageByteDeposit = (api.consts.evm.storageDepositPerByte).toString();
  const txFeePerGas = (api.consts.evm.txFeePerGas).toString();

  console.log(storageByteDeposit, txFeePerGas)
  const ethParams = calcEthereumTransactionParams({
    gasLimit: '21000000',
    validUntil: (blockNumber + 100).toString(),
    storageLimit: '64001',
    txFeePerGas,
    storageByteDeposit,
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
