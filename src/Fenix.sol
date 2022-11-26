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
    uint40 startTs;
    uint256 stakeId;
    uint256 term;
    uint256 base;
    uint256 bonus;
    uint256 shares;
}

struct Deferral {
    uint40 deferralTs;
    uint256 stakeId;
    uint256 amount;
}

contract Fenix is ERC20, IBurnRedeemable, IERC165 {
    using PRBMathUD60x18 for uint256;

    uint256 internal constant ONE_DAY_SECONDS = 86400;
    uint256 internal constant GRACE_PERIOD_DAYS = 28 * ONE_DAY_SECONDS;
    uint256 internal constant END_PENALTY_WEEKS = 7 * 100;
    uint256 internal constant DECIMALS = 18;
    uint256 internal constant SHARE_RATE_SCALE = 1e5;
    uint256 internal constant TIME_BONUS = 1_820;
    uint256 internal constant MIN_BONUS = 1e19;
    uint256 internal constant ONE_EIGHTY_DAYS_SECONDS = 180 * ONE_DAY_SECONDS;
    uint256 internal constant ONE_EIGHTY_DAYS_SECONDS_CUBED = ONE_EIGHTY_DAYS_SECONDS**3;

    address public xenContractAddress;
    uint256 public startTs = 0;
    uint256 public shareRate = 1e18;
    uint256 public poolSize = 0;
    uint256 public currentStakeId = 0;

    mapping(address => Stake[]) public stakes;
    mapping(address => Deferral[]) public deferrals;

    // Construtor

    constructor(address xenAddress) ERC20("FENIX", "FENIX", 18) {
        xenContractAddress = xenAddress;
        startTs = block.timestamp;
        poolSize = IERC20(xenContractAddress).totalSupply();
    }

    // IBurnRedeemable

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IBurnRedeemable).interfaceId;
    }

    function onTokenBurned(address user, uint256 amount) external {
        // require(msg.sender == address(xenContract), "Burner: wrong caller");
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
        uint256 equity = base + bonus;

        Stake memory _stake = Stake(uint40(block.timestamp), currentStakeId, term, base, bonus, equity);
        stakes[msg.sender].push(_stake);
        ++currentStakeId;
    }

    function deferStake(uint256 stakeIdx, address stakerAddress) public {
        Stake[] storage _stakesList = stakes[stakerAddress];
        Stake storage _stake = _stakesList[stakeIdx];
        require(_stake.stakeId >= 0, "Stake not found");

        Deferral memory deferral = Deferral(uint40(block.timestamp), _stake.stakeId, _stake.base + _stake.bonus);

        _stakesList[stakeIdx] = _stakesList[_stakesList.length - 1];
        _stakesList.pop();

        stakes[stakerAddress] = _stakesList;
        deferrals[stakerAddress].push(deferral);
    }

    function endStake(uint256 stakeIdx, address stakerAddress) public {
        deferStake(stakeIdx, stakerAddress);
    }

    function calculateBase(uint256 fenix) public pure returns (uint256) {
        return fenix.ln() * 10**DECIMALS;
    }

    function calculateBonus(uint256 fenix, uint256 term) public pure returns (uint256) {
        uint256 base = calculateBase(fenix);
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

    function calculateEarlyPenalty(Stake memory stake) public view returns (uint256) {
        require(block.timestamp >= stake.startTs, "Stake not started");
        uint256 termDelta = block.timestamp - stake.startTs;
        uint256 percent = termDelta.div(stake.term * ONE_DAY_SECONDS);
        uint256 percentAdjusted = percent.powu(2);
        uint256 penalty = ((stake.base + stake.bonus) * percentAdjusted) / 1e18;
        return penalty;
    }

    function calculateLatePenalty(Stake memory stake) public view returns (uint256) {
        uint256 endTs = stake.startTs + (stake.term * ONE_DAY_SECONDS);
        require(block.timestamp >= stake.startTs, "Stake not started");
        require(block.timestamp >= endTs, "Stake is active");
        uint256 lateDays = block.timestamp - endTs;
        if (lateDays > ONE_EIGHTY_DAYS_SECONDS) return 1e18;
        return (lateDays**3).div(ONE_EIGHTY_DAYS_SECONDS_CUBED);
    }

    function calculatePayout(Stake memory stake) public view returns (uint256) {
        uint256 endTs = stake.startTs + (stake.term * ONE_DAY_SECONDS);
        require(block.timestamp >= stake.startTs, "Stake not started");
        require(block.timestamp >= endTs, "Stake is active");
        return stake.base + stake.bonus;
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
