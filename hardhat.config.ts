import '@nomiclabs/hardhat-ethers';
import '@nomiclabs/hardhat-waffle';
import '@typechain/hardhat';
import 'hardhat-contract-sizer';
import 'hardhat-deploy';
import 'hardhat-gas-reporter';

import * as dotenv from 'dotenv';
import { HardhatUserConfig } from 'hardhat/types';

dotenv.config();

const DEFAULT_ENDPOINT = 'http://localhost:8545';
const DEFAULT_PRIVATE_KEY = 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';

const kovanEndpoint = process.env.KOVAN_ENDPOINT || DEFAULT_ENDPOINT;
const kovanPrivateKey = process.env.KOVAN_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const ropstenEndpoint = process.env.ROPSTEN_ENDPOINT || DEFAULT_ENDPOINT;
const ropstenPrivateKey = process.env.ROPSTEN_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const goerliEndpoint = process.env.GOERLI_ENDPOINT || DEFAULT_ENDPOINT;
const goerliPrivateKey = process.env.GOERLI_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const bscTestEndpoint = process.env.BSC_TEST_ENDPOINT || DEFAULT_ENDPOINT;
const bscTestPrivateKey = process.env.BSC_TEST_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const fantomTestEndpoint = process.env.FANTOM_TEST_ENDPOINT || DEFAULT_ENDPOINT;
const fantomTestPrivateKey = process.env.FANTOM_TEST_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const ethMainnetEndpoint = process.env.ETH_MAINNET_ENDPOINT || DEFAULT_ENDPOINT;
const ethMainnetPrivateKey = process.env.ETH_MAINNET_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const bscEndpoint = process.env.BSC_ENDPOINT || DEFAULT_ENDPOINT;
const bscPrivateKey = process.env.BSC_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const arbitrumEndpoint = process.env.ARBITRUM_ENDPOINT || DEFAULT_ENDPOINT;
const arbitrumPrivateKey = process.env.ARBITRUM_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const polygonEndpoint = process.env.POLYGON_ENDPOINT || DEFAULT_ENDPOINT;
const polygonPrivateKey = process.env.POLYGON_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const fantomEndpoint = process.env.FANTOM_ENDPOINT || DEFAULT_ENDPOINT;
const fantomPrivateKey = process.env.FANTOM_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const avalancheEndpoint = process.env.AVALANCHE_ENDPOINT || DEFAULT_ENDPOINT;
const avalanchePrivateKey = process.env.AVALANCHE_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const config: HardhatUserConfig = {
  defaultNetwork: 'hardhat',
  networks: {
    hardhat: {},
    localhost: { timeout: 600000 },
    kovan: {
      url: kovanEndpoint,
      accounts: [`0x${kovanPrivateKey}`]
    },
    ropsten: {
      url: ropstenEndpoint,
      accounts: [`0x${ropstenPrivateKey}`]
    },
    goerli: {
      url: goerliEndpoint,
      accounts: [`0x${goerliPrivateKey}`]
    },
    bscTest: {
      url: bscTestEndpoint,
      accounts: [`0x${bscTestPrivateKey}`]
    },
    fantomTest: {
      url: fantomTestEndpoint,
      accounts: [`0x${fantomTestPrivateKey}`]
    },
    ethMainnet: {
      url: ethMainnetEndpoint,
      accounts: [`0x${ethMainnetPrivateKey}`]
    },
    bsc: {
      url: bscEndpoint,
      accounts: [`0x${bscPrivateKey}`]
    },
    arbitrum: {
      url: arbitrumEndpoint,
      accounts: [`0x${arbitrumPrivateKey}`]
    },
    polygon: {
      url: polygonEndpoint,
      accounts: [`0x${polygonPrivateKey}`]
    },
    fantom: {
      url: fantomEndpoint,
      accounts: [`0x${fantomPrivateKey}`]
    },
    avalanche: {
      url: avalancheEndpoint,
      accounts: [`0x${avalanchePrivateKey}`]
    }
  },
  namedAccounts: {
    deployer: {
      default: 0
    }
  },
  solidity: {
    version: '0.8.9',
    settings: {
      optimizer: {
        enabled: true,
        runs: 800
      }
    }
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
  }
};

export default config;
