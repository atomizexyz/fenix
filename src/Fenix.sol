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

import { UD60x18, wrap, unwrap, ud, E, ZERO } from "@prb/math/UD60x18.sol";
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

    uint256 public constant XEN_RATIO = 10_000;

    uint256 public constant TIME_BONUS = 1_820;
    uint256 public constant MAX_STAKE_LENGTH_DAYS = 20_075; // 365 * 55 (55 years)

    uint256 internal constant ONE_DAY_TS = 86_400; // (1 day)
    uint256 internal constant ONE_EIGHTY_DAYS_TS = 15_552_000; // 86_400 * 180 (180 days)
    uint256 internal constant REWARD_COOLDOWN_TS = 7_862_400; // 86_400 * 7 * 13  (13 weeks)
    uint256 internal constant REWARD_LAUNCH_COOLDOWN_TS = 1_814_400; // 86_400 * 7 * 3 (3 weeks)

    UD60x18 public constant ANNUAL_INFLATION_RATE = UD60x18.wrap(1_618033988749894848);
    UD60x18 internal constant ONE = UD60x18.wrap(1e18);
    UD60x18 internal constant TEN_PERCENT = UD60x18.wrap(0.1e18);
    UD60x18 internal constant NINETY_PERCENT = UD60x18.wrap(0.9e18);
    UD60x18 internal constant ONE_YEAR_DAYS = UD60x18.wrap(365);

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

    mapping(address => Stake[]) public stakes;

    ///----------------------------------------------------------------------------------------------------------------
    /// Contract
    ///----------------------------------------------------------------------------------------------------------------

    constructor() ERC20("FENIX", "FENIX", 18) {
        startTs = uint40(block.timestamp);
        cooldownUnlockTs = block.timestamp + REWARD_LAUNCH_COOLDOWN_TS;
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
            UD60x18 root = ONE.add(ANNUAL_INFLATION_RATE);
            UD60x18 exponent = ud(term).div(ONE_YEAR_DAYS);
            UD60x18 newPoolSupply = ud(stakePoolSupply).mul(root.pow(exponent));
            stakePoolSupply = unwrap(newPoolSupply) + fenix;
            maxInflationEndTs = endTs;
        }

        stakePoolTotalShares += shares;

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
        uint256 endTs = _stake.startTs + (_stake.term * ONE_DAY_TS);

        if (block.timestamp < endTs && msg.sender != stakerAddress) revert FenixError.WrongCaller(msg.sender);

        UD60x18 rewardPercent = ZERO;
        if (block.timestamp > endTs) {
            rewardPercent = ud(calculateLatePayout(_stake));
        } else {
            rewardPercent = ud(calculateEarlyPayout(_stake));
        }

        UD60x18 stakeShares = ud(_stake.shares);
        UD60x18 poolSharePercent = stakeShares.div(ud(stakePoolTotalShares));
        UD60x18 stakerPoolShares = stakeShares.mul(rewardPercent);
        uint256 stakerSupply = unwrap(ud(stakePoolSupply).mul(poolSharePercent).mul(rewardPercent));

        Stake memory deferredStake = Stake(
            Status.DEFER,
            _stake.startTs,
            uint40(block.timestamp),
            _stake.term,
            _stake.fenix,
            _stake.shares,
            stakerSupply
        );

        stakes[stakerAddress][stakeIndex] = deferredStake;
        stakePoolTotalShares -= unwrap(stakerPoolShares);

        stakePoolSupply -= stakerSupply;

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

        uint256 returnOnStake = unwrap(ud(_stake.payout).div(ud(_stake.fenix)));
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
        UD60x18 sizeBonus = ZERO;
        if (ud(fenix).gte(ONE)) {
            sizeBonus = ONE.sub(ud(fenix).inv());
        }

        UD60x18 timeBonus = ud(term).div(ud(MAX_STAKE_LENGTH_DAYS)).powu(2);
        UD60x18 bonus = ud(fenix).mul(E.pow(sizeBonus.mul(TEN_PERCENT).add(timeBonus.mul(NINETY_PERCENT))));
        return unwrap(bonus);
    }

    /// @notice Calcualte the early end stake penalty
    /// @dev Calculates the early end stake penality to be split between the pool and the staker
    /// @param stake the stake to calculate the penalty for
    /// @return reward the reward percentage for the stake
    function calculateEarlyPayout(Stake memory stake) public view returns (uint256) {
        if (block.timestamp < stake.startTs && stake.status == Status.ACTIVE) revert FenixError.StakeNotStarted();
        uint256 currentTerm = (block.timestamp - stake.startTs) / ONE_DAY_TS;
        UD60x18 reward = ud(currentTerm).div(ud(stake.term)).powu(2);
        return unwrap(reward);
    }

    /// @notice Calculate the late end stake penalty
    /// @dev Calculates the late end stake penality to be split between the pool and the staker
    /// @param stake a parameter just like in doxygen (must be followed by parameter name)
    /// @return reward the reward percentage for the stake
    function calculateLatePayout(Stake memory stake) public view returns (uint256) {
        uint256 endTs = stake.startTs + (stake.term * ONE_DAY_TS);
        if (block.timestamp < stake.startTs) revert FenixError.StakeNotStarted();
        if (block.timestamp < endTs) revert FenixError.StakeNotEnded();

        uint256 lateTs = block.timestamp - endTs;

        if (lateTs > ONE_EIGHTY_DAYS_TS) return 0;

        UD60x18 penalty = ud(lateTs).div(ud(ONE_EIGHTY_DAYS_TS)).powu(3);
        UD60x18 reward = ONE.sub(penalty);
        return unwrap(reward);
    }

    function flushRewardPool() public {
        if (block.timestamp < cooldownUnlockTs) revert FenixError.CooldownActive();
        uint256 cooldownPeriods = (block.timestamp - cooldownUnlockTs) / REWARD_COOLDOWN_TS;
        stakePoolSupply += rewardPoolSupply;
        cooldownUnlockTs += REWARD_COOLDOWN_TS + (cooldownPeriods * REWARD_COOLDOWN_TS);
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
