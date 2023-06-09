import '@nomiclabs/hardhat-ethers';
import '@nomiclabs/hardhat-etherscan';
import '@nomiclabs/hardhat-waffle';
import '@typechain/hardhat';
import 'hardhat-contract-sizer';
import 'hardhat-deploy';
import 'hardhat-gas-reporter';
import '@oasisprotocol/sapphire-hardhat';
import '@rumblefishdev/hardhat-kms-signer';

import * as dotenv from 'dotenv';
import { HardhatUserConfig, NetworkUserConfig } from 'hardhat/types';

dotenv.config();

const DEFAULT_ENDPOINT = 'http://localhost:8545';
const DEFAULT_PRIVATE_KEY =
  process.env.DEFAULT_PRIVATE_KEY || 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';

const kmsKeyId = process.env.KMS_KEY_ID || '';

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

const antimatterB2TestEndpoint = process.env.ANTIMATTER_B2_TEST_ENDPOINT || DEFAULT_ENDPOINT;
const antimatterB2TestPrivateKey = process.env.ANTIMATTER_B2_TEST_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

// Mainnets
const ethMainnetEndpoint = process.env.ETH_MAINNET_ENDPOINT || DEFAULT_ENDPOINT;
const ethMainnetPrivateKey = process.env.ETH_MAINNET_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const bscEndpoint = process.env.BSC_ENDPOINT || DEFAULT_ENDPOINT;
const bscPrivateKey = process.env.BSC_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const arbitrumOneEndpoint = process.env.ARBITRUM_ONE_ENDPOINT || DEFAULT_ENDPOINT;
const arbitrumOnePrivateKey = process.env.ARBITRUM_ONE_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const arbitrumNovaEndpoint = process.env.ARBITRUM_NOVA_ENDPOINT || DEFAULT_ENDPOINT;
const arbitrumNovaPrivateKey = process.env.ARBITRUM_NOVA_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

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

const moonbeamEndpoint = process.env.MOONBEAM_ENDPOINT || DEFAULT_ENDPOINT;
const moonbeamPrivateKey = process.env.MOONBEAM_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const moonriverEndpoint = process.env.MOONRIVER_ENDPOINT || DEFAULT_ENDPOINT;
const moonriverPrivateKey = process.env.MOONRIVER_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const celoEndpoint = process.env.CELO_ENDPOINT || DEFAULT_ENDPOINT;
const celoPrivateKey = process.env.CELO_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const oasisEmeraldEndpoint = process.env.OASIS_EMERALD_ENDPOINT || DEFAULT_ENDPOINT;
const oasisEmeraldPrivateKey = process.env.OASIS_EMERALD_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const oasisSapphireEndpoint = process.env.OASIS_SAPPHIRE_ENDPOINT || DEFAULT_ENDPOINT;
const oasisSapphirePrivateKey = process.env.OASIS_SAPPHIRE_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

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

