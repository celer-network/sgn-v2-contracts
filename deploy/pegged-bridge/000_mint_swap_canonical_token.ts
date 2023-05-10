import * as dotenv from 'dotenv';
import { ethers } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { utils, Wallet } from 'zksync-web3';

import { Deployer } from '@matterlabs/hardhat-zksync-deploy';

dotenv.config();

// how to use, from the root directory:
// yarn hardhat deploy-zksync --network zkSync --script deploy/pegged-bridge/000_mint_swap_canonical_token.ts
export default async function(hre: HardhatRuntimeEnvironment) {
  // Initialize the wallet.
  const wallet = new Wallet(process.env.ZK_SYNC_TEST_PRIVATE_KEY as string);

  // Create deployer object and load the artifact of the contract we want to deploy.
  const deployer = new Deployer(hre, wallet);
  const artifact = await deployer.loadArtifact('MintSwapCanonicalToken');

  // Estimate contract deployment fee
  // const deploymentFee = await deployer.estimateDeployFee(artifact, []);

  // // Deposit some funds to L2 in order to be able to perform L2 transactions.
  // const depositHandle = await deployer.zkWallet.deposit({
  //   to: deployer.zkWallet.address,
  //   token: utils.ETH_ADDRESS,
  //   amount: deploymentFee.mul(2)
  // });
  // // Wait until the deposit is processed on zkSync
  // await depositHandle.wait();

  //const parsedFee = ethers.utils.formatEther(deploymentFee.toString());
  //console.log(`The deployment is estimated to cost ${parsedFee} ETH`);

  // Deploy this contract. The returned object will be of a `Contract` type, similarly to ones in `ethers`.
  const args = [
    process.env.MINT_SWAP_CANONICAL_TOKEN_NAME as string,
    process.env.MINT_SWAP_CANONICAL_TOKEN_SYMBOL as string,
    process.env.MINT_SWAP_CANONICAL_TOKEN_DECIMALS,
  ];
  const contract = await deployer.deploy(artifact, args);

  // Show the contract info.
  const contractAddress = contract.address;
  console.log(`${artifact.contractName} was deployed to ${contractAddress}`);

  const verificationId = await hre.run("verify:verify", {
    address: contractAddress,
    contract: "contracts/pegged-bridge/tokens/MintSwapCanonicalToken.sol:MintSwapCanonicalToken",
    constructorArguments: args
  });

  console.log(`verification id is ${verificationId}`);
};