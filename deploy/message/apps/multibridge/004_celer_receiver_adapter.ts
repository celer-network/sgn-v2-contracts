import * as dotenv from 'dotenv';
import { DeployFunction } from 'hardhat-deploy/types';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

dotenv.config();

const deployFunc: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const args = [process.env.MULTI_BRIDGE_CELER_DST_MESSAGE_BUS];
  const celerReceiverAdapter = await deploy('CelerReceiverAdapter', {
    from: deployer,
    log: true,
    args: args
  });
  await hre.run('verify:verify', { address: celerReceiverAdapter.address, constructorArguments: args });
};

deployFunc.tags = ['CelerReceiverAdapter'];
deployFunc.dependencies = [];
export default deployFunc;
