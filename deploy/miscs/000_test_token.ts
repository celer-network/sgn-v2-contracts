import * as dotenv from 'dotenv';
import { DeployFunction } from 'hardhat-deploy/types';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

dotenv.config();

const deployFunc: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy('MintableERC20', {
    from: deployer,
    log: true,
    args: [
      process.env.TEST_TOKEN_NAME,
      process.env.TEST_TOKEN_SYMBOL,
      process.env.TEST_TOKEN_DECIMALS,
      process.env.TEST_TOKEN_SUPPLY
    ]
  });
};

deployFunc.tags = ['Test' + (process.env.TEST_TOKEN_SYMBOL || 'Token')];
export default deployFunc;
