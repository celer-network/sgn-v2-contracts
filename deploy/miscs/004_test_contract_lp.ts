import { DeployFunction } from 'hardhat-deploy/types';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

const deployFunc: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy('ContractLP', {
    from: deployer,
    log: true,
    args: [
      process.env.TEST_TOKEN_NAME,
      process.env.TEST_TOKEN_SYMBOL,
    ]
  });
};

deployFunc.tags = ['ContractLP'];
export default deployFunc;
