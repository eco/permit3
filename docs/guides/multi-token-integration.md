<a id="multi-token-guide-top"></a>
# Multi-Token Integration Guide 

This guide walks you through integrating NFT and semi-fungible token support in your Permit3-based application.

<a id="prerequisites"></a>
## 📋 Prerequisites

Before implementing multi-token support, ensure you have:

1. ✅ Basic understanding of [Permit3 concepts](/docs/concepts/README.md)
2. ✅ Familiarity with ERC721 and ERC1155 standards
3. ✅ Permit3 contract deployed or accessible
4. ✅ Web3 library (ethers.js, viem, or web3.js)

<a id="basic-setup"></a>
## Basic Setup

### 1. Import Required Interfaces

```solidity
import { IMultiTokenPermit } from "@permit3/interfaces/IMultiTokenPermit.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
```

### 2. Initialize Contract Connection

```javascript
// JavaScript/TypeScript
import { ethers } from 'ethers';

const permit3Address = "0x..."; // Your Permit3 deployment
const permit3ABI = [...]; // IMultiTokenPermit ABI

const permit3 = new ethers.Contract(
    permit3Address,
    permit3ABI,
    signer
);
```

<a id="detecting-token-types"></a>
## Detecting Token Types

### Automatic Token Standard Detection

```javascript
async function detectTokenStandard(tokenAddress) {
    const tokenContract = new ethers.Contract(
        tokenAddress,
        [
            'function supportsInterface(bytes4) view returns (bool)',
            'function decimals() view returns (uint8)',
        ],
        provider
    );

    try {
        // Check for ERC721
        const isERC721 = await tokenContract.supportsInterface('0x80ac58cd');
        if (isERC721) return 'ERC721';

        // Check for ERC1155  
        const isERC1155 = await tokenContract.supportsInterface('0xd9b67a26');
        if (isERC1155) return 'ERC1155';

        // Check for ERC20 (has decimals function)
        await tokenContract.decimals();
        return 'ERC20';
    } catch {
        throw new Error('Unknown token standard');
    }
}
```

### Solidity Token Detection

```solidity
contract TokenDetector {
    bytes4 constant ERC721_INTERFACE_ID = 0x80ac58cd;
    bytes4 constant ERC1155_INTERFACE_ID = 0xd9b67a26;

    function getTokenStandard(address token) public view returns (IMultiTokenPermit.TokenStandard) {
        try IERC165(token).supportsInterface(ERC721_INTERFACE_ID) returns (bool isERC721) {
            if (isERC721) return IMultiTokenPermit.TokenStandard.ERC721;
        } catch {}

        try IERC165(token).supportsInterface(ERC1155_INTERFACE_ID) returns (bool isERC1155) {
            if (isERC1155) return IMultiTokenPermit.TokenStandard.ERC1155;
        } catch {}

        return IMultiTokenPermit.TokenStandard.ERC20;
    }
}
```

<a id="approval-patterns"></a>
## Approval Patterns

### ERC721 NFT Approvals

#### Approve Specific NFT

```javascript
// Approve transfer of NFT with tokenId 42
async function approveSpecificNFT(nftContract, spender, tokenId) {
    const expiration = Math.floor(Date.now() / 1000) + 86400; // 24 hours
    
    await permit3.approve(
        nftContract,
        spender,
        tokenId,
        1, // Amount is always 1 for NFTs
        expiration
    );
}
```

#### Approve Entire Collection

```javascript
// Approve all NFTs in a collection
async function approveCollection(nftContract, spender) {
    const COLLECTION_WILDCARD = ethers.constants.MaxUint256;
    const expiration = Math.floor(Date.now() / 1000) + 86400;
    
    await permit3.approve(
        nftContract,
        spender,
        COLLECTION_WILDCARD, // type(uint256).max as wildcard
        1,
        expiration
    );
}
```

### ERC1155 Semi-Fungible Token Approvals

```javascript
// Approve specific ERC1155 token with amount
async function approveERC1155(
    tokenContract,
    spender,
    tokenId,
    amount
) {
    const expiration = Math.floor(Date.now() / 1000) + 86400;
    
    await permit3.approve(
        tokenContract,
        spender,
        tokenId,
        amount,
        expiration
    );
}
```

### ERC20 Token Approvals

```javascript
// Standard ERC20 approval (tokenId = 0)
async function approveERC20(tokenContract, spender, amount) {
    const expiration = Math.floor(Date.now() / 1000) + 86400;
    
    await permit3.approve(
        tokenContract,
        spender,
        0, // tokenId is 0 for ERC20
        amount,
        expiration
    );
}
```

<a id="transfer-operations"></a>
## Transfer Operations

### Single NFT Transfer

