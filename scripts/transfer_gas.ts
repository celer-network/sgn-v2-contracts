// Moves native gas off an SGN signer whose key lives in AWS KMS, on one chain, into a wallet.
//
// Every parameter is an env var, like the other scripts here:
//   KMS_KEY_ID              key id, key ARN, `alias/<name>` or alias ARN of the signer key. Comma
//                           separate several of them to sweep more than one signer in a run.
//   KMS_REGION              region of the KMS key, falls back to AWS_REGION / AWS_DEFAULT_REGION.
//   GAS_TRANSFER_TO         destination wallet (required).
//   GAS_TRANSFER_AMOUNT     amount in native units, e.g. 0.25, or `all` to sweep (required).
//   GAS_TRANSFER_RESERVE    native units to leave on the signer, on top of this tx's own gas cost.
//   GAS_TRANSFER_RPC        rpc endpoint. Defaults to the url of the --network given to hardhat, so
//                           it is only needed for chains with no entry in hardhat.config.ts.
//   GAS_TRANSFER_CHAIN_ID   abort unless the endpoint reports this chain id.
//   GAS_TRANSFER_GAS_PRICE  gas price in gwei, overriding what the rpc suggests.
//   GAS_TRANSFER_GAS_LIMIT  gas limit, overriding 21000 / the estimate for a contract destination.
//   GAS_TRANSFER_DRY_RUN    `true` prints what would be sent and stops.
//
// On a chain that has a network entry in hardhat.config.ts:
//   KMS_KEY_ID=alias/sgn-signer-1 KMS_REGION=us-west-2 \
//   GAS_TRANSFER_TO=0x... GAS_TRANSFER_AMOUNT=all \
//   hardhat run scripts/transfer_gas.ts --network bsc --no-compile
//
// On any other chain, Manta Pacific here, where GAS_TRANSFER_RPC makes hardhat unnecessary:
//   KMS_KEY_ID=alias/sgn-signer-1 KMS_REGION=us-west-2 \
//   GAS_TRANSFER_RPC=https://pacific-rpc.manta.network/http GAS_TRANSFER_CHAIN_ID=169 \
//   GAS_TRANSFER_TO=0x... GAS_TRANSFER_AMOUNT=all \
//   npx ts-node scripts/transfer_gas.ts
//
// The ambient AWS credentials must be allowed to kms:GetPublicKey and kms:Sign with the key, which
// normally means running this on the validator host that owns it. Nothing here needs the compiled
// contracts, so on such a host it is enough to install ethers, @aws-sdk/client-kms, dotenv, ts-node
// and typescript and run `npx ts-node scripts/transfer_gas.ts` with GAS_TRANSFER_RPC set.
import * as dotenv from 'dotenv';
import {
  Contract,
  JsonRpcProvider,
  Transaction,
  formatEther,
  formatUnits,
  getAddress,
  parseEther,
  parseUnits,
  toBigInt
} from 'ethers';
import { AwsKmsSigner } from './aws_kms_signer';

import type { Provider, TransactionLike, TransactionRequest } from 'ethers';

dotenv.config();

// Predeploy that prices the L1 data fee on OP-stack chains (Optimism, Base, Manta, Mode, ...).
const OP_GAS_PRICE_ORACLE = '0x420000000000000000000000000000000000000F';

interface TransferConfig {
  rpcUrl: string;
  rpcHost: string;
  keyIds: string[];
  region?: string;
  to: string;
  sweep: boolean;
  amount: bigint;
  reserve: bigint;
  gasLimit?: bigint;
  gasPrice?: bigint;
  chainId?: bigint;
  dryRun: boolean;
}

interface Fees {
  gasPrice?: bigint;
  maxFeePerGas?: bigint;
  maxPriorityFeePerGas?: bigint;
}

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`${name} is not set`);
  }
  return value;
}

// hardhat is only consulted for the endpoint behind --network <name>, so this stays optional: with
// GAS_TRANSFER_RPC set the script also runs under plain ts-node, on a host that has no full install
// of this repo. Handy on a validator box, and required anyway for chains hardhat.config.ts lacks.
function hardhatNetwork(): { name: string; url: string } {
  try {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const { network } = require('hardhat');
    return { name: network.name, url: network.config.url || '' };
  } catch {
    return { name: '', url: '' };
  }
}

