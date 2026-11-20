# Permit3 Allowance System 

The allowance system is a core component of Permit3, providing flexible and secure management of token permissions across multiple chains. This document explains the underlying mechanics and advanced features of this system.

## Allowance Structure

Permit3 uses a sophisticated allowance structure that combines amount, expiration, and timestamp:

```solidity
struct Allowance {
    uint160 amount;        // Approved amount
    uint48 expiration;     // Timestamp when the allowance expires
    uint48 timestamp;      // Timestamp of the operation that last set the expiration or locked
}
```

This structure is stored for each unique combination of (`owner`, `token`, `spender`).

### Key Components

- **Amount**: The approved token quantity (max value for unlimited approval)
- **Expiration**: Unix timestamp after which the allowance is invalid
- **Timestamp**: The timestamp of the operation that last set the expiration or locked the allowance. It decides which of two out-of-order Increases sets the expiration; it does not order amount changes (see [Timestamp Management](#timestamp-management))

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

### 1. TransferERC20 Mode (0)

Executes an immediate ERC20 token transfer without changing allowances.

```solidity
// Example: Transfer 100 USDC to recipient
{
    modeOrExpiration: 0,             // TransferERC20 mode
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
- Reduces the allowance for `account` by `amountDelta` (to 0 if `amountDelta` is larger), whatever the operation timestamp
- If `amountDelta` is `type(uint160).max`, resets allowance to 0
- An unlimited allowance (`type(uint160).max`) is left unchanged by any smaller `amountDelta`
- No change to timestamp or expiration

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
- Stores the operation timestamp, or `block.timestamp` if the operation timestamp is later
- Can only be removed by an unlock operation with a more recent timestamp

### 4. Unlock Mode (3)

Removes the locked state from a token.

```solidity
// Example: Unlock USDC (requires subsequent increase operation to set allowance)
{
    modeOrExpiration: 3,             // Unlock mode
    token: USDC_ADDRESS,              // Token to unlock
    account: address(0),              // Not used for unlocking
    amountDelta: 0                    // Not used for unlocking
}
```

**Behavior:**
- Removes the locked state by setting expiration to 0
- Does not modify allowance amount or timestamp
- Subsequent increase operation required to set allowance and expiration

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
- Adds `amountDelta` to the allowance, whatever the operation timestamp; reverts if the sum overflows `uint160`
- If `amountDelta` is `type(uint160).max`, sets unlimited approval; an unlimited allowance stays unlimited
- Sets the expiration to `modeOrExpiration`, and the stored timestamp to the operation timestamp, only if the operation timestamp is newer than the stored one. With an equal timestamp the later expiration wins; with an older timestamp both are left unchanged
- If `amountDelta` is 0, only the expiration can change
- Reverts with `InvalidTimestamp` if the operation timestamp is later than `block.timestamp`

## Timestamp Management

Every signed permit carries one `timestamp`: the time it was signed. The allowance stores a timestamp next to the expiration. That timestamp decides which of two out-of-order Increases sets the expiration. It does **not** order amount changes, and it is not replay protection.

### Purpose

1. **Expiration Ordering**: An Increase signed earlier cannot overwrite the expiration set by an Increase signed later, even when the transactions are confirmed in the other order

2. **Cross-Chain Consistency**: The same expiration update, signed once with one timestamp, resolves the same way on every chain

> **Important:** Amount changes are applied whatever their timestamp: every Increase adds its `amountDelta` and every Decrease subtracts its own, in the order the transactions run. Replay protection (running the same signed permit twice) comes from the per-salt, non-sequential nonce, not from timestamps. See [Nonce Management](nonce-management.md).

### Example Scenario

```
Chain A (Ethereum) ───► [Operation timestamp: 100] ───► [Confirmed at block time: 120]
                                     │
                                     ▼
Chain B (Arbitrum) ───► [Operation timestamp: 100] ───► [Confirmed at block time: 110]
```

Even though the confirmations happen at different times, both operations use the same timestamp (100), so the expiration they set resolves the same way on both chains.

### Rules

- **Increase**: the amount changes whatever the timestamp. The expiration and the stored timestamp change only if the operation timestamp is newer than the stored one; with an equal timestamp the later expiration wins. A timestamp later than `block.timestamp` reverts with `InvalidTimestamp`
- **Decrease**: the amount changes whatever the timestamp. The expiration and the stored timestamp are left unchanged; a Decrease never reads the timestamp
- **Lock**: stores its own timestamp, even one older than the stored timestamp. A timestamp later than `block.timestamp` is never stored: the Lock stores `block.timestamp` instead, so a Lock signed on a clock that runs ahead of the chain still lands. A Lock on an allowance that is already locked reverts with `AllowanceLocked`
- **Unlock**: lifts a lock only if its timestamp is newer than the stored lock timestamp, and leaves the stored timestamp unchanged. A timestamp later than `block.timestamp` reverts with `InvalidTimestamp`
- **Direct calls**: `approve()` and `lockdown()` set the stored timestamp to `block.timestamp`; the owner's own `permit(AllowanceOrTransfer[])` call uses `block.timestamp` as the operation timestamp
- **TransferERC20** operations do not read the timestamp

### Signing the Timestamp

Sign the timestamp of the latest block of the chain the permit will run on. For a permit that covers several chains, sign the smallest of the latest block timestamps of those chains. Do not sign the wall clock (`Date.now()`): a device clock can run ahead of a chain, and a chain's block timestamps can lag the wall clock, so the signed time can be later than `block.timestamp` when the transaction lands.

```javascript
// The timestamp to sign: the latest block timestamp of the chain, or the smallest one across the chains a permit covers
async function signingTimestamp(providers) {
    const blocks = await Promise.all(providers.map(provider => provider.getBlock('latest')));
    return Math.min(...blocks.map(block => block.timestamp));
}
```

If a permit contains an Increase or an Unlock and its timestamp is later than `block.timestamp`, the whole permit reverts with `InvalidTimestamp(providedTimestamp, currentTimestamp)`. Nothing is consumed: the nonce stays unused and the signature stays valid until its deadline, so the same signature can be submitted again once `block.timestamp` reaches the signed timestamp. To replace it with a new permit instead, first cancel it with `invalidateNonces`. A Lock or a Decrease never reverts for this reason, but a revert takes every operation of the permit with it: sign an emergency Lock or Decrease as its own permit, without Increase or Unlock operations.

The `Permit` event reports the operation's timestamp: the signed one, or `block.timestamp` for a Lock whose signed timestamp was later. A Decrease reports its signed timestamp, which nothing stores.

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
if (allowances[owner][token][account].expiration == LOCKED_ALLOWANCE) {
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

### Expiration Update Priority

The precedence rules below decide which **expiration** an Increase leaves in place; they do not order amount changes:
1. Timestamp (higher is more recent): an Increase with a newer timestamp replaces the stored expiration
2. Expiration (longer is preferred): when timestamps are equal, the later expiration wins

## Integration with EIP-712 Signatures

The allowance system integrates with EIP-712 for secure signature-based approvals:

```solidity
// Typehash for AllowanceOrTransfer
bytes32 constant ALLOWANCE_TRANSFER_TYPEHASH = keccak256(
    "AllowanceOrTransfer(uint48 modeOrExpiration,address token,address account,uint160 amountDelta)"
);
```

This enables users to sign structured data representing allowance operations, which can then be submitted to the blockchain by anyone.