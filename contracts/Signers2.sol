// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.9;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Signers2 is Ownable {
    using ECDSA for bytes32;

    bytes32 public ssHash;

    event SignersUpdated(address[] _signers, uint256[] _powers);

    function verifySigs(
        bytes calldata _msg,
        bytes[] calldata _sigs,
        address[] calldata _signers, // current sorted signers
        uint256[] calldata _powers // powers of current sorted signers
    ) public view {
        require(_signers.length == _powers.length, "signers and powers length not match");
        bytes32 h = keccak256(abi.encodePacked(_signers, _powers));
        require(ssHash == h, "Mismatch current signers");
        uint256 totalPower; // sum of all signer.power, do one loop here for simpler code
        for (uint256 i = 0; i < _signers.length; i++) {
            totalPower += _powers[i];
        }
        uint256 quorum = (totalPower * 2) / 3 + 1;
        _verifySignedPowers(keccak256(_msg).toEthSignedMessageHash(), _sigs, _signers, _powers, quorum);
    }

    function resetSigners(address[] calldata _signers, uint256[] calldata _powers) external onlyOwner {
        _updateSigners(_signers, _powers);
    }

    // separate from verifySigs func to avoid "stack too deep" issue
    function _verifySignedPowers(
        bytes32 _hash,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers,
        uint256 quorum
    ) private pure {
        uint256 signedPower; // sum of signer powers who are in sigs
        address prev = address(0);
        uint256 index = 0;
        for (uint256 i = 0; i < _sigs.length; i++) {
            address signer = _hash.recover(_sigs[i]);
            require(signer > prev, "Signers not in ascending order");
            prev = signer;
            // now find match signer in ss, add its power
            while (signer > _signers[index]) {
                index += 1;
                require(index < _signers.length, "Signer not found");
            }
            if (signer == _signers[index]) {
                signedPower += _powers[index];
            }
            if (signedPower >= quorum) {
                // return early to save gas
                return;
            }
        }
        revert("Quorum not reached");
    }

    function _updateSigners(address[] calldata _signers, uint256[] calldata _powers) private {
        require(_signers.length == _powers.length, "signers and powers length not match");
        address prev = address(0);
        for (uint256 i = 0; i < _signers.length; i++) {
            require(_signers[i] > prev, "New signers not in ascending order");
            prev = _signers[i];
        }
        ssHash = keccak256(abi.encodePacked(_signers, _powers));
        emit SignersUpdated(_signers, _powers);
    }
}
