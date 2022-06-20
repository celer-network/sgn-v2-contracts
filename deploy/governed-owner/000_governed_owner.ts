import { DeployFunction } from 'hardhat-deploy/types';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

const deployFunc: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const governedOwnerProxy = await deploy('GovernedOwnerProxy', {
    from: deployer,
    log: true
  });
  await hre.run('verify:verify', { address: governedOwnerProxy.address });

  const voters = (process.env.GOVERNANCE_VOTERS as string).split(',');
  const powers = (process.env.GOVERNANCE_POWERS as string).split(',');
  const proxies = (process.env.GOVERNANCE_PROXIES as string).split(',');
  const args = [
    voters,
    powers,
    proxies,
    process.env.GOVERNANCE_ACTIVE_PERIOD,
    process.env.GOVERNANCE_QUORUM_THRESHOLD,
    process.env.GOVERNANCE_FAST_PASS_THRESHOLD
  ];
  const simpleGovernance = await deploy('SimpleGovernance', {
    from: deployer,
    log: true,
    args: args
  });
  await hre.run('verify:verify', { address: simpleGovernance.address, constructorArguments: args });
};

deployFunc.tags = ['GovernedOwner'];
export default deployFunc;
