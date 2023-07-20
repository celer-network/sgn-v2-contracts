import * as dotenv from 'dotenv';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { Wallet } from 'zksync-web3';

import { Deployer } from '@matterlabs/hardhat-zksync-deploy';

dotenv.config();

const deployFunc = async (hre: HardhatRuntimeEnvironment) => {
  const wallet = new Wallet(process.env.ZK_SYNC_PRIVATE_KEY as string);
  const deployer = new Deployer(hre, wallet);
  const artifact = await deployer.loadArtifact('MessageBus');

  const args = [
    process.env.MESSAGE_BUS_SIGS_VERIFIER,
    process.env.MESSAGE_BUS_LIQUIDITY_BRIDGE as string,
    process.env.MESSAGE_BUS_PEG_BRIDGE as string,
    process.env.MESSAGE_BUS_PEG_VAULT as string,
    process.env.MESSAGE_BUS_PEG_BRIDGE_V2 as string,
    process.env.MESSAGE_BUS_PEG_VAULT_V2 as string
  ];
  const messageBusContract = await deployer.deploy(artifact, args);

  const contractAddress = messageBusContract.address;
  console.log(`${artifact.contractName} was deployed to ${contractAddress}`);
};

export default deployFunc;
