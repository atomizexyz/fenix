// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { Fenix, Stake } from "src/Fenix.sol";
import { XENCrypto } from "xen-crypto/XENCrypto.sol";

contract HelpersTest is Test {
    function getFenixFor(
        address[] memory users,
        Fenix fenix,
        XENCrypto xenCrypto
    ) public {
        for (uint256 i = 0; i < users.length; i++) {
            address userAddress = address(users[i]);
            address fenixAddr = address(fenix);
            uint256 balancePreBurn = xenCrypto.balanceOf(userAddress);

            vm.prank(users[i]);
            xenCrypto.approve(fenixAddr, balancePreBurn);

            vm.prank(users[i]);
            fenix.burnXEN(balancePreBurn);
        }
    }

    function generateXENFor(address[] memory users, XENCrypto xenCrypto) public {
        uint256 timestamp = block.timestamp;

        for (uint256 i = 0; i < users.length; i++) {
            vm.prank(users[i]);
            xenCrypto.claimRank(1);
        }

        vm.warp(timestamp + (86400 * 1) + 1);

        for (uint256 i = 0; i < users.length; i++) {
            vm.prank(users[i]);
            xenCrypto.claimMintReward();
        }
    }
}