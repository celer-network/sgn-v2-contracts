import * as dotenv from 'dotenv';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { Wallet } from 'zksync-web3';

import { Deployer } from '@matterlabs/hardhat-zksync-deploy';

dotenv.config();

const deployFunc = async (hre: HardhatRuntimeEnvironment) => {
  const wallet = new Wallet(process.env.ZK_SYNC_PRIVATE_KEY as string);
  const deployer = new Deployer(hre, wallet);
  const artifact = await deployer.loadArtifact('PeggedTokenBridgeV2');

  const args = [process.env.PEGGED_TOKEN_BRIDGE_SIGS_VERIFIER];
  const peggedTokenBridgeV2Contract = await deployer.deploy(artifact, args);

  const contractAddress = peggedTokenBridgeV2Contract.address;
  console.log(`${artifact.contractName} was deployed to ${contractAddress}`);
};

export default deployFunc;
