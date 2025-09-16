<a id="erc7702-example-top"></a>
# ERC-7702 Token Approver Example

<a id="overview"></a>
## Overview

This example demonstrates how to integrate the ERC-7702 Token Approver with Permit3 to create a seamless user experience for batch token approvals AND permit operations using Account Abstraction.

The ERC-7702 integration eliminates the need for both approval transactions and signature creation by leveraging delegatecall functionality to approve tokens and execute permit operations in a single transaction.

<a id="setup"></a>
## Setup

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
## Basic Usage

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

### Multiple Token Approval + Permit Execution

```javascript
// Batch approve multiple tokens AND execute permit operations
const tokens = [
    "0xA0b86a33E6441c4d9dB1b7e8D44d6A9a7b91c2b8", // USDC
    "0xdAC17F958D2ee523a2206206994597C13D831ec7", // USDT
    "0x6B175474E89094C44Da98b954EedeAC495271d0F", // DAI
];

const permits = [
    {
        modeOrExpiration: 2000, // Expiration timestamp
        token: "0xA0b86a33E6441c4d9dB1b7e8D44d6A9a7b91c2b8",
        account: spenderAddress,
        amountDelta: ethers.utils.parseUnits("1000", 6) // 1000 USDC
    }
];

const transaction = {
    type: 0x04,
    authorizationList: [authorization],
    to: userAddress,
    data: multicall([
        approver.interface.encodeFunctionData("approve", [tokens]),
        approver.interface.encodeFunctionData("permit", [permits])
    ]),
    gasLimit: 300000, // Higher gas limit for combined operations
};
```

<a id="advanced-integration"></a>
## Advanced Integration

### DApp Integration Pattern

```javascript
class ERC7702PermitManager {
    constructor(permit3Address, approverAddress) {
        this.permit3 = new ethers.Contract(permit3Address, PERMIT3_ABI, provider);
        this.approver = new ethers.Contract(approverAddress, APPROVER_ABI, provider);
    }
    
    async batchApproveAndPermit(userAddress, tokens, permits) {
        // Single ERC-7702 transaction: approve + permit (no signatures needed!)
        const combinedTx = await this.createCombinedTransaction(userAddress, tokens, permits);
        const receipt = await userAddress.sendTransaction(combinedTx);
        
        return { receipt };
    }
    
    async approveOnly(userAddress, tokens) {
        // ERC-7702 transaction: just approve tokens
        const approvalTx = await this.createApprovalTransaction(userAddress, tokens);
        const receipt = await userAddress.sendTransaction(approvalTx);
        
        return { receipt };
    }
    
    async permitOnly(userAddress, permits) {
        // ERC-7702 transaction: just execute permits (requires prior approvals)
        const permitTx = await this.createPermitTransaction(userAddress, permits);
        const receipt = await userAddress.sendTransaction(permitTx);
        
        return { receipt };
    }
    
    async createCombinedTransaction(userAddress, tokens, permits) {
        const authorization = await this.signAuthorization(userAddress);
        
        return {
            type: 0x04,
            authorizationList: [authorization],
            to: userAddress,
            data: multicall([
                this.approver.interface.encodeFunctionData("approve", [tokens]),
                this.approver.interface.encodeFunctionData("permit", [permits])
            ]),
            gasLimit: 80000 + (tokens.length * 24000) + (permits.length * 25000),
        };
    }
    
    async createApprovalTransaction(userAddress, tokens) {
        const authorization = await this.signAuthorization(userAddress);
        
        return {
            type: 0x04,
            authorizationList: [authorization],
            to: userAddress,
            data: this.approver.interface.encodeFunctionData("approve", [tokens]),
            gasLimit: 50000 + (tokens.length * 24000),
        };
    }
    
    async createPermitTransaction(userAddress, permits) {
        const authorization = await this.signAuthorization(userAddress);
        
        return {
            type: 0x04,
            authorizationList: [authorization],
            to: userAddress,
            data: this.approver.interface.encodeFunctionData("permit", [permits]),
            gasLimit: 50000 + (permits.length * 25000),
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
    const [isProcessing, setIsProcessing] = useState(false);
    
    const batchApprove = useCallback(async (tokens) => {
        if (!address || !walletClient) return;
        
        setIsProcessing(true);
        try {
            const authorization = await signAuthorization(address, walletClient);
            
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
            setIsProcessing(false);
        }
    }, [address, walletClient]);
    
    const executePermit = useCallback(async (permits) => {
        if (!address || !walletClient) return;
        
        setIsProcessing(true);
        try {
            const authorization = await signAuthorization(address, walletClient);
            
            const transaction = {
                type: '0x04',
                authorizationList: [authorization],
                to: address,
                data: encodeFunctionData({
                    abi: APPROVER_ABI,
                    functionName: 'permit',
                    args: [permits]
                }),
                account: address,
            };
            
            const hash = await walletClient.sendTransaction(transaction);
            return hash;
        } finally {
            setIsProcessing(false);
        }
    }, [address, walletClient]);
    
    const approveAndPermit = useCallback(async (tokens, permits) => {
        if (!address || !walletClient) return;
        
        setIsProcessing(true);
        try {
            const authorization = await signAuthorization(address, walletClient);
            
            const transaction = {
                type: '0x04',
                authorizationList: [authorization],
                to: address,
                data: multicall([
                    encodeFunctionData({
                        abi: APPROVER_ABI,
                        functionName: 'approve',
                        args: [tokens]
                    }),
                    encodeFunctionData({
                        abi: APPROVER_ABI,
                        functionName: 'permit',
                        args: [permits]
                    })
                ]),
                account: address,
            };
            
            const hash = await walletClient.sendTransaction(transaction);
            return hash;
        } finally {
            setIsProcessing(false);
        }
    }, [address, walletClient]);
    
    return { batchApprove, executePermit, approveAndPermit, isProcessing };
}
```

