// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.9;

interface ISigsVerifier {
    /**
     * @notice Verifies that a message is signed by a quorum among the signers.
     * @param _msg signed message
     * @param _signers the list of signers
     * @param _sigs the list of signatures
     */
    function verifySigs(
        bytes calldata _msg,
        bytes calldata _signers,
        bytes[] calldata _sigs
    ) external view;
}