const astarEndpoint = process.env.ASTAR_ENDPOINT || DEFAULT_ENDPOINT;
const astarPrivateKey = process.env.ASTAR_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const shidenEndpoint = process.env.SHIDEN_ENDPOINT || DEFAULT_ENDPOINT;
const shidenPrivateKey = process.env.SHIDEN_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const syscoinEndpoint = process.env.SYSCOIN_ENDPOINT || DEFAULT_ENDPOINT;
const syscoinPrivateKey = process.env.SYSCOIN_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const milkomedaC1Endpoint = process.env.MILKOMEDA_C1_ENDPOINT || DEFAULT_ENDPOINT;
const milkomedaC1PrivateKey = process.env.MILKOMEDA_C1_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const milkomedaA1Endpoint = process.env.MILKOMEDA_A1_ENDPOINT || DEFAULT_ENDPOINT;
const milkomedaA1PrivateKey = process.env.MILKOMEDA_A1_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const evmosEndpoint = process.env.EVMOS_ENDPOINT || DEFAULT_ENDPOINT;
const evmosPrivateKey = process.env.EVMOS_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const cloverEndpoint = process.env.CLOVER_ENDPOINT || DEFAULT_ENDPOINT;
const cloverPrivateKey = process.env.CLOVER_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const reiEndpoint = process.env.REI_ENDPOINT || DEFAULT_ENDPOINT;
const reiPrivateKey = process.env.REI_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const confluxEndpoint = process.env.CONFLUX_ENDPOINT || DEFAULT_ENDPOINT;
const confluxPrivateKey = process.env.CONFLUX_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const darwiniaCrabEndpoint = process.env.DARWINIA_CRAB_ENDPOINT || DEFAULT_ENDPOINT;
const darwiniaCrabPrivateKey = process.env.DARWINIA_CRAB_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const platonEndpoint = process.env.PLATON_ENDPOINT || DEFAULT_ENDPOINT;
const platonPrivateKey = process.env.PLATON_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const ontologyEndpoint = process.env.ONTOLOGY_ENDPOINT || DEFAULT_ENDPOINT;
const ontologyPrivateKey = process.env.ONTOLOGY_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const swimmerEndpoint = process.env.SWIMMER_ENDPOINT || DEFAULT_ENDPOINT;
const swimmerPrivateKey = process.env.SWIMMER_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const sxNetworkEndpoint = process.env.SX_NETWORK_ENDPOINT || DEFAULT_ENDPOINT;
const sxNetworkPrivateKey = process.env.SX_NETWORK_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const apeEndpoint = process.env.APE_ENDPOINT || DEFAULT_ENDPOINT;
const apePrivateKey = process.env.APE_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const kavaEndpoint = process.env.KAVA_ENDPOINT || DEFAULT_ENDPOINT;
const kavaPrivateKey = process.env.KAVA_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const fncyEndpoint = process.env.FNCY_ENDPOINT || DEFAULT_ENDPOINT;
const fncyPrivateKey = process.env.FNCY_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const nervosGodwokenEndpoint = process.env.NERVOS_GODWOKEN_ENDPOINT || DEFAULT_ENDPOINT;
const nervosGodwokenPrivateKey = process.env.NERVOS_GODWOKEN_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const klaytnEndpoint = process.env.KLAYTN_ENDPOINT || DEFAULT_ENDPOINT;
const klaytnPrivateKey = process.env.KLAYTN_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const oasysEndpoint = process.env.OASYS_ENDPOINT || DEFAULT_ENDPOINT;
const oasysPrivateKey = process.env.OASYS_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const spsEndpoint = process.env.SPS_ENDPOINT || DEFAULT_ENDPOINT;
const spsPrivateKey = process.env.SPS_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const fvmEndpoint = process.env.FVM_ENDPOINT || DEFAULT_ENDPOINT;
const fvmPrivateKey = process.env.FVM_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const cantoEndpoint = process.env.CANTO_ENDPOINT || DEFAULT_ENDPOINT;
const cantoPrivateKey = process.env.CANTO_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const polygonZkevmEndpoint = process.env.POLYGON_ZKEVM_ENDPOINT || DEFAULT_ENDPOINT;
const polygonZkevmPrivateKey = process.env.POLYGON_ZKEVM_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

const antimatterB2Endpoint = process.env.ANTIMATTER_B2_ENDPOINT || DEFAULT_ENDPOINT;
const antimatterB2PrivateKey = process.env.ANTIMATTER_B2_PRIVATE_KEY || DEFAULT_PRIVATE_KEY;

