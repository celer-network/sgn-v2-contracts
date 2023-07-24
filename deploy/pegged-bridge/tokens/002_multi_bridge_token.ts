import * as dotenv from 'dotenv';
import { DeployFunction } from 'hardhat-deploy/types';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

dotenv.config();

const deployFunc: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const args = [
    process.env.MULTI_BRIDGE_TOKEN_NAME,
    process.env.MULTI_BRIDGE_TOKEN_SYMBOL,
    process.env.MULTI_BRIDGE_TOKEN_DECIMALS
  ];
  const multiBridgeToken = await deploy('MultiBridgeToken', {
    from: deployer,
    log: true,
    args: args
  });
  await hre.run('verify:verify', { address: multiBridgeToken.address, constructorArguments: args });
};

deployFunc.tags = ['MultiBridgeToken'];
deployFunc.dependencies = [];
export default deployFunc;
