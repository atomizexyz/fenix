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

        helper.dealXENTo(stakers, tenKXen, xenCrypto);
        helper.getFenixFor(stakers, fenix, xenCrypto);
    }

    /// @notice Test that the contract can be deployed successfully
    function testShareRateUpdate() public {
        uint256 term = 3650;

        fenix.startStake(fenix.balanceOf(bob), term);

        vm.warp(block.timestamp + (86_400 * term));
        fenix.endStake(0);

        assertGt(fenix.shareRate(), 1e18); // verify
        assertEq(fenix.shareRate(), 1_000000000000001512); // verify
        assertEq(fenix.stakePoolSupply(), 0); // verify
    }

    /// @notice Test that the contract can be deployed successfully
    function testShortVsLongShareUpdate() public {
        uint256 launchTerm = 1;
        uint256 shortTerm = 1;
        uint256 longTerm = 10;

        uint256 blockTs = block.timestamp;

        // Allow each person to claim launch bonus
        uint256 aliceFenixBalance = fenix.balanceOf(alice);
        vm.prank(alice);
        fenix.startStake(aliceFenixBalance, launchTerm);

        uint256 bobFenixBalance = fenix.balanceOf(bob);
        vm.prank(bob);
        fenix.startStake(bobFenixBalance, launchTerm);

        vm.warp(blockTs + (86_400 * launchTerm));

        vm.prank(bob);
        fenix.endStake(0);

        vm.prank(alice);
        fenix.endStake(0);

        // Start testing long term vs short term stake

        uint256 aliceLongUpdateBalance = fenix.balanceOf(alice);
        vm.prank(alice);
        fenix.startStake(aliceLongUpdateBalance, longTerm);

        for (uint256 i = shortTerm; i <= longTerm; i++) {
            uint256 bobShortUpdateBalance = fenix.balanceOf(bob);
            vm.prank(bob);
            fenix.startStake(bobShortUpdateBalance, shortTerm);

            vm.warp(blockTs + (86_400 * (i + launchTerm)));
            vm.prank(bob);
            fenix.endStake(i);
        }

        vm.warp(blockTs + (86_400 * (longTerm + launchTerm)));
        vm.prank(alice);
        fenix.endStake(1);

        uint256 bobFinalBalance = fenix.balanceOf(bob);
        uint256 aliceFinalBalance = fenix.balanceOf(alice);

        assertGt(aliceFinalBalance, bobFinalBalance); // verify
        assertEq(fenix.stakePoolSupply(), 0); // verify
    }
}
