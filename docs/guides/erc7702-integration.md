<a id="erc7702-integration-top"></a>
# ERC-7702 Token Approver Integration Guide

<a id="overview"></a>
## Overview

The `ERC7702TokenApprover` contract is designed to work with ERC-7702 to enable EOAs (Externally Owned Accounts) to batch approve infinite allowances to the Permit3 contract AND execute permit operations in a single transaction.

This integration provides a seamless user experience by leveraging Account Abstraction capabilities to eliminate both approval friction and signature requirements for permit operations.

<a id="how-erc-7702-works"></a>
##  How ERC-7702 Works

ERC-7702 allows EOAs to temporarily set code for a single transaction by:
1. **Authorization List**: Including an authorization list in the transaction
2. **Temporary Smart Contract**: The EOA temporarily behaves like a smart contract
3. **Delegatecall Execution**: The EOA can then delegatecall to approved contract logic

<a id="usage-pattern"></a>
##  Usage Pattern

### 1.  Deploy the ERC7702TokenApprover

```solidity
// Deploy with the Permit3 contract address
ERC7702TokenApprover approver = new ERC7702TokenApprover(PERMIT3_ADDRESS);
```

### 2.  Create ERC-7702 Transaction

Users create an ERC-7702 transaction that:
- **Authorizes delegation** to the `ERC7702TokenApprover` contract
- **Executes multiple operations** via delegatecall (choose one or both):
  - `approve(address[] tokens)` - Batch approve tokens
  - `permit(AllowanceOrTransfer[] memory permits)` - Execute permit operations

### 3.  Result

In a single transaction, the user can:
- Set infinite allowances for all specified tokens to Permit3
- Execute permit operations (transfers, allowance modifications, etc.)
- All without requiring separate signatures or transactions

<a id="contract-functions"></a>
##  Contract Functions

###  Core Functions

#### Batch Token Approval
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

#### Permit Execution
```solidity
function permit(IPermit3.AllowanceOrTransfer[] memory permits) external
```

Executes permit operations directly on Permit3 without requiring signatures.

**Parameters:**
- `permits`: Array of permit operations to execute on current chain

**Behavior:**
- Forwards the permit call to Permit3 contract
- `msg.sender` becomes the token owner for permit operations
- Automatically uses current chain ID (no need to specify)
- No signature verification required (caller authority via ERC-7702)

<a id="important-notes"></a>
##  Important Notes

###  ERC-7702 Only Design

This contract is **specifically designed for ERC-7702 delegatecalls**. When called directly:
- `approve()`: Allowances are set for the contract itself, not the caller
- `permit()`: Operations are executed with the contract as owner, not the caller
- This is not useful behavior and should be avoided

###  Modular Usage Patterns

#### Option 1: Approval Only
```javascript
// Single ERC-7702 transaction: just approve tokens
data: approver.interface.encodeFunctionData("approve", [tokens])
```

#### Option 2: Permit Only  
```javascript
// Single ERC-7702 transaction: just execute permits (requires prior approvals)
data: approver.interface.encodeFunctionData("permit", [chainPermits])
```

#### Option 3: Combined Operations
```javascript
// Single ERC-7702 transaction: approve + permit in one transaction
data: multicall([
  approver.interface.encodeFunctionData("approve", [tokens]),
  approver.interface.encodeFunctionData("permit", [chainPermits])
])
```

<a id="security-considerations"></a>
###  Security Considerations

1. **Infinite Approvals**: The `approve()` function always sets infinite allowances
2. **No Access Control**: Both functions are publicly callable (security comes from ERC-7702 authorization)
3. **Atomic Operations**: All operations succeed or the entire transaction reverts
4. **Single Use**: Each ERC-7702 authorization is for one transaction only
5. **Direct Authority**: `permit()` uses caller as token owner - no signature verification needed
6. **Chain Validation**: `permit()` validates chain ID to prevent cross-chain replay attacks

<a id="example-transaction-structure"></a>
## Example ERC-7702 Transaction Structures

### Basic Approval Transaction
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
  data: approver.interface.encodeFunctionData("approve", [
    ["0xA0b8...", "0xdAC1..."] // Token addresses
  ])
}
```

### Combined Approval + Permit Transaction
```javascript
{
  type: 0x04,
  authorization_list: [/* same as above */],
  to: userAddress,
  data: multicall([
    // 1. Approve tokens
    approver.interface.encodeFunctionData("approve", [tokens]),
    // 2. Execute permit operations
    approver.interface.encodeFunctionData("permit", [chainPermits])
  ])
}
```

<a id="integration-with-permit3"></a>
## Integration with Permit3

This contract provides two integration levels with Permit3:

### Level 1: Setup Only (Approval)
After using `approve()`, users can:
1. **Cross-Chain Permits**: Use Permit3's standard permit functionality with signatures
2. **Gasless Transfers**: Transfer tokens without additional approval transactions
3. **Multi-Chain Operations**: Enjoy efficient token operations across multiple chains

### Level 2: Complete Integration (Approval + Permit)
Using both `approve()` and `permit()` enables:
1. **Signature-Free Operations**: Execute permits without EIP-712 signatures
2. **Single Transaction Setup**: Approve tokens AND execute operations in one transaction
3. **Direct Execution**: Immediate permit operations without separate signing steps
4. **Gas Optimization**: Combine multiple operations to reduce total gas costs

<a id="error-handling"></a>
## Error Handling

The contract includes specific error types:

### ERC7702TokenApprover Errors
- `NoTokensProvided()`: Empty token array passed to `approve()`
- `ApprovalFailed(address token)`: Token approval failed for specified token

### Permit3 Errors (via `permit()` function)
- `WrongChainId(uint256 expected, uint256 actual)`: Chain ID mismatch
- `AllowanceLocked()`: Attempting to modify locked allowance
- `AllowanceExpired(uint48 expiration)`: Permit operation on expired allowance

<a id="gas-considerations"></a>
## Gas Considerations

### Approval Operations
- **Linear Scaling**: Gas cost scales linearly with number of tokens (~24k gas per token)
- **Efficiency**: Batch processing is more efficient than individual approvals

### Permit Operations  
- **No Signature Overhead**: Eliminates gas costs for signature verification
- **Direct Execution**: ~20-30k gas savings per permit operation vs signed permits
- **Operation Dependent**: Gas varies by permit type (transfer vs allowance modification)

### Combined Operations
- **Transaction Overhead**: Single transaction overhead vs multiple transactions
- **Optimal Pattern**: Approve + immediate permit usage in one transaction
