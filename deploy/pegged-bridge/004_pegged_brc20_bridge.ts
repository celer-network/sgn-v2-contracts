import * as dotenv from 'dotenv';
import { DeployFunction } from 'hardhat-deploy/types';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

dotenv.config();

const deployFunc: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const args = [process.env.PEGGED_BRC20_BRIDGE_MINTER];

  const peggedBrc20Bridge = await deploy('PeggedBrc20Bridge', {
    from: deployer,
    log: true,
    args: args
  });
  await hre.run('verify:verify', { address: peggedBrc20Bridge.address, constructorArguments: args });
};

deployFunc.tags = ['PeggedBrc20Bridge'];
deployFunc.dependencies = [];
export default deployFunc;
