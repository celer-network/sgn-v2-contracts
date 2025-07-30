import * as dotenv from 'dotenv';
import { DeployFunction } from 'hardhat-deploy/types';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

dotenv.config();

const deployFunc: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy('SigsVerifier', {
    from: deployer,
    log: true,
    args: []
  });
};

deployFunc.tags = ['SigsVerifier'];
deployFunc.dependencies = [];
export default deployFunc;
