// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { Fenix } from "@atomize/Fenix.sol";
import { XENCrypto } from "xen-crypto/XENCrypto.sol";
import { HelpersTest } from "./Helpers.t.sol";

contract BigBonusTest is Test {
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

    error BonusNotActive();
    error BonusClaimed();

    /// ============ Setup test suite ============

    function setUp() public {
        helper = new HelpersTest();
        vm.broadcast(helper.xenDeployerPrivateKey());
        xenCrypto = new XENCrypto();

        stakers.push(bob);
        stakers.push(alice);
        stakers.push(carol);
        stakers.push(dan);
        stakers.push(frank);
        stakers.push(oscar);

        helper.generateXENFor(stakers, xenCrypto);

        fenix = new Fenix();
    }

    /// @notice Test that the contract can be deployed successfully
    function testBigBonus() public {
        helper.getFenixFor(stakers, fenix, xenCrypto);

        uint256 currentSupply = fenix.poolSupply();

        vm.warp(block.timestamp + (8_6400 * 180) + 1);
        fenix.claimBigBonus();

        uint256 newSupply = fenix.poolSupply();
        assertEq(currentSupply, 3_462200000000000000);
        assertEq(newSupply, 3_462200000000000000);
    }

    function testClaimBigBonusMoreStakes() public {
        helper.getFenixFor(stakers, fenix, xenCrypto);
        uint256 currentSupply = fenix.poolSupply();

        helper.generateXENFor(stakers, xenCrypto);

        vm.warp(block.timestamp + (86_400 * 180) + 1);
        fenix.claimBigBonus();

        uint256 newSupply = fenix.poolSupply();
        assertEq(currentSupply, 3_462200000000000000);
        assertEq(newSupply, 6_922900000000000000);
    }

    function testClaimBigBonusTooEarly() public {
        helper.getFenixFor(stakers, fenix, xenCrypto);

        helper.generateXENFor(stakers, xenCrypto);

        vm.warp(block.timestamp + (86_400 * 179) - fenix.startTs());
        vm.expectRevert(BonusNotActive.selector);
        fenix.claimBigBonus();
    }

    function testClaimBigBonusOnlyOnce() public {
        helper.getFenixFor(stakers, fenix, xenCrypto);

        helper.generateXENFor(stakers, xenCrypto);

        vm.warp(block.timestamp + (86_400 * 180));
        fenix.claimBigBonus();
        vm.expectRevert(BonusClaimed.selector);
        fenix.claimBigBonus();
    }
}
