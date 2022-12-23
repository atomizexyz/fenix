// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { Fenix, Stake } from "@atomize/Fenix.sol";
import { XENCrypto } from "xen-crypto/XENCrypto.sol";
import { HelpersTest } from "./Helpers.t.sol";

contract FenixBigBonusTest is Test {
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

        vm.warp(block.timestamp + (86400 * 180) + 1);
        fenix.bigBonus();

        uint256 newSupply = fenix.poolSupply();
        assertEq(currentSupply, 3462200000000000000);
        assertEq(newSupply, 3462200000000000000);
    }

    function testBigBonusMoreStakes() public {
        helper.getFenixFor(stakers, fenix, xenCrypto);
        uint256 currentSupply = fenix.poolSupply();

        helper.generateXENFor(stakers, xenCrypto);

        vm.warp(block.timestamp + (86400 * 180) + 1);
        fenix.bigBonus();

        uint256 newSupply = fenix.poolSupply();
        assertEq(currentSupply, 3462200000000000000);
        assertEq(newSupply, 6922900000000000000);
    }

    function testBigBonusTooEarly() public {
        helper.getFenixFor(stakers, fenix, xenCrypto);

        helper.generateXENFor(stakers, xenCrypto);

        vm.warp(block.timestamp + (86_400 * 179) - fenix.startTs());
        vm.expectRevert(bytes("Big bonus not active"));
        fenix.bigBonus();
    }

    function testBigBonusOnlyOnce() public {
        helper.getFenixFor(stakers, fenix, xenCrypto);

        helper.generateXENFor(stakers, xenCrypto);

        vm.warp(block.timestamp + (86_400 * 180));
        fenix.bigBonus();
        vm.expectRevert(bytes("Big bonus already claimed"));
        fenix.bigBonus();
    }
}
