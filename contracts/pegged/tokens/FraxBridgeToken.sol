// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >= 0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IFraxCanoToken {
    function exchangeOldForCanonical(address, uint256) external returns (uint256);
    function exchangeCanonicalForOld(address, uint256) external returns (uint256);
}

/**
 * @title bridge token support swap with Frax canonical token.
 */
contract FraxBridgeToken is ERC20, Ownable {
    address public bridge;
    address public canonical; // canonical token that support swap

    event BridgeUpdated(address bridge);

    modifier onlyBridge() {
        require(msg.sender == bridge, "caller is not bridge");
        _;
    }

    constructor(
        string memory name_,
        string memory symbol_,
        address bridge_,
        address canonical_
    ) ERC20(name_, symbol_) {
        bridge = bridge_;
        canonical = canonical_;
    }

    function mint(address _to, uint256 _amount) external onlyBridge returns (bool) {
        _mint(address(this), _amount); // add amount to myself so swapBridgeForCanonical can transfer amount
        approve(canonical, _amount);
        uint256 got = IFraxCanoToken(canonical).exchangeOldForCanonical(address(this), _amount);
        // now this has canonical token, next step is to transfer to user
        return IERC20(canonical).transfer(_to, got);
    }

    function burn(address _from, uint256 _amount) external onlyBridge returns (bool) {
        IERC20(canonical).transferFrom(_from, address(this), _amount);
        uint256 got = IFraxCanoToken(canonical).exchangeCanonicalForOld(address(this), _amount);
        _burn(address(this), got);
        return true;
    }

    function updateBridge(address _bridge) external onlyOwner {
        bridge = _bridge;
        emit BridgeUpdated(bridge);
    }

    // to make compatible with BEP20
    function getOwner() external view returns (address) {
        return owner();
    }
}
