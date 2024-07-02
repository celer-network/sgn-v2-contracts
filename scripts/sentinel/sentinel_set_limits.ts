import 'hardhat-deploy';

import * as dotenv from 'dotenv';

import { Sentinel__factory } from '../../typechain';
import { TypedContractMethod } from '../../typechain/common';
import { getDeployerSigner, getFeeOverrides, getParseUnitsCallback } from '../common';

import type { AddressLike, BigNumberish, Overrides } from 'ethers';
dotenv.config();

async function setLimitIfSpecified(
  limitEnv: string,
  target: string,
  tokens: string[],
  decimals: string[],
  methodName: string,
  method: TypedContractMethod<
    [_target: string, _tokens: AddressLike[], _amounts: BigNumberish[]],
    [void],
    'nonpayable'
  >,
  feeOverrides: Overrides
): Promise<void> {
  if (limitEnv) {
    const limitStr = limitEnv.split(',');
    if (limitEnv.length > 0 && limitStr.length === decimals.length) {
      const limits = limitStr.map(getParseUnitsCallback(decimals.map(Number)));
      await (await method(target, tokens, limits, feeOverrides)).wait();
      console.log(
        methodName,
        target,
        tokens,
        limits.map((limit) => limit.toString())
      );
    }
  }
}

async function setBridgeLimits(sentinelAddr: string): Promise<void> {
  const deployerSigner = await getDeployerSigner();
  const feeOverrides = await getFeeOverrides();

  const bridgeAddr = process.env.BRIDGE as string;
  if (!bridgeAddr) {
    return;
  }
  const tokensStr = process.env.BRIDGE_LIMIT_TOKENS;
  if (!tokensStr) {
    return;
  }
  const sentinel = Sentinel__factory.connect(sentinelAddr, deployerSigner);
  const tokens = (process.env.BRIDGE_LIMIT_TOKENS as string).split(',');
  const decimals = (process.env.BRIDGE_LIMIT_DECIMALS as string).split(',');

  await setLimitIfSpecified(
    process.env.BRIDGE_LIMIT_MIN_ADDS as string,
    bridgeAddr,
    tokens,
    decimals,
    'setMinAdd',
    sentinel.setMinAdd,
    feeOverrides
  );
  await setLimitIfSpecified(
    process.env.BRIDGE_LIMIT_MIN_SENDS as string,
    bridgeAddr,
    tokens,
    decimals,
    'setMinSend',
    sentinel.setMinSend,
    feeOverrides
  );
  await setLimitIfSpecified(
    process.env.BRIDGE_LIMIT_MAX_SENDS as string,
    bridgeAddr,
    tokens,
    decimals,
    'setMaxSend',
    sentinel.setMaxSend,
    feeOverrides
  );
  await setLimitIfSpecified(
    process.env.BRIDGE_LIMIT_EPOCH_VOLUME_CAPS as string,
    bridgeAddr,
    tokens,
    decimals,
    'setEpochVolumeCaps',
    sentinel.setEpochVolumeCaps,
    feeOverrides
  );
  await setLimitIfSpecified(
    process.env.BRIDGE_LIMIT_DELAY_THRESHOLDS as string,
    bridgeAddr,
    tokens,
    decimals,
    'setDelayThresholds',
    sentinel.setDelayThresholds,
    feeOverrides
  );
}

