// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.8.9;

import "../../framework/MessageApp.sol";
import "../../../safeguard/Pauser.sol";
import "../../../safeguard/DelayedMessage.sol";

// A HelloWorld example for basic cross-chain message passing
contract MessageReceiverAdapter is MessageApp, DelayedMessage, Pauser {
    event MessageReceived(address srcContract, uint64 srcChainId, bytes message);

    constructor(address _messageBus) MessageApp(_messageBus) {}

    // called by MessageBus on destination chain to receive cross-chain messages
    function executeMessage(
        address _srcContract,
        uint64 _srcChainId,
        bytes calldata _message,
        address // executor
    ) external payable override onlyMessageBus returns (ExecutionStatus) {
        (address dstContract, bytes memory callData) = abi.decode(_message, (address, bytes));
        bool delay = delayPeriods[dstContract] > 0 ? true : false;
        if (delay) {
            _addDelayedMessage(_srcContract, _srcChainId, dstContract, callData);
            return ExecutionStatus.Success;
        }
        emit MessageReceived(_srcContract, _srcChainId, _message);
        return externalCall(dstContract, callData);
    }

    function executeDelayedMessage(
        address _srcContract,
        uint64 _srcChainId,
        address _dstContract,
        bytes calldata _callData,
        uint32 _nonce
    ) external payable returns (ExecutionStatus) {
        _executeDelayedMessage(_srcContract, _srcChainId, _dstContract, _callData, _nonce);
        return externalCall(_dstContract, _callData);
    }

    function externalCall(address _dstContract, bytes memory _callData) internal returns (ExecutionStatus) {
        (bool ok, bytes memory returnData) = _dstContract.call{value: msg.value}(_callData);
        if (ok) {
            // a successful call only accept ExecutionStatus as returnData.
            // a enum value(uint8) would be packed to a 32 bytes slice
            if (returnData.length == 32) {
                return abi.decode((returnData), (ExecutionStatus));
            }
            return ExecutionStatus.Success;
        } else {
            // Bubble up the revert from the returnData
            revertFromReturnedData;
            // unreached code
            return ExecutionStatus.Fail;
        }
    }

    // based on https://github.com/superfluid-finance/protocol-monorepo/blob/dev/packages/ethereum-contracts/contracts/libs/CallUtils.sol
    /// @dev Bubble up the revert from the returnedData (supports Panic, Error & Custom Errors)
    /// @notice This is needed in order to provide some human-readable revert message from a call
    /// @param returnedData Response of the call
    function revertFromReturnedData(bytes memory returnedData) internal pure {
        if (returnedData.length < 4) {
            // case 1: catch all
            revert("Adapter: dstContract revert()");
        } else {
            bytes4 errorSelector;
            assembly {
                errorSelector := mload(add(returnedData, 0x20))
            }
            if (
                errorSelector == bytes4(0x4e487b71) /* `seth sig "Panic(uint256)"` */
            ) {
                // case 2: Panic(uint256) (Defined since 0.8.0)
                // solhint-disable-next-line max-line-length
                // ref: https://docs.soliditylang.org/en/v0.8.0/control-structures.html#panic-via-assert-and-error-via-require)
                string memory reason = "Adapter: dstContract panicked: 0x__";
                uint256 errorCode;
                assembly {
                    errorCode := mload(add(returnedData, 0x24))
                    let reasonWord := mload(add(reason, 0x20))
                    // [0..9] is converted to ['0'..'9']
                    // [0xa..0xf] is not correctly converted to ['a'..'f']
                    // but since panic code doesn't have those cases, we will ignore them for now!
                    let e1 := add(and(errorCode, 0xf), 0x30)
                    let e2 := shl(8, add(shr(4, and(errorCode, 0xf0)), 0x30))
                    reasonWord := or(
                        and(reasonWord, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0000),
                        or(e2, e1)
                    )
                    mstore(add(reason, 0x20), reasonWord)
                }
                revert(reason);
            } else {
                // case 3: Error(string) (Defined at least since 0.7.0)
                // case 4: Custom errors (Defined since 0.8.0)
                uint256 len = returnedData.length;
                assembly {
                    revert(add(returnedData, 32), len)
                }
            }
        }
    }
}
