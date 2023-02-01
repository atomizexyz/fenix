// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { Fenix, FenixError } from "@atomize/Fenix.sol";
import { XENCrypto } from "xen-crypto/XENCrypto.sol";
import { HelpersTest } from "./Helpers.t.sol";

contract AdoptionRewardTest is Test {
    HelpersTest internal helper;
    Fenix internal fenix;
    XENCrypto internal xenCrypto;

    address internal bob = address(this);
    address internal alice = vm.addr(1);
    address internal carol = vm.addr(2);
    address internal dan = vm.addr(3);
    address internal frank = vm.addr(4);
    address internal oscar = vm.addr(5);
    address internal chad = vm.addr(5);

    address[] internal stakers;

    uint256 tenKXen = 100_000e18;

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
        stakers.push(oscar);

        helper.dealXENTo(stakers, tenKXen, xenCrypto);
        helper.getFenixFor(stakers, fenix, xenCrypto);
    }

    /// @notice Test that the contract can be deployed successfully
    function test_referralReward() public {
        assertEq(fenix.rewardPoolSupply(), 60_000000000000000000); // verify
    }

    /// @notice Test that referral can be flushed to the stake pool
    function test_referralRewardToStakePool() public {
        uint256 skipWeeks = 3;
        uint256 startSupply = fenix.stakePoolSupply();

        vm.warp(block.timestamp + (86_400 * 7 * skipWeeks));
        fenix.flushRewardPool();

        uint256 endSupply = fenix.stakePoolSupply();

        assertEq(startSupply, 1); // verify
        assertEq(endSupply, 60_000000000000000001); // verify
        assertEq(fenix.cooldownUnlockTs(), 9676801); // verify
    }

    /// @notice Test referral reward accumulating more referrals
    function test_referralRewardAccumulatesMore() public {
        assertEq(fenix.rewardPoolSupply(), 60_000000000000000000); // verify

        helper.dealXENTo(stakers, tenKXen, xenCrypto);
        helper.getFenixFor(stakers, fenix, xenCrypto);

        assertEq(fenix.rewardPoolSupply(), 120_000000000000000000); // verify
    }

    /// @notice Test referral reward skipping a cooldown
    function test_referralRewardSkipCooldown() public {
        uint256 skipWeeks = 30;
        uint256 startSupply = fenix.stakePoolSupply();

        vm.warp(block.timestamp + (86_400 * 7 * skipWeeks));
        fenix.flushRewardPool();

        uint256 endSupply = fenix.stakePoolSupply();

        assertEq(startSupply, 1); // verify
        assertEq(endSupply, 60_000000000000000001); // verify
        assertEq(fenix.cooldownUnlockTs(), 25401601); // verify
    }

    /// @notice Test referral reward reverting if you try to claim too early
    function test_referralReward_RevertIf_TooEarly() public {
        vm.warp(block.timestamp + 86_400);

        vm.expectRevert(FenixError.CooldownActive.selector); // verify
        fenix.flushRewardPool();
    }

    /// @notice Test referral reward reverting if you try and claim more than once
    function test_referralReward_RevertIf_AlreadyClaimed() public {
        uint256 skipWeeks = 3;

        vm.warp(block.timestamp + (86_400 * 7 * skipWeeks));
        fenix.flushRewardPool();

        vm.expectRevert(FenixError.CooldownActive.selector); // verify
        fenix.flushRewardPool();
    }
}
