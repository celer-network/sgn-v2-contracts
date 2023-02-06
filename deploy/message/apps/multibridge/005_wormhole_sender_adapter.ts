import * as dotenv from 'dotenv';
import { DeployFunction } from 'hardhat-deploy/types';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

dotenv.config();

const deployFunc: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const args = [process.env.MULTI_BRIDGE_WORMHOLE_SRC_BRIDGE, process.env.MULTI_BRIDGE_WORMHOLE_SRC_RELAYER];
  const wormholeSenderAdapter = await deploy('WormholeSenderAdapter', {
    from: deployer,
    log: true,
    args: args
  });
  await hre.run('verify:verify', { address: wormholeSenderAdapter.address, constructorArguments: args });
};

deployFunc.tags = ['WormholeSenderAdapter'];
deployFunc.dependencies = [];
export default deployFunc;
