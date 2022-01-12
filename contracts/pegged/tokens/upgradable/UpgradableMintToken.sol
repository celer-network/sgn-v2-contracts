// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title Upgradable token support mint/burn from multiple bridges.
 */
contract UpgradableMintToken is Initializable, OwnableUpgradeable, ERC20Upgradeable {
    struct Supply {
        uint256 cap;
        uint256 total;
    }
    mapping(address => Supply) public bridges; // bridge address -> supply

    uint8 private _decimals;

    event BridgeSupplyCapUpdated(address bridge, uint256 supplyCap);

    function initialize(
        string memory name_,
        string memory symbol_,
        uint8 decimals_) public initializer {
            // MUST call super.initialize explicitly here and MUST keep same order
            OwnableUpgradeable.__Ownable_init();
            ERC20Upgradeable.__ERC20_init(name_, symbol_);
            _decimals = decimals_;
    }


    function mint(address _to, uint256 _amount) external returns (bool) {
        Supply storage b = bridges[msg.sender];
        require(b.cap > 0, "invalid caller");
        b.total += _amount;
        require(b.total <= b.cap, "exceeds bridge supply cap");
        _mint(_to, _amount);
        return true;
    }

    function burn(address _from, uint256 _amount) external returns (bool) {
        Supply storage b = bridges[msg.sender];
        require(b.cap > 0, "invalid caller");
        b.total -= _amount;
        _burn(_from, _amount);
        return true;
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function updateBridgeSupplyCap(address _bridge, uint256 _cap) external onlyOwner {
        // cap == 0 means revoking bridge role
        bridges[_bridge].cap = _cap;
        emit BridgeSupplyCapUpdated(_bridge, _cap);
    }

    // to make compatible with BEP20
    function getOwner() external view returns (address) {
        return owner();
    }
}
