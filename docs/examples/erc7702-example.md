<a id="erc7702-example-top"></a>
# 🔗 ERC-7702 Token Approver Example

###### Quick Navigation: [Overview](#overview) | [Setup](#setup) | [Basic Usage](#basic-usage) | [Advanced Integration](#advanced-integration) | [Frontend Example](#frontend-example)

🧭 [Home](/docs/README.md) > [Examples](/docs/examples/README.md) > ERC-7702 Example

<a id="overview"></a>
## 📖 Overview

This example demonstrates how to integrate the ERC-7702 Token Approver with Permit3 to create a seamless user experience for batch token approvals using Account Abstraction.

The ERC-7702 integration eliminates the need for multiple approval transactions by leveraging delegatecall functionality to batch approve infinite allowances in a single transaction.

<a id="setup"></a>
## 🛠️ Setup

### Contract Deployment

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ERC7702TokenApprover} from "../src/ERC7702TokenApprover.sol";
import {IPermit3} from "../src/interfaces/IPermit3.sol";

contract ExampleSetup {
    ERC7702TokenApprover public immutable approver;
    IPermit3 public immutable permit3;
    
    constructor(address _permit3) {
        permit3 = IPermit3(_permit3);
        approver = new ERC7702TokenApprover(_permit3);
    }
    
    function getApproverAddress() external view returns (address) {
        return address(approver);
    }
}
```

<a id="basic-usage"></a>
## 🚀 Basic Usage

### Single Token Approval

```javascript
// 1. Prepare token addresses
const tokens = [
    "0xA0b86a33E6441c4d9dB1b7e8D44d6A9a7b91c2b8", // USDC
];

// 2. Create ERC-7702 authorization
const authorization = {
    chainId: 1,
    address: ERC7702_APPROVER_ADDRESS,
    nonce: 0,
    // Signature components from user
    yParity: signature.yParity,
    r: signature.r,
    s: signature.s
};

// 3. Create transaction
const transaction = {
    type: 0x04, // ERC-7702 transaction type
    authorizationList: [authorization],
    to: userAddress, // User's own address
    data: approver.interface.encodeFunctionData("approve", [tokens]),
    gasLimit: 100000,
    // ... other fields
};

// 4. Submit transaction
const txHash = await wallet.sendTransaction(transaction);
```

### Multiple Token Approval

```javascript
// Batch approve multiple tokens
const tokens = [
    "0xA0b86a33E6441c4d9dB1b7e8D44d6A9a7b91c2b8", // USDC
    "0xdAC17F958D2ee523a2206206994597C13D831ec7", // USDT
    "0x6B175474E89094C44Da98b954EedeAC495271d0F", // DAI
    "0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599", // WBTC
];

const transaction = {
    type: 0x04,
    authorizationList: [authorization],
    to: userAddress,
    data: approver.interface.encodeFunctionData("approve", [tokens]),
    gasLimit: 200000, // Higher gas limit for multiple tokens
};
```

<a id="advanced-integration"></a>
## 🔧 Advanced Integration

### DApp Integration Pattern

```javascript
class ERC7702PermitManager {
    constructor(permit3Address, approverAddress) {
        this.permit3 = new ethers.Contract(permit3Address, PERMIT3_ABI, provider);
        this.approver = new ethers.Contract(approverAddress, APPROVER_ABI, provider);
    }
    
    async batchApproveAndPermit(userAddress, tokens, permitData, signature) {
        // 1. First, batch approve tokens using ERC-7702
        const approvalTx = await this.createApprovalTransaction(userAddress, tokens);
        const approvalReceipt = await userAddress.sendTransaction(approvalTx);
        
        // 2. Then execute Permit3 operations
        const permitTx = await this.permit3.permit(
            permitData.owner,
            permitData.salt,
            permitData.deadline,
            permitData.timestamp,
            permitData.chainPermits,
            signature
        );
        
        return { approvalReceipt, permitTx };
    }
    
    async createApprovalTransaction(userAddress, tokens) {
        // Create ERC-7702 authorization signature
        const authorization = await this.signAuthorization(userAddress);
        
        return {
            type: 0x04,
            authorizationList: [authorization],
            to: userAddress,
            data: this.approver.interface.encodeFunctionData("approve", [tokens]),
            gasLimit: 50000 + (tokens.length * 24000), // Dynamic gas estimation
        };
    }
    
    async signAuthorization(userAddress) {
        // Implementation depends on wallet integration
        // This would typically involve user signing the authorization
        const domain = {
            name: "ERC7702",
            version: "1",
            chainId: await provider.getNetwork().then(n => n.chainId)
        };
        
        const types = {
            Authorization: [
                { name: "chainId", type: "uint256" },
                { name: "address", type: "address" },
                { name: "nonce", type: "uint256" }
            ]
        };
        
        const value = {
            chainId: domain.chainId,
            address: this.approver.address,
            nonce: 0
        };
        
        return await userAddress._signTypedData(domain, types, value);
    }
}
```

### React Hook Integration

```jsx
import { useState, useCallback } from 'react';
import { useAccount, useWalletClient } from 'wagmi';

