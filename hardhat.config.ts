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

// Testnets
const kovanEndpoint = process.env.KOVAN_ENDPOINT || DEFAULT_ENDPOINT;
const kovanPrivateKey = process.env.KOVAN_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const ropstenEndpoint = process.env.ROPSTEN_ENDPOINT || DEFAULT_ENDPOINT;
const ropstenPrivateKey = process.env.ROPSTEN_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const goerliEndpoint = process.env.GOERLI_ENDPOINT || DEFAULT_ENDPOINT;
const goerliPrivateKey = process.env.GOERLI_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const bscTestEndpoint = process.env.BSC_TEST_ENDPOINT || DEFAULT_ENDPOINT;
const bscTestPrivateKey = process.env.BSC_TEST_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const optimismTestEndpoint = process.env.OPTIMISM_TEST_ENDPOINT || DEFAULT_ENDPOINT;
const optimismTestPrivateKey = process.env.OPTIMISM_TEST_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const fantomTestEndpoint = process.env.FANTOM_TEST_ENDPOINT || DEFAULT_ENDPOINT;
const fantomTestPrivateKey = process.env.FANTOM_TEST_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const avalancheTestEndpoint = process.env.AVALANCHE_TEST_ENDPOINT || DEFAULT_ENDPOINT;
const avalancheTestPrivateKey = process.env.AVALANCHE_TEST_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const celoAlfajoresTestEndpoint = process.env.CELO_ALFAJORES_TEST_ENDPOINT || DEFAULT_ENDPOINT;
const celoAlfajoresTestPrivateKey = process.env.CELO_ALFAJORES_TEST_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const oasisEmeraldTestEndpoint = process.env.OASIS_EMERALD_TEST_ENDPOINT || DEFAULT_ENDPOINT;
const oasisEmeraldTestPrivateKey = process.env.OASIS_EMERALD_TEST_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const moonbaseAlphaTestEndpoint = process.env.MOONBASE_ALPHA_TEST_ENDPOINT || DEFAULT_ENDPOINT;
const moonbaseAlphaTestPrivateKey = process.env.MOONBASE_ALPHA_TEST_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const reiTestEndpoint = process.env.REI_TEST_ENDPOINT || DEFAULT_ENDPOINT;
const reiTestPrivateKey = process.env.REI_TEST_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

// Mainnets
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

const optimismEndpoint = process.env.OPTIMISM_ENDPOINT || DEFAULT_ENDPOINT;
const optimismPrivateKey = process.env.OPTIMISM_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const bobaEndpoint = process.env.BOBA_ENDPOINT || DEFAULT_ENDPOINT;
const bobaPrivateKey = process.env.BOBA_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const harmonyEndpoint = process.env.HARMONY_ENDPOINT || DEFAULT_ENDPOINT;
const harmonyPrivateKey = process.env.HARMONY_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const moonriverEndpoint = process.env.MOONRIVER_ENDPOINT || DEFAULT_ENDPOINT;
const moonriverPrivateKey = process.env.MOONRIVER_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const celoEndpoint = process.env.CELO_ENDPOINT || DEFAULT_ENDPOINT;
const celoPrivateKey = process.env.CELO_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const oasisEmeraldEndpoint = process.env.OASIS_EMERALD_ENDPOINT || DEFAULT_ENDPOINT;
const oasisEmeraldPrivateKey = process.env.OASIS_EMERALD_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const metisEndpoint = process.env.METIS_ENDPOINT || DEFAULT_ENDPOINT;
const metisPrivateKey = process.env.METIS_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const auroraEndpoint = process.env.AURORA_ENDPOINT || DEFAULT_ENDPOINT;
const auroraPrivateKey = process.env.AURORA_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const xdaiEndpoint = process.env.XDAI_ENDPOINT || DEFAULT_ENDPOINT;
const xdaiPrivateKey = process.env.XDAI_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const oecEndpoint = process.env.OEC_ENDPOINT || DEFAULT_ENDPOINT;
const oecPrivateKey = process.env.OEC_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const hecoEndpoint = process.env.HECO_ENDPOINT || DEFAULT_ENDPOINT;
const hecoPrivateKey = process.env.HECO_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const moonbeamEndpoint = process.env.MOONBEAM_ENDPOINT || DEFAULT_ENDPOINT;
const moonbeamPrivateKey = process.env.MOONBEAM_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

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
    optimismTest: {
      url: optimismTestEndpoint,
      accounts: [`0x${optimismTestPrivateKey}`]
    },
    avalancheTest: {
      url: avalancheTestEndpoint,
      accounts: [`0x${avalancheTestPrivateKey}`]
    },
    celoAlfajoresTest: {
      url: celoAlfajoresTestEndpoint,
      accounts: [`0x${celoAlfajoresTestPrivateKey}`]
    },
    oasisEmeraldTest: {
      url: oasisEmeraldTestEndpoint,
      accounts: [`0x${oasisEmeraldTestPrivateKey}`]
    },
    moonbaseAlphaTest: {
      url: moonbaseAlphaTestEndpoint,
      accounts: [`0x${moonbaseAlphaTestPrivateKey}`]
    },
    reiTest: {
      url: reiTestEndpoint,
      accounts: [`0x${reiTestPrivateKey}`]
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
    },
    optimism: {
      url: optimismEndpoint,
      accounts: [`0x${optimismPrivateKey}`]
    },
    boba: {
      url: bobaEndpoint,
      accounts: [`0x${bobaPrivateKey}`]
    },
    harmony: {
      url: harmonyEndpoint,
      accounts: [`0x${harmonyPrivateKey}`]
    },
    moonriver: {
      url: moonriverEndpoint,
      accounts: [`0x${moonriverPrivateKey}`]
    },
    celo: {
      url: celoEndpoint,
      accounts: [`0x${celoPrivateKey}`]
    },
    oasisEmerald: {
      url: oasisEmeraldEndpoint,
      accounts: [`0x${oasisEmeraldPrivateKey}`]
    },
    metis: {
      url: metisEndpoint,
      accounts: [`0x${metisPrivateKey}`]
    },
    aurora: {
      url: auroraEndpoint,
      accounts: [`0x${auroraPrivateKey}`]
    },
    xdai: {
      url: xdaiEndpoint,
      accounts: [`0x${xdaiPrivateKey}`]
    },
    oec: {
      url: oecEndpoint,
      accounts: [`0x${oecPrivateKey}`]
    },
    heco: {
      url: hecoEndpoint,
      accounts: [`0x${hecoPrivateKey}`]
    },
    moonbeam: {
      url: moonbeamEndpoint,
      accounts: [`0x${moonbeamPrivateKey}`]
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
