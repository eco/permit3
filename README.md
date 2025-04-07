# Permit3: One-Click Cross-Chain Token Permissions

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)

Permit3 is a revolutionary protocol that enables **cross-chain token approvals and transfers with a single signature**. It unlocks a one-signature cross-chain future through innovative UnhingedProofs and non-sequential nonces, while maintaining Permit2 compatibility.

> **"Permit3 unlocks a one-click/signature cross-chain future."**

## Key Features

- **Cross-Chain Operations**: Authorize token operations across multiple blockchains with one signature
- **Unhinged Merkle Trees**: A novel two-part data structure that combines:
  ```
               [H1] → [H2] → [H3] → ROOT  ← Sequential chain (top part)
            /      \      \      \
          [BR]    [D5]   [D6]   [D7]      ← Additional chain data
         /     \
     [BH1]     [BH2]                      ← Balanced tree (bottom part)
    /    \     /    \
  [D1]  [D2] [D3]  [D4]                   ← Leaf data
  ```
  - Bottom part: Standard balanced tree for efficient membership proofs within a chain
  - Top part: Sequential hash chain incorporating the balanced root and cross-chain data
  - Benefits: Optimal gas usage by processing only what each chain needs
- **Witness Functionality**: Attach arbitrary data to permits for enhanced verification and complex permission patterns
- **Flexible Allowance Management**:
    - Increase/decrease allowances asynchronously
    - Time-bound permissions with automatic expiration
    - Account locking for enhanced security
- **Gas-Optimized Design**:
    - Non-sequential nonces for concurrent operations
    - Bitmap-based nonce tracking for efficient gas usage
    - UnhingedProofs for efficient and secure cross-chain verification
- **Emergency Security Controls**:
    - Cross-chain revocation system
    - Account locking mechanism
    - Time-bound permissions
- **Full Permit2 Compatibility**:
    - Implements all Permit2 interfaces
    - Drop-in replacement for existing integrations

## Documentation

Comprehensive documentation is available in the [docs](./docs) directory:

- [Overview and Getting Started](./docs/README.md)
- [Core Concepts](./docs/concepts/index.md)
    - [Architecture](./docs/concepts/architecture.md)
    - [Witness Functionality](./docs/concepts/witness-functionality.md)
    - [Cross-Chain Operations](./docs/concepts/cross-chain-operations.md)
    - [Unhinged Merkle Trees](./docs/concepts/unhinged-merkle-tree.md)
    - [Nonce Management](./docs/concepts/nonce-management.md)
- [Guides](./docs/guides/index.md)
    - [Quick Start Guide](./docs/guides/quick-start.md)
- [API Reference](./docs/api/index.md)
    - [Complete API Reference](./docs/api/api-reference.md)
- [Examples](./docs/examples/index.md)
    - [Witness Example](./docs/examples/witness-example.md)

## Permit2 Compatibility

Permit3 implements IPermit for Permit2 trasfer compatibility:

```solidity
// Existing Permit2 contracts work without changes
IPermit permit = IPermit(PERMIT3_ADDRESS);

// Access extended functionality
IPermit3 permit3 = IPermit3(PERMIT3_ADDRESS);
```

### Supported Permit2 Functions
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

## Concepts

### Allowance Operations

The protocol centers around the `AllowanceOrTransfer` structure:

```solidity
struct AllowanceOrTransfer {
    uint48 transferOrExpiration;  // Operation mode/expiration
    address token;               // Token address
    address spender;            // Approved spender/recipient
    uint160 amountDelta;        // Amount change/transfer amount
}
```

#### Operation Modes

1. **Transfer Mode** (`transferOrExpiration = 0`)
    - Executes immediate token transfer
    - `spender` is recipient
    - `amountDelta` is transfer amount

2. **Decrease Mode** (`transferOrExpiration = 1`)
    - Reduces existing allowance
    - `amountDelta`: regular decrease amount
    - Special: `type(uint160).max` resets to 0

3. **Lock Mode** (`transferOrExpiration = 2`)
    - Enters special locked state
    - Blocks increases/transfers
    - Rejects all operations until unlocked

4. **Unlock Mode** (`transferOrExpiration = 3`)
    - Cancels locked state
    - Tracks unlock timestamp
    - Sets allowance to provided amount

5. **Increase Mode** (`transferOrExpiration > 3`)
    - Value acts as expiration timestamp
    - Updates if timestamp is newer
    - `amountDelta`: increase amount
    - Special cases:
        - `0`: Updates expiration only
        - `type(uint160).max`: Unlimited approval

### Timestamp Management

```solidity
struct Allowance {
    uint160 amount;
    uint48 expiration;
    uint48 timestamp;
}
```

- Timestamps order operations across chains
- Most recent timestamp takes precedence in expiration updates
- Prevents cross-chain race conditions
- Critical for async allowance updates

### Account Locking

Locked accounts have special restrictions:
- Cannot increase/decrease allowances
- Cannot execute transfers
- Must submit unlock command with timestamp validation to disable
- Provides emergency security control

## Integration

### Basic Setup
```solidity
// Access Permit2 compatibility
IPermit permit = IPermit(PERMIT3_ADDRESS);

// Access Permit3 features
IPermit3 permit3 = IPermit3(PERMIT3_ADDRESS);
```

### Example Operations

```solidity
// 1. Increase Allowance
ChainPermits memory permitData = ChainPermits({
    chainId: block.chainid,
    nonce: generateNonce(),
    permits: [AllowanceOrTransfer({
        transferOrExpiration: block.timestamp + 1 days,
        token: USDC,
        spender: DEX,
        amountDelta: 1000e6
    })]
});

// 2. Lock Account
permitData.permits.push(AllowanceOrTransfer({
    transferOrExpiration: 2,
    token: USDC,
    spender: address(0),
    amountDelta: 0
}));

// 3. Execute Transfer
permitData.permits.push(AllowanceOrTransfer({
    transferOrExpiration: 0,
    token: USDC,
    spender: recipient,
    amountDelta: 500e6
}));
```

### Cross-Chain Usage with UnhingedProofs

```javascript
// Create permits for each chain
const ethPermits = {
    chainId: 1,
    permits: [{
        transferOrExpiration: futureTimestamp,
        token: USDC_ETH,
        spender: DEX_ETH,
        amountDelta: 1000e6
    }]
};

const arbPermits = {
    chainId: 42161,
    permits: [{
        transferOrExpiration: 1, // Decrease mode
        token: USDC_ARB,
        spender: DEX_ARB,
        amountDelta: 500e6
    }]
};

// Generate subtree roots for each chain
const ethRoot = hashSubtree(ethPermits);
const arbRoot = hashSubtree(arbPermits);

// Create unhinged root and proof
const unhingedRoot = createUnhingedRoot([ethRoot, arbRoot]);
const unhingedProof = createUnhingedProof(ethRoot, arbRoot);

// Create and sign with the unhinged root
const signature = signPermit3(owner, salt, deadline, timestamp, unhingedRoot);
```

## Security Guidelines

1. **Allowance Management**
    - Set reasonable expiration times
    - Use lock mode for sensitive accounts
    - Monitor allowance changes across chains

2. **Timestamp Validation**
    - Validate operation ordering
    - Check for expired timestamps
    - Handle locked state properly

3. **Cross-Chain Security**
    - Verify chain IDs match
    - Use unique nonces
    - Monitor pending operations

## Development

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

## License

MIT License - see [LICENSE](./LICENSE)