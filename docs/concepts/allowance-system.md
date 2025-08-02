# 🔏 Permit3 Allowance System 🔑

The allowance system is a core component of Permit3, providing flexible and secure management of token permissions across multiple chains. This document explains the underlying mechanics and advanced features of this system.

## Allowance Structure

Permit3 uses a sophisticated allowance structure that combines amount, expiration, and timestamp:

```solidity
struct Allowance {
    uint160 amount;        // Approved amount
    uint48 expiration;     // Timestamp when the allowance expires
    uint48 timestamp;      // Timestamp of the last update
}
```

This structure is stored for each unique combination of (`owner`, `token`, `spender`).

### Key Components

- **Amount**: The approved token quantity (max value for unlimited approval)
- **Expiration**: Unix timestamp after which the allowance is invalid
- **Timestamp**: The time when the allowance was last updated, crucial for synchronizing operations across chains

## Operation Modes

Permit3 unifies different allowance operations in a single structure through the `modeOrExpiration` field in `AllowanceOrTransfer`:

```solidity
struct AllowanceOrTransfer {
    uint48 modeOrExpiration;
    address token;
    address account;
    uint160 amountDelta;
}
```

The system supports five distinct operations based on the `modeOrExpiration` value:

### 1. Transfer Mode (0)

Executes an immediate token transfer without changing allowances.

```solidity
// Example: Transfer 100 USDC to recipient
{
    modeOrExpiration: 0,             // Transfer mode
    token: USDC_ADDRESS,              // Token to transfer
    account: RECIPIENT_ADDRESS,       // Transfer recipient
    amountDelta: 100000000            // 100 USDC (with 6 decimals)
}
```

**Behavior:**
- Transfers `amountDelta` tokens from owner to `account`
- Consumes existing allowance if called by a third party
- No state changes to allowances

### 2. Decrease Mode (1)

Reduces an existing allowance.

```solidity
// Example: Decrease DEX allowance by 50 USDC
{
    modeOrExpiration: 1,             // Decrease mode
    token: USDC_ADDRESS,              // Token address
    account: DEX_ADDRESS,             // Spender
    amountDelta: 50000000             // Decrease by 50 USDC
}
```

**Behavior:**
- Reduces allowance for `account` by `amountDelta`
- If `amountDelta` is `type(uint160).max`, resets allowance to 0
- No change to timestamp (preserves existing timestamp)
- No change to expiration

### 3. Lock Mode (2)

Locks all allowances for a token, providing emergency security control.

```solidity
// Example: Lock all USDC allowances
{
    modeOrExpiration: 2,             // Lock mode
    token: USDC_ADDRESS,              // Token to lock
    account: address(0),              // Not used for locking
    amountDelta: 0                    // Not used for locking
}
```

**Behavior:**
- Enters special security state that blocks all transfers and allowance increases
- Sets allowance to 0
- Updates timestamp to current operation time
- Can only be removed by an unlock operation with a more recent timestamp

### 4. Unlock Mode (3)

Removes the locked state from a token.

```solidity
// Example: Unlock USDC and set allowance to 1000
{
    modeOrExpiration: 3,             // Unlock mode
    token: USDC_ADDRESS,              // Token to unlock
    account: DEX_ADDRESS,             // Spender to restore allowance for
    amountDelta: 1000000000           // New allowance of 1000 USDC
}
```

**Behavior:**
- Removes the locked state
- Sets allowance to `amountDelta`
- Updates timestamp to current operation time
- Sets expiration to max (no expiration)

### 5. Increase Mode (>3)

The most common mode, using `modeOrExpiration` as the expiration timestamp.

```solidity
// Example: Approve 500 USDC until tomorrow
{
    modeOrExpiration: NOW + 86400,   // Expires in 24 hours
    token: USDC_ADDRESS,              // Token address
    account: DEX_ADDRESS,             // Spender
    amountDelta: 500000000            // 500 USDC
}
```

**Behavior:**
- Increases allowance by `amountDelta`
- Updates expiration to `modeOrExpiration` timestamp
- Updates the timestamp to the operation timestamp
- If `amountDelta` is 0, only updates the expiration
- If `amountDelta` is `type(uint160).max`, sets unlimited approval

## Timestamp Management

The timestamp field serves a critical role in the allowance system, especially for cross-chain operations.

### Purpose

1. **Operation Ordering**: Ensures operations are applied in the correct order, even when transactions are confirmed out of order

2. **Cross-Chain Consistency**: Allows the same logical operation to be synchronized across multiple chains

3. **Race Condition Prevention**: Prevents allowance race conditions in asynchronous environments

### Example Scenario

```
Chain A (Ethereum) ───► [Operation timestamp: 100] ───► [Confirmed at block time: 120]
                                     │
                                     ▼
Chain B (Arbitrum) ───► [Operation timestamp: 100] ───► [Confirmed at block time: 110]
```

Even though the confirmations happen at different times, both operations use the same timestamp (100), ensuring consistent behavior.

### Rules

- Allowance updates that change timestamps are only applied if the operation timestamp is > the stored timestamp
- This applies to increases, locks, and unlocks, but NOT to decreases (which preserve existing timestamps)
- For allowance increases, the highest expiration time is kept when the timestamps are equal

## Account Locking

The lock/unlock system provides emergency security controls for Permit3.

### Locking Mechanism

A locked token has special restrictions:

1. **No Allowance Increases**: Cannot grant new or increase existing permissions
2. **No Transfers**: Cannot execute transfers of the locked token
3. **Timestamp Validation**: Can only be unlocked by operations with newer timestamps

### Implementation

Locking is implemented by setting a special value in the allowance mapping and checking this state before operations:

```solidity
// Pseudocode for lock check
if (allowances[owner][token][account].timestamp == type(uint48).max) {
    revert AllowanceLocked();
}
```

### Cross-Chain Lock Considerations

Locks can be propagated across chains by creating a multi-chain permit with lock operations for each chain, using the same timestamp. This ensures consistent security across the entire token ecosystem.

## Expiration Mechanics

Permit3 provides time-bound permissions through expiration timestamps.

### Behavior

- Allowances cannot be used after their expiration time
- Expiration only applies to allowances, not to locked states
- When increasing an allowance with multiple operations that have the same timestamp, the maximum expiration is used

### Operation Priority

The priority of operations is:
1. Timestamp (higher is more recent)
2. Expiration (longer is preferred)
3. Amount (more restrictive takes precedence for decreases, more permissive for increases)

## Integration with EIP-712 Signatures

The allowance system integrates with EIP-712 for secure signature-based approvals:

```solidity
// Simplified typehash for AllowanceOrTransfer
bytes32 constant ALLOWANCE_TRANSFER_TYPEHASH = keccak256(
    "AllowanceOrTransfer(uint48 modeOrExpiration,address token,address account,uint160 amountDelta)"
);
```

This enables users to sign structured data representing allowance operations, which can then be submitted to the blockchain by anyone.

## Conclusion

The Permit3 allowance system combines flexibility, security, and cross-chain capability:

- **Unified Operations**: One structure for transfers, increases, decreases, locks, and unlocks
- **Timestamp Synchronization**: Ensures consistent behavior across chains
- **Flexible Permissions**: Time-bound allowances with precise control
- **Emergency Controls**: Account locking for enhanced security

This system forms the foundation for Permit3's advanced cross-chain token permission capabilities.