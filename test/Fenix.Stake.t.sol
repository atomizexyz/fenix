// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { Fenix, Stake } from "src/Fenix.sol";
import { XENCrypto } from "xen-crypto/XENCrypto.sol";

contract FenixStakeTest is Test {
    Fenix internal fenix;
    XENCrypto internal xenCrypto;

    /// ============ Setup test suite ============

    function setUp() public {
        xenCrypto = new XENCrypto();
        address xenAddress = address(xenCrypto);
        _generateXEN();
        fenix = new Fenix(xenAddress);
    }

    /// @notice Test starting stake works
    function testStartStakes() public {
        address stakerAddress = address(this);
        _getFenixFor(stakerAddress);

        uint256 fenixBalance = fenix.balanceOf(address(this));
        uint256 feinxHalfBalance = fenixBalance / 2;

        assertEq(fenix.currentStakeId(), 0);

        fenix.startStake(feinxHalfBalance / 2, 100);

        assertEq(fenix.currentStakeId(), 1);

        fenix.startStake(feinxHalfBalance / 2, 100);
        assertEq(fenix.currentStakeId(), 2);

        assertEq(fenix.stakeCount(stakerAddress), 2);

        assertEq(fenix.stakeFor(stakerAddress, 0).stakeId, 0);
        assertEq(fenix.stakeFor(stakerAddress, 1).stakeId, 1);
    }

    /// @notice Test deferring stake
    function testDeferStake() public {
        uint256 term = 100;
        address stakerAddress = address(this);
        _getFenixFor(stakerAddress);

        uint256 fenixBalance = fenix.balanceOf(address(this));
        fenix.startStake(fenixBalance, term);

        vm.warp(block.timestamp + (86400 * term));
        fenix.deferStake(0, stakerAddress);

        assertEq(fenix.deferralCount(stakerAddress), 1);
        assertEq(fenix.deferralFor(stakerAddress, 0).stakeId, 0);
    }

    /// Helpers
    function _getFenixFor(address user) public {
        address userAddress = address(user);
        address fenixAddr = address(fenix);
        uint256 balancePreBurn = xenCrypto.balanceOf(userAddress);
        xenCrypto.approve(fenixAddr, balancePreBurn);
        fenix.burnXEN(balancePreBurn);
    }

    function _generateXEN() public {
        uint256 timestamp = block.timestamp;
        xenCrypto.claimRank(1);
        vm.warp(timestamp + (86400 * 1) + 1);
        xenCrypto.claimMintReward();
    }
}
