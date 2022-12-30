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

/// @title FENIX pays you to hold your own crypto
/// @author Joe Blau <joe@atomize.xyz>
/// @notice FENIX pays you to hold your own crypto
/// @dev Fenix is an ERC20 token that pays you to hold your own crypto.
contract Fenix is ERC20, IBurnRedeemable, IERC165 {
    address internal constant XEN_ADDRESS = 0xcB99cbfA54b88CDA396E39aBAC010DFa6E3a03EE;

    uint256 internal constant ANNUAL_INFLATION_RATE = 3_141592653589793238;
    uint256 internal constant SIZE_BONUS_RATE = 0.10e18;
    uint256 internal constant TIME_BONUS_RATE = 0.20e18;

    uint256 internal constant ONE_DAY_SECONDS = 86_400;
    uint256 internal constant ONE_EIGHTY_DAYS = 180;
    uint256 internal constant ONE_YEAR_DAYS = 365;
    uint256 internal constant TIME_BONUS = 1_820;
    uint256 internal constant MAX_STAKE_LENGTH_DAYS = 365 * 50;
    uint256 internal constant XEN_RATIO = 10_000;

    uint256 public startTs = 0;
    uint256 public shareRate = 1e18;

    uint256 public maxInflationEndTs = 0;

    uint256 public poolSupply = 0;
    uint256 public poolTotalShares = 0;
    uint256 public poolTotalStakes = 0;

    uint256 public currentStakeId = 0;

    bool public bigBonusUnclaimed = true;

    mapping(address => Stake[]) public stakes;

    // Construtor

    constructor() ERC20("FENIX", "FENIX", 18) {
        startTs = block.timestamp;
        poolSupply = IERC20(XEN_ADDRESS).totalSupply() / XEN_RATIO;
    }

    /// @notice Evaluate if the contract supports the interface
    /// @dev Evaluate if the contract supports burning tokens
    /// @param interfaceId the interface to evaluate
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IBurnRedeemable).interfaceId;
    }

    /// @notice Mint FENIX tokens
    /// @dev Mint FENIX tokens to the user address
    /// @param user the address of the user to mint FENIX tokens for
    /// @param amount the amount of FENIX tokens to mint
    function onTokenBurned(address user, uint256 amount) external {
        require(msg.sender == XEN_ADDRESS, "Burner: wrong caller");
        require(user != address(0), "Burner: zero user address");
        require(amount != 0, "Burner: zero amount");
        _mint(user, amount / XEN_RATIO);
    }

    /// @notice Burn XEN tokens
    /// @dev Execute proof of burn on remote contract to burn XEN tokens
    /// @param xen the amount of XEN to burn from the current wallet address
    function burnXEN(uint256 xen) public {
        IBurnableToken(XEN_ADDRESS).burn(msg.sender, xen);
    }

    /// @notice Starts a stake
    /// @dev Initialize a stake for the current wallet address
    /// @param fenix the amount of fenix to stake
    /// @param term the number of days to stake
    function startStake(uint256 fenix, uint256 term) public {
        require(term <= MAX_STAKE_LENGTH_DAYS, "term too long");
        uint256 base = calculateBaseBonus(fenix);
        uint256 bonus = calculateBonus(base, term);
        uint256 totalBonus = base + bonus;

        // Convert effective FENIX to sahres
        uint256 shares = unwrap(wrap(totalBonus).div(wrap(shareRate)));

        Stake memory _stake = Stake(block.timestamp, 0, currentStakeId, term, fenix, totalBonus, shares, 0);
        stakes[msg.sender].push(_stake);

        uint256 endTs = block.timestamp + term;
        if (endTs > maxInflationEndTs) {
            UD60x18 root = toUD60x18(1).add(wrap(ANNUAL_INFLATION_RATE));
            UD60x18 exponent = toUD60x18(term).div(toUD60x18(ONE_YEAR_DAYS));
            UD60x18 newPoolSupply = toUD60x18(poolSupply).mul(root.pow(exponent));
            poolSupply = fromUD60x18(newPoolSupply) + fenix;

            maxInflationEndTs = endTs;
        }

        poolTotalShares += shares;

        ++poolTotalStakes;
        ++currentStakeId;
        _burn(msg.sender, fenix);
    }

    /// @notice Defer stake until future date
    /// @dev Defer a stake by removing the supply allocated to the stake from the pool
    /// @param stakeIndex the index of the stake to defer
    /// @param stakerAddress the address of the stake owner that will be deferred
    function deferStake(uint256 stakeIndex, address stakerAddress) public {
        Stake[] storage _stakesList = stakes[stakerAddress];
        Stake storage _stake = _stakesList[stakeIndex];

        uint256 endTs = _stake.startTs + (_stake.term * ONE_DAY_SECONDS);
        uint256 payout = 0;

        require(_stake.stakeId >= 0, "stake not found");
        require(_stake.deferralTs == 0, "stake already deferred");
        if (block.timestamp < endTs) {
            require(msg.sender == stakerAddress, "only owner can premturely defer stake");
        }

        UD60x18 stakeShares = toUD60x18(_stake.shares);
        UD60x18 poolEquity = stakeShares.div(toUD60x18(poolTotalShares));
        UD60x18 equitySupply = toUD60x18(poolSupply).mul(poolEquity);

        UD60x18 penalty = toUD60x18(1);
        if (block.timestamp > endTs) {
            penalty = wrap(calculateLatePenalty(_stake));
        } else {
            penalty = wrap(calculateEarlyPenalty(_stake));
        }

        payout = fromUD60x18(equitySupply.sub(equitySupply.mul(penalty)));

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

    /// @notice End a stake
    /// @dev End a stake by allocating the stake supply to the stakers wallet
    /// @param stakeIndex the index of the stake to end
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

    /// @notice Calculate share bonus
    /// @dev Use fenix amount and term to calcualte size and time bonus used for pool equity stake
    /// @param base the amount of fenix used to calculate the equity stake
    /// @param term the term of the stake in days used to calculate the pool equity stake
    /// @return bonus the bonus for pool equity stake
    function calculateBonus(uint256 base, uint256 term) public pure returns (uint256) {
        uint256 sizeBonus = calculateSizeBonus(base);
        uint256 timeBonus = calculateTimeBonus(base, term);
        return sizeBonus + timeBonus;
    }

    /// @notice Calculate base bonus
    /// @dev Use fenix amount to calcualte base bonus used for pool equity stake
    /// @param fenix the amount of fenix used to calculate the equity stake
    /// @return bonus the base bonus for pool equity stake
    function calculateBaseBonus(uint256 fenix) public pure returns (uint256) {
        return unwrap(toUD60x18(fenix).ln());
    }

    /// @notice Calculate size bonus
    /// @dev Use fenix amount to calcualte size bonus used for pool equity stake
    /// @param base the base bonus
    /// @return bonus rate for larger stake size
    function calculateSizeBonus(uint256 base) public pure returns (uint256) {
        UD60x18 bonus = wrap(base).mul(ud(SIZE_BONUS_RATE));
        return unwrap(bonus);
    }

    /// @notice Calculate time bonus
    /// @dev Use 20% annual compound interest rate formula to calculate the time bonus
    /// @param base the base bonus
    /// @param term the term of the stake in days used to calculate the pool equity stake
    /// @return bonus rate for longer stake duration
    function calculateTimeBonus(uint256 base, uint256 term) public pure returns (uint256) {
        UD60x18 annualCompletionPercent = toUD60x18(term).div(toUD60x18(ONE_YEAR_DAYS));
        UD60x18 bonus = toUD60x18(base).mul(toUD60x18(1).add(ud(TIME_BONUS_RATE)).pow(annualCompletionPercent));
        return fromUD60x18(bonus);
    }

    /// @notice Calcualte the early end stake penalty
    /// @dev Calculates the early end stake penality to be split between the pool and the staker
    /// @param stake the stake to calculate the penalty for
    /// @return penalty the penalty percentage for the stake
    function calculateEarlyPenalty(Stake memory stake) public view returns (uint256) {
        require(block.timestamp >= stake.startTs, "Stake not started");
        uint256 termDelta = block.timestamp - stake.startTs;
        uint256 scaleTerm = stake.term * ONE_DAY_SECONDS;
        UD60x18 base = toUD60x18(termDelta).div(toUD60x18(scaleTerm));
        UD60x18 penalty = toUD60x18(1).sub(base.mul(base));
        return unwrap(penalty);
    }

    /// @notice Calculate the late end stake penalty
    /// @dev Calculates the late end stake penality to be split between the pool and the staker
    /// @param stake a parameter just like in doxygen (must be followed by parameter name)
    /// @return penalty the penalty percentage for the stake
    function calculateLatePenalty(Stake memory stake) public view returns (uint256) {
        uint256 endTs = stake.startTs + (stake.term * ONE_DAY_SECONDS);
        require(block.timestamp >= stake.startTs, "Stake not started");
        require(block.timestamp >= endTs, "Stake is active");
        uint256 lateDay = (block.timestamp - endTs) / ONE_DAY_SECONDS;
        if (lateDay > ONE_EIGHTY_DAYS) return unwrap(toUD60x18(1));
        uint256 rootNumerator = lateDay;
        uint256 rootDenominator = ONE_EIGHTY_DAYS;
        UD60x18 penalty = (toUD60x18(rootNumerator).div(toUD60x18(rootDenominator))).powu(3);
        return unwrap(penalty);
    }

    function bigBonus() public {
        uint256 endTs = startTs + (ONE_EIGHTY_DAYS * ONE_DAY_SECONDS);
        require(block.timestamp > endTs, "Big bonus not active");
        require(bigBonusUnclaimed, "Big bonus already claimed");
        poolSupply += IERC20(XEN_ADDRESS).totalSupply() / XEN_RATIO;
        bigBonusUnclaimed = false;
    }

    /// @notice Get stake for address at index
    /// @dev Read stake from stakes mapping stake array
    /// @param stakerAddress address of stake owner
    /// @param stakeIndex index of stake to read
    /// @return stake
    function stakeFor(address stakerAddress, uint256 stakeIndex) public view returns (Stake memory) {
        return stakes[stakerAddress][stakeIndex];
    }

    /// @notice Get stake count for address
    /// @dev Read stake count from stakes mapping
    /// @param stakerAddress address of stake owner
    /// @return stake count
    function stakeCount(address stakerAddress) public view returns (uint256) {
        return stakes[stakerAddress].length;
    }
}
