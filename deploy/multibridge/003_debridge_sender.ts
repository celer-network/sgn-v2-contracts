import * as dotenv from 'dotenv';
import { DeployFunction } from 'hardhat-deploy/types';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

dotenv.config();

const deployFunc: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const constructorArgs = [
    "0x43dE2d77BF8027e25dBD179B491e8d64f38398aA" //_deBridgeGate
  ];

  const result = await deploy('DeBridgeSenderAdapter', {
    from: deployer,
    log: true,
    args: constructorArgs
  });
  await hre.run('verify:verify', { address: result.address, constructorArguments: constructorArgs  });
};

deployFunc.tags = ['003_debridge_sender'];
deployFunc.dependencies = [];
export default deployFunc;
