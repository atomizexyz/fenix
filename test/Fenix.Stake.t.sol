// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { Fenix, Stake } from "src/Fenix.sol";
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
        uint256 deferTerm = 100;

        uint256 fenixBalance = fenix.balanceOf(bob);
        fenix.startStake(fenixBalance, deferTerm);

        vm.warp(block.timestamp + (86400 * deferTerm));
        fenix.deferStake(0, bob);

        assertEq(fenix.deferralCount(bob), 1);
        assertEq(fenix.deferralFor(bob, 0).stakeId, 0);
        assertEq(fenix.deferralFor(bob, 0).payout, 38511844885099801535056);
    }

    /// @notice Test deferring late stake
    function testDeferLateStake() public {
        helper.getFenixFor(stakers, fenix, xenCrypto);
        uint256 term = 100;

        uint256 fenixBalance = fenix.balanceOf(bob);
        fenix.startStake(fenixBalance, term);

        vm.warp(block.timestamp + (86400 * term) + 1);
        fenix.deferStake(0, bob);

        assertEq(fenix.deferralCount(bob), 1);
        assertEq(fenix.deferralFor(bob, 0).stakeId, 0);
        assertEq(fenix.deferralFor(bob, 0).payout, 38511844885099801535056);
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

        assertEq(fenixPayoutBalance, 38511844885099801535056);
    }

    /// @notice Test multiple stakes - Symmetric Split
    function testMultipleStakes_SymmetricSplit() public {
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

        assertEq(bobPayout, 20689787933644277026303);
        assertEq(alicePayout, 17822056951455524508753);
    }

    /// @notice Test multiple stakes - Assymetric Term
    function testMultipleStakes_AssymetricTerm() public {
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
        assertEq(bobPayout, 30818557111336789579498);
        assertEq(alicePayout, 53082654299957409175161);
    }
}
