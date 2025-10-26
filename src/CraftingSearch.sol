// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ResourceNFT1155} from "./ResourceNFT1155.sol";
import {ItemNFT721} from "./ItemNFT721.sol";

/**
 * @title CraftingSearch
 * @notice Implements resource search with cooldown and a basic crafting mechanism.
 * @dev This contract manages the primary game loop: gathering resources and converting them into items.
 */
contract CraftingSearch is AccessControl {
    ResourceNFT1155 public resources;
    ItemNFT721 public items;

    /// @notice The duration (in seconds) that a user must wait between searches.
    uint256 public constant SEARCH_COOLDOWN = 60;

    /**
     * @dev Mapping to track the last time an address successfully performed a search.
     * Used to enforce the SEARCH_COOLDOWN.
     */
    mapping(address => uint256) private lastSearchTime;

    // --- Basic Recipe Storage ---

    /**
     * @dev Defines the resource requirements for crafting an item.
     * @param resourceIds Array of ResourceNFT1155 IDs required.
     * @param amounts Array of corresponding amounts required (must match resourceIds length).
     * @param itemType The ID of the ItemNFT721 to be minted upon success.
     */
    struct Recipe {
        uint256[] resourceIds;
        uint256[] amounts;
        uint256 itemType; 
    }

    /// @dev Mapping from the resulting Item Type ID to its crafting Recipe.
    mapping(uint256 => Recipe) private recipes;

    /**
     * @notice Initializes the CraftingSearch contract.
     * @param admin The address to be granted the DEFAULT_ADMIN_ROLE.
     * @param _resources The address of the ResourceNFT1155 contract.
     * @param _items The address of the ItemNFT721 contract.
     */
    constructor(address admin, ResourceNFT1155 _resources, ItemNFT721 _items) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        resources = _resources;
        items = _items;

        // Initialize a simple recipe (e.g., Item Type 1) upon deployment
        recipes[1] = Recipe({
            resourceIds: new uint256[](3),
            amounts: new uint256[](3),
            itemType: 1
        });

        // Recipe for Item Type 1: Requires 1 each of Resource IDs 1, 2, and 3.
        recipes[1].resourceIds[0] = 1; 
        recipes[1].amounts[0] = 1;     
        recipes[1].resourceIds[1] = 2; 
        recipes[1].amounts[1] = 1;     
        recipes[1].resourceIds[2] = 3; 
        recipes[1].amounts[2] = 1;     
    }

    /// @notice Executes a resource search, minting resources to the sender.
    /// @dev Enforces a 60-second cooldown using `lastSearchTime`. Mints 3 units each of Resource IDs 1, 2, and 3.
    function search() external {
        address user = msg.sender;

        /// @custom:cooldown Error thrown if the cooldown has not expired.
        require(block.timestamp >= lastSearchTime[user] + SEARCH_COOLDOWN, "Search cooldown not over");

        lastSearchTime[user] = block.timestamp;

        // Resource IDs and amounts to mint (Placeholder 'random' resources)
        uint256[] memory ids = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);

        ids[0] = 1; 
        amounts[0] = 3;
        ids[1] = 2; 
        amounts[1] = 3;
        ids[2] = 3; 
        amounts[2] = 3;

        // Calls mintBatch on the ResourceNFT1155 contract (must have MINTER_ROLE).
        // FIX: Removed the extra "" argument to match the 3-argument signature.
        resources.mintBatch(user, ids, amounts);
    }

    /// @notice Crafts a specified Item NFT by consuming required resources based on a defined recipe.
    /// @dev Requires the sender to have the necessary resource balances. Burns resources via ResourceNFT1155, then mints a new ItemNFT721.
    /// @param itemType The ID of the ItemNFT721 to craft (e.g., 1).
    function craft(uint256 itemType) external {
        address user = msg.sender;

        // 1. Get the recipe and ensure it exists
        Recipe storage recipe = recipes[itemType];
        require(recipe.itemType > 0, "Invalid item type or no recipe found");
        
        // Ensure arrays are correctly sized
        require(recipe.resourceIds.length == recipe.amounts.length, "Recipe is malformed");

        // 2. Burn resources (ResourceNFT1155 must have BURNER_ROLE)
        resources.burnBatch(user, recipe.resourceIds, recipe.amounts);

        // 3. Mint item (ItemNFT721 must have MINTER_ROLE)
        items.mintTo(user);
    }
}
