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

3. Verify contracts on Etherscan:

```sh
hardhat etherscan-verify --network <network> --license "GPL-3.0" --force-license
```
