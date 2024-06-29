import * as dotenv from 'dotenv';
import { AbiCoder, parseUnits } from 'ethers';

import { L1StandardERC20__factory, L1StandardERC20Factory__factory } from '../typechain';
import { getDeployerSigner } from './common';

dotenv.config();

async function createToken(): Promise<void> {
  const abiCoder = AbiCoder.defaultAbiCoder();

  const deployerSigner = await getDeployerSigner();

  const pegbrV2Addr = process.env.PEGGED_TOKEN_BRIDGE as string;
  const factoryAddr = process.env.OASYS_TOKEN_FACTORY as string;
  const tokenName = process.env.OASYS_FACTORY_TOKEN_NAME as string;
  const tokenSymbol = process.env.OASYS_FACTORY_TOKEN_SYMBOL as string;

  console.log(
    'params',
    '\nPEGGED_TOKEN_BRIDGE',
    pegbrV2Addr,
    '\nOASYS_TOKEN_FACTORY',
    factoryAddr,
    '\nOASYS_FACTORY_TOKEN_NAME',
    tokenName,
    '\nOASYS_FACTORY_TOKEN_SYMBOL',
    tokenSymbol
  );

  console.log('creating ERC20 token, calling token factory', factoryAddr);
  const factory = L1StandardERC20Factory__factory.connect(factoryAddr, deployerSigner);
  const tx = await factory.createStandardERC20(tokenName, tokenSymbol, {
    gasLimit: 5_000_000,
    maxFeePerGas: parseUnits('10', 'gwei'),
    maxPriorityFeePerGas: parseUnits('8', 'gwei')
  });
  console.log('tx hash', tx.hash, 'nonce', tx.nonce, 'waiting for 5 block confirmations...');
  await tx.wait(5);
  console.log('deployed, finding tx receipt for logs...');
  const receipt = (await deployerSigner.provider.getTransactionReceipt(tx.hash))!;
  const log = receipt.logs.find((log) => log.address === factoryAddr);
  if (!log || log.topics.length !== 3) {
    console.error('token creation log not found');
    process.exit(1);
  }
  const tokenAddr = abiCoder.decode(['address'], log.topics[2]).toString();

  console.log('deployed token address', tokenAddr);
  const token = L1StandardERC20__factory.connect(tokenAddr, deployerSigner);
  const minterRole = await token.MINTER_ROLE();
  console.log('adding minter role', minterRole);
  const setRoleTx = await token.grantRole(minterRole, pegbrV2Addr, {
    gasLimit: 5_000_000,
    nonce: tx.nonce + 1,
    maxFeePerGas: parseUnits('10', 'gwei'),
    maxPriorityFeePerGas: parseUnits('8', 'gwei')
  });
  console.log('tx hash', setRoleTx.hash);
  await setRoleTx.wait(2);
}

createToken();

// ABI of https://github.com/oasysgames/oasys-optimism/blob/develop/packages/contracts/contracts/oasys/L1/token/L1StandardERC20Factory.sol
// [
//   {
//     "anonymous": false,
//     "inputs": [
//       {
//         "indexed": true,
//         "internalType": "string",
//         "name": "_symbol",
//         "type": "string"
//       },
//       {
//         "indexed": true,
//         "internalType": "address",
//         "name": "_address",
//         "type": "address"
//       }
//     ],
//     "name": "ERC20Created",
//     "type": "event"
//   },
//   {
//     "inputs": [
//       {
//         "internalType": "string",
//         "name": "_name",
//         "type": "string"
//       },
//       {
//         "internalType": "string",
//         "name": "_symbol",
//         "type": "string"
//       }
//     ],
//     "name": "createStandardERC20",
//     "outputs": [],
//     "stateMutability": "nonpayable",
//     "type": "function"
//   }
// ]
