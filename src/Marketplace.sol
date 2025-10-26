// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ItemNFT721} from "./ItemNFT721.sol";
import {MagicToken} from "./MagicToken.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @title Marketplace
 * @notice Allows users to list ItemNFT721 tokens for sale in exchange for MagicToken.
 * The current implementation uses a 'burn-on-sale' model, where the item is burned upon purchase.
 */
contract Marketplace is AccessControl {
    ItemNFT721 public items;
    MagicToken public magic;

    // --- Storage ---

    /**
     * @dev Struct to hold details of an active listing.
     * The seller is implicit via ownership check before listing.
     */
    struct Listing {
        address seller;
        uint256 price; // Price in MagicToken
        bool active;
    }

    /**
     * @dev Mapping from Item NFT Token ID to its Listing details.
     */
    mapping(uint256 => Listing) public listings;

    // --- Events ---

    event Listed(uint256 indexed tokenId, address indexed seller, uint256 price);
    event Delisted(uint256 indexed tokenId);
    event ItemSold(uint256 indexed tokenId, address indexed seller, address indexed buyer, uint256 price);

    // --- Constructor ---

    /**
     * @notice Initializes the Marketplace with admin privileges and contract addresses.
     * @param admin The address to be granted the DEFAULT_ADMIN_ROLE.
     * @param _items The address of the ItemNFT721 contract.
     * @param _magic The address of the MagicToken contract.
     */
    constructor(address admin, ItemNFT721 _items, MagicToken _magic) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        items = _items;
        magic = _magic;
    }

    // --- Listing Management ---

    /**
     * @notice Lists an Item NFT for sale at a specified price.
     * @dev The sender must be the owner of the token and must have approved this Marketplace contract.
     * @param tokenId The ID of the Item NFT to list.
     * @param price The price in MagicToken.
     */
    function list(uint256 tokenId, uint256 price) external {
        // 1. Ownership and Pre-approval Check
        address seller = msg.sender;
        require(items.ownerOf(tokenId) == seller, "Marketplace: Sender must own the token");
        
        // IMPORTANT: The seller must approve the Marketplace address to burn the token.
        // We check if the caller has approved this contract, either individually or for all.
        require(items.getApproved(tokenId) == address(this) || items.isApprovedForAll(seller, address(this)), 
            "Marketplace: Token must be approved for transfer/burn by this contract");
        
        require(price > 0, "Marketplace: Price must be greater than zero");
        require(!listings[tokenId].active, "Marketplace: Item already listed");

        // 2. Create Listing
        listings[tokenId] = Listing({
            seller: seller,
            price: price,
            active: true
        });

        emit Listed(tokenId, seller, price);
    }

    /**
     * @notice Removes an active listing. Can only be called by the seller or an admin.
     * @param tokenId The ID of the Item NFT to delist.
     */
    function delist(uint256 tokenId) external {
        Listing storage listing = listings[tokenId];
        require(listing.active, "Marketplace: Item is not currently listed");
        
        // Only the seller or an admin can delist
        require(msg.sender == listing.seller || hasRole(DEFAULT_ADMIN_ROLE, msg.sender), 
            "Marketplace: Sender must be seller or admin");

        // Remove the listing
        delete listings[tokenId];

        emit Delisted(tokenId);
    }

    // --- Purchase Logic ---

    /**
     * @notice Executes the purchase of a listed Item NFT.
     * @dev Buyer must approve the Marketplace to spend the required amount of MagicToken.
     * The item is burned, and the equivalent MagicToken is minted to the seller.
     * @param tokenId The ID of the Item NFT to purchase.
     */
    function purchase(uint256 tokenId) external {
        Listing storage listing = listings[tokenId];
        require(listing.active, "Marketplace: Item is not currently listed");

        address buyer = msg.sender;
        address seller = listing.seller;
        uint256 price = listing.price;
        
        // Prevent self-purchase
        require(buyer != seller, "Marketplace: Cannot purchase your own item");
        
        // 1. Transfer Payment (Burn from Buyer, Mint to Seller)
        
        // The buyer must have approved the Marketplace to spend 'price' MagicToken.
        // The implementation assumes MagicToken has an appropriate transfer/burn mechanism
        // or uses standard ERC20 which allows the Marketplace to call transferFrom().
        // Since MagicToken is a custom token, we use a simple burn/mint pattern for this example.
        
        // Check buyer balance and burn the MagicToken from the buyer
        magic.burn(buyer, price);
        
        // Mint the MagicToken to the seller
        magic.mint(seller, price);

        // 2. Fulfill Item Transfer (Burn the NFT)
        
        // The ItemNFT721 must have granted this Marketplace contract the ability to burn tokens.
        // Assuming ItemNFT721 has a custom burn function or that the ERC721 burn
        // function is accessible if this contract is the approved address.
        
        // The ItemNFT721 is burned by the Marketplace (which was approved by the seller)
        items.burn(tokenId); // Assumes ItemNFT721 has a public or internal burn function accessible via the approved marketplace

        // 3. Clear Listing
        delete listings[tokenId];

        emit ItemSold(tokenId, seller, buyer, price);
    }
}