function loadConfig(): TransferConfig {
  const hardhat = process.env.GAS_TRANSFER_RPC ? { name: '', url: '' } : hardhatNetwork();
  const rpcUrl = process.env.GAS_TRANSFER_RPC || hardhat.url;
  if (!rpcUrl) {
    throw new Error(
      hardhat.name
        ? `network "${hardhat.name}" has no rpc url, pass --network <name> or set GAS_TRANSFER_RPC`
        : 'set GAS_TRANSFER_RPC, or run under hardhat with --network <name>'
    );
  }
  let rpcHost: string;
  try {
    // Only the host is ever logged, endpoint urls tend to carry an api key.
    rpcHost = new URL(rpcUrl).host;
  } catch {
    throw new Error(`"${rpcUrl}" is not a valid rpc url`);
  }

  const keyIds = requireEnv('KMS_KEY_ID')
    .split(',')
    .map((keyId) => keyId.trim())
    .filter((keyId) => keyId.length > 0);
  if (keyIds.length === 0) {
    throw new Error('KMS_KEY_ID is empty');
  }

  const to = getAddress(requireEnv('GAS_TRANSFER_TO'));
  const amountEnv = requireEnv('GAS_TRANSFER_AMOUNT');
  const sweep = amountEnv.toLowerCase() === 'all';

  return {
    rpcUrl,
    rpcHost,
    keyIds,
    region: process.env.KMS_REGION || process.env.AWS_REGION || process.env.AWS_DEFAULT_REGION,
    to,
    sweep,
    amount: sweep ? 0n : parseEther(amountEnv),
    reserve: parseEther(process.env.GAS_TRANSFER_RESERVE || '0'),
    gasLimit: process.env.GAS_TRANSFER_GAS_LIMIT ? toBigInt(process.env.GAS_TRANSFER_GAS_LIMIT) : undefined,
    gasPrice: process.env.GAS_TRANSFER_GAS_PRICE ? parseUnits(process.env.GAS_TRANSFER_GAS_PRICE, 'gwei') : undefined,
    chainId: process.env.GAS_TRANSFER_CHAIN_ID ? toBigInt(process.env.GAS_TRANSFER_CHAIN_ID) : undefined,
    dryRun: process.env.GAS_TRANSFER_DRY_RUN === 'true'
  };
}

async function getFees(provider: Provider, override?: bigint): Promise<Fees> {
  const { gasPrice, maxFeePerGas, maxPriorityFeePerGas } = await provider.getFeeData();
  if (maxFeePerGas != null && maxPriorityFeePerGas != null) {
    if (override != null) {
      return {
        maxFeePerGas: override,
        maxPriorityFeePerGas: maxPriorityFeePerGas < override ? maxPriorityFeePerGas : override
      };
    }
    return { maxFeePerGas, maxPriorityFeePerGas };
  }
  if (override != null) {
    return { gasPrice: override };
  }
  if (gasPrice == null) {
    throw new Error('the rpc endpoint returned no fee data');
  }
  return { gasPrice };
}

async function getGasLimit(provider: Provider, from: string, to: string, override?: bigint): Promise<bigint> {
  if (override != null) {
    return override;
  }
  if ((await provider.getCode(to)) === '0x') {
    return 21000n;
  }
  // A contract destination (safe, deposit contract, ...) runs its own receive hook, so ask the node
  // and leave room for a hook whose cost depends on state that may change before we are mined.
  try {
    return ((await provider.estimateGas({ from, to, value: 1n })) * 12n) / 10n;
  } catch (err) {
    throw new Error(
      `cannot estimate the gas of a transfer to the contract at ${to}, set GAS_TRANSFER_GAS_LIMIT: ` +
        `${err instanceof Error ? err.message : err}`
    );
  }
}

// On OP-stack chains the L1 data fee is charged on top of the L2 gas cost and eth_estimateGas knows
// nothing about it, so a sweep of the whole balance is rejected unless that fee is left behind. Ask
// the oracle predeploy what this tx costs and keep twice that: the payload we price it on is the
// unsigned one, ~65 bytes shorter than what actually lands, and the L1 base fee drifts meanwhile.
async function getL1FeeMargin(provider: Provider, tx: TransactionRequest): Promise<bigint> {
  try {
    if ((await provider.getCode(OP_GAS_PRICE_ORACLE)) === '0x') {
      return 0n;
    }
    const oracle = new Contract(OP_GAS_PRICE_ORACLE, ['function getL1Fee(bytes) view returns (uint256)'], provider);
    const fee: bigint = await oracle.getL1Fee(Transaction.from(tx as TransactionLike<string>).unsignedSerialized);
    return fee * 2n;
  } catch (err) {
    console.log('  could not price the op-stack l1 data fee, assuming there is none:', `${err}`);
    return 0n;
  }
}

