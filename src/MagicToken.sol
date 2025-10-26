// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title MagicToken
 * @notice An ERC20 token with role-gated minting and burning, used as currency.
 */
contract MagicToken is ERC20, AccessControl {
    bytes32 public constant MARKET_ROLE = keccak256("MARKET_ROLE"); 

    constructor(address admin) ERC20("Magic Token", "MAGIC") {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    /// @notice Allows MARKET_ROLE to mint new tokens to a specified address.
    function mint(address to, uint256 amount) external onlyRole(MARKET_ROLE) {
        _mint(to, amount);
    }

    /// @notice Allows MARKET_ROLE to burn tokens from a specified address (requires approval).
    function burn(address from, uint256 amount) external onlyRole(MARKET_ROLE) {
        // Since this is called externally (by Marketplace), we rely on the Marketplace 
        // ensuring the 'from' address has approved the Marketplace to spend 'amount'.
        _burn(from, amount);
    }

    /// @inheritdoc AccessControl
    function supportsInterface(
        bytes4 interfaceId
    ) public view override(AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
