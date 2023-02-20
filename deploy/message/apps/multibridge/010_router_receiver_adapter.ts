import * as dotenv from 'dotenv';
import { DeployFunction } from 'hardhat-deploy/types';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

dotenv.config();

const deployFunc: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const args = [process.env.ROUTER_GATEWAY];
  const routerReceiverAdapter = await deploy('RouterReceiverAdapter', {
    from: deployer,
    log: true,
    args: args
  });
  await hre.run('verify:verify', { address: routerReceiverAdapter.address, constructorArguments: args });
};

deployFunc.tags = ['RouterReceiverAdapter'];
deployFunc.dependencies = [];
export default deployFunc;
