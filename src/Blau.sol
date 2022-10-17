// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {PRBMathUD60x18} from "prb-math/PRBMathUD60x18.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

struct Stake {
    uint256 stakeId;
    uint256 startTs;
    uint256 term;
    uint256 base;
    uint256 bonus;
}

contract Blau is ERC20("BLAU", "BLAU", 18) {
    using PRBMathUD60x18 for uint256;

    uint256 internal constant ONE_DAY_SECONDS = 86400;
    uint256 internal constant GRACE_PERIOD_DAYS = 28 * ONE_DAY_SECONDS;
    uint256 internal constant END_PENALTY_WEEKS = 7 * 100;
    uint256 internal constant DECIMALS = 18;
    uint256 internal constant SHARE_RATE_SCALE = 1e5;
    uint256 internal constant TIME_BONUS = 1_820;
    uint256 internal constant MIN_BONUS = 1e19;

    uint256 public shareRate = 1e18;

    function burnXEN(uint256 xen) public {}

    function startStake(address burnAddress, uint256 term) public {}

    function startStake(uint256 eqt, uint256 term) public {}

    function deferStake(uint256 stakeId) public {}

    function endStake(uint256 stakeId) public {}

    function calculateBase(uint256 xen) public pure returns (uint256) {
        return xen.ln() * 10**DECIMALS;
    }

    function calculateBonus(uint256 xen, uint256 term)
        public
        pure
        returns (uint256)
    {
        uint256 base = calculateBase(xen);
        uint256 timeBonus = (base * term) / TIME_BONUS;
        if (base > MIN_BONUS) {
            uint256 sizeBonus = base.ln();
            return timeBonus + sizeBonus;
        } else {
            return timeBonus;
        }
    }

    function updateEquity(Stake memory stake) public {
        uint256 roi = 1e18 + stake.bonus.div(stake.base);

        if (roi > shareRate) {
            shareRate = roi;
        }
    }

    function calculateEarlyPenalty(Stake memory stake)
        public
        view
        returns (uint256)
    {
        require(block.timestamp >= stake.startTs, "Stake not started");
        uint256 termDelta = block.timestamp - stake.startTs;
        uint256 percent = termDelta.div(stake.term * ONE_DAY_SECONDS);
        uint256 percentAdjusted = percent.powu(2);
        uint256 penalty = ((stake.base + stake.bonus) * percentAdjusted) / 1e18;
        return penalty;
    }

    function calculateLatePenalty(Stake memory stake)
        public
        view
        returns (uint256)
    {
        uint256 endTs = stake.startTs + (stake.term * ONE_DAY_SECONDS);
        uint256 endGraceTs = endTs + GRACE_PERIOD_DAYS;
        require(block.timestamp >= stake.startTs, "Stake not started");
        require(block.timestamp >= endTs, "Stake is active");
        require(block.timestamp >= endGraceTs, "Stake in grace period");
        uint256 termDelta = block.timestamp - endGraceTs;
        uint256 percent = termDelta.div(END_PENALTY_WEEKS * ONE_DAY_SECONDS);
        uint256 reward = stake.base + stake.bonus;
        uint256 penalty = (reward * percent) / 1e18;
        return reward - penalty;
    }
}
