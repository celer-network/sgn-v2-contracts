#!/bin/sh

# Script to run solt and generate standard-json files for Etherscan verification.

solFiles=(
  Bridge
  Staking
  SGN
  StakingReward
  FarmingRewards
  Govern
  Viewer
  interfaces/ISigsVerifier
  miscs/Faucet
  miscs/MintableERC20
  pegged/PeggedTokenBridge
  pegged/PeggedToken
  pegged/OriginalTokenVaults
)

run_solt_write() {
  for f in ${solFiles[@]}; do
    solt write contracts/$f.sol --npm --runs 800
  done
}
