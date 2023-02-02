import * as dotenv from 'dotenv';
import { DeployFunction } from 'hardhat-deploy/types';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

dotenv.config();

const deployFunc: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const result = await deploy('MockCaller', {
    from: deployer,
    log: true
  });
  await hre.run('verify:verify', { address: result.address });
};

deployFunc.tags = ['000_mock_caller'];
deployFunc.dependencies = [];
export default deployFunc;
