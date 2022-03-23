import * as dotenv from 'dotenv';
import { DeployFunction } from 'hardhat-deploy/types';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

dotenv.config();

const deployFunc: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy('NFTBridge', {
    from: deployer,
    log: true,
    args: [
      process.env.MSG_BUS_ADDR
    ]
  });
};

deployFunc.tags = ['NFTBridge'];
deployFunc.dependencies = [];
export default deployFunc;
