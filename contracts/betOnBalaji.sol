// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract BettingPlatform {
    IERC20 public wbtc;
    AggregatorV3Interface public priceFeed;
    uint256 public deadline;

    enum BetType {
        ProBalaji,
        ProBanks,
        Invalid
    }
    mapping(BetType => mapping(address => uint256)) public bets;
    mapping(BetType => uint256) public totalBets;
    BetType public winningSide = BetType.Invalid;

    uint256 public constant BONUS_FACTOR_MIN = 1 ether;
    uint256 public constant BONUS_FACTOR_MAX = 12 * (10 ** 17); // 1.2 ether

    event BetPlaced(
        address indexed user,
        BetType betType,
        uint256 amount,
        uint256 effectiveAmount
    );
    event BetsResolved(BetType winningSide);
    event RewardClaimed(address indexed user, uint256 reward);

    constructor(
        address _wbtcAddress,
        AggregatorV3Interface _priceFeed,
        uint256 duration
    ) {
        wbtc = IERC20(_wbtcAddress);
        priceFeed = _priceFeed;
        deadline = block.timestamp + duration;
    }

    function calculateBonusFactor() public view returns (uint256) {
        if (block.timestamp >= deadline) {
            return BONUS_FACTOR_MIN;
        }

        uint256 remainingTime = deadline - block.timestamp;
        uint256 totalTime = deadline - (block.timestamp - 90 days);
        uint256 bonusFactorRange = BONUS_FACTOR_MAX - BONUS_FACTOR_MIN;

        uint256 bonusFactor = BONUS_FACTOR_MIN +
            (remainingTime * bonusFactorRange) /
            totalTime;
        return bonusFactor;
    }

    function placeBet(BetType _betType, uint256 _amount) external payable {
        require(block.timestamp < deadline, "Betting closed");
        require(_amount > 0, "Invalid amount");

        uint256 bonusFactor = calculateBonusFactor();
        uint256 effectiveAmount = (_amount * bonusFactor) / 1 ether;

        wbtc.transferFrom(msg.sender, address(this), _amount);

        bets[_betType][msg.sender] += effectiveAmount;
        totalBets[_betType] += effectiveAmount;

        emit BetPlaced(msg.sender, _betType, _amount, effectiveAmount);
    }

    function resolveBets() external {
        require(block.timestamp >= deadline, "Betting still open");
        require(winningSide == BetType.Invalid, "Bets already resolved");

        (, int256 btcPrice, , , ) = priceFeed.latestRoundData();
        require(btcPrice > 0, "Invalid BTC price");

        winningSide = uint256(btcPrice) >= 1000000 * 10 ** 8
            ? BetType.ProBalaji
            : BetType.ProBanks;

        emit BetsResolved(winningSide);
    }

    function claimReward() external {
        require(winningSide != BetType.Invalid, "Bets not resolved yet");

        uint256 winnerBet = bets[winningSide][msg.sender];
        require(winnerBet > 0, "No reward to claim");

        uint256 loserSideTotal = totalBets[
            winningSide == BetType.ProBalaji
                ? BetType.ProBanks
                : BetType.ProBalaji
        ];
        uint256 reward = (winnerBet * loserSideTotal) / totalBets[winningSide];

        bets[winningSide][msg.sender] = 0;

        wbtc.transfer(msg.sender, reward);

        emit RewardClaimed(msg.sender, reward);
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
        return winningSide;
    }
}
