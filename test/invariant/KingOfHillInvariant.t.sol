// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {KingofHill} from "../../src/KingofHill.sol";
import {Handler} from "./Handler.sol";

/**
 * @title KingOfHillInvariantTest
 * @notice Tests system-wide properties that should ALWAYS be true
 * @dev Foundry calls handler functions in random sequences, then checks invariants
 */
contract KingOfHillInvariantTest is Test {
    Handler public handler;
    KingofHill public game;
    
    function setUp() public {
        // Deploy game
        game = new KingofHill{value: 1 ether}();
        
        // Deploy handler
        handler = new Handler(game);
        
        // Tell Foundry to call handler functions randomly
        targetContract(address(handler));
    }
    
    /**
     * INVARIANT 1: Contract balance must always be >= total unclaimed rewards
     * This ensures the contract can always pay out all rewards
     */
    function invariant_balanceCoversRewards() public view {
        uint256 totalRewards = handler.getTotalRewards();
        uint256 contractBalance = address(game).balance;
        
        assertGe(
            contractBalance, 
            totalRewards, 
            "Contract balance must cover all rewards"
        );
    }
    
    /**
     * INVARIANT 2: There should always be a current king (after first claim)
     */
    function invariant_alwaysHasKing() public view {
        address king = game.currentKing();
        
        // After any throne claims, there should be a king
        if (handler.ghost_throneClaimCount() > 0) {
            assertTrue(king != address(0), "Should have a king after claims");
        }
    }
    
    /**
     * INVARIANT 3: Fee to be king must always be at least MIN_FEE
     */
    function invariant_feeAboveMinimum() public view {
        uint256 fee = game.feeToBeKing();
        
        assertGe(
            fee, 
            game.MIN_FEE(), 
            "Fee must be at least MIN_FEE"
        );
    }
    
    /**
     * INVARIANT 4: The game owner should always be set
     */
    function invariant_ownerExists() public view {
        address owner = game.i_gameOwner();
        assertTrue(owner != address(0), "Owner must exist");
    }
    
    /**
     * @notice Call this after test run to see statistics
     */
    function invariant_callSummary() public view {
        console.log("\n=== Invariant Test Summary ===");
        console.log("Total throne claims:", handler.ghost_throneClaimCount());
        console.log("Total reward claims:", handler.ghost_rewardClaimCount());
        console.log("Total ETH claimed:", handler.ghost_totalEthClaimed());
        console.log("Final contract balance:", address(game).balance);
        console.log("Total unclaimed rewards:", handler.getTotalRewards());
    }
}
