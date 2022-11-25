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
        fenix = new Fenix(xenAddress);
    }

    /// @notice Test starting stake works
    function testStartStakes() public {
        address userAddr = address(this);
        _getFenixFor(userAddr);

        uint256 fenixBalance = fenix.balanceOf(address(this));
        uint256 feinxHalfBalance = fenixBalance / 2;

        assertEq(fenix.currentStakeId(), 0);

        fenix.startStake(feinxHalfBalance / 2, 100);

        assertEq(fenix.currentStakeId(), 1);

        fenix.startStake(feinxHalfBalance / 2, 100);
        assertEq(fenix.currentStakeId(), 2);

        assertEq(fenix.stakeCount(userAddr), 2);

        assertEq(fenix.stakeFor(userAddr, 0).stakeId, 0);
        assertEq(fenix.stakeFor(userAddr, 1).stakeId, 1);
    }

    /// Helpers

    function _getFenixFor(address user) public {
        address userAddress = address(user);
        address fenixAddr = address(fenix);
        uint256 timestamp = block.timestamp;
        xenCrypto.claimRank(1);
        vm.warp(timestamp + (86400 * 1) + 1);
        xenCrypto.claimMintReward();

        uint256 balancePreBurn = xenCrypto.balanceOf(userAddress);

        xenCrypto.approve(fenixAddr, balancePreBurn);

        fenix.burnXEN(balancePreBurn);
    }
}
