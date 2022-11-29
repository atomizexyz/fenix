// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { PRBMathUD60x18 } from "prb-math/PRBMathUD60x18.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IERC165 } from "@openzeppelin/contracts/interfaces/IERC165.sol";
import { IBurnableToken } from "xen-crypto/interfaces/IBurnableToken.sol";
import { IBurnRedeemable } from "xen-crypto/interfaces/IBurnRedeemable.sol";
import { console } from "forge-std/console.sol";

struct Stake {
    uint256 startTs;
    uint256 stakeId;
    uint256 term;
    uint256 base;
    uint256 bonus;
    uint256 shares;
}

struct Deferral {
    uint256 deferralTs;
    uint256 stakeId;
    uint256 payout;
}

contract Fenix is ERC20, IBurnRedeemable, IERC165 {
    using PRBMathUD60x18 for uint256;

    uint256 internal constant SCALE_NUMBER = 1e18;
    uint256 internal constant SCALE_FRACTION = 1e6;

    uint256 internal constant ONE = 1 * SCALE_NUMBER;
    uint256 internal constant TEN = 10 * SCALE_NUMBER;
    uint256 internal constant ANNUAL_INFLATION_RATE = 3_141592653589793238;

    uint256 internal constant ONE_DAY_SECONDS = 86400;
    uint256 internal constant ONE_EIGHTY_DAYS = 180;
    uint256 internal constant ONE_YEAR_DAYS = 365;
    uint256 internal constant TIME_BONUS = 1_820;

    address public xenContractAddress;
    uint256 public startTs = 0;
    uint256 public shareRate = 1 * SCALE_NUMBER;

    uint256 public maxInflationEndTs = 0;

    uint256 public poolSupply = 0;
    uint256 public poolTotalShares = 0;
    uint256 public poolTotalStakes = 0;

    uint256 public currentStakeId = 0;

    mapping(address => Stake[]) public stakes;
    mapping(address => Deferral[]) public deferrals;

    // Construtor

    constructor(address xenAddress) ERC20("FENIX", "FENIX", 18) {
        xenContractAddress = xenAddress;
        startTs = block.timestamp;
        poolSupply = IERC20(xenContractAddress).totalSupply();
    }

    // IBurnRedeemable

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IBurnRedeemable).interfaceId;
    }

    function onTokenBurned(address user, uint256 amount) external {
        require(msg.sender == xenContractAddress, "Burner: wrong caller");
        require(user != address(0), "Burner: zero user address");
        require(amount != 0, "Burner: zero amount");
        _mint(user, amount);
    }

    function burnXEN(uint256 xen) public {
        IBurnableToken(xenContractAddress).burn(msg.sender, xen);
    }

    // Init

    function startStake(uint256 fenix, uint256 term) public {
        uint256 base = calculateBase(fenix);
        uint256 bonus = calculateBonus(fenix, term);
        uint256 shares = base + bonus;

        Stake memory _stake = Stake(block.timestamp, currentStakeId, term, base, bonus, shares);
        stakes[msg.sender].push(_stake);

        uint256 endTs = block.timestamp + term;
        if (endTs > maxInflationEndTs) {
            uint256 root = ONE + ANNUAL_INFLATION_RATE;
            uint256 exponent = (term * SCALE_FRACTION).div(ONE_YEAR_DAYS * SCALE_FRACTION);

            poolSupply = poolSupply.mul(root.pow(exponent)).div(SCALE_NUMBER);
            maxInflationEndTs = endTs;
        }

        poolTotalShares += shares;

        ++poolTotalStakes;
        ++currentStakeId;
        _burn(msg.sender, fenix);
    }

    function deferStake(uint256 stakeIdx, address stakerAddress) public {
        Stake[] storage _stakesList = stakes[stakerAddress];
        Stake storage _stake = _stakesList[stakeIdx];
        require(_stake.stakeId >= 0, "stake not found");

        uint256 stakeShares = _stake.shares;
        uint256 endTs = _stake.startTs + (_stake.term * ONE_DAY_SECONDS);
        uint256 payout = 0;
        uint256 poolEquity = stakeShares.div(poolTotalShares);
        uint256 equitySupply = poolSupply.mul(poolEquity);

        if (block.timestamp > endTs) {
            payout = (equitySupply - (equitySupply * calculateLatePenalty(_stake)));
        } else {
            payout = (equitySupply - (equitySupply * calculateEarlyPenalty(_stake)));
        }

        Deferral memory deferral = Deferral(uint40(block.timestamp), _stake.stakeId, payout);

        _stakesList[stakeIdx] = _stakesList[_stakesList.length - 1];
        _stakesList.pop();

        stakes[stakerAddress] = _stakesList;
        deferrals[stakerAddress].push(deferral);

        poolTotalShares -= stakeShares;
        poolSupply -= payout;

        --poolTotalStakes;
    }

    function endStake(uint256 stakeIdx) public {
        deferStake(stakeIdx, msg.sender);
        Deferral memory deferral = deferrals[msg.sender][stakeIdx];
        _mint(msg.sender, deferral.payout);
    }

    function calculateBase(uint256 fenix) public pure returns (uint256) {
        return fenix;
    }

    function calculateBonus(uint256 fenix, uint256 term) public pure returns (uint256) {
        uint256 sizeBonus = calculateBase(fenix);
        uint256 timeBonus = (sizeBonus * (term * ONE_DAY_SECONDS)) / TIME_BONUS;
        return timeBonus + sizeBonus;
    }

    function updateShare(Stake memory stake) public {
        uint256 roi = 1e18 + stake.bonus.div(stake.base);

        if (roi > shareRate) {
            shareRate = roi;
        }
    }

    function calculateEarlyPenalty(Stake memory stake) public view returns (uint256) {
        require(block.timestamp >= stake.startTs, "Stake not started");
        uint256 termDelta = block.timestamp - stake.startTs;
        uint256 percent = termDelta.div(stake.term.mul(ONE_DAY_SECONDS * SCALE_NUMBER));
        return 1e18 - percent.powu(2);
    }

    function calculateLatePenalty(Stake memory stake) public view returns (uint256) {
        uint256 endTs = stake.startTs + (stake.term * ONE_DAY_SECONDS);
        require(block.timestamp >= stake.startTs, "Stake not started");
        require(block.timestamp >= endTs, "Stake is active");
        uint256 lateDay = (block.timestamp - endTs) / ONE_DAY_SECONDS;
        if (lateDay > ONE_EIGHTY_DAYS) return ONE;
        uint256 rootNumerator = lateDay * SCALE_NUMBER;
        uint256 rootDenominator = ONE_EIGHTY_DAYS * SCALE_NUMBER;
        return (rootNumerator.powu(3)).div(rootDenominator.powu(3));
    }

    // Helper Functions
    function stakeFor(address stakerAddress, uint256 stakeIndex) public view returns (Stake memory) {
        return stakes[stakerAddress][stakeIndex];
    }

    function stakeCount(address stakerAddress) public view returns (uint256) {
        return stakes[stakerAddress].length;
    }

    function deferralFor(address stakerAddress, uint256 stakeIndex) public view returns (Deferral memory) {
        return deferrals[stakerAddress][stakeIndex];
    }

    function deferralCount(address stakerAddress) public view returns (uint256) {
        return deferrals[stakerAddress].length;
    }
}
