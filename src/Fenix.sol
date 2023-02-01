// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/***********************************************************************************************************************
        ..:^~!?YPB&&@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
7                   .:~JP#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
&            !:            :7G@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@G           J@@#GY7~^..       ^P@@@@@@@@@@@@@Y!YYYYJG@@@@@@@77YYYJP@@@@@@@@&!&@@@@@@@@JP@@@@@@@@7#@@@@@@@G7&@@@@@@@G!&@
@@J           7@@@@@@@@@@&GJ^     ?@@@@@@@@@@@^J@@@@@@@@@@@@@.P@@@@@@@@@@@@@& ~?&@@@@@@~J@@@@@@@@.G@@@@@@@@#!?@@@@#!?&@@
@@@J        ~P#@@@@@@@@@@@@@@&!     B@@@@@@@@@~J@@@@@@@@@@@@@:P@@@@@@@@@@@@@&.@B~Y@@@@@~J@@@@@@@@:G@@@@@@@@@@G~P&?!&@@@@
@@@@G    ~G@@@@@@@@@@@@@@@@@@@@Y     G@@@@@@@@~^YYYP@@@@@@@@@:~YYYG@@@@@@@@@&.@@@P~P@@@~J@@@@@@@@:G@@@@@@@@@@@&. !@@@@@@
@@@@@&^^&@@@@@@@@@@@@@@@@@@@@@@@:     @@@@@@@@~Y@@@@@@@@@@@@@:G@@@@@@@@@@@@@&.@@@@@Y~B@!J@@@@@@@@:G@@@@@@@@@@Y~B@Y~B@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@&5!^^!P~     G@@@@@@@~J@@@@@@@@@@@@@:G@@@@@@@@@@@@@&.@@@@@@&?7.J@@@@@@@@.G@@@@@@@@P~P@@@@&7!&@@
@@@@@@@@@@@@@@@@@@@@@@@@Y             B@@@@@@@!5@@@@@@@@@@@@@^!5555Y#@@@@@@@&:@@@@@@@@&^Y@@@@@@@@^B@@@@@@&!J@@@@@@@@#!Y@
@@@@@@@@@@@@@@@@@@@@@@@&             ~@@@@@@@@@@@@@@@@@@@@@@@@@&&&&&@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@&@
@@@@@@@@@@@@@@@@@@@@@@@@7           J@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@#7.    .^Y&@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
***********************************************************************************************************************/

import { UD60x18, toUD60x18, fromUD60x18, wrap, unwrap, ud } from "@prb/math/UD60x18.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { IERC165 } from "@openzeppelin/contracts/interfaces/IERC165.sol";
import { IBurnableToken } from "xen-crypto/interfaces/IBurnableToken.sol";
import { IBurnRedeemable } from "xen-crypto/interfaces/IBurnRedeemable.sol";
import { console } from "forge-std/console.sol";

enum Status {
    ACTIVE,
    DEFER,
    END
}

struct Stake {
    Status status;
    uint40 startTs;
    uint40 deferralTs;
    uint16 term;
    uint256 fenix;
    uint256 shares;
    uint256 payout;
}

///----------------------------------------------------------------------------------------------------------------
/// Events
///----------------------------------------------------------------------------------------------------------------
library FenixEvent {
    /// @notice New FENIX tokens have been minted
    /// @dev XEN proof of burn smart contract burns XEN tokens and mints FENIX tokens
    /// @param _userAddress the address of the staker to mint FENIX tokens for
    /// @param _amount the amount of FENIX tokens to mint
    event MintFenix(address indexed _userAddress, uint256 indexed _amount);

    /// @notice Stake has been started
    /// @dev Size and Time bonus have been calculated to burn FENIX in exchnge for equity to start stake
    /// @param _stake the stake object
    event StartStake(Stake indexed _stake);

    /// @notice Stake has been deferred
    /// @dev Remove the stake and it's equity from the pool
    /// @param _stake the stake object
    event DeferStake(Stake indexed _stake);

    /// @notice Stake has been ended
    /// @dev Remove the stake from the users stakes and mint the payout into the stakers wallet
    /// @param _stake the stake object
    event EndStake(Stake indexed _stake);

    /// @notice Reward Pool has been flushed
    /// @dev Flushed reward pool into staker pool
    event FlushRewardPool();

    /// @notice Share rate has been updated
    /// @dev Share rate has been updated
    /// @param _shareRate the new share rate
    event UpdateShareRate(uint256 indexed _shareRate);
}

