// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {KingofHill} from "../../src/KingofHill.sol";

/**
 * @title Handler
 * @notice Orchestrates valid function calls for invariant testing
 * @dev Acts as a "smart" caller that makes reasonable, valid calls to the contract
 */
contract Handler is Test {
    KingofHill public game;
    
    // Track actors (players)
    address[] public actors;
    address public currentActor;
    
    // Statistics
    uint256 public ghost_throneClaimCount;
    uint256 public ghost_rewardClaimCount;
    uint256 public ghost_totalEthClaimed;
    
    constructor(KingofHill _game) {
        game = _game;
        
        // Create 3 actors
        actors.push(makeAddr("actor1"));
        actors.push(makeAddr("actor2"));
        actors.push(makeAddr("actor3"));
    }
    
    /**
     * @notice Handler for claimThrone - makes valid throne claims
     */
    function claimThrone(uint256 actorSeed, uint256 amount) public {
        // Select random actor
        currentActor = actors[actorSeed % actors.length];
        
        // Bound amount to valid range (must be > current feeToBeKing)
        amount = bound(amount, game.feeToBeKing() + 1, 50 ether);
        
        // Give actor enough ETH
        vm.deal(currentActor, amount);
        
        // Attempt throne claim
        vm.prank(currentActor);
        try game.claimThrone{value: amount}() {
            ghost_throneClaimCount++;
        } catch {
            // Silently fail (e.g., game ended, already king)
        }
    }
    
    /**
     * @notice Handler for claimReward - tries to claim rewards
     */
    function claimReward(uint256 actorSeed) public {
        currentActor = actors[actorSeed % actors.length];
        
        uint256 balanceBefore = currentActor.balance;
        
        vm.prank(currentActor);
        try game.claimReward() {
            ghost_rewardClaimCount++;
            ghost_totalEthClaimed += currentActor.balance - balanceBefore;
        } catch {
            // Silently fail (no reward, expired, etc.)
        }
    }
    
    /**
     * @notice Handler for time warping - simulates time passing
     */
    function warpTime(uint256 timeJump) public {
        timeJump = bound(timeJump, 1, 1 hours);
        vm.warp(block.timestamp + timeJump);
    }
    
    // Helper to get total rewards across all actors
    function getTotalRewards() public view returns (uint256 total) {
        for (uint256 i = 0; i < actors.length; i++) {
            total += game.rewards(actors[i]);
        }
    }
}
