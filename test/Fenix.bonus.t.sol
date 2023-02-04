// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { Fenix } from "@atomize/Fenix.sol";
import { XENCrypto } from "xen-crypto/XENCrypto.sol";
import { HelpersTest } from "./Helpers.t.sol";

contract BonusTest is Test {
    HelpersTest internal helper;
    Fenix internal fenix;
    XENCrypto internal xenCrypto;

    /// ============ Setup test suite ============

    function setUp() public {
        helper = new HelpersTest();

        vm.broadcast(helper.xenDeployerPrivateKey());
        xenCrypto = new XENCrypto();

        fenix = new Fenix();
    }

    /// @notice Test calculating bonus
    function testCalcualteBonus() public {
        uint256 amount = 1e18;
        uint256 term = 100;

        uint256 bonus = fenix.calculateBonus(amount, term);
        assertEq(bonus, 1065581458495049408);
    }

    /// @notice Test calculating large bonus
    function testCalculateBonusLarge() public {
        uint256 amount = 100_000_000e18;
        uint256 term = 100;

        uint256 bonus = fenix.calculateBonus(amount, term);
        assertEq(bonus, 117764963_759171172000000000);
    }

    /// @notice Test calculating
    function testCalculateBonusLtOne() public {
        uint256 amount = 1e17;
        uint256 term = 100;

        uint256 bonus = fenix.calculateBonus(amount, term);
        assertEq(bonus, 106558145849504940);
    }
}
