// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { Fenix, Stake, Status } from "@atomize/Fenix.sol";
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
    uint256 internal tenBillionXEN = 10_000_000_000e18;

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

        helper.batchDealTo(stakers, tenBillionXEN, address(xenCrypto));
        helper.getFenixFor(stakers, fenix, xenCrypto);
    }

    /// @notice Test multiple stakes with symmetric split terms
    function test_MultipleStakesSymmetricTerm() public {
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

        assertEq(bobPayout, 1004407_171715296150000000);
        assertEq(fenix.stakeCount(bob), 1);

        assertEq(alicePayout, 1004407_171715296150000000);
        assertEq(fenix.stakeCount(alice), 1);
        assertEq(fenix.shareRate(), 1_004407171715296150);
    }

    /// @notice Test multiple stakes with assymetric terms
    function test_MultipleStakesAssymetricTerm() public {
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

        assertEq(bobPayout, 9452729_85448836509979027);
        assertEq(fenix.stakeCount(bob), 1);

        assertEq(alicePayout, 1104090_297419575036020973);
        assertEq(fenix.stakeCount(alice), 1);
        assertEq(fenix.shareRate(), 1_104090297419575036);
    }

    function test_MultipleStakesWealthRedistribution() public {
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
        assertEq(oscarPayout, 100_440717171527606185);
        assertEq(fenix.stakeCount(oscar), 1);

        vm.warp(blockTs + (86400 * term));

        for (uint256 i = 0; i < stakers.length - 1; i++) {
            vm.prank(stakers[i]);
            fenix.endStake(0);
        }

        uint256 bobPayout = fenix.balanceOf(bob);
        assertEq(bobPayout, 1171791_626881650249045135);
        uint256 alicePayout = fenix.balanceOf(alice);
        assertEq(alicePayout, 1171791_626881650254669736);
        uint256 carolPayout = fenix.balanceOf(carol);
        assertEq(carolPayout, 1171791_626881650254669736);
        uint256 danPayout = fenix.balanceOf(dan);
        assertEq(danPayout, 1171791_626881650253497944);
        uint256 frankPayout = fenix.balanceOf(frank);
        assertEq(frankPayout, 1171791_626881650255255632);
        uint256 chadPayout = fenix.balanceOf(chad);
        assertEq(chadPayout, 1171791_626881650255255632);

        assertEq(fenix.equityPoolSupply(), 0);
        assertEq(fenix.shareRate(), 1_171791626881650255);
    }

    function test_OneDayVsMaxTerm() public {
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

        assertEq(bobPayout, 498921_153863720572949881);
        assertEq(fenix.stakeCount(bob), 1);

        assertEq(alicePayout, 1908872_823721521449050119);
        assertEq(fenix.stakeCount(alice), 1);
        assertEq(fenix.shareRate(), 1_908872823721521449);
    }

    /// @notice Test pays better always
    function testFuzz_TimePaysBetter(uint256 fuzzTerm) public {
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
        assertEq(fenix.shareRate(), 1_009118345453641023);
    }

    /// @notice Test 6,720 years of stakes
    function test_SixThousandSevenHundredTwentyYearsOfStakes() public {
        // You must go through the proof of burn process to ensure correct supply on FENIX
        uint256 xenMaxSupply = 545_638_549_388_136e18; // XEN max supply
        deal({ token: address(xenCrypto), to: bob, give: xenMaxSupply });
        xenCrypto.approve(address(fenix), xenMaxSupply);
        fenix.burnXEN(xenMaxSupply);

        uint256 maxTerm = fenix.MAX_STAKE_LENGTH_DAYS();

        uint40 blockTs = uint40(block.timestamp);

        for (uint256 i = 0; i < 320; i++) {
            uint256 bobBalance = fenix.balanceOf(bob);
            fenix.startStake(bobBalance, maxTerm);

            uint256 termInterval = i + 1;

            vm.warp(blockTs + (86_400 * termInterval * maxTerm));
            fenix.endStake(i);
        }

        uint256 finalBalance = fenix.balanceOf(bob);
        assertEq(finalBalance, 18411310410978042499698260858739638848399918979733239260222_158106372524653358);
        assertEq(fenix.shareRate(), 1_407750001732594700);
    }

    /// @notice Test inlfation rate payout
    function test_InflationRate() public {
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

        assertEq(totalSupplyStart, 7000000_000000000000000000);
        assertEq(totalSupplyMid, 6000000_000000000000000000);
        assertEq(totalSupplyEnd, 7016180_339887498948000000);

        assertEq(bobBalanceStart, 1000000_000000000000000000);
        assertEq(bobBalanceEnd, 1016180_339887498948000000);

        assertEq(fenix.shareRate(), 1_016180339887498948);
    }

    /// @notice Test minimum stake term return vs max term dilute shorter term
    function test_MinimumStakeTermVsMax() public {
        uint256 bobTerm = 1;
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
        assertEq(bobBalanceStart, 1000000_000000000000000000);
        assertEq(bobBalanceEnd, 498921_153863720572949881);
        assertGt(bobBalanceStart, bobBalanceEnd);
        assertEq(fenix.shareRate(), 1e18);
    }

    /// @notice Test minimum stake term return vs max term longer ends first
    function test_MinimumStakeTermVsMax_BothEnd() public {
        uint256 bobTerm = 1;
        uint256 aliceTerm = fenix.MAX_STAKE_LENGTH_DAYS();
        uint40 blockTs = uint40(block.timestamp);

        uint256 bobBalanceStart = fenix.balanceOf(bob);
        vm.prank(bob);
        fenix.startStake(bobBalanceStart, bobTerm);

        uint256 aliceFenixBalance = fenix.balanceOf(alice);
        vm.prank(alice);
        fenix.startStake(aliceFenixBalance, aliceTerm);

        vm.warp(blockTs + (86_400 * bobTerm));

        vm.prank(alice);
        fenix.endStake(0);

        vm.prank(bob);
        fenix.endStake(0);

        uint256 bobBalanceEnd = fenix.balanceOf(bob);
        uint256 aliceBalanceEnd = fenix.balanceOf(alice);

        assertEq(bobBalanceEnd, 2407793_946024093635194108);
        assertEq(aliceBalanceEnd, 31561148386805892);
        assertGt(bobBalanceEnd, aliceBalanceEnd);
        assertEq(fenix.shareRate(), 2_407793946024093635);
    }

    /// @notice Test minimum stake term return vs max term longer ends first
    function test_MultipleMinimumStakeTermVsOneMax() public {
        uint256 bobTerm = 1;
        uint256 aliceTerm = fenix.MAX_STAKE_LENGTH_DAYS();
        uint40 blockTs = uint40(block.timestamp);

        uint256 bobBalanceStart = fenix.balanceOf(bob);
        vm.prank(bob);
        fenix.startStake(bobBalanceStart, bobTerm);

        uint256 carolBalanceStart = fenix.balanceOf(carol);
        vm.prank(carol);
        fenix.startStake(carolBalanceStart, bobTerm);

        uint256 danBalanceStart = fenix.balanceOf(dan);
        vm.prank(dan);
        fenix.startStake(danBalanceStart, bobTerm);

        uint256 frankBalanceStart = fenix.balanceOf(frank);
        vm.prank(frank);
        fenix.startStake(frankBalanceStart, bobTerm);

        // Long Staker

        uint256 aliceFenixBalance = fenix.balanceOf(alice);
        vm.prank(alice);
        fenix.startStake(aliceFenixBalance, aliceTerm);

        vm.warp(blockTs + (86_400 * bobTerm));

        vm.prank(alice);
        fenix.endStake(0);

        vm.prank(carol);
        fenix.endStake(0);

        vm.prank(dan);
        fenix.endStake(0);

        vm.prank(frank);
        fenix.endStake(0);

        vm.prank(bob);
        fenix.endStake(0);

        uint256 carolBalanceEnd = fenix.balanceOf(carol);
        uint256 danBalanceEnd = fenix.balanceOf(dan);
        uint256 frankBalanceEnd = fenix.balanceOf(frank);
        uint256 bobBalanceEnd = fenix.balanceOf(bob);
        uint256 aliceBalanceEnd = fenix.balanceOf(alice);

        assertEq(carolBalanceEnd, 1351981_465357518297864686);
        assertEq(danBalanceEnd, 1351981_465357518296512705);
        assertEq(frankBalanceEnd, 1351981_465357518298540677);
        assertEq(bobBalanceEnd, 1351981_465357518298540678);
        assertEq(aliceBalanceEnd, 43713110793541254);
        assertGe(bobBalanceEnd, aliceBalanceEnd);
        assertEq(fenix.shareRate(), 1_351981465357518298);
    }

    /// @notice Test single staker with multiple stakes
    function test_MultipleStakes_SingleStaker() public {
        uint16 bobTerm = 2;
        uint40 blockTs = uint40(block.timestamp);

        uint256 firstFENIX = 1000e18;
        uint256 secondFENIX = 1000e18;
        uint256 thirdFENIX = 2000e18;

        fenix.startStake(firstFENIX, bobTerm);
        fenix.startStake(secondFENIX, bobTerm);
        fenix.startStake(thirdFENIX, bobTerm);

        vm.warp(blockTs + (86_400 * bobTerm));

        fenix.endStake(0);
        fenix.endStake(1);
        fenix.endStake(2);

        Stake memory firstStakeEnded = fenix.stakeFor(bob, 0);
        Stake memory secondStakeEnded = fenix.stakeFor(bob, 1);
        Stake memory thirdStakeEnded = fenix.stakeFor(bob, 2);

        assertEq(firstStakeEnded.payout, 999_837743993526233326);
        assertEq(secondStakeEnded.payout, 999_837743993526232469);
        assertEq(thirdStakeEnded.payout, 2000_676326569628570205);

        assertEq(fenix.shareRate(), 1_000338163284814285);
    }
}
