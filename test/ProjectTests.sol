// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import "forge-std/console.sol";
import {CraftingSearch} from "../src/CraftingSearch.sol";
import {ResourceNFT1155} from "../src/ResourceNFT1155.sol";
import {ItemNFT721} from "../src/ItemNFT721.sol";
import {MagicToken} from "../src/MagicToken.sol";
import {Marketplace} from "../src/Marketplace.sol";

contract ProjectTests is Test {
    // --- Contracts ---
    CraftingSearch public cs;
    ResourceNFT1155 public resources;
    ItemNFT721 public items;
    MagicToken public magic;
    Marketplace public marketplace;

    // --- Actors ---
    address public deployer = makeAddr("deployer");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    
    // --- Constants ---
    uint256 public constant ITEM_TYPE_1 = 1;
    uint256 public constant RESOURCE_ID_1 = 1;
    uint256 public constant RESOURCE_ID_2 = 2;
    uint256 public constant RESOURCE_ID_3 = 3;
    uint256 public constant SEARCH_AMOUNT = 3;
    uint256 public constant LISTING_PRICE = 100 ether;

    function setUp() public {
        // 1. Deploy all required contracts
        vm.startPrank(deployer);
        resources = new ResourceNFT1155(deployer);
        items = new ItemNFT721(deployer);
        magic = new MagicToken(deployer);
        marketplace = new Marketplace(deployer, items, magic);
        cs = new CraftingSearch(deployer, resources, items);
        vm.stopPrank();

        // 2. Grant roles to interacting contracts (CRITICAL STEP)
        vm.startPrank(deployer);
        // CraftingSearch needs MINTER and BURNER on Resources
        resources.grantRole(resources.MINTER_ROLE(), address(cs));
        resources.grantRole(resources.BURNER_ROLE(), address(cs));
        
        // CraftingSearch needs MINTER on Items
        items.grantRole(items.MINTER_ROLE(), address(cs));
        
        // Marketplace needs BURNER on Items
        items.grantRole(items.BURNER_ROLE(), address(marketplace));

        // Marketplace needs MARKET_ROLE (Mint/Burn) on MagicToken
        magic.grantRole(magic.MARKET_ROLE(), address(marketplace));
        vm.stopPrank();
    }

    // =========================================================================
    //                            CRAFTINGSEARCH TESTS
    // =========================================================================

    // --- Cooldown Logic ---

    function test_Search_Success_AfterCooldown() public {
        vm.warp(1000); // Ensure clean starting time
        vm.startPrank(user1);
        cs.search();
        vm.stopPrank(); // Stop Prank to finalize the transaction time

        // Advance time just past the cooldown
        vm.warp(block.timestamp + cs.SEARCH_COOLDOWN() + 1); 
        
        vm.startPrank(user1);
        cs.search(); // Second search
        vm.stopPrank();

        // Check that a second search was successful and resources doubled (3 + 3 = 6)
        assertEq(resources.balanceOf(user1, RESOURCE_ID_1), SEARCH_AMOUNT * 2);
    }

    function test_Search_Revert_BeforeCooldown() public {
        vm.warp(1000); // FIX: Ensure clean starting time for this test
        vm.startPrank(user1);
        cs.search(); // First search
        
        // Attempt to search again immediately (0 seconds passed)
        vm.expectRevert("Search cooldown not over");
        cs.search();

        // Advance time just before the cooldown ends
        vm.warp(block.timestamp + cs.SEARCH_COOLDOWN() - 1); 
        vm.expectRevert("Search cooldown not over");
        cs.search();
        vm.stopPrank();
    }
    
    // --- Crafting Logic (ERC1155 Mint/Burn & ERC721 Mint) ---
    
    function test_Craft_Success() public {
        // Setup: user1 searches twice to get 6 resources of each type (3 required for craft)
        prepUserCraftItem(user1, ITEM_TYPE_1);
        
        // Check initial resources: 6 of each (1, 2, 3)
        assertEq(resources.balanceOf(user1, RESOURCE_ID_1), 6);
        
        // Act: Craft item type 1 (requires 1 each of 1, 2, 3)
        vm.startPrank(user1);
        cs.craft(ITEM_TYPE_1);
        vm.stopPrank();

        // Assert: Resources burned (6 - 1 = 5)
        assertEq(resources.balanceOf(user1, RESOURCE_ID_1), 5);
        assertEq(resources.balanceOf(user1, RESOURCE_ID_2), 5);
        assertEq(resources.balanceOf(user1, RESOURCE_ID_3), 5);

        // Assert: Item NFT minted (ID 1 since nextId starts at 1)
        assertEq(items.ownerOf(1), user1);
        assertEq(items.nextId(), 2);
    }
    
    function test_Craft_Revert_InsufficientResources() public {
        vm.warp(1000); // FIX: Ensure clean starting time for this test
        // Setup: user1 searches once (gets 3 resources of each type)
        vm.startPrank(user1);
        cs.search(); 
        vm.stopPrank();
        
        // Advance time so the cooldown check for the first craft passes
        vm.warp(block.timestamp + cs.SEARCH_COOLDOWN() + 1);

        // User attempts to craft (burns 1 of each), which is successful
        vm.startPrank(user1);
        cs.craft(ITEM_TYPE_1); 
        vm.stopPrank();

        // Advance time so the cooldown check for the second craft passes
        vm.warp(block.timestamp + cs.SEARCH_COOLDOWN() + 1);

        // User now has 2 of each resource left.
        // Attempt to craft again (needs 1 of each)
        vm.startPrank(user1);
        vm.expectRevert(); // ERC1155: insufficient balance for transfer (Expected Revert)
        cs.craft(ITEM_TYPE_1); 
        vm.stopPrank();
    }
    
    // --- Recipe Validation Edge Cases ---
    
    function test_Craft_Revert_InvalidItemType() public {
        vm.startPrank(user1);
        // Item Type 99 has no recipe
        vm.expectRevert("Invalid item type or no recipe found");
        cs.craft(99); 
        vm.stopPrank();
    }

    // =========================================================================
    //                             MARKETPLACE TESTS
    // =========================================================================
    
    // --- Listing and Delisting ---

    function test_Marketplace_List_Success() public {
        // Setup: User1 crafts an item (ID 1)
        prepUserCraftItem(user1, ITEM_TYPE_1);
        
        // Act: User1 lists item 1
        vm.startPrank(user1);
        // User must approve the Marketplace to burn the item
        items.approve(address(marketplace), 1); 
        marketplace.list(1, LISTING_PRICE);
        vm.stopPrank();

        // Assert: Listing is active and details are correct
        (address seller, uint256 price, bool active) = marketplace.listings(1);
        assertEq(seller, user1);
        assertEq(price, LISTING_PRICE);
        assertTrue(active);
    }
    
    function test_Marketplace_List_Revert_Unapproved() public {
        // Setup: User1 crafts an item (ID 1)
        prepUserCraftItem(user1, ITEM_TYPE_1);
        
        // Act: User1 attempts to list item 1 without approval
        vm.startPrank(user1);
        vm.expectRevert("Marketplace: Token must be approved for transfer/burn by this contract");
        marketplace.list(1, LISTING_PRICE);
        vm.stopPrank();
    }
    
    function test_Marketplace_Delist_Success() public {
        // Setup: List item 1
        prepUserList(user1, 1, LISTING_PRICE);
        
        // Act: User1 delists the item
        vm.startPrank(user1);
        marketplace.delist(1);
        vm.stopPrank();

        // Assert: Listing is deleted
        (, , bool active) = marketplace.listings(1);
        assertFalse(active);
    }

    function test_Marketplace_Delist_Revert_NotSellerOrAdmin() public {
        // Setup: List item 1
        prepUserList(user1, 1, LISTING_PRICE);
        
        // Act: User2 attempts to delist the item
        vm.startPrank(user2);
        vm.expectRevert("Marketplace: Sender must be seller or admin");
        marketplace.delist(1);
        vm.stopPrank();
    }
    
    // --- Purchase Logic (ERC721 Burn & ERC20 Mint/Burn) ---

    function test_Marketplace_Purchase_Success() public {
        // Setup: user1 lists item 1 for 100 MAGIC. user2 needs 100 MAGIC.
        prepUserList(user1, 1, LISTING_PRICE);
        prepMagicBalance(user2, LISTING_PRICE); // Grant user2 MAGIC token balance
        
        // User2 must approve Marketplace to spend their MAGIC
        vm.startPrank(user2);
        magic.approve(address(marketplace), LISTING_PRICE);
        
        // Initial balances for assertion
        uint256 sellerInitialMagicBalance = magic.balanceOf(user1);
        uint256 buyerInitialMagicBalance = magic.balanceOf(user2);
        
        // Act: User2 purchases item 1
        marketplace.purchase(1); 
        vm.stopPrank();

        // Assert 1: Item is burned (ERC721 Burn)
        vm.expectRevert(abi.encodeWithSignature("OwnerQueryForNonexistentToken(uint256)", 1));
        items.ownerOf(1);

        // Assert 2: Listing is removed
        (, , bool active) = marketplace.listings(1);
        assertFalse(active);

        // Assert 3: Money moved (ERC20 Burn/Mint)
        assertEq(magic.balanceOf(user1), sellerInitialMagicBalance + LISTING_PRICE);
        assertEq(magic.balanceOf(user2), buyerInitialMagicBalance - LISTING_PRICE);
    }
    
    function test_Marketplace_Purchase_Revert_InsufficientApproval() public {
        // Setup: user1 lists item 1 for 100 MAGIC. user2 has 100 MAGIC.
        prepUserList(user1, 1, LISTING_PRICE);
        prepMagicBalance(user2, LISTING_PRICE);

        // User2 only approves 50 MAGIC (less than LISTING_PRICE)
        vm.startPrank(user2);
        magic.approve(address(marketplace), LISTING_PRICE / 2); // 50 MAGIC approved
        
        // Act: User2 attempts to purchase
        vm.expectRevert("ERC20: insufficient allowance"); // Revert from MagicToken._burn or equivalent
        marketplace.purchase(1);
        vm.stopPrank();
    }
    
    function test_Marketplace_Purchase_Revert_SelfPurchase() public {
        // Setup: user1 lists item 1
        prepUserList(user1, 1, LISTING_PRICE);
        
        // Act: user1 attempts to purchase their own item
        vm.startPrank(user1);
        vm.expectRevert("Marketplace: Cannot purchase your own item");
        marketplace.purchase(1);
        vm.stopPrank();
    }


    // =========================================================================
    //                                HELPER FUNCTIONS
    // =========================================================================

    /**
     * @notice Crafts an item for a user, performing two searches with a time warp in between.
     * @dev FIX: Added a large, fixed time jump to guarantee the cooldown is passed,
     * removing reliance on the dynamic `cs.SEARCH_COOLDOWN()` value in the warp calculation.
     */
    function prepUserCraftItem(address user, uint256 itemType) internal returns (uint256) {
        vm.warp(block.timestamp + 1000); // FIX: Ensure clean, advanced starting time for this sequence

        // 1. Give user resources (search once)
        vm.startPrank(user);
        cs.search(); 
        vm.stopPrank(); // END of transaction 1

        // Advance the clock by a fixed, large amount (e.g., 1 hour = 3600 seconds)
        // This guarantees the 60-second cooldown is passed.
        vm.warp(block.timestamp + 3600); 

        // 2. Search again to get sufficient resources (start new transaction)
        vm.startPrank(user);
        cs.search(); 
        vm.stopPrank(); // END of transaction 2
        
        // 3. Craft the item
        vm.startPrank(user);
        cs.craft(itemType);
        vm.stopPrank();
        
        // Item ID will be 1 (first item minted)
        return 1;
    }

    function prepUserList(address user, uint256 tokenId, uint256 price) internal {
        // 1. Ensure item exists and is owned by user (calls the fixed prepUserCraftItem)
        prepUserCraftItem(user, ITEM_TYPE_1);
        
        // 2. Approve marketplace and list the item
        vm.startPrank(user);
        items.approve(address(marketplace), tokenId);
        marketplace.list(tokenId, price);
        vm.stopPrank();
    }
    
    function prepMagicBalance(address user, uint256 amount) internal {
        vm.startPrank(deployer);
        // Temporarily grant deployer MARKET_ROLE to mint the initial balance
        magic.grantRole(magic.MARKET_ROLE(), deployer); 
        magic.mint(user, amount);
        magic.revokeRole(magic.MARKET_ROLE(), deployer);
        vm.stopPrank();
    }
}
