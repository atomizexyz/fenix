// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { Fenix, Stake } from "@atomize/Fenix.sol";
import { XENCrypto } from "xen-crypto/XENCrypto.sol";
import { HelpersTest } from "./Helpers.t.sol";

contract FenixBurnTest is Test {
    HelpersTest internal helper;
    Fenix internal fenix;
    XENCrypto internal xenCrypto;

    address internal bob = address(this);

    address[] internal stakers;

    /// ============ Setup test suite ============

    function setUp() public {
        helper = new HelpersTest();
        xenCrypto = new XENCrypto();

        stakers.push(bob);

        helper.generateXENFor(stakers, xenCrypto);
        fenix = new Fenix();
    }

    /// @notice Test that the contract can be deployed successfully
    function testXENBurn() public {
        address fenixAddr = address(fenix);
        uint256 balancePreBurn = xenCrypto.balanceOf(bob);

        assertEq(balancePreBurn, 3300 * 1e18);

        xenCrypto.approve(fenixAddr, balancePreBurn);

        fenix.burnXEN(balancePreBurn);

        uint256 balancePostBurnXEN = xenCrypto.balanceOf(bob);
        uint256 balancePostBurnFENIX = fenix.balanceOf(bob);

        assertEq(balancePostBurnXEN, 0);
        assertEq(balancePostBurnFENIX, 3300 * 1e18);
    }
}
