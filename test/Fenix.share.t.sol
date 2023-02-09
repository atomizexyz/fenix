// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { Fenix } from "@atomize/Fenix.sol";
import { XENCrypto } from "xen-crypto/XENCrypto.sol";
import { HelpersTest } from "./Helpers.t.sol";

contract FenixShareTest is Test {
    HelpersTest internal helper;
    Fenix internal fenix;
    XENCrypto internal xenCrypto;

    address internal bob = address(this);
    address internal alice = vm.addr(1);

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

        helper.batchDealTo(stakers, tenKXen, address(xenCrypto));
        helper.getFenixFor(stakers, fenix, xenCrypto);
    }

    /// @notice Test that the contract can be deployed successfully
    function testShareRateUpdate() public {
        uint256 term = 3650;

        fenix.startStake(fenix.balanceOf(bob), term);

        vm.warp(block.timestamp + (86_400 * term));
        fenix.endStake(0);

        assertGt(fenix.shareRate(), 1e18); // verify
        assertEq(fenix.shareRate(), 33_360679774997896960); // verify
        assertEq(fenix.stakePoolSupply(), 0); // verify
    }

    /// @notice Test that the contract can be deployed successfully
    function testShortVsLongShareUpdate() public {
        uint256 shortTerm = 1;
        uint256 longTerm = 4;

        uint256 blockTs = block.timestamp;

        uint256 aliceLongUpdateBalance = fenix.balanceOf(alice);
        vm.prank(alice);
        fenix.startStake(aliceLongUpdateBalance, longTerm);

        for (uint256 i = 0; i < longTerm; i++) {
            uint256 bobShortUpdateBalance = fenix.balanceOf(bob);
            vm.prank(bob);
            fenix.startStake(bobShortUpdateBalance, shortTerm);

            uint256 termInterval = i + 1;

            vm.warp(blockTs + (86_400 * (termInterval * shortTerm)));
            vm.prank(bob);
            fenix.endStake(i);
        }

        vm.warp(blockTs + (86_400 * (longTerm)));
        vm.prank(alice);
        fenix.endStake(0);

        uint256 bobFinalBalance = fenix.balanceOf(bob);
        uint256 aliceFinalBalance = fenix.balanceOf(alice);

        assertGt(aliceFinalBalance, bobFinalBalance); // verify
        assertEq(fenix.stakePoolSupply(), 0); // verify
    }
}
