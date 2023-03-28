// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract BetOnBalaji {
    using SafeERC20 for IERC20;

    struct Status {
        bool isSettled;
        BetType winningSide;
    }

    IERC20 private immutable usdc;
    AggregatorV3Interface private immutable priceFeed;
    uint256 private immutable deadline;

    enum BetType {
        ProBalaji,
        ProBanks
    }
    mapping(BetType => mapping(address => uint256)) private bets;
    mapping(BetType => uint256) private totalBets;
    Status private status;

    uint256 private constant BONUS_FACTOR_MIN = 1 ether;
    uint256 private constant BONUS_FACTOR_MAX = 12 * (10 ** 17); // 1.2 ether

    error BettingClosed();
    error BettingOpen();
    error InvalidAmount();
    error InvalidPrice();

    event BetPlaced(
        address indexed user,
        BetType indexed betType,
        uint256 amount,
        uint256 effectiveAmount
    );
    event BetSettled(int256 indexed btcPrice, BetType indexed winningSide);
    event RewardClaimed(address indexed user, uint256 reward);

    //duration in seconds
    //_priceFeed, chainlink priceFeed address for specific chain
    //_usdcAddress is on specific chain /usdc address / Accepting token address
    constructor(
        IERC20 _usdc,
        AggregatorV3Interface _priceFeed,
        uint256 duration
    ) {
        usdc = _usdc;
        priceFeed = _priceFeed;
        deadline = block.timestamp + duration;
    }

    function calculateBonusFactor() public view returns (uint256) {
        if (block.timestamp >= deadline) {
            return BONUS_FACTOR_MIN;
        }

        return
            BONUS_FACTOR_MIN +
            ((deadline - block.timestamp) *
                (BONUS_FACTOR_MAX - BONUS_FACTOR_MIN)) /
            (deadline - (block.timestamp - 90 days));
    }

    //place bet is had _betType enum value, amount in native currency
    function placeBet(BetType betType, uint256 amount) external {
        if (block.timestamp >= deadline) revert BettingClosed();
        if (amount == 0) revert InvalidAmount();

        uint256 bonusFactor = calculateBonusFactor();
        uint256 effectiveAmount = (amount * bonusFactor) / 10 ** 6;

        bets[betType][msg.sender] += effectiveAmount;
        totalBets[betType] += effectiveAmount;

        emit BetPlaced(msg.sender, betType, amount, effectiveAmount);

        usdc.safeTransferFrom(msg.sender, address(this), amount);
    }

    function placeBetNew(BetType betType, uint256 amount) external {
        if (block.timestamp >= deadline) revert BettingClosed();
        if (amount == 0) revert InvalidAmount();

        bets[betType][msg.sender] += amount;
        totalBets[betType] += amount;

        //effective amount should be be time factor multiplied
        // emit BetPlaced(msg.sender, betType, amount, effectiveAmount);

        usdc.safeTransferFrom(msg.sender, address(this), amount);
    }

    //Single time bet settlement
    //anyone can call this fucntion
    function resolveBets() external {
        if (block.timestamp < deadline) revert BettingOpen();
        if (status.isSettled) revert BettingClosed();

        (, int256 btcPrice, , , ) = priceFeed.latestRoundData();
        if (btcPrice == 0) revert InvalidPrice();

        BetType winningSide = btcPrice >= 1000000 * 10 ** 8
            ? BetType.ProBalaji
            : BetType.ProBanks;

        status = Status(true, winningSide);

        emit BetSettled(btcPrice, winningSide);
    }

    //this can be called onlyOnce per user
    function claimReward() external {
        Status memory currentStatus = status;

        if (block.timestamp < deadline || !currentStatus.isSettled)
            revert BettingOpen();

        uint256 winnerBet = bets[currentStatus.winningSide][msg.sender];
        if (winnerBet == 0) revert InvalidAmount();

        uint256 loserSideTotal = totalBets[currentStatus.winningSide];
        uint256 reward = (winnerBet * loserSideTotal) /
            totalBets[currentStatus.winningSide];

        bets[currentStatus.winningSide][msg.sender] = 0;

        emit RewardClaimed(msg.sender, reward);

        usdc.safeTransfer(msg.sender, reward);
    }

    // Additional helper functions
    function getUserBet(
        address user,
        BetType betType
    ) external view returns (uint256) {
        return bets[betType][user];
    }

    function getTotalBets(BetType betType) external view returns (uint256) {
        return totalBets[betType];
    }

    function getWinningSide() external view returns (BetType) {
        return status.winningSide;
    }

    function getRemainingTime() public view returns (uint256) {
        if (block.timestamp >= deadline) return 0;
        return deadline - block.timestamp;
    }
}