```javascript
async function transferNFT(from, to, nftContract, tokenId) {
    // Ensure NFT is approved to Permit3 first
    const nft = new ethers.Contract(nftContract, ERC721_ABI, signer);
    await nft.setApprovalForAll(permit3.address, true);
    
    // Execute transfer through Permit3
    await permit3['transferFrom(address,address,address,uint256)'](
        from,
        to,
        nftContract,
        tokenId
    );
}
```

### ERC1155 Transfer with Amount

```javascript
async function transferERC1155(
    from,
    to,
    tokenContract,
    tokenId,
    amount
) {
    // Ensure ERC1155 is approved to Permit3
    const token = new ethers.Contract(tokenContract, ERC1155_ABI, signer);
    await token.setApprovalForAll(permit3.address, true);
    
    // Execute transfer through Permit3
    await permit3['transferFrom(address,address,address,uint256,uint160)'](
        from,
        to,
        tokenContract,
        tokenId,
        amount
    );
}
```

<a id="batch-operations"></a>
## Batch Operations

### Batch NFT Transfers

```javascript
async function batchTransferNFTs(transfers) {
    // Format: Array of ERC721TransferDetails
    const formattedTransfers = transfers.map(t => ({
        from: t.from,
        to: t.to,
        tokenId: t.tokenId,
        token: t.tokenContract
    }));
    
    await permit3['transferFrom((address,address,uint256,address)[])'](
        formattedTransfers
    );
}
```

### Mixed Token Type Batch

```javascript
async function mixedBatchTransfer(transfers) {
    const formattedTransfers = [];
    
    for (const transfer of transfers) {
        const tokenType = await detectTokenStandard(transfer.token);
        
        let tokenStandard;
        if (tokenType === 'ERC20') tokenStandard = 0;
        else if (tokenType === 'ERC721') tokenStandard = 1;
        else if (tokenType === 'ERC1155') tokenStandard = 2;
        
        formattedTransfers.push({
            tokenType: tokenStandard,
            transfer: {
                from: transfer.from,
                to: transfer.to,
                token: transfer.token,
                tokenId: transfer.tokenId || 0,
                amount: transfer.amount || 1
            }
        });
    }
    
    await permit3.batchTransferFrom(formattedTransfers);
}
```

### ERC1155 Batch Transfer

```javascript
async function batchTransferERC1155(
    from,
    to,
    tokenContract,
    tokenIds,
    amounts
) {
    const batchDetails = {
        from: from,
        to: to,
        tokenIds: tokenIds,
        amounts: amounts,
        token: tokenContract
    };
    
    await permit3.batchTransferFrom(batchDetails);
}
```

<a id="best-practices"></a>
## Best Practices

### 1. Gas Optimization

```javascript
// ✅ Good: Batch multiple operations
const batchTransfers = [...];
await permit3.batchTransferFrom(batchTransfers);

// ❌ Bad: Individual transactions
for (const transfer of transfers) {
    await permit3.transferFrom(transfer);
}
```

### 2. Error Handling

```javascript
async function safeTransfer(from, to, token, tokenId, amount) {
    try {
        // Check allowance first
        const { amount: allowed } = await permit3.allowance(
            from,
            token,
            msg.sender,
            tokenId
        );
        
        if (allowed < amount) {
            throw new Error('Insufficient allowance');
        }
        
        // Proceed with transfer
        await permit3.transferFrom(from, to, token, tokenId, amount);
        
    } catch (error) {
        if (error.message.includes('AllowanceExpired')) {
            console.error('Allowance has expired');
        } else if (error.message.includes('InsufficientAllowance')) {
            console.error('Not enough tokens approved');
        } else {
            console.error('Transfer failed:', error);
        }
        throw error;
    }
}
```

### 3. Allowance Management

```javascript
class AllowanceManager {
    constructor(permit3) {
        this.permit3 = permit3;
    }
    
    async checkAndRefreshAllowance(owner, token, spender, tokenId, requiredAmount) {
        const { amount, expiration } = await this.permit3.allowance(
            owner,
            token,
            spender,
            tokenId
        );
        
        const now = Math.floor(Date.now() / 1000);
        const needsRefresh = amount < requiredAmount || expiration <= now;
        
        if (needsRefresh) {
            const newExpiration = now + 86400; // 24 hours
            await this.permit3.approve(
                token,
                spender,
                tokenId,
                requiredAmount,
                newExpiration
            );
        }
        
        return !needsRefresh;
    }
}
```

### 4. User Experience Enhancements

