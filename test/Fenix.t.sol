// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { Fenix, Stake } from "src/Fenix.sol";
import { XENCrypto } from "xen-crypto/XENCrypto.sol";

contract FenixTest is Test {
    Fenix internal fenix;
    XENCrypto internal xenCrypto;

    /// ============ Setup test suite ============

    function setUp() public {
        xenCrypto = new XENCrypto();
        address xenAddress = address(xenCrypto);
        _generateXEN();
        fenix = new Fenix(xenAddress);
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
        assertEq(ln1xen, 0); // verify ln(1) = 0

        uint256 burn10xen = 1e19;
        uint256 ln10xen = fenix.calculateBase(burn10xen);
        assertEq(ln10xen, 2302585092994045674000000000000000000); // verify ln(10)

        uint256 burn100xen = 1e20;
        uint256 ln100xen = fenix.calculateBase(burn100xen);
        assertEq(ln100xen, 4605170185988091359000000000000000000); // verify ln(100)
    }

    /// @notice Test calculating size bonus
    function testCalculateSizeBonus() public {
        uint256 burn1xen = 1 * 1e18;
        uint256 bonus1Xen = fenix.calculateBonus(burn1xen, 1);
        assertEq(bonus1Xen, 0); // verify 1 xen stake no bonus

        uint256 burn2xen = 2 * 1e18;
        uint256 bonus2Xen = fenix.calculateBonus(burn2xen, 1);
        assertEq(bonus2Xen, 380850099208802238809962102366776); // verify 2 xen stake bonus

        uint256 burn3xen = 3 * 1e18;
        uint256 bonus3Xen = fenix.calculateBonus(burn3xen, 1);
        assertEq(bonus3Xen, 603633125641860046074007004026814); // verify 2 xen stake bonus
    }

    /// @notice Test calculating time bonus
    function testCalculateTimeBonus() public {
        uint256 burnxen = 3 * 1e18;
        uint256 bonus356Days = fenix.calculateBonus(burnxen, 365);
        assertEq(bonus356Days, 220326090859263796046074007004026814); // verify 1 xen stake no bonus

        uint256 bonus3560Days = fenix.calculateBonus(burnxen, 3650);
        assertEq(bonus3560Days, 2203260908592637586595524556454576265); // verify 2 xen stake bonus

        uint256 bonus35600Days = fenix.calculateBonus(burnxen, 36500);
        assertEq(bonus35600Days, 22032609085926375492090030050960070770); // verify 2 xen stake bonus
    }

    /// @notice Test share rate update
    function testShareReateUpdate() public {
        uint256 base = 13.81551 * 1e18;
        uint256 bonus = 2.77069 * 1e18;
        Stake memory stake1 = Stake(0, 1, 1, base, bonus, base + bonus);

        assertEq(fenix.shareRate(), 1000000000000000000); // verify initial share rate

        fenix.updateEquity(stake1);
        assertEq(fenix.shareRate(), 1200549237776962269); // verify 20% gain
    }

    /// @notice Test calculate payout
    function testCalculatePayout() public {
        uint256 base = 13.81551 * 1e18;
        uint256 bonus = 2.77069 * 1e18;
        uint256 timestamp = block.timestamp;

        Stake memory stake1 = Stake(uint40(timestamp), 1, 1, base, bonus, base + bonus);

        vm.warp(timestamp + (86400 * 1));
        uint256 payout = fenix.calculatePayout(stake1);
        assertEq(payout, 16586200000000000000); // verify max payout
    }

    /// @notice Test stake penality
    function testCalculateEarlyPenalty() public {
        uint256 base = 13.81551 * 1e18;
        uint256 bonus = 2.77069 * 1e18;

        uint256 timestamp = block.timestamp;
        Stake memory stake1 = Stake(uint40(timestamp), 1, 100, base, bonus, base + bonus);

        vm.warp(timestamp + (86400 * 0));
        uint256 penalty0 = fenix.calculateEarlyPenalty(stake1);
        assertEq(penalty0, 0); // verify 0% complete 0% return

        vm.warp(timestamp + (86400 * 25));
        uint256 penalty25 = fenix.calculateEarlyPenalty(stake1);
        assertEq(penalty25, 1036637500000000000); // verify 25% complete 6.25% return

        vm.warp(timestamp + (86400 * 50));
        uint256 penalty50 = fenix.calculateEarlyPenalty(stake1);
        assertEq(penalty50, 4146550000000000000); // verify 50% complete 25% return

        vm.warp(timestamp + (86400 * 75));
        uint256 penalty75 = fenix.calculateEarlyPenalty(stake1);
        assertEq(penalty75, 9329737500000000000); // verify 75% complete 56.25% return

        vm.warp(timestamp + (86400 * 100));
        uint256 penalty100 = fenix.calculateEarlyPenalty(stake1);
        assertEq(penalty100, 16586200000000000000); // verify 100% complete 100% return
    }

    function testCalculateLatePenalty() public {
        uint256 base = 13.81551 * 1e18;
        uint256 bonus = 2.77069 * 1e18;
        uint256 baseTerm = 100;

        uint256 timestamp = block.timestamp;
        Stake memory stake1 = Stake(uint40(timestamp), 1, baseTerm, base, bonus, base + bonus);

        vm.warp(timestamp + (86400 * baseTerm));
        uint256 penalty0 = fenix.calculateLatePenalty(stake1);
        assertEq(penalty0, 0); // verify end day 0, 0% penality

        vm.warp(timestamp + (86400 * (baseTerm + 90)));
        uint256 penalty50 = fenix.calculateLatePenalty(stake1);
        assertEq(penalty50, 125000000000000000); // end day 90, 12.5% penality

        vm.warp(timestamp + (86400 * (baseTerm + 180)));
        uint256 penalty100 = fenix.calculateLatePenalty(stake1);
        assertEq(penalty100, 1000000000000000000); // verify end day 180, 100% penalty

        vm.warp(timestamp + (86400 * (baseTerm + 360)));
        uint256 penalty200 = fenix.calculateLatePenalty(stake1);
        assertEq(penalty200, 1000000000000000000); // verify end day 360, 100% penalty
    }

    /// Helpers
    function _generateXEN() public {
        uint256 timestamp = block.timestamp;
        xenCrypto.claimRank(1);
        vm.warp(timestamp + (86400 * 1) + 1);
        xenCrypto.claimMintReward();
    }
}
