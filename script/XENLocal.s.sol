// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import { Fenix } from "@atomize/Fenix.sol";
import { XENCrypto } from "xen-crypto/XENCrypto.sol";
import { console } from "forge-std/console.sol";

contract XENLocalScript is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        XENCrypto xenCrypto = new XENCrypto();
        console.log("XEN:", address(xenCrypto));

        vm.stopBroadcast();
    }
}
