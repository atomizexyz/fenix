// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { Fenix, FenixError } from "@atomize/Fenix.sol";
import { XENCrypto } from "xen-crypto/XENCrypto.sol";
import { HelpersTest } from "./Helpers.t.sol";
import { UD60x18, toUD60x18, wrap, unwrap, ud, E, ZERO, sqrt } from "@prb/math/UD60x18.sol";

contract FenixBurnTest is Test {
    HelpersTest internal helper;
    Fenix internal fenix;
    XENCrypto internal xenCrypto;

    address internal bob = address(this);
    address internal alice = address(1);

    address[] internal stakers;
    uint256 internal tenKXen = 100_000e18;

    /// ============ Setup test suite ============

    function setUp() public {
        helper = new HelpersTest();
        vm.broadcast(helper.xenDeployerPrivateKey());
        xenCrypto = new XENCrypto();

        fenix = new Fenix();

        stakers.push(bob);

        helper.batchDealTo(stakers, tenKXen, address(xenCrypto));
    }

    /// @notice Test that the contract can be deployed successfully
    function testXENBurn(uint256 amount) public {
        deal({ token: address(xenCrypto), to: address(bob), give: amount });

        uint256 balancePreBurn = xenCrypto.balanceOf(bob);

        xenCrypto.approve(address(fenix), balancePreBurn);

        uint256 balancePostBurn = xenCrypto.balanceOf(bob);

        assertLe(amount / fenix.XEN_RATIO(), balancePostBurn);
    }

    /// @notice Test token burn and revert if wrong caller
    function testTokenBurnRevertIfWrongCaller() public {
        vm.expectRevert(abi.encodeWithSelector(FenixError.WrongCaller.selector, address(bob))); // verify

        vm.prank(address(bob));
        fenix.onTokenBurned(address(bob), 100);
    }

    /// @notice Test token burn and revert if address is zero
    function testTokenBurnRevertIfAddressZero() public {
        vm.expectRevert(FenixError.AddressZero.selector); // verify

        vm.prank(address(xenCrypto));
        fenix.onTokenBurned(address(0), 100);
    }

    /// @notice Test token burn and revert if balance is zero
    function testTokenBurnRevertIfBalanceZero() public {
        vm.expectRevert(FenixError.BalanceZero.selector); // verify

        vm.prank(address(xenCrypto));
        fenix.onTokenBurned(address(bob), 0);
    }
}
