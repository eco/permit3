# Deployment Scripts

This directory contains deployment scripts for the Permit3 protocol and its modules.

## Scripts Overview

### 1. Deploy.s.sol
Deploys the complete Permit3 system including:
- `Permit3` - Main contract
- `ERC7702TokenApprover` - ERC-7702 integration for EOA delegation

### 2. DeployApprover.s.sol
Deploys only the `ERC7702TokenApprover` with a specified Permit3 address.

### 3. DeployModule.s.sol
Deploys the `Permit3ApproverModule` - an ERC-7579 executor module for smart accounts.

## Deployment Instructions

### Prerequisites
- Set up environment variables in `.env`:
```bash
PRIVATE_KEY=your_private_key
SALT=your_deployment_salt  # Optional, for deterministic deployment
PERMIT3_ADDRESS=0x000000000022D473030F116dDEE9F6B43aC78BA3  # For module deployment
```

### Deploy Complete System
```bash
forge script scripts/Deploy.s.sol:Deploy --rpc-url <RPC_URL> --broadcast --verify
```

### Deploy ERC7702 Approver Only
```bash
forge script scripts/DeployApprover.s.sol:DeployApprover --rpc-url <RPC_URL> --broadcast --verify
```

### Deploy Permit3ApproverModule

**Standard deployment:**
```bash
forge script scripts/DeployModule.s.sol:DeployModule --rpc-url <RPC_URL> --broadcast --verify
```

**Deterministic deployment (CREATE2):**
```bash
forge script scripts/DeployModule.s.sol:DeployModule --sig "runDeterministic()" --rpc-url <RPC_URL> --broadcast --verify
```

**Compute deterministic address:**
```bash
forge script scripts/DeployModule.s.sol:DeployModule --sig "computeAddress(address,bytes32)" <PERMIT3_ADDRESS> <SALT>
```

## Deployment Addresses

All deployments use the CREATE2 factory at: `0xce0042B868300000d44A59004Da54A005ffdcf9f`

This ensures deterministic addresses across all chains when using the same salt.

## Supported Networks

The scripts support deployment to any EVM-compatible chain. Verified deployments exist on:
- Ethereum Mainnet (1)
- Optimism (10)  
- Polygon (137)
- Base (8453)
- Arbitrum One (42161)

## Module Integration

After deploying the `Permit3ApproverModule`, it can be installed on any ERC-7579 compatible smart account:

```solidity
// Install the module
smartAccount.installModule(
    2,  // MODULE_TYPE for executor
    moduleAddress,
    ""  // No initialization data needed
);

// Use the module to approve tokens
address[] memory tokens = new address[](2);
tokens[0] = USDC;
tokens[1] = DAI;

bytes memory data = IPermit3ApproverModule(moduleAddress).getExecutionData(tokens);
smartAccount.executeFromExecutor(moduleAddress, data);
```

## Gas Optimization

The deployment scripts are configured with:
- Optimizer enabled
- 1,000,000 optimizer runs
- Optimized for deployment size and runtime efficiency