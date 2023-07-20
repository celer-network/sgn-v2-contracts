import * as dotenv from 'dotenv';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { Wallet } from 'zksync-web3';

import { Deployer } from '@matterlabs/hardhat-zksync-deploy';

dotenv.config();

const deployFunc = async (hre: HardhatRuntimeEnvironment) => {
  const wallet = new Wallet(process.env.ZK_SYNC_PRIVATE_KEY as string);
  const deployer = new Deployer(hre, wallet);
  const artifact = await deployer.loadArtifact('MultiBridgeToken');

  const args = [
    process.env.MULTI_BRIDGE_TOKEN_NAME as string,
    process.env.MULTI_BRIDGE_TOKEN_SYMBOL as string,
    process.env.MULTI_BRIDGE_TOKEN_DECIMALS
  ];
  const multiBridgeTokenContract = await deployer.deploy(artifact, args);

  const contractAddress = multiBridgeTokenContract.address;
  console.log(`${artifact.contractName} was deployed to ${contractAddress}`);
};

export default deployFunc;
