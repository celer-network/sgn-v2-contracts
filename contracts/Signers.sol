// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.7;

import "./libraries/PbSigner.sol";

// only store hash of serialized SortedSigners
contract Signers {
    event SignersUpdated(
        bytes curSigners // serialized SortedSigners
    );

    bytes32 ssHash;

    constructor(bytes _ss) {
        ssHash = keccak256(_ss);
    }

    // set new signers
    function update(bytes calldata _newss, bytes calldata _curss, bytes[] calldata _sigs) external {
        verifySigs(_newss, _curss, _sigs);
        // ensure newss is sorted
        PbSigner.SortedSigners memory ss = PbSigner.decSortedSigners(_newss);
        address prev = address(0);
        for (uint256 i = 0; i < ss.length; i++) {
            require(ss[i].address > prev, "signer address not in ascending order");
            prev = ss[i].address;
        }
        ssHash = keccak256(_newss);
        emit SignersUpdated(_newss);
    }

    // first verify _curss hash into ssHash, then verify sigs. sigs must be sorted by signer address
    function verifySigs(bytes memory msg, bytes memory _curss, bytes[] memory _sigs) external {
        require(ssHash == keccak256(_curss), "mismatch current signers");
        PbSigner.SortedSigners memory ss = PbSigner.decSortedSigners(_curss); // sorted signers
        uint256 totalTokens; // sum of all signer.tokens, do one loop here for simpler code
        for (uint256 i = 0; i < ss.length; i++) {
            totalTokens += ss[i].tokens;
        }
        // recover signer address, add their tokens
        bytes32 hash = keccak256(msg).toEthSignedMessageHash();
        uint256 signedTokens; // sum of signer who are in sigs
        address prev = address(0);
        uint256 signerIdx = 0;
        for (uint256 i = 0; i < _sigs.length; i++) {
            address curSigner = hash.recover(_sigs[i]);
            require(curSigner > prev, "Signers not in ascending order");
            prev = curSigner;
            // now find match signer in ss, add its token
            while (curSigner > ss[signerIdx].address) {
                signerIdx += 1;
                require(signerIdx < ss.length, "signer not found in current sorted signers");
            }
            if (curSigner == ss[signerIdx].address) {
                signedTokens += ss[signerIdx].tokens;
            }
        }

        require(signedTokens >= (totalTokens * 2) / 3 + 1, "Quorum not reached");
    }
}