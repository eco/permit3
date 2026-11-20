<a id="error-codes-top"></a>
# Permit3 Error Codes 


This document provides a comprehensive reference for all error codes that can be thrown by the Permit3 system.

<a id="core-errors"></a>
## Core Errors

<a id="signature-errors"></a>
### Signature Errors

#### SignatureExpired

```solidity
error SignatureExpired(uint48 deadline, uint48 currentTimestamp);
```

**Description:**
Thrown when attempting to use a signature past its deadline timestamp.

**Possible Causes:**
- Signature deadline has passed
- Clock skew between client and blockchain
- Transaction delayed in mempool too long

**Mitigation:**
- Set longer deadlines for complex operations
- Adjust deadline based on network congestion
- Create new signatures if expired ones are rejected

#### InvalidSignature

```solidity
error InvalidSignature(address signer);
```

**Description:**
Thrown when the provided signature does not match the expected signer or data.

**Possible Causes:**
- Wrong signer address
- Incorrect permit data
- Incorrectly constructed signature
- Wrong EIP-712 domain parameters

**Mitigation:**
- Verify signature locally before sending transaction
- Ensure correct domain parameters (name, version, chainId, contract address)
- Check that the signer is the token owner

<a id="nonce-errors"></a>
### Nonce Errors

#### NonceAlreadyUsed

```solidity
error NonceAlreadyUsed(address owner, bytes32 salt);
```

**Description:**
Thrown when attempting to use a nonce (salt) that has already been used.

**Possible Causes:**
- Replay attack attempt
- Duplicate transaction submission
- Race condition between multiple transactions

**Mitigation:**
- Generate unique random salts for each transaction
- Check if a nonce is already used with `isNonceUsed()` before submitting transaction
- Track used nonces in your application

<a id="chain-errors"></a>
### Chain Errors

#### WrongChainId

```solidity
error WrongChainId(uint256 expected, uint256 provided);
```

**Description:**
Thrown when the chainId in the permit doesn't match the actual chain where the transaction is executed.

**Parameters:**
- `expected`: The chain ID where the transaction is being executed
- `provided`: The chain ID specified in the ChainPermits structure

**Possible Causes:**
- Cross-chain proof submitted to wrong chain
- Misconfigured client connecting to wrong network
- RPC endpoint pointing to wrong network

**Mitigation:**
- Verify connected network before sending transactions
- Always include the correct chainId in ChainPermits
- Use chain-specific validity checks in your dApp

<a id="witness-errors"></a>
### Witness Errors

#### InvalidWitnessTypeString

```solidity
error InvalidWitnessTypeString(string witnessTypeString);
```

**Description:**
Thrown when the witnessTypeString is not properly formatted according to EIP-712.

**Possible Causes:**
- Missing closing parenthesis
- Incorrect type string format
- Empty type string

**Mitigation:**
- Ensure type strings follow EIP-712 format
- Verify type strings end with a closing parenthesis ')'
- Test witness verification with correct format before deploying

<a id="allowance-errors"></a>
### Allowance Errors

#### AllowanceLocked

```solidity
error AllowanceLocked(address owner, bytes32 tokenKey, address spender);
```

**Description:**
Thrown when an operation needs a (token, account) pair that is locked.

**Possible Causes:**
- Trying to approve, increase, decrease or lock a locked allowance
- The locked account trying to spend through its allowance
- A TransferERC20 operation to a locked recipient
- A signed Unlock submitted by anyone other than the owner

**Mitigation:**
- Check if an allowance is locked before attempting operations
- The owner removes the lock with an Unlock operation (mode 3) in a call sent from its own account; a relayed signature cannot unlock
- Before unlocking, cancel with `invalidateNonces` any signed permit that the lock blocked and that must not run

<a id="proof-errors"></a>
### Proof Errors

#### InvalidMerkleProof

```solidity
error InvalidMerkleProof();
```

**Description:**
Thrown when the provided merkle proof fails verification against the signed root.

**Possible Causes:**
- Incorrectly constructed proof
- Wrong ordering of chains
- Tampered permit data
- Inconsistent proof structure

