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
      process.env.CBRIDGE_ADDRESS,
      process.env.WITHDRAW_INBOX_ADDRESS,
    ]
  });
};

deployFunc.tags = ['ContractLP'];
export default deployFunc;
