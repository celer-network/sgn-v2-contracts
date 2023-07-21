import * as dotenv from 'dotenv';
import { AbiCoder } from 'ethers/lib/utils';
import { DeployFunction } from 'hardhat-deploy/types';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { Sentinel__factory } from '../../typechain';

dotenv.config();

const deployFunc: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const args: [string[], string[], string[]] = [
    (process.env.SENTINEL_GUARDS as string).split(','),
    (process.env.SENTINEL_PAUSERS as string).split(','),
    (process.env.SENTINEL_GOVERNORS as string).split(','),
  ];
  await deploy('', {
    from: deployer,
    log: true,
    args: args,
    proxy: {
      proxyContract: 'OptimizedTransparentProxy',
       viaAdminContract: process.env.PROXY_ADMIN,
      execute: {
        init: {
          methodName: 'init',
          args:args,
        }
      }
  }
  });
  const sentinelInterface = Sentinel__factory.createInterface();
  const encodedInitData = sentinelInterface.encodeFunctionData('init', args);
  console.log('Encoded init data', encodedInitData);
  const proxyAdmin = await deployments.get('DefaultProxyAdmin');
  console.log('DefaultProxyAdmin', proxyAdmin.address);
  const proxy = await deployments.get('Sentinel_Proxy');
  console.log('Sentinel_Proxy', proxy.address);
  const sentinel = await deployments.get('Sentinel_Implementation');
  await hre.run('verify:verify', { address: sentinel.address, constructorArguments: args});
  // Have to manually verify because hardhat-deploy compiles proxy with 0.8.10
  // const proxyArgs = [messageBus.address, proxyAdmin.address].concat(encodedInitData);
  // await hre.run('verify:verify', { address: proxy.address, constructorArguments: proxyArgs });
  console.log(
    'Encoded proxy constructor args',
    new AbiCoder().encode(['address', 'address', 'bytes'], [sentinel.address, proxyAdmin.address, encodedInitData])
  );
};

deployFunc.tags = ['SentinelUpgradable'];
deployFunc.dependencies = [];
export default deployFunc;