**Mitigation:**
- Generate proofs using the Unbalanced Merkle tree methodology with OpenZeppelin's MerkleProof
- Ensure consistent ordering of chains
- Verify proofs locally before submitting
- Ensure proper handling of the hasPreHash flag

#### InvalidParameters

```solidity
error InvalidParameters();
```

**Description:**
Thrown when invalid parameters are provided to a function.

**Possible Causes:**
- Invalid parameter combinations
- Out of bounds values
- Logic errors in parameter construction

**Mitigation:**
- Validate parameters before function calls
- Review parameter requirements in documentation
- Test with valid parameter combinations

### Input Validation Errors

#### AllowanceExpired

```solidity
error AllowanceExpired(uint48 deadline);
```

**Description:**
Thrown when attempting to use an allowance that has already expired.

**Parameters:**
- `deadline`: The timestamp when the allowance expired

**Possible Causes:**
- Using an outdated allowance
- Time-based allowance expiration
- Clock drift between client and blockchain

**Mitigation:**
- Check allowance expiration before attempting operations
- Refresh allowances when expired
- Account for network delays in expiration times

#### InsufficientAllowance

```solidity
error InsufficientAllowance(uint256 requestedAmount, uint256 availableAmount);
```

**Description:**
Thrown when attempting to transfer more tokens than the current allowance permits.

**Parameters:**
- `requestedAmount`: The amount that was attempted to be transferred
- `availableAmount`: The actual amount available in the allowance

**Possible Causes:**
- Attempting to spend more than approved
- Allowance decreased between approval and spending
- Multiple concurrent transactions consuming the same allowance

**Mitigation:**
- Check current allowance before attempting transfers
- Handle partial allowance scenarios
- Implement retry logic with updated allowance checks

#### EmptyArray

```solidity
error EmptyArray();
```

**Description:**
Thrown when an empty array is provided where operations require at least one element.

**Possible Causes:**
- Providing empty permit arrays
- Empty salt arrays for nonce invalidation
- Missing operation data

**Mitigation:**
- Ensure arrays contain at least one element
- Validate input data before submission
- Check array lengths in client code

### Address Validation Errors

#### ZeroOwner

```solidity
error ZeroOwner();
```

**Description:**
Thrown when the owner address is zero (0x0).

**Possible Causes:**
- Uninitialized owner address
- Logic error in address assignment
- Invalid function parameters

**Mitigation:**
- Validate owner addresses before function calls
- Ensure proper address initialization
- Use address validation in client code

#### ZeroToken

```solidity
error ZeroToken();
```

**Description:**
Thrown when the token address is zero (0x0).

**Possible Causes:**
- Uninitialized token address
- Invalid token contract reference
- Logic error in token assignment

**Mitigation:**
- Validate token addresses before operations
- Ensure proper token contract deployment
- Use address validation for all token references

#### ZeroSpender

```solidity
error ZeroSpender();
```

**Description:**
Thrown when the spender address is zero (0x0).

**Possible Causes:**
- Uninitialized spender address
- Invalid spender reference
- Logic error in address assignment

**Mitigation:**
- Validate spender addresses before approval operations
- Ensure proper spender identification
- Use address validation in client code

#### ZeroFrom

```solidity
error ZeroFrom();
```

**Description:**
Thrown when the from address is zero (0x0) in transfer operations.

**Possible Causes:**
- Uninitialized from address
- Invalid transfer source
- Logic error in transfer setup

**Mitigation:**
- Validate from addresses before transfer operations
- Ensure proper source address identification
- Use address validation for transfers

#### ZeroTo

```solidity
error ZeroTo();
```

**Description:**
Thrown when the to address is zero (0x0) in transfer operations.

**Possible Causes:**
- Uninitialized to address
- Invalid transfer destination
- Logic error in transfer setup

**Mitigation:**
- Validate to addresses before transfer operations
- Ensure proper destination address identification
- Use address validation for transfers

#### ZeroAccount

```solidity
error ZeroAccount();
```

**Description:**
Thrown when the account address is zero (0x0) in allowance operations.

**Possible Causes:**
- Uninitialized account address
- Invalid account reference in allowance operations
- Logic error in account assignment

