import '@matterlabs/hardhat-zksync-deploy';
import "@matterlabs/hardhat-zksync-verify";
import '@matterlabs/hardhat-zksync-solc';
import '@nomiclabs/hardhat-ethers';
import '@nomiclabs/hardhat-etherscan';
import '@nomiclabs/hardhat-waffle';
import '@typechain/hardhat';
import 'hardhat-contract-sizer';
import 'hardhat-deploy';
import 'hardhat-gas-reporter';
import "@rumblefishdev/hardhat-kms-signer";

import * as dotenv from 'dotenv';
import { HardhatUserConfig, NetworkUserConfig } from 'hardhat/types';

dotenv.config();

const DEFAULT_ENDPOINT = 'http://localhost:8545';
const DEFAULT_PRIVATE_KEY =
  process.env.DEFAULT_PRIVATE_KEY || 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';

// Testnets
const goerliEndpoint = process.env.GOERLI_ENDPOINT || DEFAULT_ENDPOINT;

const zkSyncTestEndpoint = process.env.ZK_SYNC_TEST_ENDPOINT || DEFAULT_ENDPOINT;
const zkSyncTestPrivateKey = process.env.ZK_SYNC_TEST_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

// Mainnets
const ethMainEndpoint = process.env.ETH_MAINNET_ENDPOINT || DEFAULT_ENDPOINT;

const zkSyncEndpoint = process.env.ZK_SYNC_ENDPOINT || DEFAULT_ENDPOINT;
const zkSyncPrivateKey = process.env.ZK_SYNC_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const kmsKeyId = process.env.KMS_KEY_ID || "";

// use kmsKeyId if it's not empty, otherwise use privateKey
function getNetworkConfig(url: string, ethNetwork: string, kmsKeyId: string, privateKey: string, verifyURL?: string) : NetworkUserConfig {
  let network : NetworkUserConfig = !kmsKeyId ? {
    url: url,
    ethNetwork: ethNetwork,
    accounts: [`0x${privateKey}`],
    zksync: true
  } : {
    url: url,
    ethNetwork: ethNetwork,
    kmsKeyId: kmsKeyId,
    zksync: true
  };

  if (verifyURL) {
    network.verifyURL =  verifyURL;
  } 

  return network;
}

const config: HardhatUserConfig = {
  defaultNetwork: 'hardhat',
  networks: {
    // Testnets
    hardhat: {
      zksync: true
    },
    zkSyncTest: getNetworkConfig(zkSyncTestEndpoint, goerliEndpoint, kmsKeyId, zkSyncTestPrivateKey),
    zkSync: getNetworkConfig(zkSyncEndpoint, ethMainEndpoint, kmsKeyId, zkSyncPrivateKey, 
      'https://zksync2-mainnet-explorer.zksync.io/contract_verification')
  },
  namedAccounts: {
    deployer: {
      default: 0
    }
  },
  solidity: {
    version: '0.8.17'
  },
  contractSizer: {
    alphaSort: true,
    runOnCompile: false,
    disambiguatePaths: false
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS === 'true' ? true : false,
    noColors: true,
    outputFile: 'reports/gas_usage/summary.txt'
  },
  typechain: {
    outDir: 'typechain',
    target: 'ethers-v5'
  },
  zksolc: {
    version: '1.3.1',
    compilerSource: 'binary',
    settings: {
      experimental: {
        dockerImage: 'matterlabs/zksolc',
        tag: 'v1.3.1'
      }
    }
  }
};

export default config;