```javascript
// Show clear token type to users
function getTokenTypeDisplay(tokenStandard) {
    switch(tokenStandard) {
        case 'ERC20': return '🪙 Fungible Token';
        case 'ERC721': return '🖼️ NFT';
        case 'ERC1155': return '🎮 Game Item';
        default: return '❓ Unknown';
    }
}

// Provide collection-wide approval option for NFTs
async function promptApprovalType(nftContract) {
    const choice = await showModal({
        title: 'Approval Type',
        options: [
            { value: 'single', label: 'Approve this NFT only' },
            { value: 'collection', label: 'Approve entire collection' }
        ]
    });
    
    if (choice === 'collection') {
        return ethers.constants.MaxUint256;
    }
    return specificTokenId;
}
```

## Common Pitfalls

### 1. Forgetting Token Approval to Permit3

```javascript
// ❌ Wrong: Trying to transfer without approval
await permit3.transferFrom(from, to, nftContract, tokenId);

// ✅ Correct: Approve NFT to Permit3 first
const nft = new ethers.Contract(nftContract, ERC721_ABI, signer);
await nft.setApprovalForAll(permit3.address, true);
await permit3.transferFrom(from, to, nftContract, tokenId);
```

### 2. Incorrect TokenId for ERC20

```javascript
// ❌ Wrong: Using non-zero tokenId for ERC20
await permit3.approve(erc20Token, spender, 123, amount, expiration);

// ✅ Correct: TokenId must be 0 for ERC20
await permit3.approve(erc20Token, spender, 0, amount, expiration);
```

### 3. Amount Confusion for NFTs

```javascript
// ❌ Wrong: Using amount > 1 for ERC721
await permit3.transferFrom(from, to, nftContract, tokenId, 100);

// ✅ Correct: Amount is always 1 for ERC721 (or omitted)
await permit3.transferFrom(from, to, nftContract, tokenId);
```

## 📚 Complete Integration Example

```javascript
class MultiTokenPermit3Client {
    constructor(permit3Contract, provider) {
        this.permit3 = permit3Contract;
        this.provider = provider;
    }
    
    async executeTransfer(params) {
        const { from, to, token, tokenId, amount } = params;
        
        // Detect token type
        const tokenType = await this.detectTokenStandard(token);
        
        // Ensure proper approval to Permit3
        await this.ensureTokenApproval(token, tokenType);
        
        // Execute appropriate transfer
        switch(tokenType) {
            case 'ERC721':
                return this.permit3['transferFrom(address,address,address,uint256)'](
                    from, to, token, tokenId
                );
            
            case 'ERC1155':
                return this.permit3['transferFrom(address,address,address,uint256,uint160)'](
                    from, to, token, tokenId, amount
                );
            
            case 'ERC20':
                return this.permit3.transferFrom(from, to, amount, token);
            
            default:
                throw new Error(`Unsupported token type: ${tokenType}`);
        }
    }
    
    async ensureTokenApproval(token, tokenType) {
        const tokenContract = new ethers.Contract(
            token,
            tokenType === 'ERC721' ? ERC721_ABI :
            tokenType === 'ERC1155' ? ERC1155_ABI :
            ERC20_ABI,
            this.provider.getSigner()
        );
        
        if (tokenType === 'ERC721' || tokenType === 'ERC1155') {
            const isApproved = await tokenContract.isApprovedForAll(
                await this.provider.getSigner().getAddress(),
                this.permit3.address
            );
            
            if (!isApproved) {
                await tokenContract.setApprovalForAll(this.permit3.address, true);
            }
        } else {
            // ERC20 approval handled separately
            const allowance = await tokenContract.allowance(
                await this.provider.getSigner().getAddress(),
                this.permit3.address
            );
            
            if (allowance.isZero()) {
                await tokenContract.approve(
                    this.permit3.address,
                    ethers.constants.MaxUint256
                );
            }
        }
    }
}
```

## Critical: Using Multi-Tokens with Signed Permits

**Important**: When using NFTs or ERC1155 tokens with Permit3's signed permit functions (`permit()` with signatures), you must encode the tokenId into the address field since `AllowanceOrTransfer` struct doesn't have a tokenId field:

```javascript
// Encode NFT/ERC1155 for signed permits
const encodedTokenId = ethers.utils.getAddress(
    '0x' + ethers.utils.keccak256(
        ethers.utils.solidityPack(
            ['address', 'uint256'],
            [tokenContract, tokenId]
        )
    ).slice(26)
);

// Use in AllowanceOrTransfer
const permit = {
    modeOrExpiration: expiration,
    token: encodedTokenId,  // Encoded address, not the token contract
    account: spender,
    amountDelta: amount  // 1 for NFTs, variable for ERC1155
};
```

**For detailed guidance on using multi-tokens with signed permits, see the [Multi-Token Signed Permits Guide](/docs/guides/multi-token-signed-permits.md).**

