<a id="events-top"></a>
# 🔏 Permit3 Events 📣

🧭 [Home](/docs/README.md) > [API Reference](/docs/api/README.md) > Events

This document provides a comprehensive reference for all events emitted by the Permit3 system.

###### Navigation: [Core Events](#core-events) | [Permit Event](#permit) | [NonceInvalidation](#nonceinvalidation) | [NonceUsed](#nonceused) | [Event Flows](#event-flow-diagrams) | [Cross-Chain Considerations](#cross-chain-event-considerations) | [Indexing](#indexing-and-monitoring)

<a id="core-events"></a>
## Core Events

<a id="permit"></a>
### Permit

Emitted when a permit operation is processed, including allowance updates or transfers.

```solidity
event Permit(
    address indexed owner,    // Token owner who signed the permit
    address indexed token,    // Token address
    address indexed spender,  // Spender who received the allowance
    uint160 amount,           // Updated allowance amount
    uint48 expiration,        // New expiration timestamp
    uint48 timestamp          // Update timestamp
);
```

**Use cases:**
- Track allowance changes
- Monitor spending permissions
- Track operation ordering by timestamp

<a id="nonceinvalidation"></a>
### NonceInvalidation

Emitted when a nonce (salt) is manually invalidated.

```solidity
event NonceInvalidation(
    address indexed owner,   // Account invalidating the nonce
    bytes32 indexed salt     // The invalidated salt/nonce
);
```

**Use cases:**
- Security monitoring
- Tracking revoked permissions
- Audit logging

<a id="nonceused"></a>
### NonceUsed

Emitted when a nonce (salt) is used in a permit operation.

```solidity
event NonceUsed(
    address indexed owner,   // Account that used the nonce
    bytes32 indexed salt     // The used salt/nonce
);
```

**Use cases:**
- Tracking permit usage
- Preventing replay attacks
- Monitoring signature usage

<a id="event-flow-diagrams"></a>
## Event Flow Diagrams

### Permit Flow

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│ Client      │     │ Permit3     │     │ Token       │
└─────────────┘     └─────────────┘     └─────────────┘
       │                   │                   │
       │  permitCall()     │                   │
       ├──────────────────►│                   │
       │                   │                   │
       │                   │  ERC20.transferFrom()
       │                   ├──────────────────►│
       │                   │                   │
       │                   │  Transfer event   │
       │                   │◄─ ─ ─ ─ ─ ─ ─ ─ ─ ┤
       │                   │                   │
       │                   │  emit Permit()    │
       │◄─ ─ ─ ─ ─ ─ ─ ─ ─ ┤                   │
       │                   │                   │
       │                   │  emit NonceUsed() │
       │◄─ ─ ─ ─ ─ ─ ─ ─ ─ ┤                   │
       │                   │                   │
```

### Allowance Update Flow

```
┌─────────────┐     ┌─────────────┐
│ Client      │     │ Permit3     │
└─────────────┘     └─────────────┘
       │                   │
       │  permitCall()     │
       ├──────────────────►│
       │                   │
       │                   │  Update allowance
       │                   │  internally
       │                   │
       │                   │  emit Permit()
       │◄─ ─ ─ ─ ─ ─ ─ ─ ─ ┤
       │                   │
       │                   │  emit NonceUsed()
       │◄─ ─ ─ ─ ─ ─ ─ ─ ─ ┤
       │                   │
```

### Manual Nonce Invalidation Flow

```
┌─────────────┐     ┌─────────────┐
│ Client      │     │ Permit3     │
└─────────────┘     └─────────────┘
       │                   │
       │ invalidateNonces()│
       ├──────────────────►│
       │                   │
       │                   │  Mark nonces
       │                   │  as used
       │                   │
       │                   │  emit NonceInvalidation()
       │◄─ ─ ─ ─ ─ ─ ─ ─ ─ ┤  (for each nonce)
       │                   │
```

<a id="cross-chain-event-considerations"></a>
## Cross-Chain Event Considerations

When using Permit3 across multiple chains, the same events are emitted on each chain where operations occur. To track cross-chain operations:

1. **Common salt/nonce**: The same salt is used across all chains for a single logical operation
2. **Unique chainId**: Each `ChainPermits` structure contains the specific chainId
3. **Consistent timestamp**: Operations use the same timestamp across chains for ordering

This allows applications to correlate related events across different blockchains by matching salt, owner, and timestamp values.

<a id="indexing-and-monitoring"></a>
## Indexing and Monitoring

Permit3 events are designed to be easily indexed by subgraphs and monitoring services. Key strategies include:

- Index events by `owner` to track all operations for a specific user
- Index by `token` to monitor activity for specific tokens
- Index by `salt` to identify cross-chain operations
- Use `timestamp` to determine operation ordering

This enables comprehensive analytics and monitoring of cross-chain token permissions.