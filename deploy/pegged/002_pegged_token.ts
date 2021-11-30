import * as dotenv from 'dotenv';
import { DeployFunction } from 'hardhat-deploy/types';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

dotenv.config();

const deployFunc: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy('PeggedToken', {
    from: deployer,
    log: true,
    args: [process.env.PEGGED_TOKEN_NAME, process.env.PEGGED_TOKEN_SYMBOL, process.env.PEGGED_TOKEN_CONTROLLER]
  });
};

deployFunc.tags = ['PeggedToken'];
deployFunc.dependencies = [];
export default deployFunc;
