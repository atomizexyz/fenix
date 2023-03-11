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

    /// ============ Setup test suite ============

    function setUp() public {
        helper = new HelpersTest();
        vm.broadcast(helper.xenDeployerPrivateKey());
        xenCrypto = new XENCrypto();

        fenix = new Fenix();

        stakers.push(bob);

        helper.batchDealTo(stakers, tenKXen, address(xenCrypto));
        helper.getFenixFor(stakers, fenix, xenCrypto);
    }

    /// @notice Test stake payout
    function test_CalculateEarlyPayout() public {
        uint256 amount = 21e18;

        uint256 shares = fenix.calculateBonus(amount, 356);

        uint40 blockTs = uint40(block.timestamp);
        Stake memory stake1 = Stake(Status.ACTIVE, blockTs, 0, 100, amount, shares, 0);

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

    function test_CalculateEarlyPayout_RevertWhen_StakeNotStarted() public {
        uint40 blockTs = uint40(block.timestamp + (86400 * 10));

        vm.warp(blockTs + (86400 * 10));

        Stake memory stake1 = Stake(Status.ACTIVE, blockTs, 0, 100, 100, 100, 0);

        vm.warp(blockTs - 86400);

        vm.expectRevert(FenixError.StakeNotStarted.selector); // verify
        fenix.calculateEarlyPayout(stake1);
    }

    function test_CalculateEarlyPayout_RevertWhen_StakeEnded() public {
        uint40 blockTs = uint40(block.timestamp + (86400 * 10));

        vm.warp(blockTs + (86400 * 10));

        Stake memory stake1 = Stake(Status.ACTIVE, blockTs, 0, 100, 100, 100, 0);

        vm.warp(blockTs + (86400 * 101));

        vm.expectRevert(FenixError.StakeEnded.selector); // verify
        fenix.calculateEarlyPayout(stake1);
    }

    function test_CalculateLatePayout() public {
        uint256 base = 13.81551 * 1e18;
        uint256 bonus = 2.77069 * 1e18;
        uint256 baseTerm = 100;

        uint40 blockTs = uint40(block.timestamp);
        Stake memory stake1 = Stake(Status.ACTIVE, blockTs, 0, uint16(baseTerm), base, base + bonus, 0);

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

    function test_CalculateLatePayout_RevertWhen_StakeNotStarted() public {
        uint40 blockTs = uint40(block.timestamp + (86400 * 10));

        Stake memory stake1 = Stake(Status.ACTIVE, uint40(blockTs), 0, 100, 100, 100, 0);

        vm.warp(blockTs - 86400);

        vm.expectRevert(FenixError.StakeNotStarted.selector); // verify
        fenix.calculateLatePayout(stake1);
    }

    function test_CalculateLatePayout_RevertWhen_StakeNotEnded() public {
        uint40 blockTs = uint40(block.timestamp + (86400 * 10));

        Stake memory stake1 = Stake(Status.ACTIVE, uint40(blockTs), 0, 100, 100, 100, 0);

        vm.warp(blockTs + 86400);

        vm.expectRevert(FenixError.StakeNotEnded.selector); // verify
        fenix.calculateLatePayout(stake1);
    }
}
