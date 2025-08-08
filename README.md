# 🔏 Permit3: One-Click Cross-Chain Token Permissions

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)

Permit3 is a revolutionary protocol that enables **cross-chain token approvals and transfers with a single signature**. It unlocks a one-signature cross-chain future through Unbalanced Merkle Trees and non-sequential nonces, while maintaining Permit2 compatibility.

> **"Permit3 unlocks a one-click/signature cross-chain future."**

## ✨ Key Features

- 🌉 **Cross-Chain Operations**: Authorize token operations across multiple blockchains with one signature
- 🔐 **Direct Permit Execution**: Execute permit operations without signatures when caller has authority
- 🔗 **ERC-7702 Integration**: Account Abstraction support for enhanced user experience
- 🌲 **Unbalanced Merkle Trees**: Hybrid two-part structure for cross-chain proofs:
  ```
                 [H1] → [H2] → [H3] → ROOT  ← Sequential chain (top part)
              /      \      \      \
            [BR]    [D5]   [D6]   [D7]      ← Additional chain data
           /     \
       [BH1]     [BH2]                      ← Balanced tree (bottom part)
      /    \     /    \
    [D1]  [D2] [D3]  [D4]                   ← Leaf data
  ```
  - 🏗️ **Two-Part Design**: Combines balanced merkle tree (bottom) with sequential hash chain (top)
  - 🔄 **Bottom Part**: Efficient membership proofs with O(log n) complexity
  - 🔗 **Top Part**: Sequential chaining for linking across chains  
  - 🚀 **Gas Optimization**: Chain ordering (cheapest chains first, expensive last)
  - 🎯 **"Unbalanced"**: Deliberate deviation from balanced trees at top level
  - 💡 **Security**: Uses merkle tree verification for compatibility
- 🧩 **Witness Functionality**: Attach arbitrary data to permits for enhanced verification and complex permission patterns
- 🔄 **Flexible Allowance Management**:
    - ⬆️ Increase/decrease allowances asynchronously
    - ⏱️ Time-bound permissions with automatic expiration
    - 🔒 Account locking for enhanced security
- ⚡ **Gas-Optimized Design**:
    - 🔢 Non-sequential nonces for concurrent operations
    - 🗃️ Bitmap-based nonce tracking for efficient gas usage
    - 🔍 Standard merkle proofs using OpenZeppelin's MerkleProof library
- 🛡️ **Emergency Security Controls**:
    - 🚫 Cross-chain revocation system
    - 🔐 Account locking mechanism
    - ⏳ Time-bound permissions
- 🔄 **Full Permit2 Compatibility*:
    - 📄 Implements basic transfer Permit2 interfaces
    - 🔌 Drop-in replacement for existing integrations

## 📚 Documentation

Comprehensive documentation is available in the [docs](./docs) directory:

