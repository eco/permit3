# Permit3 Error Codes

This document provides a comprehensive reference for all error codes that can be thrown by the Permit3 system.

## Core Errors

### Signature Errors

#### SignatureExpired

```solidity
error SignatureExpired();
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
error InvalidSignature();
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

### Nonce Errors

#### NonceAlreadyUsed

```solidity
error NonceAlreadyUsed();
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

### Witness Errors

#### InvalidWitnessTypeString

```solidity
error InvalidWitnessTypeString();
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

### Allowance Errors

#### AllowanceLocked

```solidity
error AllowanceLocked();
```

**Description:**
Thrown when attempting to modify an allowance that is in the locked state.

**Possible Causes:**
- Trying to increase/decrease a locked allowance
- Attempting to transfer using a locked allowance
- Security lockdown in effect

**Mitigation:**
- Check if an allowance is locked before attempting operations
- Use the unlock operation (mode 3) to remove the lock
- Ensure the unlock operation has a more recent timestamp than the lock

### Proof Errors

#### InvalidUnhingedProof

```solidity
error InvalidUnhingedProof();
```

**Description:**
Thrown when the provided UnhingedProof fails verification against the signed root.

**Possible Causes:**
- Incorrectly constructed proof
- Wrong ordering of chains
- Tampered permit data
- Inconsistent proof structure

**Mitigation:**
- Generate proofs using the UnhingedMerkleTree library
- Ensure consistent ordering of chains
- Verify proofs locally before submitting
- Ensure proper handling of the hasPreHash flag

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
| Proof | InvalidUnhingedProof | High | Yes | Verify proof locally |

## Cross-Chain Error Handling

When working with cross-chain permits, additional considerations apply:

1. **Chain-Specific Validation:**
   - Each chain's proof needs to be validated for that specific chain
   - The unhinged root must match across all chains
   - The same salt/nonce applies across all chains

2. **Network Congestion Considerations:**
   - Different chains have different block times and finality
   - Set deadlines appropriately for multi-chain operations
   - Consider retry strategies for failed transactions

3. **Cross-Chain Recovery:**
   - If a transaction fails on one chain, the same salt might be unusable on all chains
   - Design fallback mechanisms for partial success scenarios
   - Consider the implications of partial execution across chains