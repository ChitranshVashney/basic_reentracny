// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;


/**
 * @title SecureBank
 * @dev This contract demonstrates how to prevent reentrancy vulnerabilities
 */
contract SecureBank {
    // Mapping of user addresses to their balances
    mapping(address => uint256) public balances;
    
    // Reentrancy guard
    bool private _locked;
    
    // Events
    event Deposit(address indexed user, uint256 amount);
    event Withdrawal(address indexed user, uint256 amount);
    
    // Modifier to prevent reentrancy
    modifier nonReentrant() {
        require(!_locked, "ReentrancyGuard: reentrant call");
        _locked = true;
        _;
        _locked = false;
    }
    
    /**
     * @dev Users can deposit ETH to the contract
     */
    function deposit() external payable {
        balances[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }
    
    /**
     * @dev Users can withdraw their ETH
     * SOLUTION 1: Use the nonReentrant modifier to prevent reentrancy
     */
    function withdraw() external nonReentrant {
        uint256 amount = balances[msg.sender];
        require(amount > 0, "Insufficient balance");
        
        // SOLUTION 2: Update state before making external calls (Checks-Effects-Interactions pattern)
        balances[msg.sender] = 0;
        
        // External call after state update
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
        
        emit Withdrawal(msg.sender, amount);
    }
    
    /**
     * @dev Get the contract's balance
     */
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
} 