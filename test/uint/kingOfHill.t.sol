// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {KingofHill} from "../../src/KingofHill.sol";
import {Test} from "forge-std/Test.sol";

contract KingofHillTest is Test {
    KingofHill public game;

    address owner = address(1);
    address player1 = address(2);
    address player2 = address(3);

    // Events (copied from contract to test)
    event ThroneClaimed(
        address indexed newKing,
        uint256 amount,
        uint256 newEndTime
    );

    function setUp() public {
        // Fund the players with ETH
        vm.deal(owner, 10 ether);
        vm.deal(player1, 10 ether);
        vm.deal(player2, 10 ether);

        // Deploy the game contract as owner
        vm.startPrank(owner);
        game = new KingofHill{value: 1 ether}();
        vm.stopPrank();
    }

    function testInitialKingIsOwner() public {
        assertEq(game.currentKing(), owner);
    }

    function testPlayer1ClaimThrone() public {
        vm.startPrank(player1);
        game.claimThrone{value: 2 ether}();
        vm.stopPrank();

        assertEq(game.currentKing(), player1);
        assertEq(game.feeToBeKing(), 2 ether);
    }

    function testClaimThrone_RevertsWhen_InsufficientPayment() public {
        // Arrange: Set up who will try and how much they'll send
        vm.startPrank(player1);

        // Act + Assert: Expect revert and make the call
        vm.expectRevert(
            abi.encodeWithSelector(
                KingofHill.InsufficientPayment.selector,
                1 ether, // required
                0.5 ether // sent
            )
        );
        game.claimThrone{value: .5 ether}(); // What amount is too little?

        vm.stopPrank();
    }

    function testClaimThrone_RevertsWhen_AlreadyKing() public {
        // Step 1: Player1 becomes king
        vm.startPrank(player1);
        game.claimThrone{value: 2 ether}();
        // Now player1 IS the king

        // Step 2: Player1 (still pranking as player1) tries to claim again
        vm.expectRevert(KingofHill.AlreadyKing.selector);
        game.claimThrone{value: 2 ether}(); // What amount should they send?

        vm.stopPrank();
    }

    function testClaimThrone_RevertsWhen_GameAlreadyEnded() public {
        vm.warp(block.timestamp + 24 hours + 1); // Go past the end time

        vm.startPrank(player1);

        vm.expectRevert(KingofHill.GameAlreadyEnded.selector);
        game.claimThrone{value: 2 ether}();
        vm.stopPrank();
    }

    function testClaimThrone_UpdatesStateCorrectly() public {
        // Player1 claims the throne
        vm.startPrank(player1);
        game.claimThrone{value: 1.1 ether}();
        vm.stopPrank();

        assertEq(game.currentKing(), player1);
        assertEq(game.feeToBeKing(), 1.1 ether);

        // Owner (the dethroned king) should have received 10% of player1's payment
        uint256 ownerReward = (1.1 ether * 10) / 100; // 0.11 ether
        assertEq(game.rewards(owner), ownerReward);

        // Player2 claims the throne
        vm.startPrank(player2);
        game.claimThrone{value: 5 ether}();
        vm.stopPrank();

        assertEq(game.currentKing(), player2);
        assertEq(game.feeToBeKing(), 5 ether);

        // Player1 (the dethroned king) should have received 10% of player2's payment
        uint256 player1Reward = (5 ether * 10) / 100; // 0.5 ether
        assertEq(game.rewards(player1), player1Reward);
    }

    function testClaimThrone_EmitsThroneClaimed() public {
        vm.startPrank(player1);
        vm.expectEmit(true, false, false, true, address(game));
        emit ThroneClaimed(player1, 2 ether, block.timestamp + 2 hours);
        game.claimThrone{value: 2 ether}();
        vm.stopPrank();
    }
    function testcheckWhoIsCurrentKing_ReturnsKing() public {
        // player 1 claims the throne
        vm.startPrank(player1);
        game.claimThrone{value: 2 ether}();
        vm.stopPrank();

        (address king, uint256 timeRemaining) = game.checkWhoIsCurrentKing();
        assertEq(king, player1);
        assertGt(timeRemaining, 0); // should still have time remaining
    }

    function testcheckWhoIsCurrentKing_ReturnsZeroTimeAfterEnd() public {
        // player 1 claims the throne
        vm.startPrank(player1);
        game.claimThrone{value: 2 ether}();
        vm.stopPrank();

        // Fast forward past end time
        vm.warp(block.timestamp + 24 hours + 1);

        (address king, uint256 timeRemaining) = game.checkWhoIsCurrentKing();
        assertEq(king, player1);
        assertEq(timeRemaining, 0); // time should be zero after game end
    }
    function testClaimReward_PaysOutCorrectly() public {
        // Player1 claims the throne
        vm.startPrank(player1);
        game.claimThrone{value: 2 ether}();
        vm.stopPrank();

        // Player2 claims the throne, dethroning Player1
        vm.startPrank(player2);
        game.claimThrone{value: 3 ether}();
        vm.stopPrank();

        // Player1 claims their reward
        uint256 initialBalance = player1.balance;
        vm.startPrank(player1);
        game.claimReward();
        vm.stopPrank();

        uint256 expectedReward = (3 ether * 10) / 100; // 10% of Player2's payment
        assertEq(player1.balance, initialBalance + expectedReward);
        assertEq(game.rewards(player1), 0); // Reward should be reset to zero
    }

    function testClaimReward_RevertsWhen_NoReward() public {
        // Testing player 2 calling rewards he has yet to earn.
        vm.startPrank(player2);
        vm.expectRevert(KingofHill.NoRewardToClaim.selector);
        game.claimReward();
        vm.stopPrank();
    }
    
    function testClaimReward_ExpiredRewards() public {
        // player1 claims the throne
        vm.startPrank(player1);
        game.claimThrone{value: 2 ether}();
        vm.stopPrank();

        // player2 claims the throne from player1
        vm.startPrank(player2);
        game.claimThrone{value: 5 ether}();
        vm.stopPrank();

        // Fast forward past the reward deadline (48 hours)
        vm.warp(block.timestamp + 49 hours);

        // Player1 tries to claim expired reward
        vm.startPrank(player1);
        game.claimReward(); // Should NOT revert, just transfer to owner
        vm.stopPrank();

        // Check that player1's reward was reset
        assertEq(game.rewards(player1), 0);

        // Check that the game owner received both rewards:
        // 1. 0.2 ether from player1's claim (owner was initial king)
        // 2. 0.5 ether from player1's expired reward
        uint256 rewardFromPlayer1Claim = (2 ether * 10) / 100; // 0.2 ether
        uint256 expiredReward = (5 ether * 10) / 100; // 0.5 ether
        uint256 totalExpectedReward = rewardFromPlayer1Claim + expiredReward; // 0.7 ether
        assertEq(game.rewards(owner), totalExpectedReward);
    }
    
    function testclaimWinningsAsKing_SucceedsAfterGameEnd() public {
        // player1 claims the throne
        vm.startPrank(player1);
        game.claimThrone{value: 2 ether}();
        vm.stopPrank();

        // fast forward past the game end time
        vm.warp(block.timestamp + 25 hours);
        uint256 initialBalance = player1.balance;   

        // player1 claims winnings
        vm.startPrank(player1);
        game.claimWinningsAsKing();
        vm.stopPrank();
    }

    function testclaimWinningsAsKing_RevertsIfNotKing() public {
        // player1 claims the throne
        vm.startPrank(player1);
        game.claimThrone{value: 2 ether}();
        vm.stopPrank();

        // fast forward past the game end time
        vm.warp(block.timestamp + 25 hours);

        // player2 (not the king) tries to claim winnings
        vm.startPrank(player2);
        vm.expectRevert(KingofHill.MustBeCurrentKing.selector);
        game.claimWinningsAsKing();
        vm.stopPrank();
    }

    function testclaimWinningAsKing_GameNotYetCompleted() public {
        // player1 claims the throne
        vm.startPrank(player1);
        game.claimThrone{value: 2 ether}();
        vm.stopPrank();

        // player1 tries to claim winnings before game has ended
        vm.startPrank(player1);
        vm.expectRevert(KingofHill.GameNotYetCompleted.selector);
        game.claimWinningsAsKing();
        vm.stopPrank(); 

    }

    function testViewGameStatus_ReturnsCorrectStatus() public {
        // Initial game status
        (uint256 prizePool, uint256 timeRemaining) = game.viewGameStatus();
        assertEq(prizePool, 1 ether); // initial funding
        assertGt(timeRemaining, 0); // should have time remaining

        // player1 claims the throne
        vm.startPrank(player1);
        game.claimThrone{value: 2 ether}();
        vm.stopPrank();

        // Check updated game status
        (prizePool, timeRemaining) = game.viewGameStatus();
        assertEq(prizePool, 3 ether); // 1 ether initial + 2 ether from player1
        assertGt(timeRemaining, 0); // should still have time remaining

        // Fast forward past end time
        vm.warp(block.timestamp + 25 hours);

        // Check game status after end time
        (prizePool, timeRemaining) = game.viewGameStatus();
        assertEq(prizePool, 3 ether); // prize pool remains the same
        assertEq(timeRemaining, 0); // time should be zero after game end
    }

    function testStartNewGame_SucceedsByLastKing() public {
        // player1 claims the throne
        vm.startPrank(player1);
        game.claimThrone{value: 2 ether}();
        vm.stopPrank();

        // fast forward past the game end time
        vm.warp(block.timestamp + 25 hours);

        // player1 (last king) starts a new game
        vm.startPrank(player1);
        game.startNewGame();
        vm.stopPrank();

        // Check that the game has reset
        assertEq(game.currentKing(), address(0)); // No current king
        assertEq(game.feeToBeKing(), 1 ether); // Reset fee
    }

    function testStartNewGame_GameAlreadyInProgress() public {
        // player1 claims the throne
        vm.startPrank(player1);
        game.claimThrone{value: 2 ether}();
        vm.stopPrank();

        // player1 tries to start a new game before the current one ends
        vm.startPrank(player1);
        vm.expectRevert(KingofHill.PreviousGameStillActive.selector);
        game.startNewGame();
        vm.stopPrank();
    }
    function testConstructor_RevertsWhen_DepositTooLow() public {
    // Arrange
    vm.startPrank(player1);
    
    // Act + Assert: Try to deploy with less than MIN_FEE (1 ether)
    vm.expectRevert(
        abi.encodeWithSelector(
            KingofHill.InvalidInitialDeposit.selector,
            1 ether,  // minFee
            10 ether, // maxFee
            0.5 ether // sent (too low!)
        )
    );
    new KingofHill{value: 0.5 ether}();
    
    vm.stopPrank();
}

function testConstructor_RevertsWhen_DepositTooHigh() public {
    // Arrange: Give player1 enough ETH to try the deposit
    vm.deal(player1, 20 ether); // Give them enough
    vm.startPrank(player1);
    
    // Act + Assert: Try to deploy with more than MAX_FEE (10 ether)
    vm.expectRevert(
        abi.encodeWithSelector(
            KingofHill.InvalidInitialDeposit.selector,
            1 ether,   // minFee
            10 ether,  // maxFee
            15 ether   // sent (too high!)
        )
    );
    new KingofHill{value: 15 ether}();
    
    vm.stopPrank();
}

function testReceive_RevertsDirectPayments() public {
    // Act + Assert: Try to send ETH directly to contract (not via claimThrone)
    vm.startPrank(player1);
    vm.expectRevert(KingofHill.DirectPaymentsNotAllowed.selector);
    (bool sent, ) = address(game).call{value: 1 ether}("");
    vm.stopPrank();
}

function testStartNewGame_SucceedsAfterGameEnds() public {
    // Arrange: Complete a game
    vm.prank(player1);
    game.claimThrone{value: 2 ether}();
    
    // Warp past game end
    vm.warp(block.timestamp + 25 hours);
    
    // Act: Start new game
    vm.prank(player1);
    game.startNewGame();
    
    // Assert: Game state reset
    (address king, ) = game.checkWhoIsCurrentKing();
    assertEq(king, address(0));
    assertEq(game.feeToBeKing(), 1 ether);
}

function testStartNewGame_RevertsWhenGameActive() public {
    // Act + Assert: Try to start new game while current game is active
    vm.prank(owner);
    vm.expectRevert(KingofHill.PreviousGameStillActive.selector);
    game.startNewGame();
}

function testStartNewGame_OnlyKingOrOwner() public {
    // Arrange: Complete a game
    vm.prank(player1);
    game.claimThrone{value: 2 ether}();
    vm.warp(block.timestamp + 25 hours);
    
    // Act + Assert: Non-king/non-owner tries to start new game
    vm.prank(player2);
    vm.expectRevert(KingofHill.NotAuthorized.selector);
    game.startNewGame();
}

function testClaimThrone_FirstClaimWithNoKing() public {
    // Arrange: Start a new game where currentKing is address(0)
    vm.prank(player1);
    game.claimThrone{value: 2 ether}();
    vm.warp(block.timestamp + 25 hours);
    
    vm.prank(player1);
    game.startNewGame();
    
    uint256 ownerRewardBefore = game.rewards(owner);
    
    // Act: First throne claim when no king exists (endGameTime = 0 path)
    vm.prank(player2);
    game.claimThrone{value: 2 ether}();
    
    // Assert: Owner gets additional reward (no previous king to reward)
    uint256 expectedNewReward = (2 ether * 10) / 100;
    assertEq(game.rewards(owner), ownerRewardBefore + expectedNewReward);
}
}

