import * as dotenv from 'dotenv';
import { DeployFunction } from 'hardhat-deploy/types';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

dotenv.config();

const deployFunc: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const args = [
    process.env.CIRCLE_BRIDGE_TOKEN_NAME,
    process.env.CIRCLE_BRIDGE_TOKEN_SYMBOL,
    process.env.CIRCLE_BRIDGE_TOKEN_BRIDGE,
    process.env.CIRCLE_BRIDGE_TOKEN_CANONICAL,
    process.env.CIRCLE_BRIDGE_TOKEN_ORIG_CHAIN_ID
  ];
  const circleBridgeToken = await deploy('CircleBridgeToken', {
    from: deployer,
    log: true,
    args: args
  });
  const txHash = circleBridgeToken.transactionHash!;
  const tx = await hre.ethers.provider.getTransaction(txHash);
  console.log('deploy tx data');
  console.log(tx.data);
  await hre.run('verify:verify', { address: circleBridgeToken.address, constructorArguments: args });
};

deployFunc.tags = ['CircleBridgeToken'];
deployFunc.dependencies = [];
export default deployFunc;
