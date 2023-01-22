// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { Fenix, Stake, Status } from "@atomize/Fenix.sol";
import { XENCrypto } from "xen-crypto/XENCrypto.sol";
import { HelpersTest } from "./Helpers.t.sol";

contract FenixPenaltyTest is Test {
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

    /// @notice Test stake penality
    function testCalculateEarlyPenalty() public {
        uint256 base = 13.81551 * 1e18;
        uint256 bonus = 2.77069 * 1e18;

        uint40 blockTs = uint40(block.timestamp);
        Stake memory stake1 = Stake(Status.ACTIVE, blockTs, 0, 1, 100, base, bonus, base + bonus, 0);

        vm.warp(blockTs + (86400 * 0));
        uint256 penalty0 = fenix.calculateEarlyPenalty(stake1);
        assertEq(penalty0, 1000000000000000000); // verify 100% penalty

        vm.warp(blockTs + (86400 * 25));
        uint256 penalty25 = fenix.calculateEarlyPenalty(stake1);
        assertEq(penalty25, 996093750000000000); // verify 94% penalty

        vm.warp(blockTs + (86400 * 50));
        uint256 penalty50 = fenix.calculateEarlyPenalty(stake1);
        assertEq(penalty50, 937500000000000000); // verify 75% penalty

        vm.warp(blockTs + (86400 * 75));
        uint256 penalty75 = fenix.calculateEarlyPenalty(stake1);
        assertEq(penalty75, 683593750000000000); // verify 43% penalty

        vm.warp(blockTs + (86400 * 100));
        uint256 penalty100 = fenix.calculateEarlyPenalty(stake1);
        assertEq(penalty100, 0); // verify 0% penalty
    }

    function testCalculateLatePenalty() public {
        uint256 base = 13.81551 * 1e18;
        uint256 bonus = 2.77069 * 1e18;
        uint256 baseTerm = 100;

        uint40 blockTs = uint40(block.timestamp);
        Stake memory stake1 = Stake(Status.ACTIVE, blockTs, 0, 1, baseTerm, base, bonus, base + bonus, 0);

        vm.warp(blockTs + (86400 * baseTerm));
        uint256 penalty0 = fenix.calculateLatePenalty(stake1);
        assertEq(penalty0, 0); // verify 0% penalty

        vm.warp(blockTs + (86400 * (baseTerm + 90)));
        uint256 penalty50 = fenix.calculateLatePenalty(stake1);
        assertEq(penalty50, 125000000000000000); // verify 12.5% penality

        vm.warp(blockTs + (86400 * (baseTerm + 180)));
        uint256 penalty100 = fenix.calculateLatePenalty(stake1);
        assertEq(penalty100, 1000000000000000000); // verify 100% penalty

        vm.warp(blockTs + (86400 * (baseTerm + 360)));
        uint256 penalty200 = fenix.calculateLatePenalty(stake1);
        assertEq(penalty200, 1000000000000000000); // verify 100% penalty
    }
}
