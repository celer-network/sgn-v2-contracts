import * as dotenv from 'dotenv';
import { DeployFunction } from 'hardhat-deploy/types';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

dotenv.config();

const deployFunc: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const args = [process.env.ROUTER_GATEWAY];
  const routerSenderAdapter = await deploy('RouterSenderAdapter', {
    from: deployer,
    log: true,
    args: args
  });
  await hre.run('verify:verify', { address: routerSenderAdapter.address, constructorArguments: args });
};

deployFunc.tags = ['RouterSenderAdapter'];
deployFunc.dependencies = [];
export default deployFunc;
