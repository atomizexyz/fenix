// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { Fenix, Stake } from "@atomize/Fenix.sol";
import { XENCrypto } from "xen-crypto/XENCrypto.sol";
import { HelpersTest } from "./Helpers.t.sol";

contract FenixTest is Test {
    HelpersTest internal helper;
    Fenix internal fenix;
    XENCrypto internal xenCrypto;

    address internal bob = address(this);

    address[] internal stakers;

    /// ============ Setup test suite ============

    function setUp() public {
        helper = new HelpersTest();
        vm.broadcast(helper.xenDeployerPrivateKey());
        xenCrypto = new XENCrypto();

        stakers.push(bob);

        helper.generateXENFor(stakers, xenCrypto);
        fenix = new Fenix();
    }

    /// @notice Test that the contract can be deployed successfully
    function testMetadata() public {
        assertEq(fenix.name(), "FENIX");
        assertEq(fenix.symbol(), "FENIX");
        assertEq(fenix.decimals(), 18);
        assertEq(fenix.totalSupply(), 0);
    }
}
