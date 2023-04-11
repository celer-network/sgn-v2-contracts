import { DeployFunction } from 'hardhat-deploy/types';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

const deployFunc: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const voters = (process.env.GOVERNANCE_VOTERS as string).split(',');
  const powers = (process.env.GOVERNANCE_POWERS as string).split(',');
  const messageBusOwnerArgs = [
    voters,
    powers,
    process.env.GOVERNANCE_ACTIVE_PERIOD,
    process.env.GOVERNANCE_QUORUM_THRESHOLD
  ];
  const messageBusOwner = await deploy('MessageBusOwner', {
    from: deployer,
    log: true,
    args: messageBusOwnerArgs
  });
  await hre.run('verify:verify', { address: messageBusOwner.address, constructorArguments: messageBusOwnerArgs });
};

deployFunc.tags = ['MessageBusOwner'];
export default deployFunc;
