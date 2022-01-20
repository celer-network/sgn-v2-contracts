import * as dotenv from 'dotenv';
import { DeployFunction } from 'hardhat-deploy/types';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

dotenv.config();

const deployFunc: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy('MessageBus', {
    from: deployer,
    log: true,
    args: [
      process.env.MESSAGE_BUS_SIGS_VERIFIER,
      process.env.MESSAGE_BUS_LIQUIDITY_BRIDGE,
      process.env.MESSAGE_BUS_PEG_BRIDGE,
      process.env.MESSAGE_BUS_PEG_VAULT
    ],
    proxy: {
      proxyContract: 'OptimizedTransparentProxy',
      execute: {
        // only called when proxy is deployed, it'll call MessageBus contract.init
        // with proper args
        init: {
          methodName: 'init',
          args: [
            process.env.MESSAGE_BUS_LIQUIDITY_BRIDGE,
            process.env.MESSAGE_BUS_PEG_BRIDGE,
            process.env.MESSAGE_BUS_PEG_VAULT
          ]
        }
      }
    }
  });
};

deployFunc.tags = ['MessageBus'];
deployFunc.dependencies = [];
export default deployFunc;
