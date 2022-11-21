// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { Fenix, Stake } from "src/Fenix.sol";
import { XENCrypto } from "xen-crypto/XENCrypto.sol";

contract FenixTest is Test {
    Fenix internal FENIX;
    XENCrypto internal XENCRYPTO;

    /// ============ Setup test suite ============

    function setUp() public {
        FENIX = new Fenix();
        XENCRYPTO = new XENCrypto();
    }

    /// @notice Test that the contract can be deployed successfully
    function testMetadata() public {
        assertEq(FENIX.name(), "FENIX");
        assertEq(FENIX.symbol(), "FENIX");
        assertEq(FENIX.decimals(), 18);
        assertEq(FENIX.totalSupply(), 0);
    }

    /// @notice Test function that caluclates base amount from burn
    function testCalculateBase() public {
        uint256 burn1xen = 1e18;
        uint256 ln1xen = FENIX.calculateBase(burn1xen);
        assertEq(ln1xen, 0); // verify ln(1) = 0

        uint256 burn10xen = 1e19;
        uint256 ln10xen = FENIX.calculateBase(burn10xen);
        assertEq(ln10xen, 2302585092994045674000000000000000000); // verify ln(10)

        uint256 burn100xen = 1e20;
        uint256 ln100xen = FENIX.calculateBase(burn100xen);
        assertEq(ln100xen, 4605170185988091359000000000000000000); // verify ln(100)
    }

    /// @notice Test calculating size bonus
    function testCalculateSizeBonus() public {
        uint256 burn1xen = 1 * 1e18;
        uint256 bonus1Xen = FENIX.calculateBonus(burn1xen, 1);
        assertEq(bonus1Xen, 0); // verify 1 xen stake no bonus

        uint256 burn2xen = 2 * 1e18;
        uint256 bonus2Xen = FENIX.calculateBonus(burn2xen, 1);
        assertEq(bonus2Xen, 380850099208802238809962102366776); // verify 2 xen stake bonus

        uint256 burn3xen = 3 * 1e18;
        uint256 bonus3Xen = FENIX.calculateBonus(burn3xen, 1);
        assertEq(bonus3Xen, 603633125641860046074007004026814); // verify 2 xen stake bonus
    }

    /// @notice Test calculating time bonus
    function testCalculateTimeBonus() public {
        uint256 burnxen = 3 * 1e18;
        uint256 bonus356Days = FENIX.calculateBonus(burnxen, 365);
        assertEq(bonus356Days, 220326090859263796046074007004026814); // verify 1 xen stake no bonus

        uint256 bonus3560Days = FENIX.calculateBonus(burnxen, 3650);
        assertEq(bonus3560Days, 2203260908592637586595524556454576265); // verify 2 xen stake bonus

        uint256 bonus35600Days = FENIX.calculateBonus(burnxen, 36500);
        assertEq(bonus35600Days, 22032609085926375492090030050960070770); // verify 2 xen stake bonus
    }

    /// @notice Test share rate update
    function testShareReateUpdate() public {
        uint256 base = 13.81551 * 1e18;
        uint256 bonus = 2.77069 * 1e18;
        Stake memory stake1 = Stake(1, 0, 1, base, bonus);

        assertEq(FENIX.shareRate(), 1000000000000000000); // verify initial share rate

        FENIX.updateEquity(stake1);
        assertEq(FENIX.shareRate(), 1200549237776962269); // verify 20% gain
    }

    /// @notice Test calculate payout
    function testCalculatePayout() public {
        uint256 base = 13.81551 * 1e18;
        uint256 bonus = 2.77069 * 1e18;
        uint256 timestamp = block.timestamp;

        Stake memory stake1 = Stake(1, timestamp, 1, base, bonus);

        vm.warp(timestamp + (86400 * 1));
        uint256 payout = FENIX.calculatePayout(stake1);
        assertEq(payout, 16586200000000000000); // verify max payout
    }

    /// @notice Test stake penality
    function testCalculateEarlyPenalty() public {
        uint256 base = 13.81551 * 1e18;
        uint256 bonus = 2.77069 * 1e18;

        uint256 timestamp = block.timestamp;
        Stake memory stake1 = Stake(1, timestamp, 100, base, bonus);

        vm.warp(timestamp + (86400 * 0));
        uint256 penalty0 = FENIX.calculateEarlyPenalty(stake1);
        assertEq(penalty0, 0); // verify 0% complete 0% return

        vm.warp(timestamp + (86400 * 25));
        uint256 penalty25 = FENIX.calculateEarlyPenalty(stake1);
        assertEq(penalty25, 1036637500000000000); // verify 25% complete 6.25% return

        vm.warp(timestamp + (86400 * 50));
        uint256 penalty50 = FENIX.calculateEarlyPenalty(stake1);
        assertEq(penalty50, 4146550000000000000); // verify 50% complete 25% return

        vm.warp(timestamp + (86400 * 75));
        uint256 penalty75 = FENIX.calculateEarlyPenalty(stake1);
        assertEq(penalty75, 9329737500000000000); // verify 75% complete 56.25% return

        vm.warp(timestamp + (86400 * 100));
        uint256 penalty100 = FENIX.calculateEarlyPenalty(stake1);
        assertEq(penalty100, 16586200000000000000); // verify 100% complete 100% return
    }

    function testCalculateLatePenalty() public {
        uint256 base = 13.81551 * 1e18;
        uint256 bonus = 2.77069 * 1e18;
        uint256 baseTerm = 100;

        uint256 timestamp = block.timestamp;
        Stake memory stake1 = Stake(1, timestamp, baseTerm, base, bonus);

        vm.warp(timestamp + (86400 * baseTerm));
        uint256 penalty0 = FENIX.calculateLatePenalty(stake1);
        assertEq(penalty0, 0); // verify end day 0, 0% penality

        vm.warp(timestamp + (86400 * (baseTerm + 90)));
        uint256 penalty50 = FENIX.calculateLatePenalty(stake1);
        assertEq(penalty50, 125000000000000000); // end day 90, 12.5% penality

        vm.warp(timestamp + (86400 * (baseTerm + 180)));
        uint256 penalty100 = FENIX.calculateLatePenalty(stake1);
        assertEq(penalty100, 1000000000000000000); // verify end day 180, 100% penalty

        vm.warp(timestamp + (86400 * (baseTerm + 360)));
        uint256 penalty200 = FENIX.calculateLatePenalty(stake1);
        assertEq(penalty200, 1000000000000000000); // verify end day 360, 100% penalty
    }

    function testXENBurn() public {
        address userAddr = address(this);
        address xenAddr = address(XENCRYPTO);
        address fenixAddr = address(FENIX);
        uint256 timestamp = block.timestamp;
        XENCRYPTO.claimRank(1);
        vm.warp(timestamp + (86400 * 1) + 1);
        XENCRYPTO.claimMintReward();
        uint256 balancePreBurn = XENCRYPTO.balanceOf(userAddr);

        console.log(userAddr, balancePreBurn, xenAddr);

        assertEq(balancePreBurn, 3300 * 1e18);

        XENCRYPTO.approve(fenixAddr, balancePreBurn);

        FENIX.burnXEN(balancePreBurn, xenAddr);

        uint256 balancePostBurnXEN = XENCRYPTO.balanceOf(userAddr);
        uint256 balancePostBurnFENIX = FENIX.balanceOf(userAddr);

        assertEq(balancePostBurnXEN, 0);
        assertEq(balancePostBurnFENIX, 3300 * 1e18);
    }

    function testBigBonus() public {
        address xenAddr = address(XENCRYPTO);
        uint256 timestamp = block.timestamp;
        XENCRYPTO.claimRank(1);
        vm.warp(timestamp + (86400 * 1) + 1);
        XENCRYPTO.claimMintReward();

        FENIX.bigBonus(xenAddr);

        assertEq(FENIX.poolSize(), 3300000000000000000000);
    }
}
