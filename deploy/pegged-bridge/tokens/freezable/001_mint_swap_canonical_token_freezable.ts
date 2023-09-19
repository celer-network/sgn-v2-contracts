import * as dotenv from 'dotenv';
import { DeployFunction } from 'hardhat-deploy/types';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

dotenv.config();

const deployFunc: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy('MintSwapCanonicalTokenFreezable', {
    from: deployer,
    log: true,
    args: [
      process.env.MINT_SWAP_CANONICAL_TOKEN_NAME,
      process.env.MINT_SWAP_CANONICAL_TOKEN_SYMBOL,
      process.env.MINT_SWAP_CANONICAL_TOKEN_DECIMALS
    ]
  });
};

deployFunc.tags = ['MintSwapCanonicalTokenFreezable'];
deployFunc.dependencies = [];
export default deployFunc;
