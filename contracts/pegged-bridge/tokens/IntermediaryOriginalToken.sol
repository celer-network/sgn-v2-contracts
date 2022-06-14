// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Per bridge intermediary token that delegates to a canonical token.
 * Useful for several original tokens that need to be pegged to a single pegged token.
 */
contract IntermediaryOriginalToken is ERC20, Ownable {
    using SafeERC20 for IERC20;

    address public bridge;
    address public immutable canonical; // canonical token

    event BridgeUpdated(address bridge);

    constructor(
        string memory name_,
        string memory symbol_,
        address bridge_,
        address canonical_
    ) ERC20(name_, symbol_) {
        bridge = bridge_;
        canonical = canonical_;
    }

    function transfer(address _to, uint256 _amount) public virtual override returns (bool) {
        if (msg.sender == bridge) {
            _burn(msg.sender, _amount);
            IERC20(canonical).safeTransfer(_to, _amount);
            return true;
        }
        return super.transfer(_to, _amount);
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _amount
    ) public virtual override returns (bool) {
        if (msg.sender == bridge) {
            IERC20(canonical).safeTransferFrom(_from, address(this), _amount);
            _mint(_to, _amount);
            return true;
        }
        return super.transferFrom(_from, _to, _amount);
    }

    function updateBridge(address _bridge) external onlyOwner {
        bridge = _bridge;
        emit BridgeUpdated(bridge);
    }

    // to make compatible with BEP20
    function getOwner() external view returns (address) {
        return owner();
    }

    function decimals() public view virtual override returns (uint8) {
        return ERC20(canonical).decimals();
    }
}
