// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {SecureBank} from "../src/SecureBank.sol";

/**
 * @title SecureBankAttacker
 * @dev This contract attempts to attack the SecureBank but will fail
 */
contract SecureBankAttacker {
    SecureBank public secureBank;
    address public owner;

    // Track whether we're in the middle of an attack
    bool private attacking;
    uint256 public attackCount;

    event AttackStarted(uint256 initialDeposit);
    event AttackCompleted(uint256 stolenAmount);

    constructor(address secureBankAddress) {
        secureBank = SecureBank(secureBankAddress);
        owner = msg.sender;
    }

    // Function to start the attack
    function attack() external payable {
        require(msg.sender == owner, "Only owner can attack");
        require(msg.value > 0, "Need ETH to attack");

        // Initial deposit to get a balance in the secure contract
        emit AttackStarted(msg.value);
        console.log("Attacker: Starting attack with initial deposit of %s wei", msg.value);

        // Make an initial deposit
        secureBank.deposit{value: msg.value}();

        // Start the attack
        attacking = true;
        attackCount = 0;
        secureBank.withdraw();
        attacking = false;

        // Report attempt result
        uint256 finalBalance = address(this).balance;
        emit AttackCompleted(finalBalance);
        console.log("Attacker: Attack completed. Final balance: %s wei", finalBalance);
        console.log("Attacker: Reentrancy count: %s", attackCount);

        // Send funds to the owner
        (bool success,) = owner.call{value: address(this).balance}("");
        require(success, "Transfer failed");
    }

    // This function gets called when the vulnerable contract sends ETH
    receive() external payable {
        if (attacking && address(secureBank).balance > 0) {
            // If we're attacking and there are still funds in the bank, try to withdraw again
            attackCount++;
            console.log("Attacker: Attempting to reenter the secure contract...");
            console.log("Attacker: Bank balance remaining: %s wei", address(secureBank).balance);

            // This will fail due to reentrancy protection
            try secureBank.withdraw() {
                console.log("Attacker: Successfully reentered! (should not see this)");
            } catch Error(string memory reason) {
                console.log("Attacker: Reentrancy attempt failed: %s", reason);
            } catch {
                console.log("Attacker: Reentrancy attempt failed with unknown error");
            }
        }
    }
}

contract SecureBankTest is Test {
    SecureBank public secureBank;
    SecureBankAttacker public attacker;

    // Test accounts
    address public deployer;
    address public alice;
    address public bob;
    address public attackerOwner;

    // Initial funds
    uint256 public constant INITIAL_BALANCE = 10 ether;
    uint256 public constant ATTACK_AMOUNT = 1 ether;

    function setUp() public {
        // Set up accounts
        deployer = makeAddr("deployer");
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        attackerOwner = makeAddr("attackerOwner");

        // Fund accounts
        vm.deal(deployer, INITIAL_BALANCE);
        vm.deal(alice, INITIAL_BALANCE);
        vm.deal(bob, INITIAL_BALANCE);
        vm.deal(attackerOwner, INITIAL_BALANCE);

        // Deploy contracts
        vm.prank(deployer);
        secureBank = new SecureBank();

        vm.prank(attackerOwner);
        attacker = new SecureBankAttacker(address(secureBank));
    }

    function testNormalOperations() public {
        // Alice deposits 5 ETH
        vm.prank(alice);
        secureBank.deposit{value: 5 ether}();

        // Bob deposits 5 ETH
        vm.prank(bob);
        secureBank.deposit{value: 5 ether}();

        // Alice withdraws her 5 ETH
        vm.prank(alice);
        secureBank.withdraw();

        // Check balances
        assertEq(secureBank.balances(alice), 0, "Alice's balance should be zero after withdrawal");
        assertEq(secureBank.balances(bob), 5 ether, "Bob's balance should still be 5 ETH");
        assertEq(address(secureBank).balance, 5 ether, "Bank balance should be 5 ETH (Bob's deposit)");
    }

    function testAttackFailure() public {
        // Alice and Bob deposit funds in the bank
        vm.prank(alice);
        secureBank.deposit{value: 5 ether}();

        vm.prank(bob);
        secureBank.deposit{value: 5 ether}();

        // Total funds in the bank should be 10 ETH
        assertEq(address(secureBank).balance, 10 ether);

        // Initial balances for the attacker owner
        uint256 attackerOwnerInitialBalance = attackerOwner.balance;

        // Attacker owner launches the attack with 1 ETH
        vm.prank(attackerOwner);
        attacker.attack{value: ATTACK_AMOUNT}();

        // After the attack:
        // 1. The attacker should NOT have drained all ETH from the bank
        // 2. The attacker should only have withdrawn their initial deposit

        // Verify bank still has other users' funds
        assertEq(address(secureBank).balance, 10 ether, "Bank should still have all deposits except attacker's");

        // Balances in the bank should be updated correctly
        assertEq(secureBank.balances(alice), 5 ether, "Alice's balance should be unchanged");
        assertEq(secureBank.balances(bob), 5 ether, "Bob's balance should be unchanged");
        assertEq(secureBank.balances(address(attacker)), 0, "Attacker's balance should be 0 after withdrawal");

        // Verify attacker owner hasn't gained any additional ETH
        uint256 attackerOwnerFinalBalance = attackerOwner.balance;
        uint256 profit = attackerOwnerFinalBalance - attackerOwnerInitialBalance;

        // Attacker should have only been able to withdraw their initial deposit
        assertEq(profit, 0, "Attacker should not profit from the attack");
    }
}
