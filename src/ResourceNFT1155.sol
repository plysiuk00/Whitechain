// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title ResourceNFT1155 (Template)
 * @notice Minimal ERC1155 with roles. Ready for search/craft flows.
 *
 * TODO:
 * - Define resource IDs externally (in CraftingSearch or config).
 * - Allow only CraftingSearch to mint on search and burn on craft.
 * - Enforce “no direct mint/burn by users” in actual flows.
 */
contract ResourceNFT1155 is ERC1155, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE"); // assign to CraftingSearch
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE"); // assign to CraftingSearch

    /**
     * @notice Example of resourse definition.
     *
     */
    uint256 public constant WOOD = 1;

    constructor(address admin) ERC1155("") {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    /// @dev Mint batch of resources. Intended to be called only by CraftingSearch.
    function mintBatch(
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts
    ) external onlyRole(MINTER_ROLE) {
        _mintBatch(to, ids, amounts, "");
    }

    /// @dev Burn batch of resources. Intended to be called only by CraftingSearch.
    function burnBatch(
        address from,
        uint256[] calldata ids,
        uint256[] calldata amounts
    ) external onlyRole(BURNER_ROLE) {
        _burnBatch(from, ids, amounts);
    }

    /// @inheritdoc ERC1155
    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC1155, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
