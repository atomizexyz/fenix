// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { Fenix, Stake, FenixEvent, Status } from "@atomize/Fenix.sol";
import { XENCrypto } from "xen-crypto/XENCrypto.sol";
import { HelpersTest } from "./Helpers.t.sol";

contract FenixTest is Test {
    HelpersTest internal helper;
    Fenix internal fenix;
    XENCrypto internal xenCrypto;

    address internal bob = address(this);

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

        helper.batchDealTo(stakers, tenKXen, address(xenCrypto));
        helper.getFenixFor(stakers, fenix, xenCrypto);
    }

    /// @notice Test fenix minted event is emitted
    function testFenixMintedEvent() public {
        vm.expectEmit(true, true, false, false);
        emit FenixEvent.MintFenix(address(bob), 10_000000000000000000);

        helper.batchDealTo(stakers, tenKXen, address(xenCrypto));
        helper.getFenixFor(stakers, fenix, xenCrypto);
    }

    /// @notice Test that the start stake event is emitted
    function testStartStakeEvent() public {
        Stake memory verifyStake = Stake(
            Status.ACTIVE,
            1,
            0,
            uint16(term),
            10_000000000000000000,
            24_78579958393365129,
            0
        );

        vm.expectEmit(true, false, false, false);
        emit FenixEvent.StartStake(verifyStake);

        fenix.startStake(fenix.balanceOf(bob), term);
        // helper.printStake(fenix.stakeFor(bob, 0));
    }

    /// @notice Test that the defer stake event is emitted
    function testDeferStakeEvent() public {
        uint40 blockTs = uint40(block.timestamp);

        Stake memory verifyDeferral = Stake(
            Status.DEFER,
            1,
            8640001,
            uint16(term),
            10_000000000000000000,
            24_78579958393365129,
            14_432969832191492720
        );

        fenix.startStake(fenix.balanceOf(bob), term);

        vm.warp(blockTs + (86_400 * term));

        vm.expectEmit(true, false, false, false);
        emit FenixEvent.DeferStake(verifyDeferral);

        fenix.deferStake(0, bob);
        // helper.printStake(fenix.stakeFor(bob, 0));
    }

    /// @notice Test that the end stake event is emitted
    function testEndStakeEvent() public {
        uint40 blockTs = uint40(block.timestamp);

        Stake memory verifyEnd = Stake(
            Status.END,
            1,
            8640001,
            uint16(term),
            10_000000000000000000,
            24_78579958393365129,
            14_432969832191492720
        );

        fenix.startStake(fenix.balanceOf(bob), term);

        vm.warp(blockTs + (86_400 * term));

        vm.expectEmit(true, false, false, false);
        emit FenixEvent.EndStake(verifyEnd);

        fenix.endStake(0);
        // helper.printStake(fenix.stakeFor(bob, 0));
    }

    /// @notice Test flush reward pool event is emitted
    function testFlushRewardPoolEvent() public {
        uint40 blockTs = uint40(block.timestamp);

        vm.warp(blockTs + (86_400 * 180) + 1);

        vm.expectEmit(false, false, false, false);
        emit FenixEvent.FlushRewardPool();

        fenix.flushRewardPool();
    }

    /// @notice Test share rate update event
    function testUpdateShareRateEvent() public {
        uint40 blockTs = uint40(block.timestamp);
        uint256 oneYearTerm = 365;

        fenix.startStake(fenix.balanceOf(bob), oneYearTerm);

        vm.warp(blockTs + (86_400 * oneYearTerm));

        vm.expectEmit(true, false, false, false);
        emit FenixEvent.UpdateShareRate(2_618033988749894848);

        fenix.endStake(0);
        // console.log(fenix.shareRate());
    }
}
