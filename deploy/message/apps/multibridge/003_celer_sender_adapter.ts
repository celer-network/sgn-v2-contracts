import * as dotenv from 'dotenv';
import { DeployFunction } from 'hardhat-deploy/types';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

dotenv.config();

const deployFunc: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const args = [process.env.MULTI_BRIDGE_CELER_SRC_MESSAGE_BUS];
  const celerSenderAdapter = await deploy('CelerSenderAdapter', {
    from: deployer,
    log: true,
    args: args
  });
  await hre.run('verify:verify', { address: celerSenderAdapter.address, constructorArguments: args });
};

deployFunc.tags = ['CelerSenderAdapter'];
deployFunc.dependencies = [];
export default deployFunc;
