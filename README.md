# Permit3

The Permit3 protocol enables cross-chain token approvals and transfers while maintaining Permit2-compatible transfer functions. It adds cross-chain capabilities through hash chaining and non-sequential nonces.

## Key Features

- Cross-chain token transfers and approvals with single signature
- Flexible allowance management system
    - Increase/decrease allowances asynchronously
    - Time-bound permissions with automatic expiration
    - Account locking for enhanced security
- Non-sequential nonces for concurrent operations
- Emergency cross-chain revocation system
- Transfer functions compatible with Permit2

## Permit2 Compatibility

Permit3 implements IPermit for Permit2 transfer compatibility:

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
    - Allows only decreases
    - Tracks lock timestamp

4. **Increase Mode** (`transferOrExpiration > 2`)
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
- Cannot increase allowances
- Cannot execute transfers
- Must pass timestamp validation to unlock
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

### Cross-Chain Usage

```javascript
// Create permits for each chain
const ethPermits = {
    chainId: 1,
    nonce: generateNonce(),
    permits: [{
        transferOrExpiration: futureTimestamp,
        token: USDC_ETH,
        spender: DEX_ETH,
        amountDelta: 1000e6
    }]
};

const arbPermits = {
    chainId: 42161,
    nonce: generateNonce(),
    permits: [{
        transferOrExpiration: 1, // Decrease mode
        token: USDC_ARB,
        spender: DEX_ARB,
        amountDelta: 500e6
    }]
};

// Generate and chain hashes
const ethHash = hashChainPermits(ethPermits);
const arbHash = hashChainPermits(arbPermits);
const finalHash = keccak256(abi.encodePacked(ethHash, arbHash));

// Create and sign proof
const signature = signPermit3(owner, deadline, finalHash);
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