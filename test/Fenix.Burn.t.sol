// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { Fenix, Stake } from "src/Fenix.sol";
import { XENCrypto } from "xen-crypto/XENCrypto.sol";

contract FenixBurnTest is Test {
    Fenix internal fenix;
    XENCrypto internal xenCrypto;

    /// ============ Setup test suite ============

    function setUp() public {
        xenCrypto = new XENCrypto();
        address xenAddress = address(xenCrypto);
        _generateXEN();
        fenix = new Fenix(xenAddress);
    }

    /// @notice Test that the contract can be deployed successfully
    function testXENBurn() public {
        address userAddr = address(this);
        address fenixAddr = address(fenix);
        uint256 balancePreBurn = xenCrypto.balanceOf(userAddr);

        assertEq(balancePreBurn, 3300 * 1e18);

        xenCrypto.approve(fenixAddr, balancePreBurn);

        fenix.burnXEN(balancePreBurn);

        uint256 balancePostBurnXEN = xenCrypto.balanceOf(userAddr);
        uint256 balancePostBurnFENIX = fenix.balanceOf(userAddr);

        assertEq(balancePostBurnXEN, 0);
        assertEq(balancePostBurnFENIX, 3300 * 1e18);
    }

    /// Helpers
    function _generateXEN() public {
        uint256 timestamp = block.timestamp;
        xenCrypto.claimRank(1);
        vm.warp(timestamp + (86400 * 1) + 1);
        xenCrypto.claimMintReward();
    }
}
