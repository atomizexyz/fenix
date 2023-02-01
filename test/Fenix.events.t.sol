// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

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

        helper.dealXENTo(stakers, tenKXen, xenCrypto);
        helper.getFenixFor(stakers, fenix, xenCrypto);
    }

    /// @notice Test fenix minted event is emitted
    function test_fenixMinted_Event() public {
        vm.expectEmit(true, true, false, false);
        emit FenixEvent.FenixMinted(address(bob), 10_000000000000000000);

        helper.dealXENTo(stakers, tenKXen, xenCrypto);
        helper.getFenixFor(stakers, fenix, xenCrypto);
    }

    /// @notice Test that the start stake event is emitted
    function test_StartStake_Event() public {
        Stake memory verifyStake = Stake(
            Status.ACTIVE,
            1,
            0,
            0,
            term,
            10_000000000000000000,
            11_512197025131802050,
            11_512197025131802050,
            0
        );

        uint256 bobFenixBalance = fenix.balanceOf(bob);

        vm.expectEmit(true, false, false, false);
        emit FenixEvent.StartStake(verifyStake);

        fenix.startStake(bobFenixBalance, term);
    }

    /// @notice Test that the defer stake event is emitted
    function test_deferStake_Event() public {
        uint40 blockTs = uint40(block.timestamp);

        Stake memory verifyDeferral = Stake(
            Status.DEFER,
            1,
            8640001,
            0,
            term,
            10_000000000000000000,
            11_512197025131802050,
            11_512197025131802050,
            10_000000000000000001
        );

        fenix.startStake(fenix.balanceOf(bob), term);

        vm.warp(blockTs + (86_400 * term));

        vm.expectEmit(true, false, false, false);
        emit FenixEvent.DeferStake(verifyDeferral);

        fenix.deferStake(0, bob);
    }

    /// @notice Test that the end stake event is emitted
    function test_endStake_Event() public {
        uint40 blockTs = uint40(block.timestamp);

        Stake memory verifyEnd = Stake(
            Status.END,
            1,
            8640001,
            0,
            term,
            10_000000000000000000,
            11_512197025131802050,
            11_512197025131802050,
            10_000000000000000001
        );

        uint256 bobFenixBalance = fenix.balanceOf(bob);

        fenix.startStake(bobFenixBalance, term);

        vm.warp(blockTs + (86_400 * term));

        vm.expectEmit(true, false, false, false);
        emit FenixEvent.EndStake(verifyEnd);

        fenix.endStake(0);
    }

    /// @notice Test flush reward pool event is emitted
    function test_flushRewardPool_Event() public {
        uint40 blockTs = uint40(block.timestamp);

        vm.warp(blockTs + (86_400 * 180) + 1);

        vm.expectEmit(false, false, false, false);
        emit FenixEvent.RewardPoolFlush();

        fenix.flushRewardPool();
    }
}
