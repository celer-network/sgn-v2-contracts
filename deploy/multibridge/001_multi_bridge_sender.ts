import * as dotenv from 'dotenv';
import { DeployFunction } from 'hardhat-deploy/types';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

dotenv.config();

const deployFunc: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  // TODO: set real caller
  const mockCallerAddress = (await deployments.get("MockCaller")).address;

  const constructorArgs = [
    mockCallerAddress //caller
  ];

  const result = await deploy('MultiBridgeSender', {
    from: deployer,
    log: true,
    args: constructorArgs
  });
  await hre.run('verify:verify', { address: result.address, constructorArguments: constructorArgs });
};

deployFunc.tags = ['001_multi_bridge_sender'];
deployFunc.dependencies = [];
export default deployFunc;
