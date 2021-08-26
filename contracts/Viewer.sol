// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.7;

import {DataTypes as dt} from "./libraries/DataTypes.sol";
import "./Staking.sol";

/**
 * @title Viewer of the staking contract
 * @notice Using a seperate viewer contract to reduce staking contract size
 * TODO: add more view functions
 */
contract Viewer {
    Staking public immutable staking;

    constructor(Staking _staking) {
        staking = _staking;
    }

    function getDelegatorInfos(address _delAddr) public view returns (dt.DelegatorInfo[] memory) {
        uint256 valNum = staking.getValidatorNum();
        dt.DelegatorInfo[] memory infos = new dt.DelegatorInfo[](valNum);
        uint32 num = 0;
        for (uint32 i = 0; i < valNum; i++) {
            address valAddr = staking.valAddrs(i);
            infos[i] = staking.getDelegatorInfo(valAddr, _delAddr);
            if (infos[i].shares != 0 || infos[i].undelegationTokens != 0) {
                num++;
            }
        }
        dt.DelegatorInfo[] memory res = new dt.DelegatorInfo[](num);
        uint32 j = 0;
        for (uint32 i = 0; i < valNum; i++) {
            if (infos[i].shares != 0 || infos[i].undelegationTokens != 0) {
                res[j] = infos[i];
                j++;
            }
        }
        return res;
    }

    /**
     * @notice Get the minimum staking pool of all bonded validators
     * @return the minimum staking pool of all bonded validators
     */
    function getMinValidatorTokens() public view returns (uint256) {
        uint256 minTokens = staking.getValidatorTokens(staking.bondedValAddrs(0));
        uint256 bondedValNum = staking.getBondedValidatorNum();
        for (uint256 i = 1; i < bondedValNum; i++) {
            uint256 tokens = staking.getValidatorTokens(staking.bondedValAddrs(i));
            if (tokens < minTokens) {
                minTokens = tokens;
                if (minTokens == 0) {
                    return 0;
                }
            }
        }
        return minTokens;
    }
}