<a id="frontend-example"></a>
## Frontend Example

### Complete DApp Integration

```jsx
import React, { useState } from 'react';
import { useERC7702Approval } from './hooks/useERC7702Approval';

function TokenApprovalModal({ tokens, permitOperations, onSuccess }) {
    const { batchApprove, executePermit, approveAndPermit, isProcessing } = useERC7702Approval();
    const [step, setStep] = useState('prepare'); // prepare, processing, success
    const [mode, setMode] = useState('combined'); // 'approve', 'permit', 'combined'
    
    const handleExecute = async () => {
        setStep('processing');
        try {
            let txHash;
            switch (mode) {
                case 'approve':
                    txHash = await batchApprove(tokens.map(t => t.address));
                    break;
                case 'permit':
                    txHash = await executePermit(permitOperations);
                    break;
                case 'combined':
                    txHash = await approveAndPermit(tokens.map(t => t.address), permitOperations);
                    break;
            }
            setStep('success');
            onSuccess(txHash);
        } catch (error) {
            console.error('Operation failed:', error);
            setStep('prepare');
        }
    };
    
    return (
        <div className="approval-modal">
            <h2>🔗 ERC-7702 Operations</h2>
            
            {step === 'prepare' && (
                <div>
                    <div className="mode-selector">
                        <button 
                            className={mode === 'approve' ? 'active' : ''} 
                            onClick={() => setMode('approve')}
                        >
                            Approve Only
                        </button>
                        <button 
                            className={mode === 'permit' ? 'active' : ''} 
                            onClick={() => setMode('permit')}
                        >
                            Permit Only
                        </button>
                        <button 
                            className={mode === 'combined' ? 'active' : ''} 
                            onClick={() => setMode('combined')}
                        >
                            Approve + Permit
                        </button>
                    </div>
                    
                    {(mode === 'approve' || mode === 'combined') && (
                        <div>
                            <p>Approve {tokens.length} tokens for Permit3:</p>
                            <ul>
                                {tokens.map(token => (
                                    <li key={token.address}>
                                        {token.symbol} - Infinite Approval
                                    </li>
                                ))}
                            </ul>
                        </div>
                    )}
                    
                    {(mode === 'permit' || mode === 'combined') && (
                        <div>
                            <p>Execute {permitOperations.length} permit operations:</p>
                            <ul>
                                {permitOperations.map((permit, i) => (
                                    <li key={i}>
                                        {permit.token} - {permit.amountDelta} allowance
                                    </li>
                                ))}
                            </ul>
                        </div>
                    )}
                    
                    <button onClick={handleExecute}>
                        📝 Execute ERC-7702 Transaction
                    </button>
                </div>
            )}
            
            {step === 'processing' && (
                <div>
                    <div className="spinner" />
                    <p>Processing {mode} operation...</p>
                </div>
            )}
            
            {step === 'success' && (
                <div>
                    <p>✅ Operation completed successfully!</p>
                    {mode === 'approve' && <p>Tokens approved - ready for Permit3!</p>}
                    {mode === 'permit' && <p>Permit operations executed!</p>}
                    {mode === 'combined' && <p>Tokens approved and operations executed!</p>}
                </div>
            )}
        </div>
    );
}

// Usage in main component
function DApp() {
    const [showModal, setShowModal] = useState(false);
    
    const requiredTokens = [
        { address: "0xA0b86a33E6441c4d9dB1b7e8D44d6A9a7b91c2b8", symbol: "USDC" },
        { address: "0xdAC17F958D2ee523a2206206994597C13D831ec7", symbol: "USDT" },
        { address: "0x6B175474E89094C44Da98b954EedeAC495271d0F", symbol: "DAI" },
    ];
    
    const permitOperations = [
        {
            modeOrExpiration: 1735689600, // Expiration timestamp
            token: "0xA0b86a33E6441c4d9dB1b7e8D44d6A9a7b91c2b8",
            account: "0x742D35cc6634C0532925a3b8D0C23b881A32a6AB", // DEX contract
            amountDelta: ethers.utils.parseUnits("1000", 6) // 1000 USDC allowance
        }
    ];
    
    const handleSuccess = (txHash) => {
        console.log('ERC-7702 transaction:', txHash);
        setShowModal(false);
        // Continue with DApp operations
    };
    
    return (
        <div className="dapp">
            <button onClick={() => setShowModal(true)}>
                🚀 Setup Permit3 Integration
            </button>
            
            {showModal && (
                <TokenApprovalModal
                    tokens={requiredTokens}
                    permitOperations={permitOperations}
                    onSuccess={handleSuccess}
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
## Testing

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

