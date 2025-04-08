# 🔏 Permit3 Guides 📚

🧭 [Home](/docs/README.md) > Guides

This section provides step-by-step guides for common Permit3 use cases.

## 📖 Available Guides

| Guide | Description |
|-------|-------------|
| [🚀 Quick Start](./quick-start.md) | Quick introduction to integrating Permit3 |
| [🧩 Witness Integration](./witness-integration.md) | How to implement witness functionality |
| [🌉 Cross-Chain Permits](./cross-chain-permit.md) | Working with permits across multiple chains |
| [✍️ Signature Creation](./signature-creation.md) | Creating and signing permit operations |
| [🛡️ Security Best Practices](./security-best-practices.md) | Best practices for secure Permit3 usage |

## 🏁 Getting Started

If you're new to Permit3, we recommend starting with the [🚀 Quick Start Guide](./quick-start.md), which covers basic integration and common operations.

For more advanced use cases, check out the specific guides for witness functionality and cross-chain operations.

## 💼 Common Use Cases

### 🔓 Basic Token Approval

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

### 💸 Direct Token Transfer

Permit3 can also directly transfer tokens with a signature:

```solidity
IPermit3.AllowanceOrTransfer memory permitData = IPermit3.AllowanceOrTransfer({
    modeOrExpiration: 0, // Transfer mode
    token: tokenAddress,
    account: recipientAddress,
    amountDelta: amount
});
```

### 🔧 Advanced Use Cases

For more advanced use cases like witness functionality and cross-chain operations, refer to the specific guides in this section.

---

| ⬅️ Previous | 🏠 Section | ➡️ Next |
|:-----------|:----------:|------------:|
| [Home](/docs/README.md) | [Home](/docs/README.md) | [Quick Start](/docs/guides/quick-start.md) |