# SGN Contracts

Contracts for the Celer State Guardian Network (SGN) V2.

### Run unit tests

```sh
yarn test
```

### Benchmark gas cost

```sh
yarn report-gas:benchmark
yarn report-gas:summary
```

Check `reports/gas_usage`.

### Update contract sizes

```sh
yarn size-contracts
```

Check `reports/contract_sizes.txt`.

### Deploy contracts

1. `cp .env.template .env`, then ensure all environment variables are set in `.env`.

2. Deploy SGN and Staking contracts:

```sh
hardhat deploy --network <network> --tags SGNStaking
```

Deploy Bridge contract:

```sh
hardhat deploy --network <network>  --tags Bridge
```

### Verify contracts on explorers

#### On Etherscan variants via hardhat etherscan-verify:

This is the recommended way for most mainnet Etherscan variants.

Make sure the `ETHERSCAN_API_KEY` is set correctly in `.env`.

```sh
hardhat etherscan-verify --network <network> --license "GPL-3.0" --force-license
```

#### On Etherscan variants via solt:

This is useful since most testnet Etherscan variants don't offer verification via the API.

```sh
source scripts/solt.sh
run_solt_write
```

Then try:

```sh
solt verify --license 5 --network <network> solc-input-<contract>.json <deployed address> <contract name>
```

If the second step fails, go to Etherscan and manually verify using the standard JSON input files.

#### On Blockscout variants via sourcify:

This is used if the Blockscout variant requires "Sources and Metadata JSON".

```sh
hardhat sourcify --network <network>
```

#### On Blockscout variants via flattened source files:

This is used if the Blockscout variant requires a single source file, or in general as a last resort.

```sh
hardhat flatten <path-to-contract> > flattened.sol
```

Edit `flattened.out` to remove the duplicate `SPDX-License-Identifier` lines and submit to Blockscout. Sometimes you also need to remove the duplicate `pragma solidity` lines.
