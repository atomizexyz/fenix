// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { Fenix, Stake, FenixEvent, Status, Reward } from "@atomize/Fenix.sol";
import { XENCrypto } from "xen-crypto/XENCrypto.sol";
import { IBurnRedeemable } from "xen-crypto/interfaces/IBurnRedeemable.sol";
import { HelpersTest } from "./Helpers.t.sol";

contract FenixTest is Test {
    HelpersTest internal helper;
    Fenix internal fenix;
    XENCrypto internal xenCrypto;

    address internal bob = address(this);

    address[] internal stakers;

    uint256 internal term = 100;
    uint256 internal oneHundredKXen = 100_000e18;

    event Redeemed(
        address indexed user,
        address indexed xenContract,
        address indexed tokenContract,
        uint256 xenAmount,
        uint256 tokenAmount
    );

    /// ============ Setup test suite ============

    function setUp() public {
        helper = new HelpersTest();
        vm.broadcast(helper.xenDeployerPrivateKey());
        xenCrypto = new XENCrypto();

        fenix = new Fenix();

        stakers.push(bob);

        helper.batchDealTo(stakers, oneHundredKXen, address(xenCrypto));
        helper.getFenixFor(stakers, fenix, xenCrypto);
    }

    /// @notice Test fenix minted event is emitted
    function test_RedeemedEvent() public {
        vm.expectEmit(true, true, false, false, address(fenix));
        emit Redeemed(
            address(bob),
            address(xenCrypto),
            address(fenix),
            100000_000000000000000000,
            100_000000000000000000
        );

        vm.prank(address(xenCrypto));
        fenix.onTokenBurned(bob, oneHundredKXen);
    }

    /// @notice Test that the start stake event is emitted
    function test_StartStakeEvent() public {
        Stake memory verifyStake = Stake(
            Status.ACTIVE,
            1,
            0,
            8640001,
            uint16(term),
            10_000000000000000000,
            24_895034858800962760,
            0
        );

        vm.expectEmit(true, false, false, false);
        emit FenixEvent.StartStake(verifyStake);

        fenix.startStake(fenix.balanceOf(bob), term);
        // helper.printStake(fenix.stakeFor(bob, 0));
    }

    /// @notice Test that the defer stake event is emitted
    function test_DeferStakeEvent() public {
        uint40 blockTs = uint40(block.timestamp);

        Stake memory verifyDeferral = Stake(
            Status.DEFER,
            1,
            8640001,
            8640001,
            uint16(term),
            10_000000000000000000,
            24_895034858800962760,
            10_044071717152961500
        );

        fenix.startStake(fenix.balanceOf(bob), term);

        vm.warp(blockTs + (86_400 * term));

        vm.expectEmit(true, false, false, false);
        emit FenixEvent.DeferStake(verifyDeferral);

        fenix.deferStake(0, bob);
        // helper.printStake(fenix.stakeFor(bob, 0));
    }

    /// @notice Test that the end stake event is emitted
    function test_EndStakeEvent() public {
        uint40 blockTs = uint40(block.timestamp);

        Stake memory verifyEnd = Stake(
            Status.END,
            1,
            8640001,
            8640001,
            uint16(term),
            10_000000000000000000,
            24_895034858800962760,
            10_044071717152961500
        );

        fenix.startStake(fenix.balanceOf(bob), term);

        vm.warp(blockTs + (86_400 * term));

        vm.expectEmit(true, false, false, false);
        emit FenixEvent.EndStake(verifyEnd);

        fenix.endStake(0);
        // helper.printStake(fenix.stakeFor(bob, 0));
    }

    /// @notice Test flush reward pool event is emitted
    function test_FlushRewardPoolEvent() public {
        uint40 blockTs = uint40(block.timestamp);

        uint40 warpTs = blockTs + (86_400 * 180) + 1;
        vm.warp(warpTs);

        Reward memory verifyReward = Reward(0, warpTs, 10e18, address(bob));

        vm.expectEmit(false, false, false, false);
        emit FenixEvent.FlushRewardPool(verifyReward);

        fenix.flushRewardPool();
    }

    /// @notice Test share rate update event
    function test_UpdateShareRateEvent() public {
        uint40 blockTs = uint40(block.timestamp);
        uint256 oneYearTerm = 365;

        fenix.startStake(fenix.balanceOf(bob), oneYearTerm);

        vm.warp(blockTs + (86_400 * oneYearTerm));

        vm.expectEmit(true, false, false, false);
        emit FenixEvent.UpdateShareRate(1_016180339887498948);

        fenix.endStake(0);
        // console.log(fenix.shareRate());
    }
}
