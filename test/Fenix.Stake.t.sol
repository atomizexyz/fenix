// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { Fenix, Stake } from "src/Fenix.sol";
import { XENCrypto } from "xen-crypto/XENCrypto.sol";

contract FenixStakeTest is Test {
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
        xenCrypto = new XENCrypto();
        address xenAddress = address(xenCrypto);

        stakers.push(bob);
        stakers.push(alice);
        stakers.push(carol);
        stakers.push(dan);
        stakers.push(frank);

        _generateXENFor(stakers);
        fenix = new Fenix(xenAddress);
    }

    /// @notice Test starting stake works
    function testStartStakes() public {
        _getFenixFor(stakers);

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
        uint256 deferTerm = 100;
        _getFenixFor(stakers);

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
        uint256 deferTerm = 100;
        _getFenixFor(stakers);

        uint256 fenixBalance = fenix.balanceOf(bob);
        fenix.startStake(fenixBalance, deferTerm);

        vm.warp(block.timestamp + (86400 * deferTerm) + 1);
        fenix.deferStake(0, bob);

        assertEq(fenix.deferralCount(bob), 1);
        assertEq(fenix.deferralFor(bob, 0).stakeId, 0);
        assertEq(fenix.deferralFor(bob, 0).payout, 38511844885099801535056);
    }

    /// @notice Test ending early stake
    function testEndingEarlyStake() public {
        uint256 endTerm = 100;
        _getFenixFor(stakers);

        uint256 fenixBalance = fenix.balanceOf(bob);
        fenix.startStake(fenixBalance, endTerm);

        vm.warp(block.timestamp + (86400 * endTerm));
        fenix.endStake(0);

        uint256 fenixPayoutBalance = fenix.balanceOf(bob);

        assertEq(fenixPayoutBalance, 46173844885099801535056);
    }

    /// @notice Test multiple stakes
    function testMultipleStakes() public {
        _getFenixFor(stakers);
    }

    /// Helpers
    function _getFenixFor(address[] memory users) public {
        for (uint256 i = 0; i < users.length; i++) {
            address userAddress = address(users[i]);
            address fenixAddr = address(fenix);
            uint256 balancePreBurn = xenCrypto.balanceOf(userAddress);

            vm.prank(users[i]);
            xenCrypto.approve(fenixAddr, balancePreBurn);

            vm.prank(users[i]);
            fenix.burnXEN(balancePreBurn);
        }
    }

    function _generateXENFor(address[] memory users) public {
        uint256 timestamp = block.timestamp;

        for (uint256 i = 0; i < users.length; i++) {
            vm.prank(users[i]);
            xenCrypto.claimRank(1);
        }

        vm.warp(timestamp + (86400 * 1) + 1);

        for (uint256 i = 0; i < users.length; i++) {
            vm.prank(users[i]);
            xenCrypto.claimMintReward();
        }
    }
}
