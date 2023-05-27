// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import { Fenix } from "@atomize/Fenix.sol";
import { console } from "forge-std/console.sol";

contract FENIXProdScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        Fenix fenix = new Fenix();
        console.log("FENIX: ", address(fenix));

        vm.stopBroadcast();
    }
}