| Section | Description | Quick Links |
|---------|-------------|-------------|
| [🏠 Overview](./docs/README.md) | Getting started with Permit3 | [Introduction](./docs/README.md#getting-started) |
| [🏗️ Core Concepts](./docs/concepts/README.md) | Understanding the fundamentals | [Architecture](./docs/concepts/architecture.md) · [Witnesses](./docs/concepts/witness-functionality.md) · [Cross-Chain](./docs/concepts/cross-chain-operations.md) · [Merkle Trees](./docs/concepts/unbalanced-merkle-tree.md) · [Nonces](./docs/concepts/nonce-management.md) · [Allowances](./docs/concepts/allowance-system.md) |
| [📚 Guides](./docs/guides/README.md) | Step-by-step tutorials | [Quick Start](./docs/guides/quick-start.md) · [ERC-7702](./docs/guides/erc7702-integration.md) · [Witness Integration](./docs/guides/witness-integration.md) · [Cross-Chain](./docs/guides/cross-chain-permit.md) · [Signatures](./docs/guides/signature-creation.md) · [Security](./docs/guides/security-best-practices.md) |
| [📋 API Reference](./docs/api/README.md) | Technical specifications | [Full API](./docs/api/api-reference.md) · [Data Structures](./docs/api/data-structures.md) · [Interfaces](./docs/api/interfaces.md) · [Events](./docs/api/events.md) · [Error Codes](./docs/api/error-codes.md) |
| [💻 Examples](./docs/examples/README.md) | Code samples | [ERC-7702](./docs/examples/erc7702-example.md) · [Witness](./docs/examples/witness-example.md) · [Cross-Chain](./docs/examples/cross-chain-example.md) · [Allowance](./docs/examples/allowance-management-example.md) · [Security](./docs/examples/security-example.md) · [Integration](./docs/examples/integration-example.md) |

## 🔄 Permit2 Compatibility

Permit3 implements IPermit for Permit2 transfer compatibility:

```solidity
// Existing contracts using Permit2 can work without changes
IPermit2 permit2 = IPermit2(PERMIT3_ADDRESS);
permit2.transferFrom(msg.sender, recipient, 1000e6, USDC);
```

### ✅ Supported Permit2 Functions
```solidity
// Standard approvals
function approve(address token, address spender, uint160 amount, uint48 expiration) external;

// Direct transfers
function transferFrom(address from, address to, uint160 amount, address token) external;

// Batched transfers
function transferFrom(AllowanceTransferDetails[] calldata transfers) external;

// Permission management
function allowance(address user, address token, address spender) 
    external view returns (uint160 amount, uint48 expiration, uint48 nonce);
function lockdown(TokenSpenderPair[] calldata approvals) external;
```

### 🔗 Enhanced Functions (Permit3 Exclusive)
```solidity
// Direct permit execution (no signatures required, caller is owner)
function permit(AllowanceOrTransfer[] memory permits) external;

// Single-chain permit operations with signatures  
function permit(address owner, bytes32 salt, uint48 deadline, uint48 timestamp, 
                AllowanceOrTransfer[] calldata permits, bytes calldata signature) external;

// Cross-chain operations with UnbalancedProofs and signatures
function permit(address owner, bytes32 salt, uint48 deadline, uint48 timestamp,
                UnbalancedPermitProof calldata proof, bytes calldata signature) external;
```

**Direct Permit Usage:**
```solidity
// Execute permit operations directly (msg.sender becomes token owner)
AllowanceOrTransfer[] memory operations = [
    AllowanceOrTransfer({
        modeOrExpiration: 1735689600, // expiration timestamp
        token: USDC_ADDRESS,
        account: DEX_ADDRESS,
        amountDelta: 1000e6 // 1000 USDC allowance
    })
];

permit3.permit(operations); // No signature needed, no chainId needed!
```

## 💡 Core Concepts

### 🔄 Allowance Operations

The protocol centers around the `AllowanceOrTransfer` structure:

```solidity
struct AllowanceOrTransfer {
    uint48 modeOrExpiration;    // Operation mode/expiration
    address token;              // Token address
    address account;            // Approved spender/recipient
    uint160 amountDelta;        // Amount change/transfer amount
}
```

#### ⚙️ Operation Modes

1. 📤 **Transfer Mode** (`modeOrExpiration = 0`)
    - Executes immediate token transfer
    - `account` is recipient
    - `amountDelta` is transfer amount

2. 📉 **Decrease Mode** (`modeOrExpiration = 1`)
    - Reduces existing allowance
    - `amountDelta`: regular decrease amount
    - Special: `type(uint160).max` resets to 0

3. 🔒 **Lock Mode** (`modeOrExpiration = 2`)
    - Enters special locked state
    - Blocks increases/transfers
    - Rejects all operations until unlocked
    - Sets approval to 0 for that token/account pair

4. 🔓 **Unlock Mode** (`modeOrExpiration = 3`)
    - Cancels locked state
    - Tracks unlock timestamp
    - Sets allowance to provided amount

5. 📈 **Increase Mode** (`modeOrExpiration > 3`)
    - Value acts as expiration timestamp
    - Updates if timestamp is newer
    - `amountDelta`: increase amount
    - Special cases:
        - `0`: Updates expiration only
        - `type(uint160).max`: Unlimited approval

### ⏱️ Timestamp Management

```solidity
struct Allowance {
    uint160 amount;
    uint48 expiration;
    uint48 timestamp;
}
```

- ⏰ Timestamps order operations across chains
- 🔄 Most recent timestamp takes precedence in expiration updates
- 🚧 Prevents cross-chain race conditions
- 🔑 Critical for async allowance updates

### 🔐 Account Locking

Locked accounts have special restrictions:
- 🚫 Cannot increase/decrease allowances
- 🚫 Cannot execute transfers
- 🔑 Must submit unlock command with timestamp validation to disable
- 🛡️ Provides emergency security control

## 🔌 Integration

### 🛠️ Basic Setup
```solidity
// Access Permit2 compatibility
IPermit permit = IPermit(PERMIT3_ADDRESS);
permit.transferFrom(msg.sender, recipient, 1000e6, USDC);

// Access Permit3 features
IPermit3 permit3 = IPermit3(PERMIT3_ADDRESS);
```

### 📝 Example Operations

```solidity
// 1. Create permits array directly
AllowanceOrTransfer[] memory permits = new AllowanceOrTransfer[](3);

// 2. Increase Allowance
permits[0] = AllowanceOrTransfer({
    modeOrExpiration: uint48(block.timestamp + 1 days),
    token: USDC,
    account: DEX,
    amountDelta: 1000e6
});

// 3. Lock Account
permits[1] = AllowanceOrTransfer({
    modeOrExpiration: 2,
    token: USDC,
    account: address(0),
    amountDelta: 0
});

// 4. Execute Transfer
permits[2] = AllowanceOrTransfer({
    modeOrExpiration: 0,
    token: USDC,
    account: recipient,
    amountDelta: 500e6
});

// Execute the permits
permit3.permit(owner, salt, deadline, timestamp, permits, signature);
```

### 🌉 Cross-Chain Usage with UnbalancedProofs

```javascript
// Create permits for each chain
const ethPermits = {
    chainId: 1,
    permits: [{
        modeOrExpiration: futureTimestamp,
        token: USDC_ETH,
        account: DEX_ETH,
        amountDelta: 1000e6
    }]
};

const arbPermits = {
    chainId: 42161,
    permits: [{
        modeOrExpiration: 1, // Decrease mode
        token: USDC_ARB,
        account: DEX_ARB,
        amountDelta: 500e6
    }]
};

// Hash each chain's permits to create leaf nodes
const ethLeaf = permit3.hashChainPermits(ethPermits);
const arbLeaf = permit3.hashChainPermits(arbPermits);

// Build merkle tree and get root (typically done off-chain)
const leaves = [ethLeaf, arbLeaf];
const merkleRoot = buildMerkleRoot(leaves);

// Generate merkle proof for specific chain
const arbProof = generateMerkleProof(leaves, 1); // Index 1 for Arbitrum
const proof = { nodes: arbProof };

// Create and sign with the unbalanced root
const signature = signPermit3(owner, salt, deadline, timestamp, merkleRoot);
```

## 🛡️ Security Guidelines

1. 🔑 **Allowance Management**
    - ⏱️ Set reasonable expiration times
    - 🔒 Use lock mode for sensitive accounts
    - 📊 Monitor allowance changes across chains

2. ⏰ **Timestamp Validation**
    - 📋 Validate operation ordering
    - ⏳ Check for expired timestamps
    - 🔐 Handle locked state properly

3. 🌐 **Cross-Chain Security**
    - 🔍 Verify chain IDs match
    - 🔢 Use unique nonces
    - 👀 Monitor pending operations

## 👨‍💻 Development

```bash
# Install
forge install

# Test
forge test

# Deploy
forge script script/DeployPermit3.s.sol:DeployPermit3 \
    --rpc-url <RPC_URL> \
    --private-key <KEY> \
    --broadcast
```

## 📄 License

MIT License - see [LICENSE](./LICENSE)