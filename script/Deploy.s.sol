// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";

import {ResourceNFT1155} from "../src/ResourceNFT1155.sol";
import {ItemNFT721} from "../src/ItemNFT721.sol";
import {MagicToken} from "../src/MagicToken.sol";
import {CraftingSearch} from "../src/CraftingSearch.sol";
import {Marketplace} from "../src/Marketplace.sol";

/**
 * @dev Minimal deploy only. Grants core roles but leaves business rules to you.
 */
contract Deploy is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);

        address admin = vm.addr(pk);

        // Deploy baseline contracts
        ResourceNFT1155 res = new ResourceNFT1155(admin);
        ItemNFT721 items = new ItemNFT721(admin);
        MagicToken magic = new MagicToken(admin);
        CraftingSearch cs = new CraftingSearch(admin, res, items);
        Marketplace mkt = new Marketplace(admin, items, magic);

        // Grant roles for future flows (you will use them when implementing logic)
        res.grantRole(res.MINTER_ROLE(), address(cs));
        res.grantRole(res.BURNER_ROLE(), address(cs));

        items.grantRole(items.MINTER_ROLE(), address(cs));

        magic.grantRole(magic.MARKET_ROLE(), address(mkt));

        vm.stopBroadcast();

        console2.log("ResourceNFT1155:", address(res));
        console2.log("ItemNFT721     :", address(items));
        console2.log("MagicToken     :", address(magic));
        console2.log("CraftingSearch :", address(cs));
        console2.log("Marketplace    :", address(mkt));
        console2.log("Admin          :", admin);
    }
}
