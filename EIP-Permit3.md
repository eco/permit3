---
eip: TBD
title: 🔏 Permit3 - Cross-Chain Token Approvals and Transfers with Witness Data
description: Making token approvals work across multiple blockchains with a single signature, with support for arbitrary witness data verification
author: Your Name (@your-github-handle)
discussions-to: TBD
status: Draft
type: Standards Track
category: ERC
created: 2024-02-23
requires: 20, 712, 2612
---

## Abstract

The Permit3 protocol introduces a new standard for managing token transfers and approvals across multiple blockchains. While maintaining compatibility with Permit2's transfer functions, it enables single-signature cross-chain operations and provides advanced features for asynchronous allowance management, timestamped updates, and account security controls. A key innovation in Permit3 is the addition of witness functionality, which allows arbitrary data to be included in the signature verification process, enabling more complex permission patterns and enhanced security across chains.

## Motivation

The limitations of existing token approval systems across multiple blockchains create significant friction for users and developers:

1. **Cross-Chain Fragmentation**: Currently, authorizing token operations across multiple blockchains requires:
   - Separate signatures for each blockchain
   - Independent transaction processing on each chain
   - Multiple gas fees across different networks
   - Complex user experiences with repeated signing

2. **Limited Verification Capabilities**: Current approval systems lack the ability to:
   - Include application-specific data in the signature verification
   - Validate complex conditions as part of the approval process
   - Support advanced use cases requiring contextual information
   - Bind additional data to signatures for enhanced security

3. **System Limitations**: Existing solutions (including Permit2) have operational constraints:
   - No support for unified cross-chain permissions
   - Lack of efficient emergency revocation across chains
   - Sequential operation requirements causing UX bottlenecks
   - Limited flexibility for complex DeFi applications

4. **Developer Integration Challenges**: Building applications that work across chains requires:
   - Managing different approval systems on each chain
   - Tracking permissions across multiple networks
   - Implementing complex synchronization logic
   - Handling varying security models

## Specification

> **Note:** For a detailed explanation of the UnhingedMerkleTree data structure used in this EIP, please see [EIP-UnhingedMerkleTree](./EIP-UnhingedMerkleTree.md).

### Core Data Structures

Permit3 builds on these fundamental data structures:

```solidity
/**
 * @notice Represents a token allowance modification or transfer operation
 * @param modeOrExpiration Mode indicators:
 *        = 0: Immediate transfer mode
 *        = 1: Decrease allowance mode
 *        = 2: Lock allowance mode
 *        = 3: UnLock allowance mode
 *        > 3: Increase allowance mode, new expiration timestamp
 * @param token Address of the ERC20 token
 * @param account Transfer recipient (for mode 0) or approved spender (for allowance)
 * @param amountDelta Allowance change or transfer amount
 */
struct AllowanceOrTransfer {
    uint48 modeOrExpiration;
    address token;
    address account;
    uint160 amountDelta;
}

/**
 * @notice Struct grouping permits for a specific chain
 * @param chainId Target chain identifier
 * @param permits Array of permit operations for this chain
 */
struct ChainPermits {
    uint256 chainId;
    AllowanceOrTransfer[] permits;
}

/**
 * @notice Struct containing proof data for cross-chain permit operations using Unhinged Merkle Tree
 * @param permits Permit operations for the current chain
 * @param unhingedProof Unhinged Merkle Tree proof structure for verification
 */
struct UnhingedPermitProof {
    ChainPermits permits;
    UnhingedProof unhingedProof;
}
```

### Witness Functionality

A key innovation in Permit3 is the addition of witness functionality, which allows including arbitrary data in the signature verification process:

```solidity
/**
 * @notice Process permit with additional witness data for single chain operations
 * @param owner Token owner address
 * @param salt Unique salt for replay protection
 * @param deadline Signature expiration timestamp
 * @param timestamp Timestamp of the permit
 * @param chain Chain-specific permit data
 * @param witness Additional data to include in signature verification
 * @param witnessTypeString EIP-712 type definition for witness data
 * @param signature EIP-712 signature authorizing the permits
 */
function permitWitnessTransferFrom(
    address owner,
    bytes32 salt,
    uint256 deadline,
    uint48 timestamp,
    ChainPermits memory chain,
    bytes32 witness,
    string calldata witnessTypeString,
    bytes calldata signature
) external;
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

### Cross-Chain Operations with Gas Optimization

#### UnhingedProofs Structure for Optimal Gas Efficiency
```javascript
// Example: Three-chain operation with UnhingedProofs
// Chains ordered from cheapest to most expensive calldata
const cheapChainRoot = permit3.hashChainPermits(ArbitrumPermissions);  // L2 with lower calldata costs
const mediumChainRoot = permit3.hashChainPermits(OptimismPermissions); // L2 with moderate calldata costs
const expensiveChainRoot = permit3.hashChainPermits(EthereumPermissions); // L1 with highest calldata costs