async function transferFrom(
  keyId: string,
  cfg: TransferConfig,
  provider: Provider,
  chainId: bigint,
  done: Set<string>
): Promise<void> {
  console.log(`kms key ${keyId}`);
  const signer = new AwsKmsSigner(keyId, provider, cfg.region);
  const from = await signer.getAddress();
  const balance = await provider.getBalance(from);
  console.log(`  signer ${from} holds ${formatEther(balance)}`);
  if (done.has(from)) {
    // Two ids for one key, an alias and the key id say, would otherwise send twice.
    console.log('  already swept through another key id');
    return;
  }
  done.add(from);
  if (balance === 0n) {
    console.log('  nothing to transfer');
    return;
  }

  const fees = await getFees(provider, cfg.gasPrice);
  const feePerGas = fees.maxFeePerGas ?? fees.gasPrice ?? 0n;
  const gasLimit = await getGasLimit(provider, from, cfg.to, cfg.gasLimit);
  const nonce = await provider.getTransactionCount(from, 'pending');
  const base = {
    to: cfg.to,
    nonce,
    gasLimit,
    chainId,
    type: fees.maxFeePerGas != null ? 2 : 0,
    ...fees
  };

  const l2Cost = feePerGas * gasLimit;
  // Priced with the largest value this tx could carry, so the estimate cannot come out short.
  const l1Cost = await getL1FeeMargin(provider, { ...base, value: balance });
  const spendable = balance - l2Cost - l1Cost - cfg.reserve;
  const value = cfg.sweep ? spendable : cfg.amount;
  if (value <= 0n || value > spendable) {
    throw new Error(
      `cannot send ${cfg.sweep ? 'the balance' : formatEther(cfg.amount)}: ${formatEther(balance)} held, ` +
        `${formatEther(l2Cost)} gas${l1Cost > 0n ? ` + ${formatEther(l1Cost)} l1 data fee` : ''}` +
        `${cfg.reserve > 0n ? ` + ${formatEther(cfg.reserve)} reserved` : ''}, ${formatEther(spendable)} sendable`
    );
  }

  console.log(`  sending ${formatEther(value)} to ${cfg.to}`);
  console.log(
    `  nonce ${nonce}, gas limit ${gasLimit} at up to ${formatUnits(feePerGas, 'gwei')} gwei` +
      `, so at most ${formatEther(l2Cost)} in gas` +
      `${l1Cost > 0n ? `, keeping ${formatEther(l1Cost)} back for the l1 data fee` : ''}`
  );
  if (cfg.dryRun) {
    console.log('  dry run, not sending');
    return;
  }

  const tx = await signer.sendTransaction({ ...base, value });
  console.log(`  sent ${tx.hash}`);
  const receipt = await tx.wait();
  if (!receipt) {
    console.log('  not mined yet, check the hash on the explorer');
    return;
  }
  if (receipt.status !== 1) {
    throw new Error(`tx ${tx.hash} reverted in block ${receipt.blockNumber}`);
  }
  console.log(
    `  mined in block ${receipt.blockNumber} for ${formatEther(receipt.fee)}` +
      `, signer left with ${formatEther(await provider.getBalance(from))}`
  );
}

async function transferGas(): Promise<void> {
  const cfg = loadConfig();
  const provider = new JsonRpcProvider(cfg.rpcUrl);
  const chainId = (await provider.getNetwork()).chainId;
  if (cfg.chainId != null && chainId !== cfg.chainId) {
    throw new Error(`${cfg.rpcHost} is chain ${chainId}, not the ${cfg.chainId} of GAS_TRANSFER_CHAIN_ID`);
  }
  console.log(`chain ${chainId} via ${cfg.rpcHost}${cfg.dryRun ? ' (dry run)' : ''}`);
  console.log(`destination ${cfg.to} holds ${formatEther(await provider.getBalance(cfg.to))}`);

  const failed: string[] = [];
  const done = new Set<string>();
  for (const keyId of cfg.keyIds) {
    try {
      await transferFrom(keyId, cfg, provider, chainId, done);
    } catch (err) {
      failed.push(keyId);
      console.error(`  failed: ${err instanceof Error ? err.message : err}`);
    }
  }

  console.log(`destination ${cfg.to} now holds ${formatEther(await provider.getBalance(cfg.to))}`);
  if (failed.length > 0) {
    throw new Error(`${failed.length} of ${cfg.keyIds.length} transfers failed: ${failed.join(', ')}`);
  }
}

transferGas().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
