import '@nomiclabs/hardhat-ethers';
import '@nomiclabs/hardhat-etherscan';
import '@nomiclabs/hardhat-waffle';
import '@typechain/hardhat';
import 'hardhat-contract-sizer';
import 'hardhat-deploy';
import 'hardhat-gas-reporter';
import '@oasisprotocol/sapphire-hardhat';
import "@rumblefishdev/hardhat-kms-signer";

import * as dotenv from 'dotenv';
import { HardhatUserConfig } from 'hardhat/types';

dotenv.config();

const DEFAULT_ENDPOINT = 'http://localhost:8545';
const DEFAULT_PRIVATE_KEY =
  process.env.DEFAULT_PRIVATE_KEY || 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';

const kmsKeyId = process.env.KMS_KEY_ID;

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

const oasisSapphireTestEndpoint = process.env.OASIS_SAPPHIRE_TEST_ENDPOINT || DEFAULT_ENDPOINT;
const oasisSapphireTestPrivateKey = process.env.OASIS_SAPPHIRE_TEST_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const moonbaseAlphaTestEndpoint = process.env.MOONBASE_ALPHA_TEST_ENDPOINT || DEFAULT_ENDPOINT;
const moonbaseAlphaTestPrivateKey = process.env.MOONBASE_ALPHA_TEST_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const reiTestEndpoint = process.env.REI_TEST_ENDPOINT || DEFAULT_ENDPOINT;
const reiTestPrivateKey = process.env.REI_TEST_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const nervosGodwokenTestEndpoint = process.env.NERVOS_GODWOKEN_TEST_ENDPOINT || DEFAULT_ENDPOINT;
const nervosGodwokenTestPrivateKey = process.env.NERVOS_GODWOKEN_TEST_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const kavaTestEndpoint = process.env.KAVA_TEST_ENDPOINT || DEFAULT_ENDPOINT;
const kavaTestPrivateKey = process.env.KAVA_TEST_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const darwiniaPangolinTestEndpoint = process.env.DARWINIA_PANGOLIN_TEST_ENDPOINT || DEFAULT_ENDPOINT;
const darwiniaPangolinTestPrivateKey = process.env.DARWINIA_PANGOLIN_TEST_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const platonTestEndpoint = process.env.PLATON_TEST_ENDPOINT || DEFAULT_ENDPOINT;
const platonTestPrivateKey = process.env.PLATON_TEST_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const polygonTestEndpoint = process.env.POLYGON_TEST_ENDPOINT || DEFAULT_ENDPOINT;
const polygonTestPrivateKey = process.env.POLYGON_TEST_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const sxTestEndpoint = process.env.SX_TEST_ENDPOINT || DEFAULT_ENDPOINT;
const sxTestPrivateKey = process.env.SX_TEST_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const swimmerTestEndpoint = process.env.SWIMMER_TEST_ENDPOINT || DEFAULT_ENDPOINT;
const swimmerTestPrivateKey = process.env.SWIMMER_TEST_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const dexalotTestEndpoint = process.env.DEXALOT_TEST_ENDPOINT || DEFAULT_ENDPOINT;
const dexalotTestPrivateKey = process.env.DEXALOT_TEST_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const nervosTestnetEndpoint = process.env.NERVOS_TESTNET_ENDPOINT || DEFAULT_ENDPOINT;
const nervosTestnetPrivateKey = process.env.NERVOS_TESTNET_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const shibuyaTestnetEndpoint = process.env.SHIBUYA_TESTNET_ENDPOINT || DEFAULT_ENDPOINT;
const shibuyaTestnetPrivateKey = process.env.SHIBUYA_TESTNET_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const cubeDevnetEndpoint = process.env.CUBE_DEVNET_ENDPOINT || DEFAULT_ENDPOINT;
const cubeDevnetPrivateKey = process.env.CUBE_DEVNET_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const oasysTestEndpoint = process.env.OASYS_TEST_ENDPOINT || DEFAULT_ENDPOINT;
const oasysTestPrivateKey = process.env.OASYS_TEST_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const antiMatTestnetEndpoint = process.env.ANTIMAT_TESTNET_ENDPOINT || DEFAULT_ENDPOINT;
const antiMatTestnetPrivateKey = process.env.ANTIMAT_TESTNET_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

// Mainnets
const ethMainnetEndpoint = process.env.ETH_MAINNET_ENDPOINT || DEFAULT_ENDPOINT;