// Order chains strategically: cheapest first, most expensive last
const unhingedRoot = UnhingedMerkleTree.createUnhingedRoot([cheapChainRoot, mediumChainRoot, expensiveChainRoot]);
```

This strategic ordering optimizes gas consumption across all chains:
- Chains with expensive calldata (like Ethereum mainnet) are positioned last, requiring only a minimal preHash value
- Chains with cheaper calldata (like L2s) are positioned earlier, where larger proof structures are more economical
- Overall cross-chain transaction costs are minimized, making complex operations viable

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

2. **Step 2: Build the Unhinged Merkle Tree**
```
UnhingedMerkleTree([Ethereum Permissions, Arbitrum Permissions, Optimism Permissions])
```

3. **Step 3: Create One Master Signature**
    - Takes all permissions in the Unhinged Merkle Tree
    - Creates a secure proof that works across all chains
    - Signs the UnhingedRoot for universal verification

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
function invalidateNonces(address owner, UnhingedCancelPermitProof proof, bytes calldata signature) external;
```

3. **Flexible Timing**
```solidity
// You can:
transferOrExpiration = 1;         // Use tokens right now
transferOrExpiration = 0;         // Permission never expires
transferOrExpiration = timestamp; // Expires at a specific time
```

### The Magic Behind Connecting Chains

Here's how we link permissions across chains securely using UnhingedProofs:

1. **Building the Unhinged Merkle Tree**
```solidity
// Take three permissions:
root1 = permit3.hashChainPermits(EthereumPermissions);
root2 = permit3.hashChainPermits(ArbitrumPermissions);
root3 = permit3.hashChainPermits(OptimismPermissions);

// Create the unhinged root:
unhingedRoot = UnhingedMerkleTree.hashLink(UnhingedMerkleTree.hashLink(root1, root2), root3);
```

2. **Using UnhingedProofs with Cost Optimization**
```solidity
// For Ethereum (expensive chain, positioned last in the tree):
{
    "unhingedProof": {
        "preHash": keccak256(root1, root2), // Combined hash of cheaper chains
        "subtreeProof": [proofForEthereumPermissions],
        "followingHashes": [] // No following hashes needed (minimal calldata)
    },
    "permits": EthereumPermissions
}

// For Arbitrum (cheap chain, positioned first in the tree):
{
    "unhingedProof": {
        "preHash": bytes32(0), // No preHash needed for first chain
        "subtreeProof": [proofForArbitrumPermissions],
        "followingHashes": [root2, root3] // More data, but on a cheaper chain
    },
    "permits": ArbitrumPermissions
}
```

This approach ensures that:
- The expensive chain (Ethereum) uses minimal calldata (just a preHash)
- Cheaper chains carry more of the proof data burden
- Overall gas costs across the ecosystem are minimized

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
// Test 1: Basic cross-chain permission with UnhingedProofs
function testCrossChainPermit() {
    // Give permission on Ethereum
    ChainPermits memory ethPermits = createEthPermits();
    
    // Use it on Arbitrum with UnhingedProofs
    UnhingedPermitProof memory proof = UnhingedMerkleTree.createOptimizedProof(
        preHash,
        subtreeProof,
        followingHashes
    );
    permit3.permit(owner, salt, deadline, timestamp, proof, signature);
}

// Test 2: Emergency cancellation with UnhingedProofs
function testEmergencyLockdown() {
    // Cancel all permissions everywhere using UnhingedProofs
    UnhingedCancelPermitProof memory proof = UnhingedMerkleTree.createOptimizedProof(
        preHash,
        subtreeProof,
        followingHashes
    );
    permit3.invalidateNonces(owner, proof, signature);
}
```

## Reference Implementation

The complete implementation is available at: [Permit3 Repository]

## Witness Functionality Applications

Witness functionality in Permit3 enables numerous advanced use cases:

1. **Order Matching Systems**:
   - Include order parameters in the witness data
   - Verify order details on-chain during execution
   - Enable trustless peer-to-peer token exchanges
   - Support complex order matching conditions

2. **Multi-Signature Approvals**:
   - Include signatures from multiple parties in the witness data
   - Verify all signatures are valid before processing
   - Enable governance-controlled token operations
   - Support complex approval workflows

3. **Conditional Transfers**:
   - Encode transfer conditions in the witness data
   - Verify conditions are met before executing
   - Support price-conditional token operations
   - Enable time-based or event-based executions

4. **Cross-Protocol Interactions**:
   - Include data from other protocols in witness
   - Verify cross-protocol state or permissions
   - Enable composable DeFi applications
   - Support complex multi-protocol workflows

## Security Considerations

When implementing or using Permit3, consider these important security aspects:

1. **Signature Security**:
   - Set reasonable expiration times for all signatures
   - Use unique salts for each signature to prevent replay
   - Verify chain IDs match to prevent cross-chain replays
   - Include sufficient context in witness data to prevent misuse

2. **Witness Data Verification**:
   - Always validate witness data before taking action based on it
   - Verify witness type strings are properly formatted
   - Use application-specific verification logic for witness data
   - Be aware that any application can process a signature if it has the correct witness type

3. **Cross-Chain Security**:
   - Understand that operations execute independently on each chain
   - Implement proper error handling for cross-chain operations
   - Consider the implications of partial execution across chains
   - Verify the contract addresses are correct on each chain

4. **Implementation Security**:
   - Follow secure implementation patterns for EIP-712 signatures
   - Protect against front-running where applicable
   - Implement proper access controls for administrative functions
   - Thoroughly test all edge cases and error conditions

## Copyright

Copyright and related rights: see [LICENSE](./LICENSE).
