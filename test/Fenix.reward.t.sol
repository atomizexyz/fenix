// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { Fenix, Reward, FenixError } from "@atomize/Fenix.sol";
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

    uint256 internal tenKXen = 100_000e18;

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

        helper.batchDealTo(stakers, tenKXen, address(xenCrypto));
        helper.getFenixFor(stakers, fenix, xenCrypto);
    }

    /// @notice Test that the contract can be deployed successfully
    function test_ReferralReward() public {
        assertEq(fenix.rewardPoolSupply(), 60_000000000000000000); // verify

        assertEq(fenix.rewardCount(), 0); // verify
    }

    /// @notice Test that referral can be flushed to the stake pool
    function test_ReferralRewardToStakePool() public {
        uint256 skipWeeks = 3;
        uint256 startPoolSupply = fenix.equityPoolSupply();

        vm.warp(block.timestamp + (86_400 * 7 * skipWeeks));
        fenix.flushRewardPool();

        uint256 endPoolSupply = fenix.equityPoolSupply();

        assertEq(startPoolSupply, 0); // verify
        assertEq(endPoolSupply, 60_000000000000000000); // verify
        assertEq(fenix.cooldownUnlockTs(), 9676801); // verify
    }

    /// @notice Test referral reward accumulating more referrals
    function test_ReferralRewardAccumulatesMore() public {
        assertEq(fenix.rewardPoolSupply(), 60_000000000000000000); // verify

        helper.batchDealTo(stakers, tenKXen, address(xenCrypto));
        helper.getFenixFor(stakers, fenix, xenCrypto);

        assertEq(fenix.rewardPoolSupply(), 120_000000000000000000); // verify
    }

    /// @notice Test referral reward skipping a cooldown
    function test_ReferralRewardSkipCooldown() public {
        uint256 skipWeeks = 30;
        uint256 startPoolSupply = fenix.equityPoolSupply();

        vm.warp(block.timestamp + (86_400 * 7 * skipWeeks));
        fenix.flushRewardPool();

        uint256 endPoolSupply = fenix.equityPoolSupply();

        assertEq(startPoolSupply, 0); // verify
        assertEq(endPoolSupply, 60_000000000000000000); // verify
        assertEq(fenix.cooldownUnlockTs(), 25401601); // verify
    }

    /// @notice Test referral reward reverting when you try to claim too early
    function test_ReferralReward_RevertWhen_TooEarly() public {
        vm.warp(block.timestamp + 86_400);

        vm.expectRevert(FenixError.CooldownActive.selector); // verify
        fenix.flushRewardPool();
    }

    /// @notice Test referral reward reverting when you try and claim more than once
    function test_ReferralReward_RevertWhen_AlreadyClaimed() public {
        uint256 skipWeeks = 3;

        uint40 warpTs = uint40(block.timestamp + (86_400 * 7 * skipWeeks));
        vm.warp(warpTs);
        fenix.flushRewardPool();

        vm.expectRevert(FenixError.CooldownActive.selector); // verify
        fenix.flushRewardPool();
    }

    /// @notice Test flush reward pool and all caller to Rewards
    function test_FlushRewardPoolAddCallerToRewards() public {
        uint256 skipWeeks = 3;

        uint40 warpTs = uint40(block.timestamp + (86_400 * 7 * skipWeeks));
        vm.warp(warpTs);
        fenix.flushRewardPool();

        assertEq(fenix.rewardCount(), 1); // verify

        Reward memory reward = fenix.rewardFor(0);

        assertEq(reward.id, 0); // verify
        assertEq(reward.rewardTs, warpTs); // verify
        assertEq(reward.fenix, 60_000000000000000000); // verify
        assertEq(reward.caller, address(bob)); // verify
    }
}
