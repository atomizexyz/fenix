// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {Blau, Stake} from "src/Blau.sol";

contract BlauTest is Test {
    Blau internal BLAU;

    /// ============ Setup test suite ============

    function setUp() public {
        BLAU = new Blau();
    }

    /// @notice Test that the contract can be deployed successfully
    function testMetadata() public {
        assertEq(BLAU.name(), "BLAU");
        assertEq(BLAU.symbol(), "BLAU");
        assertEq(BLAU.decimals(), 18);
        assertEq(BLAU.totalSupply(), 0);
    }

    /// @notice Test function that caluclates base amount from burn
    function testCalculateBase() public {
        uint256 burn1xen = 1e18;
        uint256 ln1xen = BLAU.calculateBase(burn1xen);
        assertEq(ln1xen, 0); // verify ln(1) = 0

        uint256 burn10xen = 1e19;
        uint256 ln10xen = BLAU.calculateBase(burn10xen);
        assertEq(ln10xen, 2302585092994045674000000000000000000); // verify ln(10)

        uint256 burn100xen = 1e20;
        uint256 ln100xen = BLAU.calculateBase(burn100xen);
        assertEq(ln100xen, 4605170185988091359000000000000000000); // verify ln(100)
    }

    /// @notice Test calculating size bonus
    function testCalculateSizeBonus() public {
        uint256 burn1xen = 1 * 1e18;
        uint256 bonus1Xen = BLAU.calculateBonus(burn1xen, 1);
        assertEq(bonus1Xen, 0); // verify 1 xen stake no bonus

        uint256 burn2xen = 2 * 1e18;
        uint256 bonus2Xen = BLAU.calculateBonus(burn2xen, 1);
        assertEq(bonus2Xen, 380850099208802238809962102366776); // verify 2 xen stake bonus

        uint256 burn3xen = 3 * 1e18;
        uint256 bonus3Xen = BLAU.calculateBonus(burn3xen, 1);
        assertEq(bonus3Xen, 603633125641860046074007004026814); // verify 2 xen stake bonus
    }

    /// @notice Test calculating time bonus
    function testCalculateTimeBonus() public {
        uint256 burnxen = 3 * 1e18;
        uint256 bonus356Days = BLAU.calculateBonus(burnxen, 365);
        assertEq(bonus356Days, 220326090859263796046074007004026814); // verify 1 xen stake no bonus

        uint256 bonus3560Days = BLAU.calculateBonus(burnxen, 3650);
        assertEq(bonus3560Days, 2203260908592637586595524556454576265); // verify 2 xen stake bonus

        uint256 bonus35600Days = BLAU.calculateBonus(burnxen, 36500);
        assertEq(bonus35600Days, 22032609085926375492090030050960070770); // verify 2 xen stake bonus
    }

    /// @notice Test share rate update
    function testShareReateUpdate() public {
        uint256 base = 13.81551 * 1e18;
        uint256 bonus = 2.77069 * 1e18;
        Stake memory stake1 = Stake(0, 1, base, bonus);

        assertEq(BLAU.shareRate(), 1000000000000000000); // verify initial share rate

        BLAU._updateEquity(stake1);
        assertEq(BLAU.shareRate(), 1200549237776962269); // verify 20% gain
    }

    /// @notice Test stake penality
    function testCalculateEarlyPenalty() public {
        uint256 base = 13.81551 * 1e18;
        uint256 bonus = 2.77069 * 1e18;

        uint256 timestamp = block.timestamp;
        Stake memory stake1 = Stake(timestamp, 100, base, bonus);

        vm.warp(timestamp + (86400 * 0));
        uint256 penalty0 = BLAU._calculateEarlyPenalty(stake1);
        assertEq(penalty0, 0); // verify 0% complete 0% return

        vm.warp(timestamp + (86400 * 25));
        uint256 penalty25 = BLAU._calculateEarlyPenalty(stake1);
        assertEq(penalty25, 1036637500000000000); // verify 25% complete 6.25% return

        vm.warp(timestamp + (86400 * 50));
        uint256 penalty50 = BLAU._calculateEarlyPenalty(stake1);
        assertEq(penalty50, 4146550000000000000); // verify 50% complete 25% return

        vm.warp(timestamp + (86400 * 75));
        uint256 penalty75 = BLAU._calculateEarlyPenalty(stake1);
        assertEq(penalty75, 9329737500000000000); // verify 75% complete 56.25% return

        vm.warp(timestamp + (86400 * 100));
        uint256 penalty100 = BLAU._calculateEarlyPenalty(stake1);
        assertEq(penalty100, 16586200000000000000); // verify 100% complete 100% return
    }

    function testCalculateLatePenalty() public {
        uint256 base = 13.81551 * 1e18;
        uint256 bonus = 2.77069 * 1e18;

        uint256 timestamp = block.timestamp;
        Stake memory stake1 = Stake(timestamp, 100, base, bonus);

        vm.warp(timestamp + (86400 * 128));
        uint256 penalty0 = BLAU._calculateLatePenalty(stake1);
        assertEq(penalty0, 16586200000000000000); // verify 0% complete 0% return

        uint256 FIFTY_WEEKS = 7 * 50;
        vm.warp(timestamp + (86400 * (128 + FIFTY_WEEKS)));
        uint256 penalty50 = BLAU._calculateLatePenalty(stake1);
        assertEq(penalty50, 8293100000000000000); // verify 0% complete 0% return

        uint256 ONE_HUNDRED_WEEKS = 7 * 100;
        vm.warp(timestamp + (86400 * (128 + ONE_HUNDRED_WEEKS)));
        uint256 penalty100 = BLAU._calculateLatePenalty(stake1);
        assertEq(penalty100, 0); // verify 0% complete 0% return
    }
}