const bscEndpoint = process.env.BSC_ENDPOINT || DEFAULT_ENDPOINT;

const arbitrumEndpoint = process.env.ARBITRUM_ENDPOINT || DEFAULT_ENDPOINT;

const arbitrumNovaEndpoint = process.env.ARBITRUM_NOVA_ENDPOINT || DEFAULT_ENDPOINT;

const polygonEndpoint = process.env.POLYGON_ENDPOINT || DEFAULT_ENDPOINT;

const fantomEndpoint = process.env.FANTOM_ENDPOINT || DEFAULT_ENDPOINT;

const avalancheEndpoint = process.env.AVALANCHE_ENDPOINT || DEFAULT_ENDPOINT;

const optimismEndpoint = process.env.OPTIMISM_ENDPOINT || DEFAULT_ENDPOINT;

const bobaEndpoint = process.env.BOBA_ENDPOINT || DEFAULT_ENDPOINT;

const harmonyEndpoint = process.env.HARMONY_ENDPOINT || DEFAULT_ENDPOINT;

const moonbeamEndpoint = process.env.MOONBEAM_ENDPOINT || DEFAULT_ENDPOINT;

const moonriverEndpoint = process.env.MOONRIVER_ENDPOINT || DEFAULT_ENDPOINT;

const celoEndpoint = process.env.CELO_ENDPOINT || DEFAULT_ENDPOINT;

const oasisEmeraldEndpoint = process.env.OASIS_EMERALD_ENDPOINT || DEFAULT_ENDPOINT;

const oasisSapphireEndpoint = process.env.OASIS_SAPPHIRE_ENDPOINT || DEFAULT_ENDPOINT;

const metisEndpoint = process.env.METIS_ENDPOINT || DEFAULT_ENDPOINT;

const auroraEndpoint = process.env.AURORA_ENDPOINT || DEFAULT_ENDPOINT;

const xdaiEndpoint = process.env.XDAI_ENDPOINT || DEFAULT_ENDPOINT;

const oecEndpoint = process.env.OEC_ENDPOINT || DEFAULT_ENDPOINT;

const hecoEndpoint = process.env.HECO_ENDPOINT || DEFAULT_ENDPOINT;

const astarEndpoint = process.env.ASTAR_ENDPOINT || DEFAULT_ENDPOINT;

const shidenEndpoint = process.env.SHIDEN_ENDPOINT || DEFAULT_ENDPOINT;

const syscoinEndpoint = process.env.SYSCOIN_ENDPOINT || DEFAULT_ENDPOINT;

const milkomedaEndpoint = process.env.MILKOMEDA_ENDPOINT || DEFAULT_ENDPOINT;

const evmosEndpoint = process.env.EVMOS_ENDPOINT || DEFAULT_ENDPOINT;

const cloverEndpoint = process.env.CLOVER_ENDPOINT || DEFAULT_ENDPOINT;

const reiEndpoint = process.env.REI_ENDPOINT || DEFAULT_ENDPOINT;

const confluxEndpoint = process.env.CONFLUX_ENDPOINT || DEFAULT_ENDPOINT;

const darwiniaCrabEndpoint = process.env.DARWINIA_CRAB_ENDPOINT || DEFAULT_ENDPOINT;

const platonEndpoint = process.env.PLATON_ENDPOINT || DEFAULT_ENDPOINT;

const ontologyEndpoint = process.env.ONTOLOGY_ENDPOINT || DEFAULT_ENDPOINT;

const swimmerEndpoint = process.env.SWIMMER_ENDPOINT || DEFAULT_ENDPOINT;

const sxNetworkEndpoint = process.env.SX_NETWORK_ENDPOINT || DEFAULT_ENDPOINT;

const apeEndpoint = process.env.APE_ENDPOINT || DEFAULT_ENDPOINT;

const kavaEndpoint = process.env.KAVA_ENDPOINT || DEFAULT_ENDPOINT;

const fncyEndpoint = process.env.FNCY_ENDPOINT || DEFAULT_ENDPOINT;

const nervosGodwokenEndpoint = process.env.NERVOS_GODWOKEN_ENDPOINT || DEFAULT_ENDPOINT;

const klaytnEndpoint = process.env.KLAYTN_ENDPOINT || DEFAULT_ENDPOINT;