///----------------------------------------------------------------------------------------------------------------
/// Events
///----------------------------------------------------------------------------------------------------------------
library FenixError {
    error WrongCaller(address caller);
    error AddressZero();
    error BalanceZero();
    error TermZero();
    error TermGreaterThanMax();
    error StakeNotStarted();
    error StakeNotEnded();
    error CooldownActive();
    error StakeStatusAlreadySet(Status status);
}

/// @title FENIX pays you to hold your own crypto
/// @author Joe Blau <joe@atomize.xyz>
/// @notice FENIX pays you to hold your own crypto
/// @dev Fenix is an ERC20 token that pays you to hold your own crypto.
contract Fenix is ERC20, IBurnRedeemable, IERC165 {
    ///----------------------------------------------------------------------------------------------------------------
    /// Constants
    ///----------------------------------------------------------------------------------------------------------------

    address public constant XEN_ADDRESS = 0xcB99cbfA54b88CDA396E39aBAC010DFa6E3a03EE;
    // address public constant XEN_ADDRESS = 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512;

    uint256 public constant ANNUAL_INFLATION_RATE = 1_618033988749894848;
    uint256 public constant SIZE_BONUS_RATE = 0.10e18;
    uint256 public constant TIME_BONUS_RATE = 0.20e18;
    uint256 public constant EARLY_PENALTY_EXPONENT = 2;
    uint256 public constant LATE_PENALTY_EXPONENT = 3;

    uint256 public constant ONE_DAY_SECONDS = 86_400;
    uint256 public constant ONE_EIGHTY_DAYS = 180;
    uint256 public constant ONE_YEAR_DAYS = 365;
    uint256 public constant TIME_BONUS = 1_820;
    uint256 public constant MAX_STAKE_LENGTH_DAYS = 365 * 55; // 55 years
    uint256 public constant XEN_RATIO = 10_000;
    uint256 public constant REWARD_COOLDOWN = 86_400 * 7 * 13; // 13 weeks
    uint256 public constant REWARD_LAUNCH_COOLDOWN = 86_400 * 7 * 3; // 10 weeks

    ///----------------------------------------------------------------------------------------------------------------
    /// Variables
    ///----------------------------------------------------------------------------------------------------------------

    uint40 public immutable startTs;
    uint256 public cooldownUnlockTs;
    uint256 public rewardPoolSupply = 0;

    uint256 public shareRate = 1e18;

    uint256 public maxInflationEndTs = 0;

    uint256 public stakePoolSupply = 1;
    uint256 public stakePoolTotalShares = 0;
    uint256 public stakePoolStakeCount = 0;

    mapping(address => Stake[]) public stakes;

    ///----------------------------------------------------------------------------------------------------------------
    /// Contract
    ///----------------------------------------------------------------------------------------------------------------

    constructor() ERC20("FENIX", "FENIX", 18) {
        startTs = uint40(block.timestamp);
        cooldownUnlockTs = block.timestamp + REWARD_LAUNCH_COOLDOWN;
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
        if (msg.sender != XEN_ADDRESS) revert FenixError.WrongCaller(msg.sender);
        if (user == address(0)) revert FenixError.AddressZero();
        if (amount == 0) revert FenixError.BalanceZero();
        uint256 fenix = amount / XEN_RATIO;
        rewardPoolSupply += fenix;
        _mint(user, fenix);
        emit FenixEvent.MintFenix(user, fenix);
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
        if (fenix == 0) revert FenixError.BalanceZero();
        if (term == 0) revert FenixError.TermZero();
        if (term > MAX_STAKE_LENGTH_DAYS) revert FenixError.TermGreaterThanMax();
        uint256 bonus = calculateBonus(fenix, term);

        // Convert effective FENIX bonus to shares
        uint256 shares = unwrap(ud(bonus).div(ud(shareRate)));
        Stake memory _stake = Stake(Status.ACTIVE, uint40(block.timestamp), 0, uint16(term), fenix, shares, 0);

        stakes[msg.sender].push(_stake);

        uint256 endTs = block.timestamp + term;
        if (endTs > maxInflationEndTs) {
            UD60x18 root = toUD60x18(1).add(ud(ANNUAL_INFLATION_RATE));
            UD60x18 exponent = toUD60x18(term).div(toUD60x18(ONE_YEAR_DAYS));
            UD60x18 newPoolSupply = toUD60x18(stakePoolSupply).mul(root.pow(exponent));
            stakePoolSupply = fromUD60x18(newPoolSupply) + fenix;
            maxInflationEndTs = endTs;
        }

        stakePoolTotalShares += shares;

        ++stakePoolStakeCount;

        _burn(msg.sender, fenix);
        emit FenixEvent.StartStake(_stake);
    }

    /// @notice Defer stake until future date
    /// @dev Defer a stake by removing the supply allocated to the stake from the pool
    /// @param stakeIndex the index of the stake to defer
    /// @param stakerAddress the address of the stake owner that will be deferred
    function deferStake(uint256 stakeIndex, address stakerAddress) public {
        if (stakes[stakerAddress].length <= stakeIndex) revert FenixError.StakeNotStarted();
        Stake memory _stake = stakes[stakerAddress][stakeIndex];

        if (_stake.status != Status.ACTIVE) return;
        uint256 endTs = _stake.startTs + (_stake.term * ONE_DAY_SECONDS);

        if (block.timestamp < endTs && msg.sender != stakerAddress) revert FenixError.WrongCaller(msg.sender);

        UD60x18 stakeShares = toUD60x18(_stake.shares);
        UD60x18 poolEquity = stakeShares.div(toUD60x18(stakePoolTotalShares));
        UD60x18 equitySupply = toUD60x18(stakePoolSupply).mul(poolEquity);

        UD60x18 penalty = toUD60x18(1);
        if (block.timestamp > endTs) {
            penalty = ud(calculateLatePenalty(_stake));
        } else {
            penalty = ud(calculateEarlyPenalty(_stake));
        }

        uint256 payout = fromUD60x18(equitySupply.sub(equitySupply.mul(penalty)));

        Stake memory deferredStake = Stake(
            Status.DEFER,
            _stake.startTs,
            uint40(block.timestamp),
            _stake.term,
            _stake.fenix,
            _stake.shares,
            payout
        );

        stakes[stakerAddress][stakeIndex] = deferredStake;
        stakePoolTotalShares -= fromUD60x18(stakeShares);
        stakePoolSupply -= payout;

        --stakePoolStakeCount;

        emit FenixEvent.DeferStake(deferredStake);
    }

    /// @notice End a stake
    /// @dev End a stake by allocating the stake supply to the stakers wallet
    /// @param stakeIndex the index of the stake to end
    function endStake(uint256 stakeIndex) public {
        deferStake(stakeIndex, msg.sender);

        Stake memory _stake = stakes[msg.sender][stakeIndex];
        if (_stake.status == Status.END) revert FenixError.StakeStatusAlreadySet(Status.END);

        emit FenixEvent.EndStake(_stake);
        _mint(msg.sender, _stake.payout);

        uint256 returnOnStake = unwrap(toUD60x18(_stake.payout).div(toUD60x18(_stake.fenix)));
        if (returnOnStake > shareRate) {
            shareRate = returnOnStake;
            emit FenixEvent.UpdateShareRate(shareRate);
        }

        Stake memory endedStake = Stake(
            Status.END,
            _stake.startTs,
            _stake.deferralTs,
            _stake.term,
            _stake.fenix,
            _stake.shares,
            _stake.payout
        );

        stakes[msg.sender][stakeIndex] = endedStake;

        emit FenixEvent.EndStake(endedStake);
    }

    /// @notice Calculate share bonus
    /// @dev Use fenix amount and term to calcualte size and time bonus used for pool equity stake
    /// @param fenix the amount of fenix used to calculate the equity stake
    /// @param term the term of the stake in days used to calculate the pool equity stake
    /// @return bonus the bonus for pool equity stake
    function calculateBonus(uint256 fenix, uint256 term) public pure returns (uint256) {
        uint256 sizeBonus = calculateSizeBonus(fenix);
        uint256 timeBonus = calculateTimeBonus(fenix, term);
        return sizeBonus + timeBonus;
    }

    /// @notice Calculate size bonus
    /// @dev Use fenix amount to calcualte size bonus used for pool equity stake
    /// @param fenix the amount of fenix used to calculate the equity stake
    /// @return bonus rate for larger stake size
    function calculateSizeBonus(uint256 fenix) public pure returns (uint256) {
        UD60x18 bonus = ud(fenix).mul(ud(SIZE_BONUS_RATE));
        return unwrap(bonus);
    }

    /// @notice Calculate time bonus
    /// @dev Use 20% annual compound interest rate formula to calculate the time bonus
    /// @param fenix the fenix bonus
    /// @param term the term of the stake in days used to calculate the pool equity stake
    /// @return bonus rate for longer stake duration
    function calculateTimeBonus(uint256 fenix, uint256 term) public pure returns (uint256) {
        UD60x18 annualCompletionPercent = toUD60x18(term).div(toUD60x18(ONE_YEAR_DAYS));
        UD60x18 bonus = toUD60x18(fenix).mul(toUD60x18(1).add(ud(TIME_BONUS_RATE)).pow(annualCompletionPercent));
        return fromUD60x18(bonus);
    }

    /// @notice Calcualte the early end stake penalty
    /// @dev Calculates the early end stake penality to be split between the pool and the staker
    /// @param stake the stake to calculate the penalty for
    /// @return penalty the penalty percentage for the stake
    function calculateEarlyPenalty(Stake memory stake) public view returns (uint256) {
        if (block.timestamp < stake.startTs) revert FenixError.StakeNotStarted();
        uint256 termDelta = block.timestamp - stake.startTs;
        uint256 scaleTerm = stake.term * ONE_DAY_SECONDS;
        UD60x18 base = (toUD60x18(termDelta).div(toUD60x18(scaleTerm))).powu(EARLY_PENALTY_EXPONENT);
        UD60x18 penalty = toUD60x18(1).sub(base.mul(base));
        return unwrap(penalty);
    }

    /// @notice Calculate the late end stake penalty
    /// @dev Calculates the late end stake penality to be split between the pool and the staker
    /// @param stake a parameter just like in doxygen (must be followed by parameter name)
    /// @return penalty the penalty percentage for the stake
    function calculateLatePenalty(Stake memory stake) public view returns (uint256) {
        uint256 endTs = stake.startTs + (stake.term * ONE_DAY_SECONDS);
        if (block.timestamp < stake.startTs) revert FenixError.StakeNotStarted();
        if (block.timestamp < endTs) revert FenixError.StakeNotEnded();
        uint256 lateDay = (block.timestamp - endTs) / ONE_DAY_SECONDS;
        if (lateDay > ONE_EIGHTY_DAYS) return unwrap(toUD60x18(1));
        uint256 rootNumerator = lateDay;
        uint256 rootDenominator = ONE_EIGHTY_DAYS;
        UD60x18 penalty = (toUD60x18(rootNumerator).div(toUD60x18(rootDenominator))).powu(LATE_PENALTY_EXPONENT);
        return unwrap(penalty);
    }

    function flushRewardPool() public {
        if (block.timestamp < cooldownUnlockTs) revert FenixError.CooldownActive();
        uint256 cooldownPeriods = (block.timestamp - cooldownUnlockTs) / REWARD_COOLDOWN;
        stakePoolSupply += rewardPoolSupply;
        cooldownUnlockTs += REWARD_COOLDOWN + (cooldownPeriods * REWARD_COOLDOWN);
        rewardPoolSupply = 0;
        emit FenixEvent.FlushRewardPool();
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
