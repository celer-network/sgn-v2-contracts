// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract IncentiveEventsRewards is Ownable {
    using SafeERC20 for IERC20;

    IERC20 public immutable celerToken;
    bytes32 immutable public root;

    constructor(
        address _celerTokenAddress,
        bytes32 merkleroot
    ) {
        celerToken = IERC20(_celerTokenAddress);
        root = merkleroot;
    }

    /**
     * @dev user claim reward.
     */
    function claimReward(
        address calldata _addr, uint256 calldata _amount, bytes32[] calldata proof
    ) external {
        require(_verify(_leaf(account, _amount), proof), "Invalid merkle proof");
        celerToken.safeTransferFrom(address(this), msg.sender, _amount);
    }

    function _leaf(address account, uint256 amount)
    internal pure returns (bytes32)
    {
        return keccak256(abi.encodePacked(amount, account));
    }

    function _verify(bytes32 leaf, bytes32[] memory proof)
    internal view returns (bool)
    {
        return MerkleProof.verify(proof, root, leaf);
    }
}