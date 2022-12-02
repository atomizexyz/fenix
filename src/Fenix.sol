// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@prb/math/UD60x18.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IERC165 } from "@openzeppelin/contracts/interfaces/IERC165.sol";
import { IBurnableToken } from "xen-crypto/interfaces/IBurnableToken.sol";
import { IBurnRedeemable } from "xen-crypto/interfaces/IBurnRedeemable.sol";
import { console } from "forge-std/console.sol";

struct Stake {
    uint256 startTs;
    uint256 deferralTs;
    uint256 stakeId;
    uint256 term;
    uint256 base;
    uint256 bonus;
    uint256 shares;
    uint256 payout;
}

contract Fenix is ERC20, IBurnRedeemable, IERC165 {
    // using PRBMathUD60x18 for uint256;

    address internal constant XEN_ADDRESS = 0x0C7BBB021d72dB4FfBa37bDF4ef055eECdbc0a29;

    uint256 internal constant SCALE_NUMBER = 1e18;
    uint256 internal constant SCALE_FRACTION = 1e6;

    uint256 internal constant ANNUAL_INFLATION_RATE = 3_141592653589793238;

    uint256 internal constant ONE_DAY_SECONDS = 86400;
    uint256 internal constant ONE_EIGHTY_DAYS = 180;
    uint256 internal constant ONE_YEAR_DAYS = 365;
    uint256 internal constant TIME_BONUS = 1_820;

    uint256 public startTs = 0;
    uint256 public shareRate = 1 * SCALE_NUMBER;

    uint256 public maxInflationEndTs = 0;

    uint256 public poolSupply = 0;
    uint256 public poolTotalShares = 0;
    uint256 public poolTotalStakes = 0;

    uint256 public currentStakeId = 0;

    mapping(address => Stake[]) public stakes;

    // Construtor

    constructor() ERC20("FENIX", "FENIX", 18) {
        startTs = block.timestamp;
        poolSupply = IERC20(XEN_ADDRESS).totalSupply();
    }

    // IBurnRedeemable

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IBurnRedeemable).interfaceId;
    }

    function onTokenBurned(address user, uint256 amount) external {
        require(msg.sender == XEN_ADDRESS, "Burner: wrong caller");
        require(user != address(0), "Burner: zero user address");
        require(amount != 0, "Burner: zero amount");
        _mint(user, amount);
    }

    function burnXEN(uint256 xen) public {
        IBurnableToken(XEN_ADDRESS).burn(msg.sender, xen);
    }

    // Init

    function startStake(uint256 fenix, uint256 term) public {
        uint256 base = calculateBase(fenix);
        uint256 bonus = calculateBonus(fenix, term);
        uint256 shares = base + bonus;

        Stake memory _stake = Stake(block.timestamp, 0, currentStakeId, term, base, bonus, shares, 0);
        stakes[msg.sender].push(_stake);

        uint256 endTs = block.timestamp + term;
        if (endTs > maxInflationEndTs) {
            UD60x18 root = toUD60x18(1).add(wrap(ANNUAL_INFLATION_RATE));
            UD60x18 exponent = toUD60x18(term).div(toUD60x18(ONE_YEAR_DAYS));
            UD60x18 newPoolSupply = toUD60x18(poolSupply).mul(root.pow(exponent));
            poolSupply = fromUD60x18(newPoolSupply);
            maxInflationEndTs = endTs;
        }

        poolTotalShares += shares;

        ++poolTotalStakes;
        ++currentStakeId;
        _burn(msg.sender, fenix);
    }

    function deferStake(uint256 stakeIndex, address stakerAddress) public {
        Stake[] storage _stakesList = stakes[stakerAddress];
        Stake storage _stake = _stakesList[stakeIndex];
        require(_stake.stakeId >= 0, "stake not found");

        if (_stake.deferralTs >= block.timestamp) {
            return;
        }

        UD60x18 stakeShares = toUD60x18(_stake.shares);
        uint256 endTs = _stake.startTs + (_stake.term * ONE_DAY_SECONDS);
        uint256 payout = 0;
        UD60x18 poolEquity = stakeShares.div(toUD60x18(poolTotalShares));
        uint256 equitySupply = fromUD60x18(toUD60x18(poolSupply).mul(poolEquity));

        if (block.timestamp > endTs) {
            payout = (equitySupply - (equitySupply * calculateLatePenalty(_stake)));
        } else {
            payout = (equitySupply - (equitySupply * calculateEarlyPenalty(_stake)));
        }

        stakes[stakerAddress][stakeIndex] = Stake(
            _stake.startTs,
            block.timestamp,
            _stake.stakeId,
            _stake.term,
            _stake.base,
            _stake.bonus,
            _stake.shares,
            payout
        );

        poolTotalShares -= fromUD60x18(stakeShares);
        poolSupply -= payout;

        --poolTotalStakes;
    }

    function endStake(uint256 stakeIndex) public {
        deferStake(stakeIndex, msg.sender);

        uint256 lastIndex = stakes[msg.sender].length - 1;
        Stake memory _stake = stakes[msg.sender][stakeIndex];
        _mint(msg.sender, _stake.payout);
        uint256 returnOnStake = unwrap(toUD60x18(_stake.payout).div(toUD60x18(_stake.base)));
        if (returnOnStake > shareRate) {
            shareRate = returnOnStake;
        }

        if (stakeIndex != lastIndex) {
            stakes[msg.sender][stakeIndex] = stakes[msg.sender][lastIndex];
        }

        stakes[msg.sender].pop();
    }

    function calculateBase(uint256 fenix) public pure returns (uint256) {
        return fenix;
    }

    function calculateBonus(uint256 fenix, uint256 term) public pure returns (uint256) {
        uint256 sizeBonus = calculateBase(fenix);
        uint256 timeBonus = (sizeBonus * (term * ONE_DAY_SECONDS)) / TIME_BONUS;
        return timeBonus + sizeBonus;
    }

    function calculateEarlyPenalty(Stake memory stake) public view returns (uint256) {
        require(block.timestamp >= stake.startTs, "Stake not started");
        uint256 termDelta = block.timestamp - stake.startTs;
        uint256 scaleTerm = stake.term * ONE_DAY_SECONDS;
        UD60x18 base = toUD60x18(termDelta).div(toUD60x18(scaleTerm));
        UD60x18 penalty = toUD60x18(1).sub(base.powu(2));
        return unwrap(penalty);
    }

    function calculateLatePenalty(Stake memory stake) public view returns (uint256) {
        uint256 endTs = stake.startTs + (stake.term * ONE_DAY_SECONDS);
        require(block.timestamp >= stake.startTs, "Stake not started");
        require(block.timestamp >= endTs, "Stake is active");
        uint256 lateDay = (block.timestamp - endTs) / ONE_DAY_SECONDS;
        if (lateDay > ONE_EIGHTY_DAYS) return unwrap(toUD60x18(1));
        uint256 rootNumerator = lateDay;
        uint256 rootDenominator = ONE_EIGHTY_DAYS;
        UD60x18 penalty = toUD60x18(rootNumerator).powu(3).div(toUD60x18(rootDenominator).powu(3));
        return unwrap(penalty);
    }

    // Helper Functions
    function stakeFor(address stakerAddress, uint256 stakeIndex) public view returns (Stake memory) {
        return stakes[stakerAddress][stakeIndex];
    }

    function stakeCount(address stakerAddress) public view returns (uint256) {
        return stakes[stakerAddress].length;
    }
}
