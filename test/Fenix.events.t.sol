// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { Fenix, Stake, FenixEvent, Status } from "@atomize/Fenix.sol";
import { XENCrypto } from "xen-crypto/XENCrypto.sol";
import { HelpersTest } from "./Helpers.t.sol";

contract FenixTest is Test {
    HelpersTest internal helper;
    Fenix internal fenix;
    XENCrypto internal xenCrypto;

    address internal bob = address(this);

    address[] internal stakers;

    /// ============ Setup test suite ============

    function setUp() public {
        helper = new HelpersTest();
        vm.broadcast(helper.xenDeployerPrivateKey());
        xenCrypto = new XENCrypto();

        stakers.push(bob);
        helper.generateXENFor(stakers, xenCrypto);
        fenix = new Fenix();
    }

    /// @notice Test fenix minted event is emitted
    function testFenixMintedEvnet() public {
        vm.expectEmit(true, true, false, false);
        emit FenixEvent.FenixMinted(address(bob), 330000000000000000);

        helper.getFenixFor(stakers, fenix, xenCrypto);
    }

    /// @notice Test that the start stake event is emitted
    function testStartStakeEvnet() public {
        helper.getFenixFor(stakers, fenix, xenCrypto);

        uint256 baseTerm = 100;
        Stake memory verifyStake = Stake(
            Status.ACTIVE,
            86402,
            0,
            0,
            baseTerm,
            330000000000000000,
            379902501829349467,
            379902501829349467,
            0
        );

        uint256 bobFenixBalance = fenix.balanceOf(bob);

        vm.expectEmit(true, false, false, false);
        emit FenixEvent.StartStake(verifyStake);

        vm.prank(bob);
        fenix.startStake(bobFenixBalance, baseTerm);
    }

    /// @notice Test that the defer stake event is emitted
    function testDeferStakeEvnet() public {
        helper.getFenixFor(stakers, fenix, xenCrypto);

        uint256 baseTerm = 100;
        uint40 blockTs = uint40(block.timestamp);

        Stake memory verifyDeferral = Stake(
            Status.DEFER,
            86402,
            8726402,
            0,
            baseTerm,
            330000000000000000,
            379902501829349467,
            379902501829349467,
            330000000000000001
        );

        uint256 bobFenixBalance = fenix.balanceOf(bob);

        vm.prank(bob);
        fenix.startStake(bobFenixBalance, baseTerm);

        vm.warp(blockTs + (86_400 * baseTerm));

        vm.expectEmit(true, false, false, false);
        emit FenixEvent.DeferStake(verifyDeferral);

        vm.prank(bob);
        fenix.deferStake(0, bob);
    }

    /// @notice Test that the end stake event is emitted
    function testEndStakeEvnet() public {
        helper.getFenixFor(stakers, fenix, xenCrypto);

        uint256 baseTerm = 100;
        uint40 blockTs = uint40(block.timestamp);

        Stake memory verifyEnd = Stake(
            Status.END,
            86402,
            8726402,
            0,
            baseTerm,
            330000000000000000,
            379902501829349467,
            379902501829349467,
            330000000000000001
        );

        uint256 bobFenixBalance = fenix.balanceOf(bob);

        vm.prank(bob);
        fenix.startStake(bobFenixBalance, baseTerm);

        vm.warp(blockTs + (86_400 * baseTerm));

        vm.expectEmit(true, false, false, false);
        emit FenixEvent.EndStake(verifyEnd);

        vm.prank(bob);
        fenix.endStake(0);
    }

    /// @notice Test big bonus event is emitted
    function testClaimBigBonusEvent() public {
        helper.getFenixFor(stakers, fenix, xenCrypto);

        uint40 blockTs = uint40(block.timestamp);

        vm.warp(blockTs + (86_400 * 180) + 1);

        vm.expectEmit(false, false, false, false);
        emit FenixEvent.ClaimBigBonus();

        fenix.claimBigBonus();
    }
}