**Mitigation:**
- Validate account addresses before allowance operations
- Ensure proper account identification
- Use address validation for all account-related operations

### Value Validation Errors

#### InvalidAmount

```solidity
error InvalidAmount(uint160 amount);
```

**Description:**
Thrown when an invalid amount value is provided.

**Parameters:**
- `amount`: The invalid amount that was provided

**Possible Causes:**
- Amount exceeds maximum allowed value
- Invalid amount for specific operation type
- Logic error in amount calculation

**Mitigation:**
- Validate amounts against operation requirements
- Check for overflow conditions
- Use appropriate amount ranges for operations

#### InvalidExpiration

```solidity
error InvalidExpiration(uint48 expiration);
```

**Description:**
Thrown when an invalid expiration timestamp is provided.

**Parameters:**
- `expiration`: The invalid expiration timestamp

**Possible Causes:**
- Expiration timestamp in the past
- Expiration timestamp too far in the future
- Invalid timestamp format

**Mitigation:**
- Set expiration timestamps in the future
- Validate expiration times before operations
- Account for network delays and block times

#### InvalidTimestamp

```solidity
error InvalidTimestamp(uint48 providedTimestamp, uint48 currentTimestamp);
```

**Description:**
Thrown when a permit contains an Increase or an Unlock operation and its signed `timestamp` is later than `block.timestamp`. A Lock stores `block.timestamp` instead of a later timestamp, and a Decrease and a TransferERC20 operation ignore the timestamp, so they never throw it.

**Parameters:**
- `providedTimestamp`: The signed timestamp of the permit
- `currentTimestamp`: The current block timestamp

**Possible Causes:**
- The permit was signed with the wall clock (`Date.now()`) and the signer's clock runs ahead of the chain
- The chain's block timestamps lag the wall clock
- A cross-chain permit signed with a timestamp that has not yet been reached on one of its chains

**Mitigation:**
- Retry: the revert consumes nothing, so the same signature can be retried once `block.timestamp` reaches the signed timestamp, before its deadline; its other checks still apply
- Sign the latest block timestamp of the target chain, or the smallest one across all chains of a cross-chain permit
- To replace the permit instead of retrying, cancel it first with `invalidateNonces`

<a id="error-handling-best-practices"></a>
## Error Handling Best Practices

### Client-Side Error Prevention

1. **Validate Locally First:**
   - Check signature validity client-side
   - Verify connected network matches intended chainId
   - Check if nonces are already used before submission

2. **Proper Error Handling:**
   - Catch and interpret error responses
   - Provide user-friendly error messages
   - Offer actionable remediation steps

3. **Defensive Programming:**
   - Check allowance status before operations
   - Set appropriate deadlines based on network conditions
   - Generate unique salts for each signature

### Error Categories Matrix

| Category | Error | Severity | Recoverable | Prevention |
|----------|-------|----------|-------------|------------|
| Signature | SignatureExpired | Medium | Yes | Set longer deadlines |
| Signature | InvalidSignature | High | Yes | Verify locally first |
| Nonce | NonceAlreadyUsed | Medium | Yes | Check before submission |
| Chain | WrongChainId | High | Yes | Verify network connection |
| Witness | InvalidWitnessTypeString | Medium | Yes | Validate format |
| Allowance | AllowanceLocked | Medium | Yes | Check lock status first |
| Allowance | InvalidTimestamp | Low | Yes (retry later) | Sign the latest block timestamp |
| Proof | InvalidMerkleProof | High | Yes | Verify proof locally |

<a id="cross-chain-error-handling"></a>
## Cross-Chain Error Handling

When working with cross-chain permits, additional considerations apply:

1. **Chain-Specific Validation:**
   - Each chain's proof needs to be validated for that specific chain
   - The unbalanced root must match across all chains
   - The same salt/nonce applies across all chains

2. **Network Congestion Considerations:**
   - Different chains have different block times and finality
   - Set deadlines appropriately for multi-chain operations
   - Consider retry strategies for failed transactions

3. **Cross-Chain Recovery:**
   - If a transaction fails on one chain, the same salt might be unusable on all chains
   - Design fallback mechanisms for partial success scenarios
   - Consider the implications of partial execution across chains