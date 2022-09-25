import '@matterlabs/hardhat-zksync-deploy';
import '@matterlabs/hardhat-zksync-solc';
import '@nomiclabs/hardhat-ethers';
import '@nomiclabs/hardhat-etherscan';
import '@nomiclabs/hardhat-waffle';
import '@typechain/hardhat';
import 'hardhat-contract-sizer';
import 'hardhat-deploy';
import 'hardhat-gas-reporter';

import * as dotenv from 'dotenv';
import { HardhatUserConfig } from 'hardhat/types';

dotenv.config();

const DEFAULT_ENDPOINT = 'http://localhost:8545';
const DEFAULT_PRIVATE_KEY =
  process.env.DEFAULT_PRIVATE_KEY || 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';

// Testnets
const goerliEndpoint = process.env.GOERLI_ENDPOINT || DEFAULT_ENDPOINT;

const zkSyncTestEndpoint = process.env.ZK_SYNC_TEST_ENDPOINT || DEFAULT_ENDPOINT;
const zkSyncTestPrivateKey = process.env.ZK_SYNC_TEST_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

// Mainnets

const config: HardhatUserConfig = {
  defaultNetwork: 'hardhat',
  networks: {
    // Testnets
    hardhat: {
      zksync: true
    },
    zkSyncTest: {
      url: zkSyncTestEndpoint,
      accounts: [`0x${zkSyncTestPrivateKey}`],
      zksync: true
    }
  },
  namedAccounts: {
    deployer: {
      default: 0
    }
  },
  solidity: {
    version: '0.8.16'
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
  etherscan: {
    apiKey: {
      goerli: process.env.ETHERSCAN_API_KEY,
      avalancheFujiTestnet: process.env.SNOWTRACE_API_KEY,
      bscTestnet: process.env.BSCSCAN_API_KEY,
      arbitrumTestnet: process.env.ARBISCAN_API_KEY,
      ftmTestnet: process.env.FTMSCAN_API_KEY,
      polygonMumbai: process.env.POLYGONSCAN_API_KEY,

      mainnet: process.env.ETHERSCAN_API_KEY,
      avalanche: process.env.SNOWTRACE_API_KEY,
      bsc: process.env.BSCSCAN_API_KEY,
      arbitrumOne: process.env.ARBISCAN_API_KEY,
      optimisticEthereum: process.env.OPTIMISTIC_ETHERSCAN_API_KEY,
      opera: process.env.FTMSCAN_API_KEY,
      polygon: process.env.POLYGONSCAN_API_KEY,
      aurora: process.env.AURORASCAN_API_KEY,
      moonriver: process.env.MOONRIVER_MOONSCAN_API_KEY,
      moonbeam: process.env.MOONBEAM_MOONSCAN_API_KEY,
      heco: process.env.HECOSCAN_API_KEY
    }
  },
  zksolc: {
    version: '1.1.6',
    compilerSource: 'binary',
    settings: {
      experimental: {
        dockerImage: 'matterlabs/zksolc',
        tag: 'v1.1.6'
      }
    }
  },
  zkSyncDeploy: {
    zkSyncNetwork: zkSyncTestEndpoint,
    ethNetwork: goerliEndpoint
  }
};

export default config;
