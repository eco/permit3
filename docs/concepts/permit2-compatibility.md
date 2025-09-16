## Permit2 Compatibility

Permit3 implements IPermit for Permit2 transfer compatibility:

```solidity
// Existing contracts using Permit2 can work without changes
IPermit2 permit2 = IPermit2(PERMIT3_ADDRESS);
permit2.transferFrom(msg.sender, recipient, 1000e6, USDC);
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

### Enhanced Functions (Permit3 Exclusive)
```solidity
// Direct permit execution (no signatures required, caller is owner)
function permit(AllowanceOrTransfer[] memory permits) external;

// Single-chain permit operations with signatures  
function permit(address owner, bytes32 salt, uint48 deadline, uint48 timestamp, 
                AllowanceOrTransfer[] calldata permits, bytes calldata signature) external;

// Cross-chain operations with Merkle proofs and signatures
function permit(address owner, bytes32 salt, uint48 deadline, uint48 timestamp,
                ChainPermits calldata permits, bytes32[] calldata proof, bytes calldata signature) external;
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
