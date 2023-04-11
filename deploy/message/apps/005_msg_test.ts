import { DeployFunction } from 'hardhat-deploy/types';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

const deployFunc: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const args = [process.env.MESSAGE_BUS_ADDR];
  const dep = await deploy('MsgTest', {
    from: deployer,
    log: true,
    args
  });

  await hre.run('verify:verify', { address: dep.address, constructorArguments: args });
};

deployFunc.tags = ['MsgTest'];
export default deployFunc;
