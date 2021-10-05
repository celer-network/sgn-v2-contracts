// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.7;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/ISigsVerifier.sol";
import "./libraries/PbSigner.sol";

// only store hash of serialized SortedSigners
contract Signers is Ownable, ISigsVerifier {
    using ECDSA for bytes32;

    event SignersUpdated(
        bytes curSigners // serialized SortedSigners
    );

    event SignersResetting(uint256 resetTime);

    bytes32 public ssHash;

    // reset can be called by the owner address for emergency recovery
    uint256 public resetTime;
    uint256 public noticePeriod; // advance notice period as seconds for reset
    uint256 constant MAX_INT = 2**256 - 1;

    constructor(bytes memory _ss) {
        if (_ss.length > 0) {
            _updateSigners(_ss);
        }
        resetTime = MAX_INT;
    }

    // set new signers
    function updateSigners(
        bytes calldata _newss,
        bytes calldata _curss,
        bytes[] calldata _sigs
    ) external {
        verifySigs(_newss, _curss, _sigs);
        _updateSigners(_newss);
    }

    /**
     * @notice Verifies that a message is signed by a quorum among the signers. The function first
     * verifies _curss hashes into ssHash, then verifies the sigs. The sigs must be sorted by signer
     * addresses in ascending order.
     * @param _msg signed message
     * @param _curss the list of signers
     * @param _sigs the list of signatures
     */
    function verifySigs(
        bytes calldata _msg,
        bytes calldata _curss,
        bytes[] calldata _sigs
    ) public view override {
        require(ssHash == keccak256(_curss), "Mismatch current signers");
        PbSigner.SortedSigners memory ss = PbSigner.decSortedSigners(_curss); // sorted signers
        uint256 totalPower; // sum of all signer.power, do one loop here for simpler code
        for (uint256 i = 0; i < ss.signers.length; i++) {
            totalPower += ss.signers[i].power;
        }
        uint256 quorumThreshold = (totalPower * 2) / 3 + 1;
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
            if (signedPower >= quorumThreshold) {
                // return early to save gas
                return;
            }
        }
        revert("Quorum not reached");
    }

    function setInitSigners(bytes calldata _initss) external onlyOwner {
        require(ssHash == bytes32(0), "signers already set");
        _updateSigners(_initss);
    }

    function increaseNoticePeriod(uint256 period) external onlyOwner {
        require(period > noticePeriod, "notice period can only be increased");
        noticePeriod = period;
    }

    function startResetSigners() external onlyOwner {
        resetTime = block.timestamp + noticePeriod;
        emit SignersResetting(resetTime);
    }

    function resetSigners(bytes calldata _newss) external onlyOwner {
        require(block.timestamp > resetTime, "not reach reset time");
        resetTime = MAX_INT;
        _updateSigners(_newss);
    }

    function _updateSigners(bytes memory _newss) private {
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
}
