// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { Fenix, Stake } from "@atomize/Fenix.sol";
import { XENCrypto } from "xen-crypto/XENCrypto.sol";

contract HelpersTest is Test {
    uint256 public xenDeployerPrivateKey = 0x31c354f57fc542eba2c56699286723e94f7bd02a4891a0a7f68566c2a2df6795;

    /// @notice Genreate fenix for users from XEN using proof of burn
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

    /// @notice Deal XEN to users
    function batchDealTo(address[] memory users, uint256 amount, address token) public {
        for (uint256 i = 0; i < users.length; i++) {
            address userAddress = address(users[i]);
            deal({ token: token, to: userAddress, give: amount });
        }
    }

    /// @notice Print stake
    function printStake(Stake memory stake) public view {
        console.log("status: ", uint8(stake.status));
        console.log("startTs: ", stake.startTs);
        console.log("deferralTs: ", stake.deferralTs);
        console.log("term: ", stake.term);
        console.log("fenix: ", stake.fenix);
        console.log("shares: ", stake.shares);
        console.log("payout: ", stake.payout);
    }
}
