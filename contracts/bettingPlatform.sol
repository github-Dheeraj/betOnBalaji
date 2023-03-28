// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract bettingPlatform is Ownable {
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
    mapping(BetType => mapping(address => uint256)) private effectiveBets;
    mapping(BetType => uint256) private totalEffectiveBets;
    mapping(BetType => uint256) public totalBets;
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

    function calculateBonusFactorNew() public view returns (uint256) {
        if (block.timestamp >= deadline) {
            return BONUS_FACTOR_MIN;
        }

        return
            BONUS_FACTOR_MIN +
            ((deadline - block.timestamp) *
                (BONUS_FACTOR_MAX - BONUS_FACTOR_MIN)) /
            (90 days);
    }

    function placeBetNew(BetType betType, uint256 amount) external {
        if (block.timestamp >= deadline) revert BettingClosed();
        if (amount == 0) revert InvalidAmount();

        //changes it to calculateBonusFactorNew
        uint256 bonusFactor = calculateBonusFactorNew();
        uint256 effectiveAmount = (amount * bonusFactor) / 10 ** 18;

        effectiveBets[betType][msg.sender] += effectiveAmount;
        totalEffectiveBets[betType] += effectiveAmount;
        totalBets[betType] += amount;
        bets[betType][msg.sender] += effectiveAmount;

        emit BetPlaced(msg.sender, betType, amount, effectiveAmount);

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

        uint256 winnerBet = effectiveBets[currentStatus.winningSide][
            msg.sender
        ];
        if (winnerBet == 0) revert InvalidAmount();

        //add the original amount
        uint256 loserSideTotal = totalBets[
            currentStatus.winningSide == BetType.ProBalaji
                ? BetType.ProBanks
                : BetType.ProBalaji
        ];
        uint256 reward = bets[currentStatus.winningSide][msg.sender] +
            (winnerBet * loserSideTotal) /
            totalEffectiveBets[currentStatus.winningSide];

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

    // function withdrawIfRemaining() external onlyOwner returns (uint256) {
    //     require(status.isSettled, " bets not settled yet");

    //     payable(msg.sender).transfer(address(this).balance);

    //     return address(this).balance;
    // }
}
