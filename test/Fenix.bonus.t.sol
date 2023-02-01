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
        uint256 bobFenix = 853000000000000000;
        uint256 bobTerm = 100;

        uint256 bobBonus = fenix.calculateBonus(bobFenix, bobTerm);
        assertEq(bobBonus, 981990406243742714);

        uint256 aliceFenix = 766200000000000000;
        uint256 aliceTerm = 200;

        uint256 aliciaBonus = fenix.calculateBonus(aliceFenix, aliceTerm);
        assertEq(aliciaBonus, 923319165593745083);
    }

    /// @notice Test calculating size bonus
    function testCalculateSizeBonus() public {
        uint256 burn0ASH = 0;
        assertEq(fenix.calculateSizeBonus(burn0ASH), 0); // verify

        uint256 burn1ASH = 1;
        assertEq(fenix.calculateSizeBonus(burn1ASH), 0); // verify

        uint256 burn2FENIX = 2 * 1e18;
        assertEq(fenix.calculateSizeBonus(burn2FENIX), 200000000000000000); // verify

        uint256 burn3FENIX = 3 * 1e18;
        assertEq(fenix.calculateSizeBonus(burn3FENIX), 300000000000000000); // verify

        uint256 burnTrillionFENIX = 1_000_000_000_000 * 1e18;
        assertEq(fenix.calculateSizeBonus(burnTrillionFENIX), 100000000000 * 1e18); // verify

        uint256 burnUINTMax = UINT256_MAX;
        assertEq(
            fenix.calculateSizeBonus(burnUINTMax),
            11579208923731619542357098500868790785326998466564056403945758400791312963993
        ); // verify
    }

    /// @notice Test calculating time bonus
    function testCalculateTimeBonus() public {
        uint256 base = 100 * 1e18;
        uint256 oneYearTerm = 365;
        uint256 oneYearBonus = fenix.calculateTimeBonus(base, oneYearTerm);

        assertEq(oneYearBonus, 120_000000000000000000); // verify

        uint256 twoYearTerm = 365 * 2;
        uint256 twoYearBonus = fenix.calculateTimeBonus(base, twoYearTerm);
        assertEq(twoYearBonus, 143_999999999999997600); // verify

        uint256 tenYearTerm = 365 * 10;
        uint256 tenYearBonus = fenix.calculateTimeBonus(base, tenYearTerm);
        assertEq(tenYearBonus, 619_173642239999950200); // verify

        uint256 fiftyYearTerm = 365 * 55;
        uint256 fiftyYearBonus = fenix.calculateTimeBonus(base, fiftyYearTerm);
        assertEq(fiftyYearBonus, 2264480_225741333932466600); // verify
    }
}
