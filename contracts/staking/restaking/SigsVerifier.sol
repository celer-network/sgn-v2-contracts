// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.17;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../../safeguard/Ownable.sol";
import "../../liquidity-bridge/Signers.sol";

/**
 * @title Multi-sig verification and management for BVN
 */
contract SigsVerifier is Ownable, Signers {
    using ECDSA for bytes32;

    /**
     * @notice Verifies that a message is signed by a quorum among the signers
     * The sigs must be sorted by signer addresses in ascending order.
     * @param _msgHash hash of signed message
     * @param _sigs list of signatures sorted by signer addresses in ascending order
     * @param _signers sorted list of current signers
     * @param _powers powers of current signers
     */
    function verifySigs(
        bytes32 _msgHash,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers
    ) public view {
        bytes32 h = keccak256(abi.encodePacked(_signers, _powers));
        require(ssHash == h, "Mismatch current signers");
        _verifySignedPowers(_msgHash.toEthSignedMessageHash(), _sigs, _signers, _powers);
    }
}
