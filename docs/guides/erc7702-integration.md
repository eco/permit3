<a id="erc7702-integration-top"></a>
# 🔗 ERC-7702 Token Approver Integration Guide

###### Quick Navigation: [Overview](#overview) | [How ERC-7702 Works](#how-erc-7702-works) | [Usage Pattern](#usage-pattern) | [Security](#security-considerations) | [Integration](#integration-with-permit3)

🧭 [Home](/docs/README.md) > [Guides](/docs/guides/README.md) > ERC-7702 Integration

<a id="overview"></a>
## 📖 Overview

The `ERC7702TokenApprover` contract is designed to work with ERC-7702 to enable EOAs (Externally Owned Accounts) to batch approve infinite allowances to the Permit3 contract for multiple ERC20 tokens in a single transaction.

This integration provides a seamless user experience by leveraging Account Abstraction capabilities to eliminate the need for multiple approval transactions before using Permit3.

<a id="how-erc-7702-works"></a>
## 🔧 How ERC-7702 Works

ERC-7702 allows EOAs to temporarily set code for a single transaction by:
1. **Authorization List**: Including an authorization list in the transaction
2. **Temporary Smart Contract**: The EOA temporarily behaves like a smart contract
3. **Delegatecall Execution**: The EOA can then delegatecall to approved contract logic

<a id="usage-pattern"></a>
## 🚀 Usage Pattern

### 1. 🏗️ Deploy the ERC7702TokenApprover

```solidity
// Deploy with the Permit3 contract address
ERC7702TokenApprover approver = new ERC7702TokenApprover(PERMIT3_ADDRESS);
```

### 2. 🔗 Create ERC-7702 Transaction

Users create an ERC-7702 transaction that:
- **Authorizes delegation** to the `ERC7702TokenApprover` contract
- **Calls** `approve(address[] tokens)` via delegatecall

### 3. ✅ Result

The user's EOA will have infinite allowances set for all specified tokens to the Permit3 contract.

<a id="contract-functions"></a>
## 📋 Contract Functions

### 🔑 Core Function

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

<a id="important-notes"></a>
## ⚠️ Important Notes

### 🎯 ERC-7702 Only Design

This contract is **specifically designed for ERC-7702 delegatecalls**. When called directly:
- The allowances are set for the contract itself, not the caller
- This is not useful behavior and should be avoided

<a id="security-considerations"></a>
### 🛡️ Security Considerations

1. **♾️ Infinite Approvals**: The contract always sets infinite allowances
2. **🔓 No Access Control**: Publicly callable (security comes from ERC-7702 authorization)
3. **⚛️ Atomic Operations**: All approvals succeed or the entire transaction reverts
4. **🔄 Single Use**: Each ERC-7702 authorization is for one transaction only

<a id="example-transaction-structure"></a>
## 🔗 Example ERC-7702 Transaction Structure

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

<a id="integration-with-permit3"></a>
## 🔧 Integration with Permit3

After using this contract, users can:
1. **🌉 Cross-Chain Permits**: Use Permit3's cross-chain permit functionality
2. **🚀 Gasless Transfers**: Transfer tokens without additional approvals
3. **⚡ Multi-Chain Operations**: Enjoy gasless token operations across multiple chains

<a id="error-handling"></a>
## 🚨 Error Handling

The contract includes specific error types:
- `NoTokensProvided()`: Empty token array
- `ApprovalFailed(address token)`: Token approval failed

<a id="gas-considerations"></a>
## ⛽ Gas Considerations

- **📈 Linear Scaling**: Gas cost scales linearly with number of tokens
- **💰 Per-Token Cost**: Each token approval costs ~24k gas
- **🎯 Efficiency**: Batch processing is more efficient than individual approvals

---

<a id="navigation-footer"></a>
| ⬅️ Previous | 🏠 Section | ➡️ Next |
|:-----------|:----------:|------------:|
| [Security Best Practices](/docs/guides/security-best-practices.md) | [Guides](/docs/guides/README.md) | [Witness Integration](/docs/guides/witness-integration.md) |

[🔝 Back to Top](#erc7702-integration-top)