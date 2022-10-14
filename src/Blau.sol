// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {PRBMathUD60x18} from "prb-math/PRBMathUD60x18.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

contract Blau is ERC20("BLAU", "BLAU", 18) {
    using PRBMathUD60x18 for uint256;

    uint256 internal constant EQUITY_SCALE = 1e5;
    uint256 internal constant SIZE_BONUS_PERCENT = 10;
    uint256 internal constant TIME_BONUS_PERCENT = 20;

    function startStake(address burnAddress, uint256 term) public {}

    function startStake(uint256 amount, uint256 term) public {}

    function deferStake() public {}

    function endStake() public {}

    function calculateBase(uint256 xen) public pure returns (uint256) {
        return xen.ln();
    }

    function calculateBonus(uint256 xen, uint256 stakeDays)
        public
        pure
        returns (uint256)
    {
        uint256 base = calculateBase(xen);
        uint256 timeBonus = base * stakeDays * TIME_BONUS_PERCENT;
        uint256 sizeBonus = base * SIZE_BONUS_PERCENT;
        return (timeBonus + sizeBonus) / 100;
    }
}
