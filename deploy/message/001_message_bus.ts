import * as dotenv from 'dotenv';
import { DeployFunction } from 'hardhat-deploy/types';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

dotenv.config();

const deployFunc: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const constructorArgs = [
    process.env.MESSAGE_BUS_SIGS_VERIFIER,
    process.env.MESSAGE_BUS_LIQUIDITY_BRIDGE as string,
    process.env.MESSAGE_BUS_PEG_BRIDGE as string,
    process.env.MESSAGE_BUS_PEG_VAULT as string,
    process.env.MESSAGE_BUS_PEG_BRIDGE_V2 as string,
    process.env.MESSAGE_BUS_PEG_VAULT_V2 as string
  ];

  const result = await deploy('MessageBus', {
    from: deployer,
    log: true,
    args: constructorArgs
  });
  await hre.run('verify:verify', { address: result.address, constructorArguments: constructorArgs });
};

deployFunc.tags = ['MessageBus'];
deployFunc.dependencies = [];
export default deployFunc;
