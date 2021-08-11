// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.6;

/**
 * @title DPoS contract common Library
 * @notice Common items used in DPoS contract
 */
library DPoSCommon {
    // Unbonded: not a validator and not responsible for previous validator behaviors if any.
    //   Delegators now are free to withdraw stakes (directly).
    // Bonded: active validator. Delegators have to wait for slashTimeout to withdraw stakes.
    // Unbonding: transitional status from Bonded to Unbonded. Candidate has lost the right of
    //   validator but is still responsible for any misbehaviour done during being validator.
    //   Delegators should wait until candidate's unbondTime to freely withdraw stakes.
    enum CandidateStatus { Unbonded, Bonded, Unbonding }
}
