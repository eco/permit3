<a id="guides-top"></a>
# Permit3 Guides

This section provides step-by-step guides for common Permit3 use cases.

<a id="available-guides"></a>
## 📖 Available Guides

| Guide | Description |
|-------|-------------|
| [Quick Start](./quick-start.md) | Quick introduction to integrating Permit3 |
| [ERC-7702 Integration](./erc7702-integration.md) | Batch token approvals with Account Abstraction |
| [Witness Integration](./witness-integration.md) | How to implement witness functionality |
| [Multi-Token Integration](./multi-token-integration.md) | NFT and semi-fungible token support implementation |
| [Multi-Token Signed Permits](./multi-token-signed-permits.md) | Using NFTs and ERC1155 with signed permit functions and encoding |
| [Cross-Chain Permits](./cross-chain-permit.md) | Working with permits across multiple chains |
| [Signature Creation](./signature-creation.md) | Creating and signing permit operations |
| [Security Best Practices](./security-best-practices.md) | Best practices for secure Permit3 usage |

<a id="getting-started"></a>
## 🏁 Getting Started

If you're new to Permit3, we recommend starting with the [🚀 Quick Start Guide](./quick-start.md), which covers basic integration and common operations.

For more advanced use cases, check out the specific guides for witness functionality and cross-chain operations.

<a id="common-use-cases"></a>
## Common Use Cases

### Basic Token Approval

Permit3 enables signature-based token approvals for any ERC20 token:

```solidity
permit3.permit(
    owner,
    salt,
    deadline,
    timestamp,
    chainPermits,
    signature
);
```

### Direct Token Transfer

Permit3 can also directly transfer tokens with a signature:

```solidity
IPermit3.AllowanceOrTransfer memory permitData = IPermit3.AllowanceOrTransfer({
    modeOrExpiration: 0, // TransferERC20 mode
    token: tokenAddress,
    account: recipientAddress,
    amountDelta: amount
});
```

### Advanced Use Cases

For more advanced use cases like witness functionality and cross-chain operations, refer to the specific guides in this section.

## Developer Guidance

### When to Use Single-Chain vs Cross-Chain Permits

**Use Single-Chain Permits when:**
- Operations are isolated to one blockchain
- You need maximum gas efficiency on that chain
- Simpler implementation is preferred
- Users primarily operate on one network

**Use Cross-Chain Permits when:**
- Users need to authorize operations across multiple chains
- You want to minimize signature requests (one signature for all chains)
- Building cross-chain DeFi protocols or bridges
- Implementing chain-agnostic applications

### How to Choose Chain Ordering

When building cross-chain permits, optimize gas costs through strategic chain ordering:

1. **Analyze Gas Costs**: Research current gas prices on target chains
2. **Order by Cost**: Place cheapest chains (L2s) first, expensive chains (L1) last
3. **Example Ordering**:
   - ✅ Arbitrum → Optimism → Polygon → Ethereum
   - ❌ Ethereum → Arbitrum → Optimism → Polygon
4. **Dynamic Ordering**: Consider gas price oracles for real-time optimization

### Integration Best Practices

1. **Start Simple**: Begin with single-chain permits before adding cross-chain complexity
2. **Test Thoroughly**: Use testnets for all target chains before mainnet
3. **Monitor Gas**: Track actual gas usage and optimize accordingly
4. **User Experience**: Provide clear feedback about which chains are involved
5. **Error Handling**: Implement robust error handling for cross-chain failures
6. **Documentation**: Document your chain ordering strategy for users
