import * as dotenv from 'dotenv';
import { ethers } from 'hardhat';
import { DeployFunction } from 'hardhat-deploy/types';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { calcEthereumTransactionParams } from '@acala-network/eth-providers';

dotenv.config();

const deployFunc: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const blockNumber = await ethers.provider.getBlockNumber();
  const storageByteDeposit = '100000000000000';
  const txFeePerGas = '199999946752';

  const ethParams = calcEthereumTransactionParams({
    gasLimit: '31000000',
    validUntil: (blockNumber + 100).toString(),
    storageLimit: '64001',
    txFeePerGas,
    storageByteDeposit,
  });

  await deploy('Staking', {
    from: deployer,
    log: true,
    args: [
      process.env.CELR,
      process.env.PROPOSAL_DEPOSIT,
      process.env.VOTING_PERIOD,
      process.env.UNBONDING_PERIOD,
      process.env.MAX_VALIDATOR_NUM,
      process.env.MIN_VALIDATOR_TOKENS,
      process.env.MIN_SELF_DELEGATION,
      process.env.ADVANCE_NOTICE_PERIOD,
      process.env.VALIDATOR_BOND_INTERVAL,
      process.env.MAX_SLASH_FACTOR
    ],
    gasLimit: ethParams.txGasLimit, // Mandala
    gasPrice: ethParams.txGasPrice, // Mandala
  });
  const staking = await deployments.get('Staking');
  await deploy('SGN', {
    from: deployer,
    log: true,
    args: [staking.address],
    gasLimit: ethParams.txGasLimit, // Mandala
    gasPrice: ethParams.txGasPrice, // Mandala
  });
  await deploy('StakingReward', {
    from: deployer,
    log: true,
    args: [staking.address],
    gasLimit: ethParams.txGasLimit, // Mandala
    gasPrice: ethParams.txGasPrice, // Mandala
  });
  await deploy('FarmingRewards', {
    from: deployer,
    log: true,
    args: [staking.address],
    gasLimit: ethParams.txGasLimit, // Mandala
    gasPrice: ethParams.txGasPrice, // Mandala
  });
  const stakingReward = await deployments.get('StakingReward');
  await deploy('Govern', {
    from: deployer,
    log: true,
    args: [staking.address, process.env.CELR, stakingReward.address],
    gasLimit: ethParams.txGasLimit, // Mandala
    gasPrice: ethParams.txGasPrice, // Mandala
  });
  await deploy('Viewer', {
    from: deployer,
    log: true,
    args: [staking.address],
    gasLimit: ethParams.txGasLimit, // Mandala
    gasPrice: ethParams.txGasPrice, // Mandala
  });
};

deployFunc.tags = ['SGNStaking'];
deployFunc.dependencies = [];
export default deployFunc;
