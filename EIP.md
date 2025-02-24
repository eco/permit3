---
eip: TBD
title: Permit3 - Cross-Chain Token Approvals and Transfers
description: Making token approvals work across multiple blockchains with a single signature
author: Your Name (@your-github-handle)
discussions-to: TBD
status: Draft
type: Standards Track
category: ERC
created: 2024-02-23
requires: 20, 712, 2612
---

## Abstract

The Permit3 protocol introduces a new standard for managing token transfers and approvals across multiple blockchains. While maintaining compatibility with Permit2's transfer functions, it enables single-signature cross-chain operations and provides advanced features for asynchronous allowance management, timestamped updates, and account security controls.multiple wallets on different blockchains, and you want to give someone permission to use your tokens. Currently, you need to sign separate permissions for each chain. This EIP introduces Permit3, which lets you sign just once to give permissions across all chains. It works with all your existing token permissions (Permit2) and adds new features to make everything safer and easier.

## Motivation

Let's understand why we need Permit3:

1. Right now, if you want to use your tokens on three different chains:
    - You sign three different permissions from your wallet
    - You wait for each one to be processed

2. This is like having three different keys for three different doors, when you could just have one master key.

3. Also, the current system (Permit2) has some limitations:
    - You can't set multiple permissions on one chain at once
    - You can't easily cancel all permissions if something goes wrong
    - You have to do things in a specific order, which can slow down wallets with multiple asynchronous operations

## Specification

### The Building Blocks

Let's break down how Permit3 works:

```solidity
// 1. A single permission looks like this:
struct AllowanceOrTransfer {
   uint48 transferOrExpiration;  // Operation mode/expiration
   address token;               // Token address
   address spender;            // Spender/recipient address
   uint160 amountDelta;        // Amount change/transfer value
}

// 2. Permissions for one chain look like this:
struct ChainPermits {
    uint64 chainId;              // Which chain is this for
    uint48 nonce;                // A unique number to keep track
   AllowanceOrTransfer[] permits; // List of permissions
}

// 3. When you want to use permissions across chains:
struct Permit3Proof {
    bytes32 preHash;             // Proof of previous chain permissions
    ChainPermits permits;        // Current chain permissions
    bytes32[] followingHashes;   // Proof of next chain permissions
}
```

### Operation Modes

The `transferOrExpiration` field defines four distinct operation types:

1. **Transfer** (`value = 0`)
   - Direct token transfer execution
   - `spender` = recipient address
   - `amountDelta` = transfer amount

2. **Decrease** (`value = 1`)
   - Reduces allowance
   - Normal: decrease by `amountDelta`
   - Special: `type(uint160).max` sets to zero

3. **Lock** (`value = 2`)
   - Activates account security mode
   - Sets allowance to zero
   - Records timestamp for future validations
   - Only allows decrease operations

4. **Increase/Update** (`value > 2`)
   - Timestamp-based expiration
   - Updates allowance if timestamp is newer
   - Special cases:
      - `amountDelta = 0`: Updates expiration only
      - `amountDelta = type(uint160).max`: Unlimited approval

### State Management

#### Timestamp Control
```solidity
// Update rules
if (timestamp > allowed.timestamp) {
    allowed.expiration = transferOrExpiration;
    allowed.timestamp = timestamp;
}

// Lock validation
if (allowed.expiration == LOCKED_ALLOWANCE && 
    timestamp < allowed.timestamp) {
    revert AllowanceLocked();
}
```

#### Asynchronous Processing
- Operations can arrive in any order
- Most recent timestamp takes precedence in expiration updates
- Prevents cross-chain race conditions
- Maintains consistent state across chains

### Cross-Chain Operations

#### Hash Chain Construction
```javascript
// Example: Three-chain operation
const finalHash = keccak256(
    keccak256(
        keccak256(chainAHash),
        chainBHash
    ),
    chainCHash
);
```

### How It Works

Imagine you want to give permissions on three chains: Ethereum, Arbitrum, and Optimism.

1. **Step 1: Create Your Permissions**
```javascript
// On Ethereum:
{
    "token": "USDC",
    "spender": "Uniswap",
    "amount": 1000,
    "expires": "tomorrow"
}

// On Arbitrum:
{
    "token": "USDC",
    "spender": "GMX",
    "amount": 500,
    "expires": "next week"
}

// On Optimism:
{
    "token": "USDC",
    "spender": "Velodrome",
    "amount": 200,
    "expires": "next month"
}
```

2. **Step 2: Link Them Together**
```
Ethereum Permission → Arbitrum Permission → Optimism Permission
```

3. **Step 3: Create One Master Signature**
    - Takes all permissions
    - Links them together with special math (hashing)
    - Creates one secure signature that works everywhere

### Special Features

1. **Works with Old Systems**
```solidity
// If you already use Permit2, this still works:
function approve(address token, address spender, uint160 amount) external;
function transferFrom(address from, address to, uint160 amount) external;
```

2. **Emergency Stop Button**
```solidity
// Cancel all permissions everywhere with one signature
function lockdownAcrossChains(address owner, CancelProof proof) external;
```

3. **Flexible Timing**
```solidity
// You can:
transferOrExpiration = 1;         // Use tokens right now
transferOrExpiration = 0;         // Permission never expires
transferOrExpiration = timestamp; // Expires at a specific time
```

### The Magic Behind Connecting Chains

Here's how we link permissions across chains securely:

1. **Making the Chain**
```solidity
// Take three permissions:
hash1 = hash(EthereumPermission);
hash2 = hash(ArbitrumPermission);
hash3 = hash(OptimismPermission);

// Link them:
finalHash = hash(hash(hash1 + hash2) + hash3);
```

2. **Using the Chain**
```solidity
// On Arbitrum, you prove:
{
    "whatCameBefore": hash1,
    "myPermission": ArbitrumPermission,
    "whatComesNext": [hash3]
}
```

## Security

Important safety features:

1. **Can't Be Copied**
    - Each permission works only on its intended chain
    - You can't copy a permission from one chain to another

2. **Time Limits**
    - All permissions can have expiration dates
    - After expiration, they stop working automatically

3. **Emergency Controls**
    - You can cancel all permissions with one signature
    - Works across all chains at once

4. **No Order Required**
    - Use permissions in any order
    - If one fails, others still work

## Backwards Compatibility

Everything that worked with Permit2 still works:

```solidity
// Old code:
permit2.approve(token, spender, amount);

// Still works with Permit3:
permit3.approve(token, spender, amount);
```

## Test Cases

Here are examples showing how it works:

```solidity
// Test 1: Basic cross-chain permission
function testCrossChainPermit() {
    // Give permission on Ethereum
    ChainPermits memory ethPermits = createEthPermits();
    
    // Use it on Arbitrum
    Permit3Proof memory proof = createProof(ethPermits);
    permit3.permit(owner, deadline, proof, signature);
}

// Test 2: Emergency cancellation
function testEmergencyLockdown() {
    // Cancel all permissions everywhere
    CancelProof memory proof = createCancelProof();
    permit3.lockdownAcrossChains(owner, proof, signature);
}
```

## Reference Implementation

The complete implementation is available at: [Permit3 Repository]

## Security Considerations

Keep these things in mind:

1. Always set reasonable expiration times
2. Don't sign permissions for tokens you don't own
3. Keep your signing key safe
4. Check chain IDs carefully
5. Verify contracts on each chain

## Copyright

Copyright and related rights: see [LICENSE](./LICENSE).
