// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IMaiBridgeHub {
    // send bridge token, get asset
    function swapIn(address, uint256) external;
    // send asset, get bridge token back
    function swapOut(address, uint256) external;
    // asset address
    function asset() external view returns (address);
}

/**
 * @title bridge token support swap with Mai hub. note Mai hub is NOT canonical token, asset is set in hub constructor
 */
contract MaiBridgeToken is ERC20, Ownable {
    using SafeERC20 for IERC20;

    address public bridge;
    address public maihub; // mai hub address for swap
    address public asset; // acutal asset/canonical token

    event BridgeUpdated(address bridge);

    modifier onlyBridge() {
        require(msg.sender == bridge, "caller is not bridge");
        _;
    }

    constructor(
        string memory name_,
        string memory symbol_,
        address bridge_,
        address maihub_
    ) ERC20(name_, symbol_) {
        bridge = bridge_;
        maihub = maihub_;
        asset = IMaiBridgeHub(maihub_).asset();
    }

    function mint(address _to, uint256 _amount) external onlyBridge returns (bool) {
        _mint(address(this), _amount); // add amount to myself so swapIn can transfer amount to hub
        _approve(address(this), maihub, _amount);
        IMaiBridgeHub(maihub).swapIn(address(this), _amount);
        // now this has canonical token, next step is to transfer to user
        return IERC20(asset).safeTransfer(_to, _amount);
    }

    function burn(address _from, uint256 _amount) external onlyBridge returns (bool) {
        _burn(address(this), _amount);
        IERC20(asset).safeTransferFrom(_from, address(this), _amount);
        IMaiBridgeHub(maihub).swapOut(address(this), _amount);
        return true;
    }

    function updateBridge(address _bridge) external onlyOwner {
        bridge = _bridge;
        emit BridgeUpdated(bridge);
    }

    function decimals() public view virtual override returns (uint8) {
        return ERC20(asset).decimals();
    }

    // to make compatible with BEP20
    function getOwner() external view returns (address) {
        return owner();
    }
}
