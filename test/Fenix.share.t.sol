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

    /// ============ Setup test suite ============

    function setUp() public {
        helper = new HelpersTest();
        vm.broadcast(helper.xenDeployerPrivateKey());
        xenCrypto = new XENCrypto();

        stakers.push(bob);
        stakers.push(alice);

        helper.generateXENFor(stakers, xenCrypto);
        fenix = new Fenix();
    }

    /// @notice Test that the contract can be deployed successfully
    function testShareRateUpdate() public {
        helper.getFenixFor(stakers, fenix, xenCrypto);
        uint256 term = 100;

        uint256 fenixBalance = fenix.balanceOf(bob);
        vm.prank(bob);
        fenix.startStake(fenixBalance, term);

        vm.warp(block.timestamp + (86_400 * term));
        vm.prank(bob);
        fenix.endStake(0);

        assertGt(fenix.shareRate(), 1e18); // verify
        assertEq(fenix.shareRate(), 3_603417208195420921); // verify
        assertEq(fenix.poolSupply(), 0); // verify
    }

    /// @notice Test that the contract can be deployed successfully
    function testShortVsLongShareUpdate() public {
        helper.getFenixFor(stakers, fenix, xenCrypto);
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
        assertEq(fenix.poolSupply(), 0); // verify
    }
}
