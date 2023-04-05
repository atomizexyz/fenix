// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { Fenix, FenixError } from "@atomize/Fenix.sol";
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
    function test_CalcualteBonus() public {
        uint256 amount = 1e18;
        uint256 term = 100;

        uint256 bonus = fenix.calculateBonus(amount, term);
        assertEq(bonus, 0, "no bonus for amounts less or equal to 1");
    }

    /// @notice Test calculating large bonus
    function test_CalculateBonusLarge() public {
        uint256 amount = 100_000_000e18;
        uint256 term = 100;

        uint256 bonus = fenix.calculateBonus(amount, term);
        assertEq(bonus, 2_753977704008406161);
    }

    /// @notice Test calculating
    function test_CalculateBonusLessThanOne() public {
        uint256 amount = 1e17;
        uint256 term = 100;

        uint256 bonus = fenix.calculateBonus(amount, term);
        assertEq(bonus, 0, "no bonus for amounts less or equal to 1");
    }

    /// @notice Test that size bonus will always return value greater than or equal to zero
    function testFuzz_CalculateSizeBonus(uint256 fuzzFenix) public {
        uint256 bonus = fenix.calculateSizeBonus(fuzzFenix);
        assertGe(bonus, 0); // verify
    }

    /// @notice Test that time bonus will always return greater than zero
    function testFuzz_CalculateTimeBonus(uint256 fuzzTerm) public {
        if (fuzzTerm > fenix.MAX_STAKE_LENGTH_DAYS()) {
            vm.expectRevert(FenixError.TermGreaterThanMax.selector); // verify
        }
        uint256 bonus = fenix.calculateTimeBonus(fuzzTerm);
        assertGe(bonus, 0); // verify
    }
}
