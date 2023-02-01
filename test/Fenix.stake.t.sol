// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { Fenix, Stake, Status, FenixError } from "@atomize/Fenix.sol";
import { XENCrypto } from "xen-crypto/XENCrypto.sol";
import { HelpersTest } from "./Helpers.t.sol";

contract FenixStakeTest is Test {
    HelpersTest internal helper;
    Fenix internal fenix;
    XENCrypto internal xenCrypto;

    address internal bob = address(this);
    address internal alice = vm.addr(1);
    address internal chad = vm.addr(2);

    address[] internal stakers;
    uint256 internal term = 100;
    uint256 internal tenKXen = 100_000e18;

    /// ============ Setup test suite ============

    function setUp() public {
        helper = new HelpersTest();

        vm.broadcast(helper.xenDeployerPrivateKey());
        xenCrypto = new XENCrypto();

        fenix = new Fenix();

        stakers.push(bob);

        helper.dealXENTo(stakers, tenKXen, xenCrypto);
        helper.getFenixFor(stakers, fenix, xenCrypto);
    }

    /// @notice Test starting stake works
    function testStakeStartOne() public {
        fenix.startStake(fenix.balanceOf(bob), term);

        Stake memory stake0 = fenix.stakeFor(bob, 0);
        assertTrue(stake0.status == Status.ACTIVE); // verify
    }

    /// @notice Test starting multiple stakes
    function testStakeStartMultiple() public {
        uint256 fenixBalanceThird = fenix.balanceOf(bob) / 3;

        fenix.startStake(fenixBalanceThird, term);
        fenix.startStake(fenixBalanceThird, term);
        fenix.startStake(fenixBalanceThird, term);

        Stake memory stake0 = fenix.stakeFor(bob, 0);
        assertTrue(stake0.status == Status.ACTIVE); // verify

        Stake memory stake1 = fenix.stakeFor(bob, 1);
        assertTrue(stake1.status == Status.ACTIVE); // verify

        Stake memory stake2 = fenix.stakeFor(bob, 2);
        assertTrue(stake2.status == Status.ACTIVE); // verify
    }

    /// @notice Test reverting stake with term
    function testStakeStartRevertIfBalanceZero() public {
        uint256 fenixBalance = 0;

        vm.expectRevert(FenixError.BalanceZero.selector); // verify
        fenix.startStake(fenixBalance, term);
    }

    /// @notice Test reverting stake with term zero
    function testStakeRevertIfTermZero() public {
        uint256 termZero = 0;
        uint256 fenixBalance = 10e18;

        vm.expectRevert(FenixError.TermZero.selector); // verify
        fenix.startStake(fenixBalance, termZero);
    }

    /// @notice Test reverting stake with term over max
    function testStakeStartRevertIfTermGreaterThanMax() public {
        uint256 maxTerm = fenix.MAX_STAKE_LENGTH_DAYS() + 1; // 365 * 55 + 1
        uint256 fenixBalance = 10e18;
        vm.expectRevert(FenixError.TermGreaterThanMax.selector); // verify
        fenix.startStake(fenixBalance, maxTerm);
    }

    /// @notice Test deferring stake
    function testDeferStakeOwner() public {
        uint40 blockTs = uint40(block.timestamp);

        fenix.startStake(fenix.balanceOf(bob), term);

        vm.warp(blockTs + (86400 * term));

        fenix.deferStake(0, address(bob));

        Stake memory stake0 = fenix.stakeFor(bob, 0);
        assertTrue(stake0.status == Status.DEFER); // verify
        assertEq(fenix.stakeFor(bob, 0).term, term); // verify
    }

    function testDeferStakeOwnerEarly() public {
        uint40 blockTs = uint40(block.timestamp);

        fenix.startStake(fenix.balanceOf(bob), term);

        vm.warp(blockTs + (86400 * (term / 2)));

        fenix.deferStake(0, address(bob));

        Stake memory stake0 = fenix.stakeFor(bob, 0);
        assertTrue(stake0.status == Status.DEFER); // verify
        assertEq(stake0.term, term); // verify
        assertEq(fenix.stakePoolSupply(), 9_375000000000000001); // verify
    }

    /// @notice Test deferring a stake from the owner
    function testDeferStakeOwnerLate() public {
        uint40 blockTs = uint40(block.timestamp);

        fenix.startStake(fenix.balanceOf(bob), term);

        vm.warp(blockTs + (86400 * (term + (180 / 2))));

        fenix.deferStake(0, address(bob));

        Stake memory stake0 = fenix.stakeFor(bob, 0);
        assertTrue(stake0.status == Status.DEFER); // verify
        assertEq(stake0.term, term); // verify
        assertEq(fenix.stakePoolSupply(), 1_250000000000000001); // verify
    }

    /// @notice Test deferring a stake from the owner
    function testDeferStakeNonOwnerLate() public {
        uint40 blockTs = uint40(block.timestamp);

        fenix.startStake(fenix.balanceOf(bob), term);

        vm.warp(blockTs + (86400 * (term + (180 / 2))));

        vm.prank(alice);
        fenix.deferStake(0, address(bob));

        Stake memory stake0 = fenix.stakeFor(bob, 0);
        assertTrue(stake0.status == Status.DEFER); // verify
        assertEq(stake0.term, term); // verify
        assertEq(fenix.stakePoolSupply(), 1_250000000000000001); // verify
    }

    /// @notice test defer stake early and revert if not owner
    function testDeferStakeRevertIfNotOwner() public {
        uint40 blockTs = uint40(block.timestamp);

        fenix.startStake(fenix.balanceOf(bob), term);

        vm.warp(blockTs + (86400 * (term / 2)));

        vm.expectRevert(abi.encodeWithSelector(FenixError.WrongCaller.selector, address(chad))); // verify
        vm.prank(chad);
        fenix.deferStake(0, address(bob));
    }

    /// @notice test deferring a stake and ignore if already deferred
    function testDeferStakeIgnoreMultipleIfAlreadyDeferred() public {
        uint40 blockTs = uint40(block.timestamp);

        fenix.startStake(fenix.balanceOf(bob), term);

        vm.warp(blockTs + (86400 * term));

        fenix.deferStake(0, address(bob));
        fenix.deferStake(0, address(bob));
    }

    /// @notice test end stake
    function testEndStake() public {
        uint40 blockTs = uint40(block.timestamp);

        fenix.startStake(fenix.balanceOf(bob), term);

        vm.warp(blockTs + (86400 * term));

        fenix.endStake(0);

        Stake memory stake0 = fenix.stakeFor(bob, 0);
        assertTrue(stake0.status == Status.END); // verify
        assertEq(fenix.stakePoolSupply(), 0); // verify
    }

    /// @notice test defer then end stake
    function testDeferStakeThenEndStake() public {
        uint40 blockTs = uint40(block.timestamp);

        fenix.startStake(fenix.balanceOf(bob), term);

        vm.warp(blockTs + (86400 * term));

        fenix.deferStake(0, address(bob));

        vm.warp(blockTs + (86400 * (term + 180)));

        fenix.endStake(0);

        Stake memory stake0 = fenix.stakeFor(bob, 0);
        assertTrue(stake0.status == Status.END); // verify
        assertEq(fenix.stakePoolSupply(), 0); // verify
    }

    /// @notice test end stake and revert if not owner
    function testEndStakeRevertIfNotOwner() public {
        uint40 blockTs = uint40(block.timestamp);

        fenix.startStake(fenix.balanceOf(bob), term);

        vm.warp(blockTs + (86400 * term));

        vm.expectRevert(FenixError.StakeNotStarted.selector); // verify
        vm.prank(chad);
        fenix.endStake(0);

        Stake memory stake0 = fenix.stakeFor(bob, 0);
        assertTrue(stake0.status == Status.ACTIVE); // verify
    }

    /// @notice test end stake and revert is already ended
    function testEndStakeRevertIfAlreadyEnded() public {
        uint40 blockTs = uint40(block.timestamp);

        fenix.startStake(fenix.balanceOf(bob), term);

        vm.warp(blockTs + (86400 * term));

        fenix.endStake(0);
        vm.expectRevert(abi.encodeWithSelector(FenixError.StakeStatusAlreadySet.selector, Status.END));
        fenix.endStake(0);
    }
}
