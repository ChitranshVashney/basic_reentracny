// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/**
 * @title VulnerableBank
 */
contract VulnerableBank {
    // Mapping of user addresses to their balances
    mapping(address => uint256) public balances;

    // Events
    event Deposit(address indexed user, uint256 amount);
    event Withdrawal(address indexed user, uint256 amount);

    /**
     * @dev Users can deposit ETH to the contract
     */
    function deposit() external payable {
        balances[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @dev Users can withdraw their ETH
     */
    function withdraw() external {
        uint256 amount = balances[msg.sender];
        require(amount > 0, "Insufficient balance");

        (bool success,) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");

        // State update happens after the external call
        balances[msg.sender] = 0;

        emit Withdrawal(msg.sender, amount);
    }

    /**
     * @dev Get the contract's balance
     */
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
