import * as dotenv from 'dotenv';
import { DeployFunction } from 'hardhat-deploy/types';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

dotenv.config();

const deployFunc: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy('FraxBridgeToken', {
    from: deployer,
    log: true,
    args: [
      process.env.FRAX_BRIDGE_TOKEN_NAME,
      process.env.FRAX_BRIDGE_TOKEN_SYMBOL,
      process.env.FRAX_BRIDGE_TOKEN_BRIDGE,
      process.env.FRAX_BRIDGE_TOKEN_CANONICAL
    ]
  });
};

deployFunc.tags = ['FraxBridgeToken'];
deployFunc.dependencies = [];
export default deployFunc;
