import * as dotenv from 'dotenv';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { Wallet } from 'zksync-web3';

import { Deployer } from '@matterlabs/hardhat-zksync-deploy';

dotenv.config();

const deployFunc = async (hre: HardhatRuntimeEnvironment) => {
  const wallet = new Wallet(process.env.ZK_SYNC_PRIVATE_KEY as string);
  const deployer = new Deployer(hre, wallet);
  const artifact = await deployer.loadArtifact('WithdrawInbox');

  const withdrawInboxContract = await deployer.deploy(artifact);

  const contractAddress = withdrawInboxContract.address;
  console.log(`${artifact.contractName} was deployed to ${contractAddress}`);
};

export default deployFunc;
