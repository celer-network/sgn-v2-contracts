// Uncomment for zksync
// import * as dotenv from 'dotenv';
// import * as hre from 'hardhat';
// import { Wallet } from 'zksync-web3';

// import { Deployer } from '@matterlabs/hardhat-zksync-deploy';

// dotenv.config();

// async function deploy() {
//   const contractName = 'Sentinel';
//   console.log('Deploying ' + contractName + '...');

//   const zkWallet = new Wallet(process.env.ZKSYNC_ERA_PRIVATE_KEY as string);
//   const deployer = new Deployer(hre, zkWallet);

//   const contract = await deployer.loadArtifact(contractName);
//   const args: [string[], string[], string[]] = [
//     (process.env.SENTINEL_GUARDS as string).split(','),
//     (process.env.SENTINEL_PAUSERS as string).split(','),
//     (process.env.SENTINEL_GOVERNORS as string).split(',')
//   ];
//   const sentinelProxy = await hre.zkUpgrades.deployProxy(deployer.zkWallet, contract, args, {
//     initializer: 'init',
//     unsafeAllow: ['constructor']
//   });

//   await sentinelProxy.deployed();
//   console.log(contractName + ' deployed to:', sentinelProxy.address);
// }

// deploy().catch((error) => {
//   console.error(error);
//   process.exitCode = 1;
// });
