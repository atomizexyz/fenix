// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {PRBMathUD60x18} from "prb-math/PRBMathUD60x18.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

contract Blau is ERC20("BLAU", "BLAU", 18) {
    using PRBMathUD60x18 for uint256;

    function startStake(address burnAddress, uint256 term) public {}

    function startStake(uint256 amount, uint256 term) public {}

    function deferStake() public {}

    function endStake() public {}

    function _calculateBase(uint256 xenAmount) public pure returns (uint256) {
        return xenAmount.ln();
    }
}
