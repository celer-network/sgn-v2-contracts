// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.8.0;

import "../libraries/MsgDataTypes.sol";
import "../../safeguard/Pauser.sol";

abstract contract MessageAppPauser is Pauser {
    /**
     * @dev Modifier to make the message execution function callable only when
     * the contract is not paused.
     *
     * Added the ABORT_PREFIX ("MSG::ABORT:") in front of the revert message to
     * work with the Celer IM MessageBus contract, so that the message execution
     * can be retried later when the contract is unpaused.
     */
    modifier whenNotMsgPaused() {
        require(!paused(), MsgDataTypes.abortReason("Pausable: paused"));
        _;
    }
}