export function useERC7702Approval() {
    const { address } = useAccount();
    const { data: walletClient } = useWalletClient();
    const [isApproving, setIsApproving] = useState(false);
    
    const batchApprove = useCallback(async (tokens) => {
        if (!address || !walletClient) return;
        
        setIsApproving(true);
        try {
            // Create authorization signature
            const authorization = await signAuthorization(address, walletClient);
            
            // Create and send ERC-7702 transaction
            const transaction = {
                type: '0x04',
                authorizationList: [authorization],
                to: address,
                data: encodeFunctionData({
                    abi: APPROVER_ABI,
                    functionName: 'approve',
                    args: [tokens]
                }),
                account: address,
            };
            
            const hash = await walletClient.sendTransaction(transaction);
            return hash;
        } finally {
            setIsApproving(false);
        }
    }, [address, walletClient]);
    
    return { batchApprove, isApproving };
}
```

<a id="frontend-example"></a>
## 🎨 Frontend Example

### Complete DApp Integration

```jsx
import React, { useState } from 'react';
import { useERC7702Approval } from './hooks/useERC7702Approval';

function TokenApprovalModal({ tokens, onSuccess }) {
    const { batchApprove, isApproving } = useERC7702Approval();
    const [step, setStep] = useState('prepare'); // prepare, approving, success
    
    const handleApprove = async () => {
        setStep('approving');
        try {
            const txHash = await batchApprove(tokens);
            setStep('success');
            onSuccess(txHash);
        } catch (error) {
            console.error('Approval failed:', error);
            setStep('prepare');
        }
    };
    
    return (
        <div className="approval-modal">
            <h2>🔗 Batch Token Approval</h2>
            
            {step === 'prepare' && (
                <div>
                    <p>Approve {tokens.length} tokens for Permit3 usage:</p>
                    <ul>
                        {tokens.map(token => (
                            <li key={token.address}>
                                {token.symbol} - Infinite Approval
                            </li>
                        ))}
                    </ul>
                    <button onClick={handleApprove}>
                        📝 Sign ERC-7702 Authorization
                    </button>
                </div>
            )}
            
            {step === 'approving' && (
                <div>
                    <div className="spinner" />
                    <p>Processing batch approval...</p>
                </div>
            )}
            
            {step === 'success' && (
                <div>
                    <p>✅ Tokens approved successfully!</p>
                    <p>You can now use Permit3 without additional approvals.</p>
                </div>
            )}
        </div>
    );
}

// Usage in main component
function DApp() {
    const [showApprovalModal, setShowApprovalModal] = useState(false);
    
    const requiredTokens = [
        { address: "0x...", symbol: "USDC" },
        { address: "0x...", symbol: "USDT" },
        { address: "0x...", symbol: "DAI" },
    ];
    
    const handleApprovalSuccess = (txHash) => {
        console.log('Approval transaction:', txHash);
        setShowApprovalModal(false);
        // Proceed with Permit3 operations
    };
    
    return (
        <div className="dapp">
            <button onClick={() => setShowApprovalModal(true)}>
                🚀 Setup Token Approvals
            </button>
            
            {showApprovalModal && (
                <TokenApprovalModal
                    tokens={requiredTokens}
                    onSuccess={handleApprovalSuccess}
                />
            )}
        </div>
    );
}
```

### Error Handling

```javascript
class ERC7702Error extends Error {
    constructor(message, code, details) {
        super(message);
        this.name = 'ERC7702Error';
        this.code = code;
        this.details = details;
    }
}

async function safeERC7702Approval(tokens) {
    try {
        // Validate inputs
        if (!tokens || tokens.length === 0) {
            throw new ERC7702Error(
                'No tokens provided',
                'NO_TOKENS_PROVIDED',
                { tokens }
            );
        }
        
        // Check for duplicate tokens
        const uniqueTokens = [...new Set(tokens)];
        if (uniqueTokens.length !== tokens.length) {
            throw new ERC7702Error(
                'Duplicate tokens detected',
                'DUPLICATE_TOKENS',
                { tokens, uniqueTokens }
            );
        }
        
        // Execute approval
        const txHash = await batchApprove(tokens);
        return txHash;
        
    } catch (error) {
        if (error.code === 'ACTION_REJECTED') {
            throw new ERC7702Error(
                'User rejected authorization',
                'USER_REJECTED',
                { originalError: error }
            );
        }
        
        if (error.code === 'INSUFFICIENT_FUNDS') {
            throw new ERC7702Error(
                'Insufficient gas for approval',
                'INSUFFICIENT_GAS',
                { originalError: error }
            );
        }
        
        // Re-throw unknown errors
        throw error;
    }
}
```

<a id="testing"></a>
## 🧪 Testing

### Unit Test Example

```javascript
describe('ERC7702 Integration', () => {
    let approver, permit3, mockEOA;
    
    beforeEach(async () => {
        permit3 = await deployPermit3();
        approver = await deployERC7702TokenApprover(permit3.address);
        mockEOA = await deployMockEOA(approver.address);
    });
    
    it('should batch approve multiple tokens', async () => {
        const tokens = [token1.address, token2.address, token3.address];
        
        // Simulate ERC-7702 delegatecall
        await mockEOA.simulateERC7702Approval(tokens);
        
        // Verify approvals
        for (const token of tokens) {
            const allowance = await ERC20(token).allowance(
                mockEOA.address, 
                permit3.address
            );
            expect(allowance).to.equal(ethers.constants.MaxUint256);
        }
    });
    
    it('should revert on empty token array', async () => {
        await expect(
            mockEOA.simulateERC7702Approval([])
        ).to.be.revertedWith('ERC7702 simulation failed');
    });
});
```

---

<a id="navigation-footer"></a>
| ⬅️ Previous | 🏠 Section | ➡️ Next |
|:-----------|:----------:|------------:|
| [Integration Example](/docs/examples/integration-example.md) | [Examples](/docs/examples/README.md) | [Witness Example](/docs/examples/witness-example.md) |

[🔝 Back to Top](#erc7702-example-top)