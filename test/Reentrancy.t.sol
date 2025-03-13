// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {VulnerableBank} from "../src/VulnerableBank.sol";
import {Attacker} from "../src/Attacker.sol";

contract ReentrancyTest is Test {
    VulnerableBank public vulnerableBank;
    Attacker public attacker;
    
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
        vulnerableBank = new VulnerableBank();
        
        vm.prank(attackerOwner);
        attacker = new Attacker(address(vulnerableBank));
    }
    
    function testDeposit() public {
        // Alice deposits 5 ETH
        vm.prank(alice);
        vulnerableBank.deposit{value: 5 ether}();
        
        // Check Alice's balance in the bank
        assertEq(vulnerableBank.balances(alice), 5 ether);
        assertEq(address(vulnerableBank).balance, 5 ether);
    }
    
    function testWithdraw() public {
        // Alice deposits 5 ETH
        vm.prank(alice);
        vulnerableBank.deposit{value: 5 ether}();
        
        // Alice withdraws 5 ETH
        vm.prank(alice);
        vulnerableBank.withdraw();
        
        // Check Alice's balance in the bank is now 0
        assertEq(vulnerableBank.balances(alice), 0);
        assertEq(address(vulnerableBank).balance, 0);
    }
    
    function testReentrancyAttack() public {
        // Alice and Bob deposit funds in the bank
        vm.prank(alice);
        vulnerableBank.deposit{value: 5 ether}();
        
        vm.prank(bob);
        vulnerableBank.deposit{value: 5 ether}();
        
        // Total funds in the bank should be 10 ETH
        assertEq(address(vulnerableBank).balance, 10 ether);
        
        // Initial balances for the attacker owner
        uint256 attackerOwnerInitialBalance = attackerOwner.balance;
        
        // Attacker owner launches the attack with 1 ETH
        vm.prank(attackerOwner);
        attacker.attack{value: ATTACK_AMOUNT}();
        
        // After the attack:
        // 1. The attacker should have drained all ETH from the bank
        // 2. The balances mapping in the bank should still show Alice and Bob's deposits
        
        // Verify bank is empty
        assertEq(address(vulnerableBank).balance, 0, "Bank should be drained");
        
        // But the balances mapping should still show deposits (only attacker's was updated)
        assertEq(vulnerableBank.balances(alice), 5 ether, "Alice's recorded balance should not change");
        assertEq(vulnerableBank.balances(bob), 5 ether, "Bob's recorded balance should not change");
        assertEq(vulnerableBank.balances(address(attacker)), 0, "Attacker's recorded balance should be 0 after withdrawal");
        
        // Verify attacker owner has gained the stolen funds
        uint256 attackerOwnerFinalBalance = attackerOwner.balance;
        uint256 profit = attackerOwnerFinalBalance - attackerOwnerInitialBalance;
        
        // Since the attacker deposits 1 ETH and withdraws 1 ETH (their balance) plus 10 ETH (other users' deposits),
        // the total gain is 10 ETH (not 9 ETH as we initially calculated)
        assertEq(profit, 10 ether, "Attacker should profit 10 ETH");
        
        // Now Alice tries to withdraw but should fail because the bank is empty
        vm.prank(alice);
        vm.expectRevert("Transfer failed");
        vulnerableBank.withdraw();
    }
} 