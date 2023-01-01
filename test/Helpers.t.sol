// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { Fenix } from "@atomize/Fenix.sol";
import { XENCrypto } from "xen-crypto/XENCrypto.sol";

contract HelpersTest is Test {
    uint256 public xenDeployerPrivateKey = 0x31c354f57fc542eba2c56699286723e94f7bd02a4891a0a7f68566c2a2df6795;

    function getFenixFor(address[] memory users, Fenix fenix, XENCrypto xenCrypto) public {
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
