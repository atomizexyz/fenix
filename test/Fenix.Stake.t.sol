// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { Fenix } from "@atomize/Fenix.sol";
import { XENCrypto } from "xen-crypto/XENCrypto.sol";
import { HelpersTest } from "./Helpers.t.sol";

contract FenixStakeTest is Test {
    HelpersTest internal helper;
    Fenix internal fenix;
    XENCrypto internal xenCrypto;

    error TermTooLong();
    error StakeNotFound(uint256 stakeId);
    error OnlyOwnerCanEndEarly();

    address internal bob = address(this);
    address internal alice = vm.addr(1);
    address internal carol = vm.addr(2);
    address internal dan = vm.addr(3);
    address internal frank = vm.addr(4);
    address internal oscar = vm.addr(5);
    address internal chad = vm.addr(5);

    address[] internal stakers;

    /// ============ Setup test suite ============

    function setUp() public {
        helper = new HelpersTest();
        vm.broadcast(helper.xenDeployerPrivateKey());
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

    /// @notice Test split stake vs single stake
    function testSplitStake() public {
        helper.getFenixFor(stakers, fenix, xenCrypto);
        uint256 term = 365;
        uint40 blockTs = uint40(block.timestamp);

        uint256 halfBalance = 1e15;

        vm.prank(bob);
        fenix.startStake(halfBalance, term);
        vm.prank(bob);
        fenix.startStake(halfBalance, term);

        vm.prank(alice);
        fenix.startStake(halfBalance * 2, term);

        uint256 bobPostStakeBalance = fenix.balanceOf(bob);
        uint256 alicePostStakeBalance = fenix.balanceOf(alice);

        vm.warp(blockTs + (86400 * term));

        // end stakes
        vm.prank(bob);
        fenix.endStake(0);
        vm.prank(bob);
        fenix.endStake(1);

        vm.prank(alice);
        fenix.endStake(0);

        uint256 bobPayout = fenix.balanceOf(bob) - bobPostStakeBalance;
        uint256 alicePayout = fenix.balanceOf(alice) - alicePostStakeBalance;

        assertGt(alicePayout, bobPayout); // verify
    }

    /// @notice Test starting stake below max length
    function testStartMaxStake() public {
        uint256 maxStakeDays = 18250;
        uint256 maxStakeDaysPlusOne = maxStakeDays + 1;

        helper.getFenixFor(stakers, fenix, xenCrypto);
        uint256 fenixBalance = fenix.balanceOf(bob);

        vm.expectRevert(TermTooLong.selector);
        fenix.startStake(fenixBalance, maxStakeDaysPlusOne);

        fenix.startStake(fenixBalance, maxStakeDays);
        assertEq(fenix.stakeFor(bob, 0).stakeId, 0);
    }

    /// @notice Test deferring early stake
    function testDeferEarlyStake() public {
        helper.getFenixFor(stakers, fenix, xenCrypto);
        uint256 term = 100;
        uint40 blockTs = uint40(block.timestamp);

        uint256 fenixBalance = fenix.balanceOf(bob);
        fenix.startStake(fenixBalance, term);

        vm.warp(blockTs + (86400 * term));
        fenix.deferStake(0, bob);

        assertEq(fenix.stakeFor(bob, 0).stakeId, 0);
        assertEq(fenix.stakeFor(bob, 0).deferralTs, uint40(block.timestamp));
        assertEq(fenix.stakeFor(bob, 0).payout, 5_963214217430343893);
        assertEq(fenix.stakeCount(bob), 1);
    }

    /// @notice Test deferring early stake then ending
    function testDeferEarlyStakeThenEnd() public {
        testDeferEarlyStake();

        vm.prank(bob);
        fenix.endStake(0);

        assertEq(fenix.stakeCount(bob), 1);
    }

    /// @notice Test deferring late stake
    function testDeferLateStake() public {
        helper.getFenixFor(stakers, fenix, xenCrypto);
        uint256 term = 100;
        uint40 blockTs = uint40(block.timestamp);

        uint256 fenixBalance = fenix.balanceOf(bob);
        fenix.startStake(fenixBalance, term);

        vm.warp(blockTs + (86400 * term) + 1);
        fenix.deferStake(0, bob);

        assertEq(fenix.stakeFor(bob, 0).stakeId, 0);
        assertEq(fenix.stakeFor(bob, 0).deferralTs, uint40(block.timestamp));
        assertEq(fenix.stakeFor(bob, 0).payout, 5_963214217430343893);
        assertEq(fenix.stakeCount(bob), 1);
    }

    /// @notice Test deferring late stake then ending
    function testDeferLateStakeThenEnd() public {
        testDeferLateStake();

        vm.prank(bob);
        fenix.endStake(0);

        assertEq(fenix.stakeCount(bob), 1);
    }

    /// @notice Test prevent other non owner from early defer
    function testNonOwnerDeferEarlyStake() public {
        helper.getFenixFor(stakers, fenix, xenCrypto);
        uint256 term = 100;
        uint40 blockTs = uint40(block.timestamp);

        uint256 fenixBalance = fenix.balanceOf(bob);
        fenix.startStake(fenixBalance, term);

        vm.warp(blockTs + 86400);

        vm.expectRevert(OnlyOwnerCanEndEarly.selector);
        vm.prank(chad);
        fenix.deferStake(0, bob);
        assertEq(fenix.stakeFor(bob, 0).deferralTs, 0);
    }

    /// @notice Test prevent other non owner from late defer
    function testNonOwnerDeferLateStake() public {
        helper.getFenixFor(stakers, fenix, xenCrypto);
        uint256 term = 100;
        uint40 blockTs = uint40(block.timestamp);

        uint256 fenixBalance = fenix.balanceOf(bob);
        fenix.startStake(fenixBalance, term);

        vm.warp(blockTs + (86400 * term) + 1);

        vm.prank(chad);
        fenix.deferStake(0, bob);
        assertEq(fenix.stakeFor(bob, 0).deferralTs, uint40(block.timestamp));
        assertEq(fenix.stakeFor(bob, 0).payout, 5_963214217430343893);
        assertEq(fenix.stakeCount(bob), 1);
    }

    /// @notice Test ending early stake
    function testEndingEarlyStake() public {
        helper.getFenixFor(stakers, fenix, xenCrypto);
        uint256 term = 100;
        uint40 blockTs = uint40(block.timestamp);

        uint256 fenixBalance = fenix.balanceOf(bob);
        fenix.startStake(fenixBalance, term);

        vm.warp(blockTs + (86400 * term));
        fenix.endStake(0);

        uint256 fenixPayoutBalance = fenix.balanceOf(bob);

        assertEq(fenixPayoutBalance, 5_963214217430343893);
        assertEq(fenix.stakeCount(bob), 1);
    }

    /// @notice Test multiple stakes with symmetric split terms
    function testMultipleStakesSymmetricSplit() public {
        helper.getFenixFor(stakers, fenix, xenCrypto);
        uint256 term = 100;
        uint40 blockTs = uint40(block.timestamp);

        // start stakes

        uint256 bobFenixBalance = fenix.balanceOf(bob);
        vm.prank(bob);
        fenix.startStake(bobFenixBalance, term);

        uint256 aliceFenixBalance = fenix.balanceOf(alice);
        vm.prank(alice);
        fenix.startStake(aliceFenixBalance, term);

        vm.warp(blockTs + (86400 * term));

        // end stakes
        vm.prank(bob);
        fenix.endStake(0);

        vm.prank(alice);
        fenix.endStake(0);

        // check payouts
        uint256 bobPayout = fenix.balanceOf(bob);
        uint256 alicePayout = fenix.balanceOf(alice);

        assertEq(bobPayout, 3_141441284256474392);
        assertEq(fenix.stakeCount(bob), 1);

        assertEq(alicePayout, 2_821772933173869501);
        assertEq(fenix.stakeCount(alice), 1);
    }

    /// @notice Test multiple stakes with assymetric terms
    function testMultipleStakesAssymetricTerm() public {
        helper.getFenixFor(stakers, fenix, xenCrypto);
        uint256 bobTerm = 100;
        uint256 aliceTerm = 365;

        uint40 blockTs = uint40(block.timestamp);
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

        assertGt(alicePayout, bobPayout);
        assertEq(bobPayout, 12_641143294713773849);
        assertEq(fenix.stakeCount(bob), 1);

        assertEq(alicePayout, 12_822260899977946379);
        assertEq(fenix.stakeCount(alice), 1);
    }

    /// @notice Test multiple stakes with wealth redistribution
    function testMultipleStakesWealthRedistribution() public {
        helper.getFenixFor(stakers, fenix, xenCrypto);
        uint256 term = 3560;
        uint40 blockTs = uint40(block.timestamp);

        for (uint256 i = 0; i < stakers.length; i++) {
            uint256 fenixBalance = fenix.balanceOf(stakers[i]);
            vm.prank(stakers[i]);
            fenix.startStake(fenixBalance, term);
        }

        vm.warp(blockTs + 86400);

        // early end stake and redistribute wealth
        vm.prank(oscar);
        fenix.endStake(0);

        uint256 oscarPayout = fenix.balanceOf(oscar);
        assertEq(oscarPayout, 2148567269);
        assertEq(fenix.stakeCount(oscar), 1);

        vm.warp(blockTs + (86400 * term));

        for (uint256 i = 0; i < stakers.length - 1; i++) {
            vm.prank(stakers[i]);
            fenix.endStake(0);
        }

        uint256 bobPayout = fenix.balanceOf(bob);
        assertEq(bobPayout, 986159_943237702981935385);
        uint256 alicePayout = fenix.balanceOf(alice);
        assertEq(alicePayout, 885809_787231803076105613);
        uint256 carolPayout = fenix.balanceOf(carol);
        assertEq(carolPayout, 763031_140137026925907899);
        uint256 danPayout = fenix.balanceOf(dan);
        assertEq(danPayout, 604644_373169189520518236);
        uint256 frankPayout = fenix.balanceOf(frank);
        assertEq(frankPayout, 381515_570068513464391085);

        assertEq(fenix.poolSupply(), 0);
    }

    /// @notice Test long staker who ends early redistributing wealth
    function testLongStakeWithEarlyPenaltyVersusShortTerm() public {
        helper.getFenixFor(stakers, fenix, xenCrypto);
        uint256 term = 365;
        uint256 longTerm = 365 * 50;
        uint40 blockTs = uint40(block.timestamp);

        uint256 oscarFenixBalance = fenix.balanceOf(oscar);
        vm.prank(oscar);
        fenix.startStake(oscarFenixBalance, term);

        uint256 frankFenixBalance = fenix.balanceOf(frank);
        vm.prank(frank);
        fenix.startStake(frankFenixBalance, longTerm);

        vm.warp(blockTs + (86400 * term));

        vm.prank(oscar);
        fenix.endStake(0);

        vm.prank(frank);
        fenix.endStake(0); // early end stake

        uint256 oscarPayout = fenix.balanceOf(oscar);
        uint256 frankPayout = fenix.balanceOf(frank);

        assertGt(oscarPayout, frankPayout); // verify
        assertEq(oscarPayout, 15121138352912100500613755209_747062898759474079); // verify
        assertEq(frankPayout, 16936676486417001863385987_314827642949368499); // verify
    }

    /// @notice Test end stake array
    function testEndStakeArray() public {
        helper.getFenixFor(stakers, fenix, xenCrypto);
        uint256 term = 100;
        uint40 blockTs = uint40(block.timestamp);

        uint256 bobFenixBalance = fenix.balanceOf(bob);
        vm.prank(bob);
        fenix.startStake(bobFenixBalance, term);

        vm.warp(blockTs + (86400 * term));

        // end stakes
        vm.prank(bob);
        fenix.endStake(0);

        // uint256 endStakeCount = fenix.endedStakeCount(bob);

        // assertEq(endStakeCount, 1); // verify
    }

    function testEndingInvalidStake() public {
        helper.getFenixFor(stakers, fenix, xenCrypto);
        uint256 term = 100;
        uint40 blockTs = uint40(block.timestamp);

        uint256 bobFenixBalance = fenix.balanceOf(bob);
        vm.prank(bob);
        fenix.startStake(bobFenixBalance, term);

        vm.warp(blockTs + (86400 * term));

        // end stakes
        // vm.prank(bob);
        // FIX this test
        // fenix.endStake(100);
    }
}
