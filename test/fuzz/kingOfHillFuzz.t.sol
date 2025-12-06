// SPDX-License-Identifier: MIT

// // TEST FUNCTION
// function testFuzz_DoSomething(uint256 param) public {
//     // ARRANGE: Make preconditions true
//     param = bound(param, min, max);  // Ensure valid range
//     // Setup any other preconditions...
    
//     // ACT: Call the function
//     contractInstance.doSomething{value: someValue}(param);
    
//     // ASSERT: Verify postconditions
//     assertEq(contractInstance.stateVar1(), expectedValue);
//     assertEq(contractInstance.stateVar2(), param);
//     // Check event emitted...
// }

pragma solidity ^0.8.0;

import {KingofHill} from "../../src/KingofHill.sol";
import {Test} from "forge-std/Test.sol";

contract KingofHillFuzz is Test {
    KingofHill public game;
    address public player1;
    address public player2;
    address public player3;

    function setUp() public {
        game = new KingofHill{value: 1 ether}();

        player1 = makeAddr("player1");
        player2 = makeAddr("player2");
        player3 = makeAddr("player3");

        vm.deal(player1, 10 ether);
        vm.deal(player2, 10 ether);
        vm.deal(player3, 10 ether);
    }

    // Allow test contract to receive ETH (needed for expired reward transfers)
    receive() external payable {}

    // fuzz tests:

    function testFuzz_ClaimThrone(uint256 thronePayment) public {
        thronePayment = bound(
            thronePayment,
            game.MIN_FEE() + 1,
            100 ether
        );

        vm.deal(player1, thronePayment);
        vm.prank(player1);
        game.claimThrone{value: thronePayment}();

        (address king, ) = game.checkWhoIsCurrentKing();
        assertEq(king, player1);
    }

    function testFuzz_ClaimRewardBeforeDeadline(uint256 claimTime) public {
    // ARRANGE: Create a scenario where player1 has a reward
    vm.prank(player1);
    game.claimThrone{value: 2 ether}();
    
    vm.prank(player2);
    game.claimThrone{value: 3 ether}(); // Now player1 has 0.3 ether reward
    
    // Fuzz the claim timing (before 48h deadline)
    claimTime = bound(claimTime, 0, 48 hours - 1);
    vm.warp(block.timestamp + claimTime);
    
    // ACT: Claim at random time
    uint256 balanceBefore = player1.balance;
    vm.prank(player1);
    game.claimReward();
    
    // ASSERT: Player got paid
    assertGt(player1.balance, balanceBefore);
}

    function testFuzz_ClaimRewardAfterDeadline(uint256 claimTime) public {
        // ARRANGE: Create a scenario where player1 has a reward
        vm.prank(player1);
        game.claimThrone{value: 2 ether}();
        
        vm.prank(player2);
        game.claimThrone{value: 3 ether}(); // Now player1 has 0.3 ether reward
        
        // Fuzz the claim timing (after 48h deadline)
        claimTime = bound(claimTime, 48 hours + 1, 365 days);
        vm.warp(block.timestamp + claimTime);
        
        // ACT: Claim expired reward
        uint256 player1BalanceBefore = player1.balance;
        uint256 ownerBalanceBefore = address(this).balance;
        uint256 expectedReward = (3 ether * 10) / 100; // 0.3 ether
        
        vm.prank(player1);
        game.claimReward();
        
        // ASSERT: Player didn't receive reward, owner did
        assertEq(player1.balance, player1BalanceBefore); // Player balance unchanged
        assertEq(address(this).balance, ownerBalanceBefore + expectedReward); // Owner received reward
    }

    function testFuzz_ClaimWinningsAsKing(uint256 timeAfterGameEnd) public {
        // ARRANGE: Setup a completed game with player1 as final king
        vm.prank(player1);
        game.claimThrone{value: 2 ether}();
        
        // Fuzz time elapsed AFTER game ends
        // Game ends at endGameTime, so we need timestamp > endGameTime
        timeAfterGameEnd = bound(timeAfterGameEnd, 1, 365 days);
        
        // Warp to: game start (block.timestamp) + initial 24h + 2h round timer + fuzzed extra time
        vm.warp(block.timestamp + 24 hours + 2 hours + timeAfterGameEnd);
        
        // ACT: King claims winnings at random time after game ends
        // Calculate expected values: owner has unclaimed reward (10% of 2 ether = 0.2 ether)
        uint256 unclaimedReward = (2 ether * 10) / 100; // 0.2 ether to owner
        uint256 contractBalance = address(game).balance;
        uint256 expectedWinnings = contractBalance - unclaimedReward;
        uint256 kingBalanceBefore = player1.balance;
        
        vm.prank(player1);
        game.claimWinningsAsKing();
        
        // ASSERT: King received winnings minus unclaimed rewards
        assertEq(player1.balance, kingBalanceBefore + expectedWinnings);
        assertEq(address(game).balance, unclaimedReward); // Unclaimed reward stays in contract
    }

    function testFuzz_ClaimWinningsAsKing_RevertsBeforeGameEnds(uint256 timeBeforeEnd) public {
        // ARRANGE: Setup game with player1 as king
        vm.prank(player1);
        game.claimThrone{value: 2 ether}();
        
        // When claimThrone is called, endGameTime = block.timestamp + 2 hours (i_roundTimer)
        // Fuzz time BEFORE the 2 hour round timer expires
        timeBeforeEnd = bound(timeBeforeEnd, 1, 2 hours - 1);
        vm.warp(block.timestamp + timeBeforeEnd);
        
        // ACT & ASSERT: Should revert if trying to claim before game completes
        vm.prank(player1);
        vm.expectRevert(KingofHill.GameNotYetCompleted.selector);
        game.claimWinningsAsKing();
    }

    function testFuzz_MultipleThroneClaims(
        uint256 payment1,
        uint256 payment2,
        uint256 payment3
    ) public {
        // ARRANGE: Bound all three payments to valid ranges
        // Each payment must be greater than the previous to claim throne
        payment1 = bound(payment1, game.MIN_FEE() + 1, 10 ether);
        payment2 = bound(payment2, payment1 + 1, 20 ether);
        payment3 = bound(payment3, payment2 + 1, 30 ether);
        
        // Fund all players with enough ETH
        vm.deal(player1, payment1);
        vm.deal(player2, payment2);
        vm.deal(player3, payment3);
        
        // ACT: Three sequential throne claims
        // Player1 claims first
        vm.prank(player1);
        game.claimThrone{value: payment1}();
        
        // Player2 dethrones player1
        vm.prank(player2);
        game.claimThrone{value: payment2}();
        
        // Player3 dethrones player2
        vm.prank(player3);
        game.claimThrone{value: payment3}();
        
        // ASSERT: Verify final state
        (address king, ) = game.checkWhoIsCurrentKing();
        assertEq(king, player3); // Player3 is final king
        assertEq(game.feeToBeKing(), payment3); // Fee matches last payment
        
        // Verify dethroned players have rewards accumulated (not yet claimed)
        // Player1 got 10% of payment2
        uint256 expectedReward1 = (payment2 * 10) / 100;
        assertEq(game.rewards(player1), expectedReward1);
        
        // Player2 got 10% of payment3
        uint256 expectedReward2 = (payment3 * 10) / 100;
        assertEq(game.rewards(player2), expectedReward2);
        
        // Player3 has no rewards (still king)
        assertEq(game.rewards(player3), 0);
    }
}
