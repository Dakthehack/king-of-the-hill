// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

/* 
-This contract is a smart contract game of king of the hill. 
-The goal is to be the last person to claim the throne by sending more ether than the previous king. 
-To start a player will pay a fee to claim the title of King. 
-A player can steal the title of King by paying a fee that is greater than the current king. 
-The previous king will receive a percentage of the new kings fee. 
-Once a player has claimed the title of King, it will start a timer, when this timer runs out and no other player has claimed the title by paying a higher fee, the current player will win the game and is eligible to withdraw the entire balance of the contract.
-If a player tries to claim the title of King but does not pay enough ether, the transaction will be reverted. 
-If a player tries to claim the title of King but the game has already been won, the transaction will be reverted. 
-The contract will also have a function to withdraw the balance of the contract, but only the current king can call this function and only if they have won the game. 
-The contract will also have a function to check the who is the current king and the time remaining for the game.
*/

// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

contract KingofHill is ReentrancyGuard {
    // Custom Errors
    error InvalidInitialDeposit(uint256 minFee, uint256 maxFee, uint256 sent);
    error NotAuthorized();
    error GameAlreadyEnded();
    error AlreadyKing();
    error InsufficientPayment(uint256 required, uint256 sent);
    error NoRewardToClaim();
    error RewardTransferFailed();
    error MustBeCurrentKing();
    error GameNotYetCompleted();
    error WinningsTransferFailed();
    error PreviousGameStillActive();
    error DirectPaymentsNotAllowed();
    error ExpiredRewardTransferFailed();

    // State variables
    address public currentKing;
    address public immutable i_gameOwner;

    uint256 public feeToBeKing;
    uint256 public endGameTime;
    uint256 public immutable i_roundTimer;

    // Game statistics
    uint256 public totalGamesPlayed;
    uint256 public totalPrizesAwarded;

    // Constants
    uint256 public constant MIN_FEE = 1 ether;
    uint256 public constant MAX_FEE = 10 ether;
    uint256 public constant REWARD_PERCENTAGE = 10;
    uint256 public constant REWARD_DEADLINE = 48 hours;

    // Events
    event ThroneClaimed(
        address indexed newKing,
        uint256 amount,
        uint256 newEndTime
    );
    event KingHasConquered(
        address indexed currentKing,
        uint256 amount,
        uint256 gameover
    );
    event NewGameStarted(
        address indexed starter,
        uint256 startingFee,
        uint256 newEndTime
    );
    event RewardExpired(
        address indexed player,
        uint256 amount,
        address indexed transferredTo
    );

    // Mappings
    mapping(address => uint256) public rewards;
    mapping(address => uint256) public rewardDeadlines;
    
    // Array to track all addresses with rewards
    address[] private rewardRecipients;
    mapping(address => bool) private hasReward; // Track if address is already in array

    /**
     * @notice Creates a new King of Hill game
     * @dev Initial deposit must be between MIN_FEE and MAX_FEE
     */
    constructor() payable {
        if (msg.value < MIN_FEE || msg.value > MAX_FEE) {
            revert InvalidInitialDeposit(MIN_FEE, MAX_FEE, msg.value);
        }

        currentKing = msg.sender;
        feeToBeKing = msg.value;
        i_roundTimer = 2 hours;
        endGameTime = block.timestamp + 24 hours;
        i_gameOwner = msg.sender;

        emit ThroneClaimed(msg.sender, msg.value, endGameTime);
    }

    /**
     * @notice Rejects direct ETH transfers
     * @dev Use claimThrone() to participate in the game
     */
    receive() external payable {
        revert DirectPaymentsNotAllowed();
    }

    // Modifiers
    modifier onlyLastKingOrOwner() {
        if (msg.sender != currentKing && msg.sender != i_gameOwner) {
            revert NotAuthorized();
        }
        _;
    }

    /**
     * @notice Claim the throne by paying more than the current king
     * @dev Payment must be higher than current feeToBeKing
     * @dev Previous king gets 10% of your payment as a reward
     */
    function claimThrone() external payable {
        if (endGameTime == 0) {
            endGameTime = block.timestamp + 24 hours; // start first round
        } else {
            if (block.timestamp >= endGameTime) {
                revert GameAlreadyEnded();
            }
        }

        if (msg.sender == currentKing) {
            revert AlreadyKing();
        }
        if (msg.value <= feeToBeKing) {
            revert InsufficientPayment(feeToBeKing, msg.value);
        }

        uint256 reward = (msg.value * REWARD_PERCENTAGE) / 100;
        
        // Give reward to the king being dethroned
        address rewardRecipient;
        if (currentKing != address(0)) {
            rewardRecipient = currentKing;
        } else {
            // First ever claim, no king to reward
            rewardRecipient = i_gameOwner;
        }
        
        rewards[rewardRecipient] += reward;
        rewardDeadlines[rewardRecipient] = block.timestamp + REWARD_DEADLINE;
        
        // Add to tracking array if not already tracked
        if (!hasReward[rewardRecipient]) {
            rewardRecipients.push(rewardRecipient);
            hasReward[rewardRecipient] = true;
        }

        // Update state variables
        currentKing = msg.sender;
        feeToBeKing = msg.value;
        endGameTime = block.timestamp + i_roundTimer;

        emit ThroneClaimed(msg.sender, msg.value, endGameTime);
    }

    /**
     * @notice Check who is currently the king
     * @return king The address of the current king
     * @return timeRemaining Time left in the current round (0 if game ended)
     */
    function checkWhoIsCurrentKing()
        external
        view
        returns (address king, uint256 timeRemaining)
    {
        king = currentKing;
        
        if (block.timestamp >= endGameTime) {
            timeRemaining = 0;
        } else {
            timeRemaining = endGameTime - block.timestamp;
        }

        return (king, timeRemaining);
    }

    /**
     * @notice Claim your accumulated rewards
     * @dev You have 48 hours to claim after receiving a reward
     * @dev If you miss the deadline, the reward goes to the game owner
     * @dev REENTRANCY PROTECTION: nonReentrant modifier prevents recursive calls during ETH transfer
     */
    function claimReward() external nonReentrant {
        uint256 reward = rewards[msg.sender];
        if (reward == 0) {
            revert NoRewardToClaim();
        }

        if (block.timestamp > rewardDeadlines[msg.sender]) {
            // Too late - add the expired reward to game owner's claimable rewards
            rewards[msg.sender] = 0;
            hasReward[msg.sender] = false; // Remove from tracking
            rewards[i_gameOwner] += reward;
            rewardDeadlines[i_gameOwner] = block.timestamp + REWARD_DEADLINE;
            
            // Add owner to tracking if not already there
            if (!hasReward[i_gameOwner]) {
                rewardRecipients.push(i_gameOwner);
                hasReward[i_gameOwner] = true;
            }
            
            emit RewardExpired(msg.sender, reward, i_gameOwner);
        } else {
            // On time - pay out to player
            rewards[msg.sender] = 0;
            hasReward[msg.sender] = false; // Remove from tracking
            (bool sent, ) = msg.sender.call{value: reward}("");
            if (!sent) {
                revert RewardTransferFailed();
            }
        }
    }

    /**
     * @notice Winner claims the prize pool after game ends
     * @dev Only the current king can call this after the game timer expires
     * @dev Only claims winnings, doesn't drain unclaimed rewards
     * @dev REENTRANCY PROTECTION: nonReentrant modifier prevents recursive calls during ETH transfer
     */
    function claimWinningsAsKing() external nonReentrant {
        if (msg.sender != currentKing) {
            revert MustBeCurrentKing();
        }

        if (block.timestamp <= endGameTime) {
            revert GameNotYetCompleted();
        }

        // Calculate total unclaimed rewards that shouldn't be taken
        uint256 totalUnclaimedRewards = _getTotalUnclaimedRewards();
        
        // Winner gets contract balance minus unclaimed rewards
        uint256 winnings = address(this).balance - totalUnclaimedRewards;

        (bool sent, ) = currentKing.call{value: winnings}("");
        if (!sent) {
            revert WinningsTransferFailed();
        }

        // Track statistics
        totalGamesPlayed++;
        totalPrizesAwarded += winnings;

        emit KingHasConquered(msg.sender, winnings, endGameTime);
    }

    /**
     * @notice View current game status
     * @return prizePool Total ETH in the contract
     * @return timeRemaining Time left in the current round
     */
    function viewGameStatus()
        external
        view
        returns (uint256 prizePool, uint256 timeRemaining)
    {
        if (block.timestamp >= endGameTime) {
            timeRemaining = 0;
        } else {
            timeRemaining = endGameTime - block.timestamp;
        }

        return (address(this).balance, timeRemaining);
    }

    /**
     * @notice Start a new game after the previous one ends
     * @dev Only the last king or game owner can start a new game
     */
    function startNewGame() external onlyLastKingOrOwner {
        if (block.timestamp <= endGameTime) {
            revert PreviousGameStillActive();
        }

        // Reset game state
        currentKing = address(0);
        feeToBeKing = 1 ether;
        endGameTime = 0;

        emit NewGameStarted(msg.sender, feeToBeKing, endGameTime);
    }

    /**
     * @notice Helper function to calculate total unclaimed rewards
     * @dev Internal function used by claimWinningsAsKing
     * @dev Loops through all reward recipients to sum their unclaimed rewards
     * @return total Sum of all unclaimed rewards across all players
     */
    function _getTotalUnclaimedRewards() internal view returns (uint256 total) {
        for (uint256 i = 0; i < rewardRecipients.length; i++) {
            address recipient = rewardRecipients[i];
            // Only count rewards that haven't been claimed yet
            if (hasReward[recipient]) {
                total += rewards[recipient];
            }
        }
        return total;
    }
    
    /**
     * @notice Get the list of all reward recipients (for transparency/debugging)
     * @return Array of addresses that have or had rewards
     */
    function getRewardRecipients() external view returns (address[] memory) {
        return rewardRecipients;
    }
    
    /**
     * @notice Get count of addresses being tracked for rewards
     * @return Number of addresses in the tracking array
     */
    function getRewardRecipientsCount() external view returns (uint256) {
        return rewardRecipients.length;
    }
}

