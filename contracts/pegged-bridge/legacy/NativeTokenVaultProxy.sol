// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../libraries/PbPegged.sol";
import "../../interfaces/IOriginalTokenVault.sol";
import "../../interfaces/IWETH.sol";

// To support single-transaction deposit of native gas token (e.g., ETH in ethereum)
// to legacy vaults that do not have the depositNative function
contract NativeTokenVaultProxy {
    address public immutable nativeWrap;
    address public immutable vault;

    mapping(bytes32 => address) public senders;

    constructor(address _nativeWrap, address _vault) {
        nativeWrap = _nativeWrap;
        vault = _vault;
    }

    /**
     * @notice Deposit native token in the vault
     * @param _amount The amount to deposit.
     * @param _mintChainId The destination chain ID to mint tokens.
     * @param _mintAccount The destination account to receive the minted pegged tokens.
     * @param _nonce A number input to guarantee unique depositId. Can be timestamp in practice.
     */
    function depositNative(
        uint256 _amount,
        uint64 _mintChainId,
        address _mintAccount,
        uint64 _nonce
    ) external payable returns (bytes32) {
        require(msg.value == _amount, "Amount mismatch");
        require(nativeWrap != address(0), "Native wrap not set");
        bytes32 depositId = keccak256(
            abi.encodePacked(
                address(this),
                nativeWrap,
                _amount,
                _mintChainId,
                _mintAccount,
                _nonce,
                uint64(block.chainid)
            )
        );
        IWETH(nativeWrap).deposit{value: _amount}();
        IOriginalTokenVault(vault).deposit(nativeWrap, _amount, _mintChainId, _mintAccount, _nonce);
        senders[depositId] = msg.sender;
        return depositId;
    }

    /**
     * @notice Refund a failed native token deposit
     * @param _request The serialized request protobuf.
     * @param _sigs The list of signatures sorted by signing addresses in ascending order.
     * @param _signers The sorted list of signers.
     * @param _powers The signing powers of the signers.
     */
    function refund(
        bytes calldata _request,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers
    ) external returns (bytes32) {
        PbPegged.Withdraw memory wd = PbPegged.decWithdraw(_request);
        require(wd.receiver == address(this), "Receiver mismatch");
        require(wd.token == nativeWrap, "Token mismatch");
        bytes32 withdrawId = keccak256(
            abi.encodePacked(wd.receiver, wd.token, wd.amount, wd.burnAccount, wd.refChainId, wd.refId)
        );
        if (!IOriginalTokenVault(vault).records(withdrawId)) {
            IOriginalTokenVault(vault).withdraw(_request, _sigs, _signers, _powers);
        }
        address sender = senders[wd.refId];
        require(sender != address(0), "Sender not found");
        delete senders[wd.refId];
        IWETH(nativeWrap).withdraw(wd.amount);
        (bool sent, ) = sender.call{value: wd.amount, gas: 50000}("");
        require(sent, "failed to send native token");
        return withdrawId;
    }
}