async function setOriginalTokenVaultLimits(sentinelAddr: string): Promise<void> {
  const deployerSigner = await getDeployerSigner();
  const feeOverrides = await getFeeOverrides();

  const originalTokenVaultAddr = process.env.ORIGINAL_TOKEN_VAULT as string;
  if (!originalTokenVaultAddr) {
    return;
  }
  const tokensStr = process.env.ORIGINAL_TOKEN_VAULT_LIMIT_TOKENS;
  if (!tokensStr) {
    return;
  }
  const sentinel = Sentinel__factory.connect(sentinelAddr, deployerSigner);
  const tokens = (process.env.ORIGINAL_TOKEN_VAULT_LIMIT_TOKENS as string).split(',');
  const decimals = (process.env.ORIGINAL_TOKEN_VAULT_LIMIT_DECIMALS as string).split(',');

  await setLimitIfSpecified(
    process.env.ORIGINAL_TOKEN_VAULT_LIMIT_MIN_DEPOSITS as string,
    originalTokenVaultAddr,
    tokens,
    decimals,
    'setMinDeposit',
    sentinel.setMinDeposit,
    feeOverrides
  );
  await setLimitIfSpecified(
    process.env.ORIGINAL_TOKEN_VAULT_LIMIT_MAX_DEPOSITS as string,
    originalTokenVaultAddr,
    tokens,
    decimals,
    'setMaxDeposit',
    sentinel.setMaxDeposit,
    feeOverrides
  );
  await setLimitIfSpecified(
    process.env.ORIGINAL_TOKEN_VAULT_LIMIT_EPOCH_VOLUME_CAPS as string,
    originalTokenVaultAddr,
    tokens,
    decimals,
    'setEpochVolumeCaps',
    sentinel.setEpochVolumeCaps,
    feeOverrides
  );
  await setLimitIfSpecified(
    process.env.ORIGINAL_TOKEN_VAULT_LIMIT_DELAY_THRESHOLDS as string,
    originalTokenVaultAddr,
    tokens,
    decimals,
    'setDelayThresholds',
    sentinel.setDelayThresholds,
    feeOverrides
  );
}

async function setPeggedTokenBridgeLimits(sentinelAddr: string): Promise<void> {
  const deployerSigner = await getDeployerSigner();
  const feeOverrides = await getFeeOverrides();

  const peggedTokenBridgeAddr = process.env.PEGGED_TOKEN_BRIDGE as string;
  if (!peggedTokenBridgeAddr) {
    return;
  }
  const tokensStr = process.env.PEGGED_TOKEN_BRIDGE_LIMIT_TOKENS;
  if (!tokensStr) {
    return;
  }
  const sentinel = Sentinel__factory.connect(sentinelAddr, deployerSigner);
  const tokens = (process.env.PEGGED_TOKEN_BRIDGE_LIMIT_TOKENS as string).split(',');
  const decimals = (process.env.PEGGED_TOKEN_BRIDGE_LIMIT_DECIMALS as string).split(',');

  await setLimitIfSpecified(
    process.env.PEGGED_TOKEN_BRIDGE_LIMIT_MIN_BURNS as string,
    peggedTokenBridgeAddr,
    tokens,
    decimals,
    'setMinBurn',
    sentinel.setMinBurn,
    feeOverrides
  );
  await setLimitIfSpecified(
    process.env.PEGGED_TOKEN_BRIDGE_LIMIT_MAX_BURNS as string,
    peggedTokenBridgeAddr,
    tokens,
    decimals,
    'setMaxBurn',
    sentinel.setMaxBurn,
    feeOverrides
  );
  await setLimitIfSpecified(
    process.env.PEGGED_TOKEN_BRIDGE_LIMIT_EPOCH_VOLUME_CAPS as string,
    peggedTokenBridgeAddr,
    tokens,
    decimals,
    'setEpochVolumeCaps',
    sentinel.setEpochVolumeCaps,
    feeOverrides
  );
  await setLimitIfSpecified(
    process.env.PEGGED_TOKEN_BRIDGE_LIMIT_DELAY_THRESHOLDS as string,
    peggedTokenBridgeAddr,
    tokens,
    decimals,
    'setDelayThresholds',
    sentinel.setDelayThresholds,
    feeOverrides
  );
}

async function setLimits(): Promise<void> {
  const sentinelAddr = process.env.SENTINEL as string;
  if (!sentinelAddr) {
    return;
  }
  await setBridgeLimits(sentinelAddr);
  await setOriginalTokenVaultLimits(sentinelAddr);
  await setPeggedTokenBridgeLimits(sentinelAddr);
}

setLimits();
