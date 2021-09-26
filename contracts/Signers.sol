// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.7;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./libraries/PbSigner.sol";

// only store hash of serialized SortedSigners
contract Signers is Ownable {
    event SignersUpdated(
        bytes curSigners // serialized SortedSigners
    );
    using ECDSA for bytes32;
    bytes32 public ssHash;

    constructor(bytes memory _ss) {
        if (_ss.length > 0) {
            ssHash = keccak256(_ss);
            emit SignersUpdated(_ss);
        }
    }

    // set new signers
    function updateSigners(
        bytes calldata _newss,
        bytes calldata _curss,
        bytes[] calldata _sigs
    ) external {
        verifySigs(_newss, _curss, _sigs);
        // ensure newss is sorted
        PbSigner.SortedSigners memory ss = PbSigner.decSortedSigners(_newss);
        address prev = address(0);
        for (uint256 i = 0; i < ss.signers.length; i++) {
            require(ss.signers[i].account > prev, "New signers not in ascending order");
            prev = ss.signers[i].account;
        }
        ssHash = keccak256(_newss);
        emit SignersUpdated(_newss);
    }

    // first verify _curss hash into ssHash, then verify sigs. sigs must be sorted by signer address
    function verifySigs(
        bytes calldata _msg,
        bytes calldata _curss,
        bytes[] calldata _sigs
    ) public view {
        require(ssHash == keccak256(_curss), "Mismatch current signers");
        PbSigner.SortedSigners memory ss = PbSigner.decSortedSigners(_curss); // sorted signers
        uint256 totalPower; // sum of all signer.power, do one loop here for simpler code
        for (uint256 i = 0; i < ss.signers.length; i++) {
            totalPower += ss.signers[i].power;
        }
        // recover signer address, add their power
        bytes32 hash = keccak256(_msg).toEthSignedMessageHash();
        uint256 signedPower; // sum of signer powers who are in sigs
        address prev = address(0);
        uint256 signerIdx = 0;
        for (uint256 i = 0; i < _sigs.length; i++) {
            address curSigner = hash.recover(_sigs[i]);
            require(curSigner > prev, "Signers not in ascending order");
            prev = curSigner;
            // now find match signer in ss, add its power
            while (curSigner > ss.signers[signerIdx].account) {
                signerIdx += 1;
                require(signerIdx < ss.signers.length, "Signer not found");
            }
            if (curSigner == ss.signers[signerIdx].account) {
                signedPower += ss.signers[signerIdx].power;
            }
        }

        require(signedPower > (totalPower * 2) / 3, "Quorum not reached");
    }

    function setInitSigners(bytes memory _ss) external onlyOwner {
        require(ssHash == bytes32(0), "signers already set");
        ssHash = keccak256(_ss);
        emit SignersUpdated(_ss);
    }
}
