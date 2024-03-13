import * as dotenv from 'dotenv';
import { DeployFunction } from 'hardhat-deploy/types';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

dotenv.config();

const deployFunc: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  // const { deployments, getNamedAccounts } = hre;
  // const { deploy } = deployments;
  // const { deployer } = await getNamedAccounts();

  const args = [process.env.BLAST_POINTS_ADDRESS, process.env.BLAST_POINTS_OPERATOR];

  // const bridge = await deploy('Bridge', {
  //   from: deployer,
  //   log: true,
  //   args: args
  // });
  const bridge = { address: '0x841ce48F9446C8E281D3F1444cB859b4A6D0738C' };
  await hre.run('verify:verify', { address: bridge.address, constructorArguments: args });
};

deployFunc.tags = ['Bridge'];
deployFunc.dependencies = [];
export default deployFunc;
