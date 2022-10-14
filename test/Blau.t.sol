// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
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

    /// @notice Test function that caluclates base amount from burn
    function testCalculateBase() public {
        uint256 burn1xen = 1 * 10**18;
        uint256 ln1xen = BLAU._calculateBase(burn1xen);
        assertEq(ln1xen, 0); // verify ln(1) = 0

        uint256 burn10xen = 10 * 10**18;
        uint256 ln10xen = BLAU._calculateBase(burn10xen);
        assertEq(ln10xen, 2302585092994045674); // verify ln(10)

        uint256 burn100xen = 100 * 10**18;
        uint256 ln100xen = BLAU._calculateBase(burn100xen);
        assertEq(ln100xen, 4605170185988091359); // verify ln(100)
    }
}
