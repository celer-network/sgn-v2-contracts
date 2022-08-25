// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface INativeVault {
    function mint(address to, uint256 amount) external;

    function burn() external payable;
}

contract MintBurnNativeToken is ERC20, Ownable {
    using SafeERC20 for IERC20;

    address public bridge;
    address public immutable nativeVault;
    uint8 private immutable _decimals;

    event BridgeUpdated(address bridge);

    modifier onlyBridge() {
        require(msg.sender == bridge, "caller is not bridge");
        _;
    }

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address bridge_,
        address vault_
    ) ERC20(name_, symbol_) {
        _decimals = decimals_;
        bridge = bridge_;
        nativeVault = vault_;
    }

    function mint(address _to, uint256 _amount) external onlyBridge returns (bool) {
        _mint(address(this), _amount);
        INativeVault(nativeVault).mint(_to, _amount);
        return true;
    }

    function burn() external payable onlyBridge returns (bool) {
        _burn(address(this), msg.value);
        INativeVault(nativeVault).burn{value: msg.value}();
        return true;
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function updateBridge(address _bridge) external onlyOwner {
        bridge = _bridge;
        emit BridgeUpdated(bridge);
    }
}