const oasysEndpoint = process.env.OASYS_ENDPOINT || DEFAULT_ENDPOINT;

const config: HardhatUserConfig = {
  defaultNetwork: 'hardhat',
  networks: {
    // Testnets
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
    oasisSapphireTest: {
      url: oasisSapphireTestEndpoint,
      accounts: [`0x${oasisSapphireTestPrivateKey}`]
    },
    moonbaseAlphaTest: {
      url: moonbaseAlphaTestEndpoint,
      accounts: [`0x${moonbaseAlphaTestPrivateKey}`]
    },
    reiTest: {
      url: reiTestEndpoint,
      accounts: [`0x${reiTestPrivateKey}`]
    },
    nervosGodwokenTest: {
      url: nervosGodwokenTestEndpoint,
      accounts: [`0x${nervosGodwokenTestPrivateKey}`]
    },
    kavaTest: {
      url: kavaTestEndpoint,
      accounts: [`0x${kavaTestPrivateKey}`]
    },
    darwiniaPangolinTest: {
      url: darwiniaPangolinTestEndpoint,
      accounts: [`0x${darwiniaPangolinTestPrivateKey}`]
    },
    platonTest: {
      url: platonTestEndpoint,
      accounts: [`0x${platonTestPrivateKey}`]
    },
    polygonTest: {
      url: polygonTestEndpoint,
      accounts: [`0x${polygonTestPrivateKey}`]
    },
    sxTest: {
      url: sxTestEndpoint,
      accounts: [`0x${sxTestPrivateKey}`]
    },
    swimmerTest: {
      url: swimmerTestEndpoint,
      accounts: [`0x${swimmerTestPrivateKey}`]
    },
    dexalotTest: {
      url: dexalotTestEndpoint,
      accounts: [`0x${dexalotTestPrivateKey}`]
    },
    nervosTestnet: {
      url: nervosTestnetEndpoint,
      accounts: [`0x${nervosTestnetPrivateKey}`]
    },
    shibuyaTestnet: {
      url: shibuyaTestnetEndpoint,
      accounts: [`0x${shibuyaTestnetPrivateKey}`]
    },
    cubeDevnet: {
      url: cubeDevnetEndpoint,
      accounts: [`0x${cubeDevnetPrivateKey}`]
    },
    oasysTest: {
      url: oasysTestEndpoint,
      accounts: [`0x${oasysTestPrivateKey}`]
    },
    antiMatTest: {
      url: antiMatTestnetEndpoint,
      accounts: [`0x${antiMatTestnetPrivateKey}`]
    },
    // Mainnets, note, use kms to deploy/run scripts on prod
    ethMainnet: {
      url: ethMainnetEndpoint,
      kmsKeyId: kmsKeyId
    },
    bsc: {
      url: bscEndpoint,
      kmsKeyId: kmsKeyId
    },
    arbitrum: {
      url: arbitrumEndpoint,
      kmsKeyId: kmsKeyId
    },
    arbitrumNova: {
      url: arbitrumNovaEndpoint,
      kmsKeyId: kmsKeyId
    },
    polygon: {
      url: polygonEndpoint,
      kmsKeyId: kmsKeyId,
      gasPrice: 50000000000
    },
    fantom: {
      url: fantomEndpoint,
      kmsKeyId: kmsKeyId
    },
    avalanche: {
      url: avalancheEndpoint,
      kmsKeyId: kmsKeyId
    },
    optimism: {
      url: optimismEndpoint,
      kmsKeyId: kmsKeyId
    },
    boba: {
      url: bobaEndpoint,
      kmsKeyId: kmsKeyId
    },
    harmony: {
      url: harmonyEndpoint,
      kmsKeyId: kmsKeyId
    },
    moonbeam: {
      url: moonbeamEndpoint,
      kmsKeyId: kmsKeyId
    },
    moonriver: {
      url: moonriverEndpoint,
      kmsKeyId: kmsKeyId
    },
    celo: {
      url: celoEndpoint,
      kmsKeyId: kmsKeyId
    },
    oasisEmerald: {
      url: oasisEmeraldEndpoint,
      kmsKeyId: kmsKeyId
    },
    oasisSapphire: {
      url: oasisSapphireEndpoint,
      kmsKeyId: kmsKeyId
    },
    metis: {
      url: metisEndpoint,
      kmsKeyId: kmsKeyId
    },
    aurora: {
      url: auroraEndpoint,
      kmsKeyId: kmsKeyId
    },
    xdai: {
      url: xdaiEndpoint,
      kmsKeyId: kmsKeyId
    },
    oec: {
      url: oecEndpoint,
      kmsKeyId: kmsKeyId
    },
    heco: {
      url: hecoEndpoint,
      kmsKeyId: kmsKeyId
    },
    astar: {
      url: astarEndpoint,
      kmsKeyId: kmsKeyId
    },
    shiden: {
      url: shidenEndpoint,
      kmsKeyId: kmsKeyId
    },
    syscoin: {
      url: syscoinEndpoint,
      kmsKeyId: kmsKeyId
    },
    milkomeda: {
      url: milkomedaEndpoint,
      kmsKeyId: kmsKeyId
    },
    evmos: {
      url: evmosEndpoint,
      kmsKeyId: kmsKeyId
    },
    clover: {
      url: cloverEndpoint,
      kmsKeyId: kmsKeyId
    },
    rei: {
      url: reiEndpoint,
      kmsKeyId: kmsKeyId
    },
    conflux: {
      url: confluxEndpoint,
      kmsKeyId: kmsKeyId
    },
    darwiniaCrab: {
      url: darwiniaCrabEndpoint,
      kmsKeyId: kmsKeyId
    },
    platon: {
      url: platonEndpoint,
      kmsKeyId: kmsKeyId
    },
    ontology: {
      url: ontologyEndpoint,
      kmsKeyId: kmsKeyId
    },
    swimmer: {
      url: swimmerEndpoint,
      kmsKeyId: kmsKeyId
    },
    sxNetwork: {
      url: sxNetworkEndpoint,
      kmsKeyId: kmsKeyId
    },
    ape: {
      url: apeEndpoint,
      kmsKeyId: kmsKeyId
    },
    kava: {
      url: kavaEndpoint,
      kmsKeyId: kmsKeyId
    },
    fncy: {
      url: fncyEndpoint,
      kmsKeyId: kmsKeyId
    },
    nervosGodwoken: {
      url: nervosGodwokenEndpoint,
      kmsKeyId: kmsKeyId
    },
    klaytn: {
      url: klaytnEndpoint,
      kmsKeyId: kmsKeyId,
      gasPrice: 250000000000
    },
    oasys: {
      url: oasysEndpoint,
      kmsKeyId: kmsKeyId
    }
  },
  namedAccounts: {
    deployer: {
      default: 0
    }
  },
  solidity: {
    version: '0.8.17',
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
  },
  etherscan: {
    apiKey: {
      // Testnets
      goerli: process.env.ETHERSCAN_API_KEY || '',
      avalancheFujiTestnet: process.env.SNOWTRACE_API_KEY || '',
      bscTestnet: process.env.BSCSCAN_API_KEY || '',
      arbitrumTestnet: process.env.ARBISCAN_API_KEY || '',
      ftmTestnet: process.env.FTMSCAN_API_KEY || '',
      polygonMumbai: process.env.POLYGONSCAN_API_KEY || '',
      // Mainnets
      mainnet: process.env.ETHERSCAN_API_KEY || '',
      avalanche: process.env.SNOWTRACE_API_KEY || '',
      bsc: process.env.BSCSCAN_API_KEY || '',
      arbitrumOne: process.env.ARBISCAN_API_KEY || '',
      optimisticEthereum: process.env.OPTIMISTIC_ETHERSCAN_API_KEY || '',
      opera: process.env.FTMSCAN_API_KEY || '',
      polygon: process.env.POLYGONSCAN_API_KEY || '',
      aurora: process.env.AURORASCAN_API_KEY || '',
      moonriver: process.env.MOONRIVER_MOONSCAN_API_KEY || '',
      moonbeam: process.env.MOONBEAM_MOONSCAN_API_KEY || '',
      heco: process.env.HECOSCAN_API_KEY || '',
      arbitrumNova: process.env.ARBISCAN_NOVA_API_KEY || ''
    },
    customChains: [
      {
        network: 'arbitrumNova',
        chainId: 42170,
        urls: {
          apiURL: process.env.ARBITRUM_NOVA_ENDPOINT || '',
          browserURL: process.env.ARBITRUM_NOVA_EXPLORER || ''
        }
      }
    ]
  }
};

export default config;
