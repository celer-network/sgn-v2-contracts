// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Intermediary token that automatically transfers the canonical token when interacting with approved bridges.
 */
contract IntermediaryOriginalToken is ERC20, Ownable {
    using SafeERC20 for IERC20;

    mapping(address => bool) public bridges;
    address public immutable canonical; // canonical token

    event BridgeUpdated(address bridge, bool enable);

    modifier onlyBridge() {
        require(bridges[msg.sender], "caller is not bridge");
        _;
    }

    constructor(
        string memory name_,
        string memory symbol_,
        address[] memory bridges_,
        address canonical_
    ) ERC20(name_, symbol_) {
        for (uint256 i = 0; i < bridges_.length; i++) {
            bridges[bridges_[i]] = true;
        }
        canonical = canonical_;
    }

    function transfer(address _to, uint256 _amount) public virtual override onlyBridge returns (bool) {
        _burn(msg.sender, _amount);
        IERC20(canonical).safeTransfer(_to, _amount);
        return true;
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _amount
    ) public virtual override onlyBridge returns (bool) {
        _mint(_to, _amount);
        IERC20(canonical).safeTransferFrom(_from, address(this), _amount);
        return true;
    }

    function updateBridge(address _bridge, bool _enable) external onlyOwner {
        bridges[_bridge] = _enable;
        emit BridgeUpdated(_bridge, _enable);
    }

    // to make compatible with BEP20
    function getOwner() external view returns (address) {
        return owner();
    }

    function decimals() public view virtual override returns (uint8) {
        return ERC20(canonical).decimals();
    }
}
