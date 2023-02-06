import * as dotenv from 'dotenv';
import { DeployFunction } from 'hardhat-deploy/types';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

dotenv.config();

const deployFunc: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const args = [process.env.MULTI_BRIDGE_WORMHOLE_DST_BRIDGE, process.env.MULTI_BRIDGE_WORMHOLE_DST_RELAYER];
  const wormholeReceiverAdapter = await deploy('WormholeReceiverAdapter', {
    from: deployer,
    log: true,
    args: args
  });
  await hre.run('verify:verify', { address: wormholeReceiverAdapter.address, constructorArguments: args });
};

deployFunc.tags = ['WormholeReceiverAdapter'];
deployFunc.dependencies = [];
export default deployFunc;
