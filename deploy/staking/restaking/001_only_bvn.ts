import * as dotenv from 'dotenv';
import { DeployFunction } from 'hardhat-deploy/types';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

dotenv.config();

const deployFunc: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const staking = await deployments.get('Staking');
  await deploy('BvnRestaking', {
    from: deployer,
    log: true,
    args: [staking.address]
  });
};

deployFunc.tags = ['BvnRestaking'];
deployFunc.dependencies = [];
export default deployFunc;
