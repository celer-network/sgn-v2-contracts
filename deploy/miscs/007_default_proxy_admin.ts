import * as dotenv from 'dotenv';
import { DeployFunction } from 'hardhat-deploy/types';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

dotenv.config();

const deployFunc: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const args = [process.env.PROXY_ADMIN_OWNER];
  const proxyAdmin = await deploy('DefaultProxyAdmin', {
    contract: 'ProxyAdmin',
    from: deployer,
    log: true,
    args: args
  });
  await hre.run('verify:verify', { address: proxyAdmin.address, constructorArguments: args });
};

deployFunc.tags = ['DefaultProxyAdmin'];
export default deployFunc;
