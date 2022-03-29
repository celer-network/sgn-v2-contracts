import * as dotenv from 'dotenv';
import { DeployFunction } from 'hardhat-deploy/types';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

dotenv.config();

const deployFunc: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy('MsgTest', {
    from: deployer,
    log: true,
    args: [process.env.MESSAGE_BUS]
  });

  const msgtest = await deployments.get('MsgTest');

  await hre.run('verify:verify', {
    address: msgtest.address,
    constructorArguments: [process.env.MESSAGE_BUS]
  });
};

deployFunc.tags = ['MsgTest'];
deployFunc.dependencies = [];
export default deployFunc;
