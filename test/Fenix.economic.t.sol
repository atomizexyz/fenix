// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { Fenix, Stake, Status, FenixError } from "@atomize/Fenix.sol";
import { XENCrypto } from "xen-crypto/XENCrypto.sol";
import { HelpersTest } from "./Helpers.t.sol";

contract FenixEconomicTest is Test {
    HelpersTest internal helper;
    Fenix internal fenix;
    XENCrypto internal xenCrypto;

    address internal bob = address(this);
    address internal alice = vm.addr(1);
    address internal carol = vm.addr(2);
    address internal dan = vm.addr(3);
    address internal frank = vm.addr(4);
    address internal chad = vm.addr(5);
    address internal oscar = vm.addr(6);

    address[] internal stakers;
    uint256 internal term = 100;
    uint256 internal tenKXEN = 100_000e18;

    /// ============ Setup test suite ============

    function setUp() public {
        helper = new HelpersTest();

        vm.broadcast(helper.xenDeployerPrivateKey());
        xenCrypto = new XENCrypto();

        fenix = new Fenix();

        stakers.push(bob);
        stakers.push(alice);
        stakers.push(carol);
        stakers.push(dan);
        stakers.push(frank);
        stakers.push(chad);
        stakers.push(oscar);

        helper.batchDealTo(stakers, tenKXEN, address(xenCrypto));
        helper.getFenixFor(stakers, fenix, xenCrypto);
    }

    /// @notice Test multiple stakes with symmetric split terms
    function testMultipleStakesSymmetricTerm() public {
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

        assertEq(bobPayout, 20_515394412670224520);
        assertEq(fenix.stakeCount(bob), 1);

        assertEq(alicePayout, 20_515394412670224520);
        assertEq(fenix.stakeCount(alice), 1);
    }

    /// @notice Test multiple stakes with assymetric terms
    function testMultipleStakesAssymetricTerm() public {
        uint256 bobTerm = 100;
        uint256 aliceTerm = 1000;

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

        assertEq(bobPayout, 35_848257895644364308);
        assertEq(fenix.stakeCount(bob), 1);

        assertEq(alicePayout, 42_2018181089599225183);
        assertEq(fenix.stakeCount(alice), 1);
    }

    function testMultipleStakesWealthRedistribution() public {
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
        assertEq(oscarPayout, 586154126076280);
        assertEq(fenix.stakeCount(oscar), 1);

        vm.warp(blockTs + (86400 * term));

        for (uint256 i = 0; i < stakers.length - 1; i++) {
            vm.prank(stakers[i]);
            fenix.endStake(0);
        }

        uint256 bobPayout = fenix.balanceOf(bob);
        assertEq(bobPayout, 6_838367111869062099);
        uint256 alicePayout = fenix.balanceOf(alice);
        assertEq(alicePayout, 6_838367111869062132);
        uint256 carolPayout = fenix.balanceOf(carol);
        assertEq(carolPayout, 6_838367111869062132);
        uint256 danPayout = fenix.balanceOf(dan);
        assertEq(danPayout, 6_838367111869062125);
        uint256 frankPayout = fenix.balanceOf(frank);
        assertEq(frankPayout, 6_838367111869062136);
        uint256 chadPayout = fenix.balanceOf(chad);
        assertEq(chadPayout, 6_838367111869062136);

        assertEq(fenix.stakePoolSupply(), 0);
    }

    function testOneDayVsMaxTerm() public {
        uint256 bobTerm = 1;
        uint256 aliceTerm = fenix.MAX_STAKE_LENGTH_DAYS();

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

        assertEq(bobPayout, 1824087719443);
        assertEq(fenix.stakeCount(bob), 1);

        assertEq(alicePayout, 2399_053824551853172290);
        assertEq(fenix.stakeCount(alice), 1);
    }

    /// @notice Test pays better always
    function testTimePaysBetter(uint256 fuzzTerm) public {
        if (fuzzTerm > 0 || fuzzTerm < fenix.MAX_STAKE_LENGTH_DAYS()) return;
        uint40 blockTs = uint40(block.timestamp);
        uint256 maxTerm = fenix.MAX_STAKE_LENGTH_DAYS();

        vm.prank(oscar);
        fenix.startStake(fenix.balanceOf(oscar), fuzzTerm);

        vm.prank(frank);
        fenix.startStake(fenix.balanceOf(frank), maxTerm);

        vm.warp(blockTs + (86400 * fuzzTerm));

        vm.prank(oscar);
        fenix.endStake(0);

        vm.prank(frank);
        fenix.endStake(0); // early end stake

        uint256 oscarPayout = fenix.balanceOf(oscar);
        uint256 frankPayout = fenix.balanceOf(frank);

        assertGe(oscarPayout, frankPayout); // verify
    }

    /// @notice Test 630 years of stakes
    function testTwoThousandYearsOfStakes() public {
        // You must go through the proof of burn process to ensure correct supply on FENIX
        uint256 xenMaxSupply = 545_638_549_388_136e18; // XEN max supply
        deal({ token: address(xenCrypto), to: bob, give: xenMaxSupply });
        xenCrypto.approve(address(fenix), xenMaxSupply);
        fenix.burnXEN(xenMaxSupply);

        uint256 maxTerm = fenix.MAX_STAKE_LENGTH_DAYS();

        uint40 blockTs = uint40(block.timestamp);

        for (uint256 i = 0; i < 30; i++) {
            uint256 bobBalance = fenix.balanceOf(bob);

            fenix.startStake(bobBalance, maxTerm);

            uint256 termInterval = i + 1;

            vm.warp(blockTs + (86_400 * termInterval * maxTerm));
            fenix.endStake(i);
        }

        uint256 finalBalance = fenix.balanceOf(bob);
        assertEq(finalBalance, 1124657058738365879398514170226248425106550696908650194650_840769603638938280);
    }

    /// @notice Test inlfation rate payout
    function testInflationRate() public {
        uint256 oneYearTerm = 365;
        uint40 blockTs = uint40(block.timestamp);

        uint256 totalSupplyStart = fenix.totalSupply();

        uint256 bobBalanceStart = fenix.balanceOf(bob);
        fenix.startStake(bobBalanceStart, oneYearTerm);

        uint256 totalSupplyMid = fenix.totalSupply();

        vm.warp(blockTs + (86_400 * oneYearTerm));

        fenix.endStake(0);

        uint256 totalSupplyEnd = fenix.totalSupply();
        uint256 bobBalanceEnd = fenix.balanceOf(bob);

        assertEq(totalSupplyStart, 70_000000000000000000);
        assertEq(totalSupplyMid, 60_000000000000000000);
        assertEq(totalSupplyEnd, 183_262379212492639360);

        assertEq(bobBalanceStart, 10_000000000000000000);
        assertEq(bobBalanceEnd, 123_262379212492639360);
    }

    /// @notice Test minimum stake term return vs max term
    function testMinimumStakeTermVsMax() public {
        uint256 bobTerm = 4554;
        uint256 aliceTerm = fenix.MAX_STAKE_LENGTH_DAYS();
        uint40 blockTs = uint40(block.timestamp);

        uint256 bobBalanceStart = fenix.balanceOf(bob);
        vm.prank(bob);
        fenix.startStake(bobBalanceStart, bobTerm);

        uint256 aliceFenixBalance = fenix.balanceOf(alice);
        vm.prank(alice);
        fenix.startStake(aliceFenixBalance, aliceTerm);

        vm.warp(blockTs + (86_400 * bobTerm));

        vm.prank(bob);
        fenix.endStake(0);

        uint256 bobBalanceEnd = fenix.balanceOf(bob);

        assertGt(bobBalanceEnd, bobBalanceStart);
    }
}
