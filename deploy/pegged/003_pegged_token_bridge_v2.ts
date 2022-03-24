import * as dotenv from 'dotenv';
import { DeployFunction } from 'hardhat-deploy/types';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

dotenv.config();

const deployFunc: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy('PeggedTokenBridgeV2', {
    from: deployer,
    log: true,
    args: [process.env.PEGGED_TOKEN_BRIDGE_SIGS_VERIFIER]
  });
};

deployFunc.tags = ['PeggedTokenBridgeV2'];
deployFunc.dependencies = [];
export default deployFunc;
