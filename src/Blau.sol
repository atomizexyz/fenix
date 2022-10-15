// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {PRBMathUD60x18} from "prb-math/PRBMathUD60x18.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

struct Stake {
    uint256 startTs;
    uint256 term;
    uint256 base;
    uint256 bonus;
}

contract Blau is ERC20("BLAU", "BLAU", 18) {
    using PRBMathUD60x18 for uint256;

    uint256 internal constant DECIMALS = 18;
    uint256 internal constant SHARE_RATE_SCALE = 1e5;
    uint256 internal constant TIME_BONUS = 1_820;
    uint256 internal constant MIN_BONUS = 1e19;

    uint256 public shareRate = 1e18;

    function startStake(address burnAddress, uint256 term) public {}

    function startStake(uint256 amount, uint256 term) public {}

    function deferStake() public {}

    function endStake() public {}

    function calculateBase(uint256 xen) public pure returns (uint256) {
        return xen.ln() * 10**DECIMALS;
    }

    function calculateBonus(uint256 xen, uint256 stakeDays)
        public
        pure
        returns (uint256)
    {
        uint256 base = calculateBase(xen);
        uint256 timeBonus = (base * stakeDays) / TIME_BONUS;
        if (base > MIN_BONUS) {
            uint256 sizeBonus = base.ln();
            return timeBonus + sizeBonus;
        } else {
            return timeBonus;
        }
    }

    function _updateEquity(Stake memory stake) public {
        uint256 roi = 1e18 + stake.bonus.div(stake.base);

        if (roi > shareRate) {
            shareRate = roi;
        }
    }
}
