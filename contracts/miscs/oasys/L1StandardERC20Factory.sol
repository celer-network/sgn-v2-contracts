// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {L1StandardERC20} from "./L1StandardERC20.sol";

/**
 * @title L1StandardERC20Factory
 * @dev L1StandardERC20Factory deploys the Oasys Standard ERC20 contract.
 */
contract L1StandardERC20Factory {
    /**********
     * Events *
     **********/

    event ERC20Created(string indexed _symbol, address indexed _address);

    /********************
     * Public Functions *
     ********************/

    /**
     * Deploys the Oasys Standard ERC20.
     * @param _name Name of the ERC20.
     * @param _symbol Symbol of the ERC20.
     */
    function createStandardERC20(string memory _name, string memory _symbol) external {
        L1StandardERC20 erc20 = new L1StandardERC20(msg.sender, _name, _symbol);
        emit ERC20Created(_symbol, address(erc20));
    }
}
