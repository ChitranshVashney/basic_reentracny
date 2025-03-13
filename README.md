## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```

# Reentrancy Attack Demo

This project demonstrates a reentrancy vulnerability in Solidity smart contracts and shows how to prevent it.

## What is a Reentrancy Attack?

A reentrancy attack occurs when a contract (Contract A) makes an external call to another contract (Contract B) before it updates its state. This allows Contract B to make a recursive call back to vulnerable functions in Contract A while its state is still in the previous state, potentially leading to unexpected behavior like draining funds.

## Contracts in this Demo

### VulnerableBank.sol

This contract demonstrates a classic reentrancy vulnerability in its `withdraw()` function:

```solidity
function withdraw() external {
    uint256 amount = balances[msg.sender];
    require(amount > 0, "Insufficient balance");
    
    // VULNERABILITY: External call before state update
    (bool success, ) = msg.sender.call{value: amount}("");
    require(success, "Transfer failed");
    
    // State update happens after the external call
    balances[msg.sender] = 0;
    
    emit Withdrawal(msg.sender, amount);
}
```

The vulnerability exists because the contract sends ETH to the caller before updating the balance. An attacker can exploit this by creating a contract with a fallback function that calls back into `withdraw()` before the balance is updated.

### Attacker.sol

This contract exploits the vulnerability in VulnerableBank:

```solidity
// This function gets called when the vulnerable contract sends ETH
receive() external payable {
    if (attacking && address(vulnerableBank).balance > 0) {
        // If we're attacking and there are still funds in the bank, withdraw again
        vulnerableBank.withdraw();
    }
}
```

### SecureBank.sol

This contract demonstrates how to prevent reentrancy attacks using two mechanisms:

1. **Reentrancy Guard**: A mutex lock that prevents reentrant calls
   ```solidity
   modifier nonReentrant() {
       require(!_locked, "ReentrancyGuard: reentrant call");
       _locked = true;
       _;
       _locked = false;
   }
   ```

2. **Checks-Effects-Interactions Pattern**: Update state before making external calls
   ```solidity
   function withdraw() external nonReentrant {
       uint256 amount = balances[msg.sender];
       require(amount > 0, "Insufficient balance");
       
       // Update state before making external calls
       balances[msg.sender] = 0;
       
       // External call after state update
       (bool success, ) = msg.sender.call{value: amount}("");
       require(success, "Transfer failed");
       
       emit Withdrawal(msg.sender, amount);
   }
   ```

## Running the Tests

This project uses Foundry for testing. To run the tests:

```bash
# Run all tests
forge test -vv

# Run only the reentrancy attack test
forge test -vv --match-path test/Reentrancy.t.sol

# Run only the secure bank test
forge test -vv --match-path test/SecureBank.t.sol
```

## Key Takeaways

1. Always update contract state before making external calls.
2. Consider using reentrancy guards for functions that involve external calls.
3. Follow the Checks-Effects-Interactions pattern: first check conditions, then modify state, and finally interact with other contracts.
4. Be aware that reentrancy can occur not just with direct ETH transfers but also with other external calls like ERC20 token transfers.

