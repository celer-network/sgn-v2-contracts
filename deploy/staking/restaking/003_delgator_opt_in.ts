import * as dotenv from 'dotenv';
import { DeployFunction } from 'hardhat-deploy/types';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

dotenv.config();

const deployFunc: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const bvn = await deployments.get('BvnRestaking');
  await deploy('DelegatorOptIn', {
    from: deployer,
    log: true,
    args: [bvn.address]
  });
};

deployFunc.tags = ['DelegatorOptIn'];
deployFunc.dependencies = [];
export default deployFunc;
