// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {Blau} from "src/Blau.sol";

contract CounterTest is Test {
    Blau internal BLAU;

    /// ============ Setup test suite ============

    function setUp() public {
        BLAU = new Blau();
    }

    /// @notice Test that the contract can be deployed successfully
    function testMetadata() public {
        assertEq(BLAU.name(), "BLAU");
        assertEq(BLAU.symbol(), "BLAU");
        assertEq(BLAU.decimals(), 18);
        assertEq(BLAU.totalSupply(), 0);
    }
}
