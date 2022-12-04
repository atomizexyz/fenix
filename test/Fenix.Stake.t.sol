// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { Fenix, Stake } from "@atomize/Fenix.sol";
import { XENCrypto } from "xen-crypto/XENCrypto.sol";
import { HelpersTest } from "./Helpers.t.sol";

contract FenixStakeTest is Test {
    HelpersTest internal helper;
    Fenix internal fenix;
    XENCrypto internal xenCrypto;

    address internal bob = address(this);
    address internal alice = vm.addr(1);
    address internal carol = vm.addr(2);
    address internal dan = vm.addr(3);
    address internal frank = vm.addr(4);
    address internal oscar = vm.addr(5);

    address[] internal stakers;

    /// ============ Setup test suite ============

    function setUp() public {
        helper = new HelpersTest();
        xenCrypto = new XENCrypto();

        stakers.push(bob);
        stakers.push(alice);
        stakers.push(carol);
        stakers.push(dan);
        stakers.push(frank);
        stakers.push(oscar);

        helper.generateXENFor(stakers, xenCrypto);
        fenix = new Fenix();
    }

    /// @notice Test starting stake works
    function testStartStakes() public {
        helper.getFenixFor(stakers, fenix, xenCrypto);

        uint256 fenixBalance = fenix.balanceOf(bob);
        uint256 feinxHalfBalance = fenixBalance / 2;

        assertEq(fenix.currentStakeId(), 0);

        fenix.startStake(feinxHalfBalance / 2, 100);

        assertEq(fenix.currentStakeId(), 1);

        fenix.startStake(feinxHalfBalance / 2, 100);
        assertEq(fenix.currentStakeId(), 2);

        assertEq(fenix.stakeCount(bob), 2);

        assertEq(fenix.stakeFor(bob, 0).stakeId, 0);
        assertEq(fenix.stakeFor(bob, 1).stakeId, 1);
    }

    /// @notice Test deferring early stake
    function testDeferEarlyStake() public {
        helper.getFenixFor(stakers, fenix, xenCrypto);
        uint256 term = 100;

        uint256 fenixBalance = fenix.balanceOf(bob);
        fenix.startStake(fenixBalance, term);

        vm.warp(block.timestamp + (86400 * term));
        fenix.deferStake(0, bob);

        assertEq(fenix.stakeFor(bob, 0).stakeId, 0);
        assertEq(fenix.stakeFor(bob, 0).deferralTs, block.timestamp);
        assertEq(fenix.stakeFor(bob, 0).payout, 51102142174303438937096);
        assertEq(fenix.stakeCount(bob), 1);
    }

    /// @notice Test deferring late stake
    function testDeferLateStake() public {
        helper.getFenixFor(stakers, fenix, xenCrypto);
        uint256 term = 100;

        uint256 fenixBalance = fenix.balanceOf(bob);
        fenix.startStake(fenixBalance, term);

        vm.warp(block.timestamp + (86400 * term) + 1);
        fenix.deferStake(0, bob);

        assertEq(fenix.stakeFor(bob, 0).stakeId, 0);
        assertEq(fenix.stakeFor(bob, 0).deferralTs, block.timestamp);
        assertEq(fenix.stakeFor(bob, 0).payout, 51102142174303438937096);
        assertEq(fenix.stakeCount(bob), 1);
    }

    /// @notice Test deferring multiple stakes
    function testDeferMultipleStakes() public {}

    function testEndingDeferredStake() public {}

    /// @notice Test ending early stake
    function testEndingEarlyStake() public {
        helper.getFenixFor(stakers, fenix, xenCrypto);
        uint256 term = 100;

        uint256 fenixBalance = fenix.balanceOf(bob);
        fenix.startStake(fenixBalance, term);

        vm.warp(block.timestamp + (86400 * term));
        fenix.endStake(0);

        uint256 fenixPayoutBalance = fenix.balanceOf(bob);

        assertEq(fenixPayoutBalance, 51102142174303438937096);
        assertEq(fenix.stakeCount(bob), 0);
    }

    /// @notice Test multiple stakes - Symmetric Split
    function testMultipleStakesSymmetricSplit() public {
        helper.getFenixFor(stakers, fenix, xenCrypto);
        uint256 term = 100;

        // start stakes

        uint256 bobFenixBalance = fenix.balanceOf(bob);
        vm.prank(bob);
        fenix.startStake(bobFenixBalance, term);

        uint256 aliceFenixBalance = fenix.balanceOf(alice);
        vm.prank(alice);
        fenix.startStake(aliceFenixBalance, term);

        vm.warp(block.timestamp + (86400 * term));

        // end stakes
        vm.prank(bob);
        fenix.endStake(0);

        vm.prank(alice);
        fenix.endStake(0);

        // check payouts
        uint256 bobPayout = fenix.balanceOf(bob);
        uint256 alicePayout = fenix.balanceOf(alice);

        assertEq(bobPayout, 26920780184461977136847);
        assertEq(fenix.stakeCount(bob), 0);

        assertEq(alicePayout, 24181361989841461800249);
        assertEq(fenix.stakeCount(alice), 0);
    }

    /// @notice Test multiple stakes - Assymetric Term
    function testMultipleStakesAssymetricTerm() public {
        helper.getFenixFor(stakers, fenix, xenCrypto);
        uint256 bobTerm = 100;
        uint256 aliceTerm = 200;

        uint256 blockTs = block.timestamp;
        // start stakes
        uint256 bobFenixBalance = fenix.balanceOf(bob);
        vm.prank(bob);
        fenix.startStake(bobFenixBalance, bobTerm);

        uint256 aliceFenixBalance = fenix.balanceOf(alice);
        vm.prank(alice);
        fenix.startStake(aliceFenixBalance, aliceTerm);

        vm.warp(blockTs + (86400 * bobTerm));

        // end stakes
        vm.prank(bob);
        fenix.endStake(0);

        vm.warp(blockTs + (86400 * aliceTerm));

        vm.prank(alice);
        fenix.endStake(0);

        // check payouts
        uint256 bobPayout = fenix.balanceOf(bob);
        uint256 alicePayout = fenix.balanceOf(alice);

        assertTrue(alicePayout > bobPayout);
        assertEq(bobPayout, 39816178867677923588195);
        assertEq(fenix.stakeCount(bob), 0);

        assertEq(alicePayout, 71514027382583756209589);
        assertEq(fenix.stakeCount(alice), 0);
    }

    function testMultipleStakesWealthRedistribution() public {
        helper.getFenixFor(stakers, fenix, xenCrypto);
        uint256 term = 3560;
        uint256 blockTs = block.timestamp;

        for (uint256 i = 0; i < stakers.length; i++) {
            uint256 fenixBalance = fenix.balanceOf(stakers[i]);
            vm.prank(stakers[i]);
            fenix.startStake(fenixBalance, term);
        }

        vm.warp(blockTs + 1);

        // emergency end stake and redistribute wealth
        vm.prank(oscar);
        fenix.endStake(0);

        uint256 oscarPayout = fenix.balanceOf(oscar);
        assertEq(oscarPayout, 34515128735);
        assertEq(fenix.stakeCount(oscar), 0);

        vm.warp(blockTs + (86400 * term));

        for (uint256 i = 0; i < stakers.length - 1; i++) {
            vm.prank(stakers[i]);
            fenix.endStake(0);
        }

        uint256 bobPayout = fenix.balanceOf(bob);
        assertEq(bobPayout, 9861597109380419863998960459);
        uint256 alicePayout = fenix.balanceOf(alice);
        assertEq(alicePayout, 8858095785706069978180497216);
        uint256 carolPayout = fenix.balanceOf(carol);
        assertEq(carolPayout, 7630309603975471403821982902);
        uint256 danPayout = fenix.balanceOf(dan);
        assertEq(danPayout, 6046442307392684177455972681);
        uint256 frankPayout = fenix.balanceOf(frank);
        assertEq(frankPayout, 3815154801987735716282336283);

        assertEq(fenix.poolSupply(), 0);
    }
}
