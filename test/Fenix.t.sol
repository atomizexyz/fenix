// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { Fenix, Stake } from "src/Fenix.sol";
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

    /// @notice Test function that caluclates base amount from burn
    function testCalculateBase() public {
        uint256 burn1xen = 1e18;
        uint256 ln1xen = fenix.calculateBase(burn1xen);
        assertEq(ln1xen, 1000000000000000000); // verify

        uint256 burn10xen = 1e19;
        uint256 ln10xen = fenix.calculateBase(burn10xen);
        assertEq(ln10xen, 10000000000000000000); // verify

        uint256 burn100xen = 1e20;
        uint256 ln100xen = fenix.calculateBase(burn100xen);
        assertEq(ln100xen, 100000000000000000000); // verify
    }

    /// @notice Test calculating size bonus
    function testCalculateSizeBonus() public {
        uint256 burn1xen = 1 * 1e18;
        uint256 bonus1Xen = fenix.calculateBonus(burn1xen, 1);
        assertEq(bonus1Xen, 48472527472527472527); // verify

        uint256 burn2xen = 2 * 1e18;
        uint256 bonus2Xen = fenix.calculateBonus(burn2xen, 1);
        assertEq(bonus2Xen, 96945054945054945054); // verify

        uint256 burn3xen = 3 * 1e18;
        uint256 bonus3Xen = fenix.calculateBonus(burn3xen, 1);
        assertEq(bonus3Xen, 145417582417582417582); // verify
    }

    /// @notice Test calculating time bonus
    function testCalculateTimeBonus() public {
        uint256 burnxen = 3 * 1e18;
        uint256 bonus356Days = fenix.calculateBonus(burnxen, 365);
        assertEq(bonus356Days, 51985417582417582417582); // verify

        uint256 bonus3560Days = fenix.calculateBonus(burnxen, 3650);
        assertEq(bonus3560Days, 519827175824175824175824); // verify

        uint256 bonus35600Days = fenix.calculateBonus(burnxen, 36500);
        assertEq(bonus35600Days, 5198244758241758241758241); // verify
    }

    /// @notice Test share rate update
    function testShareReateUpdate() public {
        uint256 base = 13.81551 * 1e18;
        uint256 bonus = 2.77069 * 1e18;
        Stake memory stake1 = Stake(0, 1, 1, base, bonus, base + bonus);

        assertEq(fenix.shareRate(), 1000000000000000000); // verify

        fenix.updateShare(stake1);
        assertEq(fenix.shareRate(), 1200549237776962269); // verify
    }

    /// @notice Test stake penality
    function testCalculateEarlyPenalty() public {
        uint256 base = 13.81551 * 1e18;
        uint256 bonus = 2.77069 * 1e18;

        uint256 timestamp = block.timestamp;
        Stake memory stake1 = Stake(timestamp, 1, 100, base, bonus, base + bonus);

        vm.warp(timestamp + (86400 * 0));
        uint256 penalty0 = fenix.calculateEarlyPenalty(stake1);
        assertEq(penalty0, 1000000000000000000); // verify 100% penalty

        vm.warp(timestamp + (86400 * 25));
        uint256 penalty25 = fenix.calculateEarlyPenalty(stake1);
        assertEq(penalty25, 937500000000000000); // verify 94% penalty

        vm.warp(timestamp + (86400 * 50));
        uint256 penalty50 = fenix.calculateEarlyPenalty(stake1);
        assertEq(penalty50, 750000000000000000); // verify 75% penalty

        vm.warp(timestamp + (86400 * 75));
        uint256 penalty75 = fenix.calculateEarlyPenalty(stake1);
        assertEq(penalty75, 437500000000000000); // verify 43% penalty

        vm.warp(timestamp + (86400 * 100));
        uint256 penalty100 = fenix.calculateEarlyPenalty(stake1);
        assertEq(penalty100, 0); // verify 0% penalty
    }

    function testCalculateLatePenalty() public {
        uint256 base = 13.81551 * 1e18;
        uint256 bonus = 2.77069 * 1e18;
        uint256 baseTerm = 100;

        uint256 timestamp = block.timestamp;
        Stake memory stake1 = Stake(timestamp, 1, baseTerm, base, bonus, base + bonus);

        vm.warp(timestamp + (86400 * baseTerm));
        uint256 penalty0 = fenix.calculateLatePenalty(stake1);
        assertEq(penalty0, 0); // verify 0% penalty

        vm.warp(timestamp + (86400 * (baseTerm + 90)));
        uint256 penalty50 = fenix.calculateLatePenalty(stake1);
        assertEq(penalty50, 125000000000000000); // verify 12.5% penality

        vm.warp(timestamp + (86400 * (baseTerm + 180)));
        uint256 penalty100 = fenix.calculateLatePenalty(stake1);
        assertEq(penalty100, 1000000000000000000); // verify 100% penalty

        vm.warp(timestamp + (86400 * (baseTerm + 360)));
        uint256 penalty200 = fenix.calculateLatePenalty(stake1);
        assertEq(penalty200, 1000000000000000000); // verify 100% penalty
    }
}
