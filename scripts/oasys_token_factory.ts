import * as dotenv from 'dotenv';
import { parseUnits } from 'ethers/lib/utils';

import { L1StandardERC20__factory, L1StandardERC20Factory__factory } from '../typechain';
import { getDeployerSigner } from './common';

dotenv.config();

async function createToken(): Promise<void> {
  const deployerSigner = await getDeployerSigner();

  const pegbrV2Addr = process.env.PEGGED_TOKEN_BRIDGE as string;
  const factoryAddr = process.env.OASYS_TOKEN_FACTORY as string;
  const tokenName = process.env.OASYS_FACTORY_TOKEN_NAME as string;
  const tokenSymbol = process.env.OASYS_FACTORY_TOKEN_SYMBOL as string;

  console.log('creating token, calling token factory', factoryAddr);
  const factory = L1StandardERC20Factory__factory.connect(factoryAddr, deployerSigner);
  const tx = await factory.createStandardERC20(tokenName, tokenSymbol, {
    gasLimit: 5_000_000,
    maxFeePerGas: parseUnits('10', 'gwei'),
    maxPriorityFeePerGas: parseUnits('8', 'gwei')
  });
  console.log('tx hash', tx.hash);
  await tx.wait(2);

  const tokenAddr = 'ef1c93a38ea284cdc7f2a0edca7c4ffde4d55cba';

  console.log('deployed token address', tokenAddr);
  console.log('adding minter role');
  const token = L1StandardERC20__factory.connect(tokenAddr, deployerSigner);
  const setRoleTx = await token.grantRole(await token.MINTER_ROLE(), pegbrV2Addr, {
    gasLimit: 5_000_000,
    nonce: 24,
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
