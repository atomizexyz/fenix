// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { Fenix, Stake, Status } from "@atomize/Fenix.sol";
import { XENCrypto } from "xen-crypto/XENCrypto.sol";
import { HelpersTest } from "./Helpers.t.sol";

contract AuditTest is Test {
    HelpersTest internal helper;
    Fenix internal fenix;
    XENCrypto internal xenCrypto;

    address internal bob = address(this);
    // address internal alice = vm.addr(1);
    // address internal carol = vm.addr(2);
    // address internal dan = vm.addr(3);
    // address internal frank = vm.addr(4);
    // address internal chad = vm.addr(5);
    // address internal oscar = vm.addr(6);

    address[] internal stakers;
    uint256 internal tenBillionXEN = 10_000_000_000e18;

    /// ============ Setup test suite ============

    function setUp() public {
        helper = new HelpersTest();

        vm.broadcast(helper.xenDeployerPrivateKey());
        xenCrypto = new XENCrypto();

        fenix = new Fenix();
    }

    function testStartStakeInflation_Year() public {
        inflationHelper(365, 1_016_180_339887498948000000); // verify 1 year
    }

    function testStartStakeInflation_2Year() public {
        inflationHelper(730, 1_032_622_483173872870000000); // verify 2 years
    }

    function testStartStakeInflation_3Year() public {
        inflationHelper(1_095, 1_049_330_665927099289000000); // verify 3 years
    }

    function testStartStakeInflation_4Year() public {
        inflationHelper(1_460, 1_066_309_192756175359000000); // verify 4 years
    }

    function testStartStakeInflation_5Year() public {
        inflationHelper(1_825, 1_083_562_437920134900000000); // verify 5 years
    }

    function testStartStakeInflation_6Year() public {
        inflationHelper(2_190, 1_101_094_846455009654000000); // verify 6 years
    }

    function testStartStakeInflation_7Year() public {
        inflationHelper(2_555, 1_118_910_935319025168000000); // verify 7 years
    }

    function testStartStakeInflation_8Year() public {
        inflationHelper(2_920, 1_137_015_294556326338000000); // verify 8 years
    }

    function testStartStakeInflation_9Year() public {
        inflationHelper(3_285, 1_155_412_588479532423000000); // verify 9 years
    }

    function testStartStakeInflation_10Year() public {
        inflationHelper(3_650, 1_174_107_556871426200000000); // verify 10 years
    }

    function testStartStakeInflation_11Year() public {
        inflationHelper(4_015, 1_193_105_016206086869000000); // verify 11 years
    }

    function testStartStakeInflation_12Year() public {
        inflationHelper(4_380, 1_212_409_860889781286000000); // verify 12 years
    }

    function testStartStakeInflation_13Year() public {
        inflationHelper(4_745, 1_232_027_064521933256000000); // verify 13 years
    }

    function testStartStakeInflation_14Year() public {
        inflationHelper(5_110, 1_251_961_681176495724000000); // verify 14 years
    }

    function testStartStakeInflation_15Year() public {
        inflationHelper(5_475, 1_272_218_846704056009000000); // verify 15 years
    }

    function testStartStakeInflation_16Year() public {
        inflationHelper(5_840, 1_292_803_780055009547000000); // verify 16 years
    }

    function testStartStakeInflation_17Year() public {
        inflationHelper(6_205, 1_313_721_784624143026000000); // verify 17 years
    }

    function testStartStakeInflation_18Year() public {
        inflationHelper(6_570, 1_334_978_249616973340000000); // verify 18 years
    }

    function testStartStakeInflation_19Year() public {
        inflationHelper(6_935, 1_356_578_651438194371000000); // verify 19 years
    }

    function testStartStakeInflation_20Year() public {
        inflationHelper(7_300, 1_378_528_555102589310000000); // verify 20 years
    }

    function testStartStakeInflation_21Year() public {
        inflationHelper(7_665, 1_400_833_615668772017000000); // verify 21 years
    }

    function testSupplyInflationAfterImmeidateEndStake_1Year() public {
        uint256 term = 365;
        stakers.push(bob);
        helper.batchDealTo(stakers, tenBillionXEN, address(xenCrypto));
        helper.getFenixFor(stakers, fenix, xenCrypto);

        uint256 bobFenixBalance = fenix.balanceOf(bob);
        vm.prank(bob);
        fenix.startStake(bobFenixBalance, term);

        fenix.endStake(0);
        assertEq(fenix.totalSupply(), 0); // verify
        assertEq(fenix.balanceOf(bob), 0); // verify
        assertEq(fenix.equityPoolSupply(), 1_016_180_339887498948000000); // verify
    }

    function testSupplyInflationAfterImmeidateEndStake_21Year() public {
        uint256 term = 7_665;
        stakers.push(bob);
        helper.batchDealTo(stakers, tenBillionXEN, address(xenCrypto));
        helper.getFenixFor(stakers, fenix, xenCrypto);

        uint256 bobFenixBalance = fenix.balanceOf(bob);
        vm.prank(bob);
        fenix.startStake(bobFenixBalance, term);

        fenix.endStake(0);
        assertEq(fenix.totalSupply(), 0); // verify
        assertEq(fenix.balanceOf(bob), 0); // verify
        assertEq(fenix.equityPoolSupply(), 1_400_833_615668772017000000); // verify
    }

    function inflationHelper(uint256 term, uint256 expectedPoolSupply) public {
        stakers.push(bob);
        helper.batchDealTo(stakers, tenBillionXEN, address(xenCrypto));
        helper.getFenixFor(stakers, fenix, xenCrypto);

        uint256 bobFenixBalance = fenix.balanceOf(bob);
        vm.prank(bob);
        fenix.startStake(bobFenixBalance, term);

        assertEq(fenix.totalSupply(), 0); // verify
        assertEq(fenix.balanceOf(bob), 0); // verify
        assertEq(bobFenixBalance, 1_000_000_000000000000000000); // verify
        assertEq(fenix.equityPoolSupply(), expectedPoolSupply); // verify
    }
}
