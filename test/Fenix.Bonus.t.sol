// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { Fenix, Stake } from "@atomize/Fenix.sol";
import { XENCrypto } from "xen-crypto/XENCrypto.sol";
import { HelpersTest } from "./Helpers.t.sol";

contract BonusTest is Test {
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

    /// @notice Test time bonus calculation
    function testTimeBonus() public {
        uint256 base = 100;
        uint256 oneYearTerm = 365;
        uint256 oneYearBonus = fenix.calculateTimeBonus(base, oneYearTerm);

        assertEq(oneYearBonus, 120_000000000000000000);

        uint256 twoYearTerm = 365 * 2;
        uint256 twoYearBonus = fenix.calculateTimeBonus(base, twoYearTerm);
        assertEq(twoYearBonus, 143_999999999999997600);

        uint256 tenYearTerm = 365 * 10;
        uint256 tenYearBonus = fenix.calculateTimeBonus(base, tenYearTerm);
        assertEq(tenYearBonus, 619_173642239999950200);

        uint256 fiftyYearTerm = 365 * 50;
        uint256 fiftyYearBonus = fenix.calculateTimeBonus(base, fiftyYearTerm);
        assertEq(fiftyYearBonus, 910043_815000214611982800);
    }
}