// use kmsKeyId if it's not empty, otherwise use privateKey
function getNetworkConfig(url: string, kmsKeyId: string, privateKey: string, gasPrice?: number): NetworkUserConfig {
  const network: NetworkUserConfig = !kmsKeyId
    ? {
        url: url,
        accounts: [`0x${privateKey}`]
      }
    : {
        url: url,
        kmsKeyId: kmsKeyId
      };
  if (gasPrice) {
    network.gasPrice = gasPrice;
  }

  return network;
}

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
    antimatterB2Test: {
      url: antimatterB2TestEndpoint,
      accounts: [`0x${antimatterB2TestPrivateKey}`]
    },
    // Mainnets
    ethMainnet: getNetworkConfig(ethMainnetEndpoint, kmsKeyId, ethMainnetPrivateKey),
    bsc: getNetworkConfig(bscEndpoint, kmsKeyId, bscPrivateKey),
    arbitrumOne: getNetworkConfig(arbitrumOneEndpoint, kmsKeyId, arbitrumOnePrivateKey),
    arbitrumNova: getNetworkConfig(arbitrumNovaEndpoint, kmsKeyId, arbitrumNovaPrivateKey),
    polygon: getNetworkConfig(polygonEndpoint, kmsKeyId, polygonPrivateKey, 50000000000),
    fantom: getNetworkConfig(fantomEndpoint, kmsKeyId, fantomPrivateKey),
    avalanche: getNetworkConfig(avalancheEndpoint, kmsKeyId, avalanchePrivateKey),
    optimism: getNetworkConfig(optimismEndpoint, kmsKeyId, optimismPrivateKey),
    boba: getNetworkConfig(bobaEndpoint, kmsKeyId, bobaPrivateKey),
    harmony: getNetworkConfig(harmonyEndpoint, kmsKeyId, harmonyPrivateKey),
    moonbeam: getNetworkConfig(moonbeamEndpoint, kmsKeyId, moonbeamPrivateKey),
    moonriver: getNetworkConfig(moonriverEndpoint, kmsKeyId, moonriverPrivateKey),
    celo: getNetworkConfig(celoEndpoint, kmsKeyId, celoPrivateKey),
    oasisEmerald: getNetworkConfig(oasisEmeraldEndpoint, kmsKeyId, oasisEmeraldPrivateKey),
    oasisSapphire: getNetworkConfig(oasisSapphireEndpoint, kmsKeyId, oasisSapphirePrivateKey),
    metis: getNetworkConfig(metisEndpoint, kmsKeyId, metisPrivateKey),
    aurora: getNetworkConfig(auroraEndpoint, kmsKeyId, auroraPrivateKey),
    xdai: getNetworkConfig(xdaiEndpoint, kmsKeyId, xdaiPrivateKey),
    oec: getNetworkConfig(oecEndpoint, kmsKeyId, oecPrivateKey),
    heco: getNetworkConfig(hecoEndpoint, kmsKeyId, hecoPrivateKey),
    astar: getNetworkConfig(astarEndpoint, kmsKeyId, astarPrivateKey),
    shiden: getNetworkConfig(shidenEndpoint, kmsKeyId, shidenPrivateKey),
    syscoin: getNetworkConfig(syscoinEndpoint, kmsKeyId, syscoinPrivateKey),
    milkomedaC1: getNetworkConfig(milkomedaC1Endpoint, kmsKeyId, milkomedaC1PrivateKey),
    milkomedaA1: getNetworkConfig(milkomedaA1Endpoint, kmsKeyId, milkomedaA1PrivateKey),
    evmos: getNetworkConfig(evmosEndpoint, kmsKeyId, evmosPrivateKey),
    clover: getNetworkConfig(cloverEndpoint, kmsKeyId, cloverPrivateKey),
    rei: getNetworkConfig(reiEndpoint, kmsKeyId, reiPrivateKey),
    conflux: getNetworkConfig(confluxEndpoint, kmsKeyId, confluxPrivateKey),
    darwiniaCrab: getNetworkConfig(darwiniaCrabEndpoint, kmsKeyId, darwiniaCrabPrivateKey),
    platon: getNetworkConfig(platonEndpoint, kmsKeyId, platonPrivateKey),
    ontology: getNetworkConfig(ontologyEndpoint, kmsKeyId, ontologyPrivateKey),
    swimmer: getNetworkConfig(swimmerEndpoint, kmsKeyId, swimmerPrivateKey),
    sxNetwork: getNetworkConfig(sxNetworkEndpoint, kmsKeyId, sxNetworkPrivateKey),
    ape: getNetworkConfig(apeEndpoint, kmsKeyId, apePrivateKey),
    kava: getNetworkConfig(kavaEndpoint, kmsKeyId, kavaPrivateKey),
    fncy: getNetworkConfig(fncyEndpoint, kmsKeyId, fncyPrivateKey),
    nervosGodwoken: getNetworkConfig(nervosGodwokenEndpoint, kmsKeyId, nervosGodwokenPrivateKey),
    klaytn: getNetworkConfig(klaytnEndpoint, kmsKeyId, klaytnPrivateKey, 250000000000),
    oasys: getNetworkConfig(oasysEndpoint, kmsKeyId, oasysPrivateKey),
    sps: getNetworkConfig(spsEndpoint, kmsKeyId, spsPrivateKey),
    fvm: getNetworkConfig(fvmEndpoint, kmsKeyId, fvmPrivateKey),
    canto: getNetworkConfig(cantoEndpoint, kmsKeyId, cantoPrivateKey),
    polygonZkevm: getNetworkConfig(polygonZkevmEndpoint, kmsKeyId, polygonZkevmPrivateKey),
    antimatterB2: getNetworkConfig(antimatterB2Endpoint, kmsKeyId, antimatterB2PrivateKey)
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
