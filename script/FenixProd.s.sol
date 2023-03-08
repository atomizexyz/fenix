// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import { Fenix } from "@atomize/Fenix.sol";
import { console } from "forge-std/console.sol";

contract FenixProdScript is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        Fenix fenix = new Fenix();
        console.log("FENIX: ", address(fenix));

        vm.stopBroadcast();
    }
}
