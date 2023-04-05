// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { Fenix, Stake, Status, FenixError } from "@atomize/Fenix.sol";
import { XENCrypto } from "xen-crypto/XENCrypto.sol";
import { HelpersTest } from "./Helpers.t.sol";

contract FenixPayoutTest is Test {
    HelpersTest internal helper;
    Fenix internal fenix;
    XENCrypto internal xenCrypto;

    address internal bob = address(this);

    address[] internal stakers;
    uint256 internal tenKXen = 100_000e18;
    uint256 baseTerm = 100;
    uint40 calcBlockTs;
    uint40 endBlockTs;

    /// ============ Setup test suite ============

    function setUp() public {
        helper = new HelpersTest();
        vm.broadcast(helper.xenDeployerPrivateKey());
        xenCrypto = new XENCrypto();

        fenix = new Fenix();

        stakers.push(bob);

        helper.batchDealTo(stakers, tenKXen, address(xenCrypto));
        helper.getFenixFor(stakers, fenix, xenCrypto);

        calcBlockTs = uint40(block.timestamp + (86400 * 10));
        endBlockTs = uint40(calcBlockTs + (86400 * baseTerm));
    }

    /// @notice Test stake payout
    function test_CalculateEarlyPayout() public {
        uint256 amount = 21e18;

        uint256 shares = fenix.calculateBonus(amount, 356);

        uint40 blockTs = uint40(block.timestamp);
        uint40 endTs = uint40(blockTs + (86400 * baseTerm));

        Stake memory stake1 = Stake(Status.ACTIVE, blockTs, 0, endTs, uint16(baseTerm), amount, shares, 0);

        vm.warp(blockTs + (86400 * 0));
        uint256 reward0 = fenix.calculateEarlyPayout(stake1);
        assertEq(reward0, 0); // verify 0% reward

        vm.warp(blockTs + (86400 * 25));
        uint256 reward25 = fenix.calculateEarlyPayout(stake1);
        assertEq(reward25, 62500000000000000); // verify 6.25% reward

        vm.warp(blockTs + (86400 * 50));
        uint256 reward50 = fenix.calculateEarlyPayout(stake1);
        assertEq(reward50, 250000000000000000); // verify 25% reward

        vm.warp(blockTs + (86400 * 75));
        uint256 reward75 = fenix.calculateEarlyPayout(stake1);
        assertEq(reward75, 562500000000000000); // verify 56% reward

        vm.warp(blockTs + (86400 * 100));
        uint256 reward100 = fenix.calculateEarlyPayout(stake1);
        assertEq(reward100, 1000000000000000000); // verify 100% reward
    }

    function test_CalculateLatePayout() public {
        uint256 FENIX = 20_000e18;
        uint256 bonus = fenix.calculateBonus(FENIX, baseTerm);
        uint256 shares = fenix.calculateShares(bonus);

        uint40 blockTs = uint40(block.timestamp);
        uint40 endTs = uint40(blockTs + (86400 * baseTerm));

        Stake memory stake1 = Stake(Status.ACTIVE, blockTs, 0, endTs, uint16(baseTerm), FENIX, shares, 0);

        vm.warp(blockTs + (86400 * baseTerm));
        uint256 reward0 = fenix.calculateLatePayout(stake1);
        assertEq(reward0, 1000000000000000000); // verify 100% reward

        vm.warp(blockTs + (86400 * (baseTerm + 90)));
        uint256 reward50 = fenix.calculateLatePayout(stake1);
        assertEq(reward50, 875000000000000000); // verify 87.5% reward

        vm.warp(blockTs + (86400 * (baseTerm + 143)));
        uint256 reward143 = fenix.calculateLatePayout(stake1);
        assertEq(reward143, 498592764060356655); // verify 50% reward

        vm.warp(blockTs + (86400 * (baseTerm + 180)));
        uint256 reward100 = fenix.calculateLatePayout(stake1);
        assertEq(reward100, 0); // verify 0% reward

        vm.warp(blockTs + (86400 * (baseTerm + 360)));
        uint256 reward200 = fenix.calculateLatePayout(stake1);
        assertEq(reward200, 0); // verify 0% reward
    }

    /// ---------- EARLY PAYOUT ----------

    /// @notice Test the calculateEarlyPayout function when the stake is active and the calculation block is before the term
    function test_CalculateEarlyPayout_Active_BeforeTs_RevertWhen_StakeNotActive() public {
        Stake memory stake1 = Stake(Status.ACTIVE, calcBlockTs, 0, endBlockTs, uint16(baseTerm), 100, 100, 0);
        vm.warp(calcBlockTs - 1);
        vm.expectRevert(FenixError.StakeNotActive.selector); // verify
        fenix.calculateEarlyPayout(stake1);
    }

    /// @notice Test the calculateEarlyPayout function when the stake is active and the calculation block is during the term
    function test_CalculateEarlyPayout_Active_DuringTs() public {
        Stake memory stake1 = Stake(Status.ACTIVE, calcBlockTs, 0, endBlockTs, uint16(baseTerm), 100, 100, 0);
        vm.warp(calcBlockTs + 1);
        uint256 payout = fenix.calculateEarlyPayout(stake1);
        assertEq(payout, 13395); // verify
    }

    /// @notice Test the calculateEarlyPayout function when the stake is active and the calculation block is after the term
    function test_CalculateEarlyPayout_Active_AfterTs_RevertWhen_StakeLate() public {
        Stake memory stake1 = Stake(Status.ACTIVE, calcBlockTs, 0, endBlockTs, uint16(baseTerm), 100, 100, 0);
        vm.warp(calcBlockTs + (86400 * baseTerm) + 1);
        vm.expectRevert(FenixError.StakeLate.selector); // verify
        fenix.calculateEarlyPayout(stake1);
    }

    /// @notice Test the calculateEarlyPayout function when the stake is defer and the calculation block is before the term
    function test_CalculateEarlyPayout_Defer_BeforeTs_RevertWhen_StakeNotActive() public {
        Stake memory stake1 = Stake(Status.DEFER, calcBlockTs, 0, endBlockTs, uint16(baseTerm), 100, 100, 0);
        vm.warp(calcBlockTs - 1);
        vm.expectRevert(FenixError.StakeNotActive.selector); // verify
        fenix.calculateEarlyPayout(stake1);
    }

    /// @notice Test the calculateEarlyPayout function when the stake is defer and the calculation block is during the term
    function test_CalculateEarlyPayout_Defer_DuringTs_RevertWhen_StakeNotActive() public {
        Stake memory stake1 = Stake(Status.DEFER, calcBlockTs, 0, endBlockTs, uint16(baseTerm), 100, 100, 0);
        vm.warp(calcBlockTs + 1);
        vm.expectRevert(FenixError.StakeNotActive.selector); // verify
        fenix.calculateEarlyPayout(stake1);
    }

    /// @notice Test the calculateEarlyPayout function when the stake is defer and the calculation block is after the term
    function test_CalculateEarlyPayout_Defer_AfterTs_RevertWhen_StakeNotActive() public {
        Stake memory stake1 = Stake(Status.DEFER, calcBlockTs, 0, endBlockTs, uint16(baseTerm), 100, 100, 0);
        vm.warp(calcBlockTs + (86400 * baseTerm) + 1);
        vm.expectRevert(FenixError.StakeNotActive.selector); // verify
        fenix.calculateEarlyPayout(stake1);
    }

    /// @notice Test the calculateEarlyPayout function when the stake is end and the calculation block is before the term
    function test_CalculateEarlyPayout_End_BeforeTs_RevertWhen_StakeNotActive() public {
        Stake memory stake1 = Stake(Status.END, calcBlockTs, 0, endBlockTs, uint16(baseTerm), 100, 100, 0);
        vm.warp(calcBlockTs - 1);
        vm.expectRevert(FenixError.StakeNotActive.selector); // verify
        fenix.calculateEarlyPayout(stake1);
    }

    /// @notice Test the calculateEarlyPayout function when the stake is end and the calculation block is during the term
    function test_CalculateEarlyPayout_End_DuringTs_RevertWhen_StakeNotActive() public {
        Stake memory stake1 = Stake(Status.END, calcBlockTs, 0, endBlockTs, uint16(baseTerm), 100, 100, 0);
        vm.warp(calcBlockTs + 1);
        vm.expectRevert(FenixError.StakeNotActive.selector); // verify
        fenix.calculateEarlyPayout(stake1);
    }

    /// @notice Test the calculateEarlyPayout function when the stake is end and the calculation block is after the term
    function test_CalculateEarlyPayout_End_AfterTs_RevertWhen_StakeNotActive() public {
        Stake memory stake1 = Stake(Status.END, calcBlockTs, 0, endBlockTs, uint16(baseTerm), 100, 100, 0);
        vm.warp(calcBlockTs + (86400 * baseTerm) + 1);
        vm.expectRevert(FenixError.StakeNotActive.selector); // verify
        fenix.calculateEarlyPayout(stake1);
    }

    /// ---------- LATE PAYOUT ----------

    /// @notice Test the calculateLatePayout function when the stake is active and the calculation block is before the term
    function test_CalculateLatePayout_Active_BeforeTs_RevertWhen_StakeNotActive() public {
        Stake memory stake1 = Stake(Status.ACTIVE, calcBlockTs, 0, endBlockTs, uint16(baseTerm), 100, 100, 0);
        vm.warp(calcBlockTs - 1);
        vm.expectRevert(FenixError.StakeNotActive.selector); // verify
        fenix.calculateLatePayout(stake1);
    }

    /// @notice Test the calculateLatePayout function when the stake is active and the calculation block is during the term
    function test_CalculateLatePayout_Active_DuringTs_RevertWhen_StakeNotEnded() public {
        Stake memory stake1 = Stake(Status.ACTIVE, calcBlockTs, 0, endBlockTs, uint16(baseTerm), 100, 100, 0);
        vm.warp(calcBlockTs + 1);
        vm.expectRevert(FenixError.StakeNotEnded.selector); // verify
        fenix.calculateLatePayout(stake1);
    }

    /// @notice Test the calculateLatePayout function when the stake is active and the calculation block is after the term
    function test_CalculateLatePayout_Active_AfterTs() public {
        Stake memory stake1 = Stake(Status.ACTIVE, calcBlockTs, 0, endBlockTs, uint16(baseTerm), 100, 100, 0);
        vm.warp(calcBlockTs + (86400 * baseTerm) + 1);
        uint256 payout = fenix.calculateLatePayout(stake1);
        assertEq(payout, 1_000000000000000000); // verify
    }

    /// @notice Test the calculateLatePayout function when the stake is defer and the calculation block is before the term
    function test_CalculateLatePayout_Defer_BeforeTs_RevertWhen_StakeNotActive() public {
        Stake memory stake1 = Stake(Status.DEFER, calcBlockTs, 0, endBlockTs, uint16(baseTerm), 100, 100, 0);
        vm.warp(calcBlockTs - 1);
        vm.expectRevert(FenixError.StakeNotActive.selector); // verify
        fenix.calculateLatePayout(stake1);
    }

    /// @notice Test the calculateLatePayout function when the stake is defer and the calculation block is during the term
    function test_CalculateLatePayout_Defer_DuringTs_RevertWhen_StakeNotActive() public {
        Stake memory stake1 = Stake(Status.DEFER, calcBlockTs, 0, endBlockTs, uint16(baseTerm), 100, 100, 0);
        vm.warp(calcBlockTs + 1);
        vm.expectRevert(FenixError.StakeNotActive.selector); // verify
        fenix.calculateLatePayout(stake1);
    }

    /// @notice Test the calculateLatePayout function when the stake is defer and the calculation block is after the term
    function test_CalculateLatePayout_Defer_AfterTs_RevertWhen_StakeNotActive() public {
        Stake memory stake1 = Stake(Status.DEFER, calcBlockTs, 0, endBlockTs, uint16(baseTerm), 100, 100, 0);
        vm.warp(calcBlockTs + (86400 * baseTerm) + 1);
        vm.expectRevert(FenixError.StakeNotActive.selector); // verify
        fenix.calculateLatePayout(stake1);
    }

    /// @notice Test the calculateLatePayout function when the stake is end and the calculation block is before the term
    function test_CalculateLatePayout_End_BeforeTs_RevertWhen_StakeNotActive() public {
        Stake memory stake1 = Stake(Status.END, calcBlockTs, 0, endBlockTs, uint16(baseTerm), 100, 100, 0);
        vm.warp(calcBlockTs - 1);
        vm.expectRevert(FenixError.StakeNotActive.selector); // verify
        fenix.calculateLatePayout(stake1);
    }

    /// @notice Test the calculateLatePayout function when the stake is end and the calculation block is during the term
    function test_CalculateLatePayout_End_DuringTs_RevertWhen_StakeNotActive() public {
        Stake memory stake1 = Stake(Status.END, calcBlockTs, 0, endBlockTs, uint16(baseTerm), 100, 100, 0);
        vm.warp(calcBlockTs + 1);
        vm.expectRevert(FenixError.StakeNotActive.selector); // verify
        fenix.calculateLatePayout(stake1);
    }

    /// @notice Test the calculateLatePayout function when the stake is end and the calculation block is after the term
    function test_CalculateLatePayout_End_AfterTs_RevertWhen_StakeNotActive() public {
        Stake memory stake1 = Stake(Status.END, calcBlockTs, 0, endBlockTs, uint16(baseTerm), 100, 100, 0);
        vm.warp(calcBlockTs + (86400 * baseTerm) + 1);
        vm.expectRevert(FenixError.StakeNotActive.selector); // verify
        fenix.calculateLatePayout(stake1);
    }
}
