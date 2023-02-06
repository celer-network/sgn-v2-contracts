import * as dotenv from 'dotenv';
import { DeployFunction } from 'hardhat-deploy/types';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

dotenv.config();

const deployFunc: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const args = [process.env.MULTI_BRIDGE_DEBRIDGE_SRC_GATE];
  const deBridgeSenderAdapter = await deploy('DeBridgeSenderAdapter', {
    from: deployer,
    log: true,
    args: args
  });
  await hre.run('verify:verify', { address: deBridgeSenderAdapter.address, constructorArguments: args });
};

deployFunc.tags = ['DeBridgeSenderAdapter'];
deployFunc.dependencies = [];
export default deployFunc;
