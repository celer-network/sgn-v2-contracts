import * as dotenv from 'dotenv';
import { DeployFunction } from 'hardhat-deploy/types';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

dotenv.config();

const deployFunc: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy('TransferSwap', {
    from: deployer,
    log: true,
    args: [process.env.CC_SWAP_MSG_BUS]
  });
};

deployFunc.tags = ['TransferSwap'];
deployFunc.dependencies = [];
export default deployFunc;
