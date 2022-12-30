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

    function testCalculateBaseBonus() public {
        uint256 burn1ASH = 1;
        uint256 baseBonus1ASH = fenix.calculateBaseBonus(burn1ASH);
        assertEq(baseBonus1ASH, 0); // verify

        uint256 burn1FENIX = 1 * 1e18;
        uint256 baseBonus1FENIX = fenix.calculateBaseBonus(burn1FENIX);
        assertEq(baseBonus1FENIX, 41_446531673892822311); // verify

        uint256 burn2FENIX = 2 * 1e18;
        uint256 baseBonus2FENIX = fenix.calculateBaseBonus(burn2FENIX);
        assertEq(baseBonus2FENIX, 42_139678854452767620); // verify

        uint256 burnTrillionFENIX = 1_000_000_000_000 * 1e18;
        uint256 baseBonusTrillionFENIX = fenix.calculateBaseBonus(burnTrillionFENIX);
        assertEq(baseBonusTrillionFENIX, 69_077552789821370529); // verify
    }

    /// @notice Test calculating size bonus
    function testCalculateSizeBonus() public {
        uint256 base1FENIX = 0;
        uint256 sizeBonus1FENIX = fenix.calculateSizeBonus(base1FENIX);
        assertEq(sizeBonus1FENIX, 0); // verify

        uint256 base2FENIX = 42_139678854452767620;
        uint256 sizeBonus2FENIX = fenix.calculateSizeBonus(base2FENIX);
        assertEq(sizeBonus2FENIX, 4_213967885445276762); // verify

        uint256 base3FENIX = 42_545143962560932004;
        uint256 sizeBonus3FENIX = fenix.calculateSizeBonus(base3FENIX);
        assertEq(sizeBonus3FENIX, 4_254514396256093200); // verify

        uint256 base4FENIX = 69_077552789821370529;
        uint256 sizeBonus4FENIX = fenix.calculateSizeBonus(base4FENIX);
        assertEq(sizeBonus4FENIX, 6_907755278982137052); // verify
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

        uint256 fiftyYearTerm = 365 * 50;
        uint256 fiftyYearBonus = fenix.calculateTimeBonus(base, fiftyYearTerm);
        assertEq(fiftyYearBonus, 910043_815000214611982800); // verify
    }
}
