# ERC-7702 Token Approver Integration Guide

## Overview

The `ERC7702TokenApprover` contract is designed to work with ERC-7702 to enable EOAs (Externally Owned Accounts) to batch approve infinite allowances to the Permit3 contract for multiple ERC20 tokens in a single transaction.

## How ERC-7702 Works

ERC-7702 allows EOAs to temporarily set code for a single transaction by:
1. Including an authorization list in the transaction
2. The EOA temporarily behaves like a smart contract
3. The EOA can then delegatecall to approved contract logic

## Usage Pattern

### 1. Deploy the ERC7702TokenApprover

```solidity
// Deploy with the Permit3 contract address
ERC7702TokenApprover approver = new ERC7702TokenApprover(PERMIT3_ADDRESS);
```

### 2. Create ERC-7702 Transaction

Users create an ERC-7702 transaction that:
- Authorizes delegation to the `ERC7702TokenApprover` contract
- Calls `approve(address[] tokens)` via delegatecall

### 3. Result

The user's EOA will have infinite allowances set for all specified tokens to the Permit3 contract.

## Contract Functions

### Core Function

```solidity
function approve(address[] calldata tokens) external
```

Batch approves infinite allowances (`type(uint256).max`) for the specified ERC20 tokens to the Permit3 contract.

**Parameters:**
- `tokens`: Array of ERC20 token contract addresses

**Behavior:**
- Sets `allowance[msg.sender][PERMIT3] = type(uint256).max` for each token
- Reverts if any approval fails
- Reverts if tokens array is empty

## Important Notes

### ERC-7702 Only Design

This contract is **specifically designed for ERC-7702 delegatecalls**. When called directly:
- The allowances are set for the contract itself, not the caller
- This is not useful behavior and should be avoided

### Security Considerations

1. **Infinite Approvals**: The contract always sets infinite allowances
2. **No Access Control**: Publicly callable (security comes from ERC-7702 authorization)
3. **Atomic Operations**: All approvals succeed or the entire transaction reverts
4. **Single Use**: Each ERC-7702 authorization is for one transaction only

## Example ERC-7702 Transaction Structure

```javascript
{
  type: 0x04, // ERC-7702 transaction type
  authorization_list: [
    {
      chain_id: 1,
      address: "0x...", // ERC7702TokenApprover contract address
      nonce: 0,
      y_parity: 0,
      r: "0x...",
      s: "0x..."
    }
  ],
  to: userAddress, // User's own address
  data: "0x...", // ABI encoded call to approve
  // ... other transaction fields
}
```

## Integration with Permit3

After using this contract, users can:
1. Use Permit3's cross-chain permit functionality
2. Transfer tokens without additional approvals
3. Enjoy gasless token operations across multiple chains

## Error Handling

The contract includes specific error types:
- `NoTokensProvided()`: Empty token array
- `ApprovalFailed(address token)`: Token approval failed

## Gas Considerations

- Gas cost scales linearly with number of tokens
- Each token approval costs ~24k gas
- Batch processing is more efficient than individual approvals