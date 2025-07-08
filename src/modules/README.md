# Permit3ApproverModule - ERC-7579 Module

## Overview

The `Permit3ApproverModule` is an ERC-7579 executor module that enables smart accounts to grant anyone the ability to approve their tokens to the Permit3 contract. This module integrates with existing smart accounts rather than replacing them, providing a seamless way to enable permissionless token approvals.

## Key Features

- **ERC-7579 Compatible**: Works with any ERC-7579 compliant smart account
- **Permissionless Approvals**: Once installed, anyone can trigger token approvals to Permit3
- **Non-Invasive**: Integrates with existing smart accounts without overriding their functionality
- **Batch Operations**: Approve multiple tokens in a single transaction
- **Safe Implementation**: Uses OpenZeppelin's SafeERC20 for secure token interactions

## How It Works

1. The module is installed on a smart account
2. Anyone can call the smart account to execute the module's approval function
3. The module approves specified tokens to the Permit3 contract with infinite allowance
4. The smart account maintains all its existing functionality

## Usage

### Installation

To install the module on a smart account:

```solidity
// Install the module (no initialization data required)
smartAccount.installModule(
    2, // MODULE_TYPE for executor
    address(permit3ApproverModule),
    ""  // No initialization data needed
);
```

### Executing Approvals

To approve tokens through the module:

```solidity
// Prepare the list of tokens to approve
address[] memory tokens = new address[](2);
tokens[0] = address(USDC);
tokens[1] = address(DAI);

// Encode the execution data
bytes memory data = permit3ApproverModule.getExecutionData(tokens);

// Execute through the smart account
smartAccount.executeFromExecutor(
    address(permit3ApproverModule),
    data
);
```

### Module Functions

- `execute(address account, bytes calldata data)`: Main execution function called by the smart account
- `getExecutionData(address[] calldata tokens)`: Helper to encode token addresses for execution
- `onInstall(bytes calldata data)`: Called when module is installed (no-op for this module)
- `onUninstall(bytes calldata data)`: Called when module is uninstalled (no-op for this module)
- `isInitialized(address smartAccount)`: Always returns true (no initialization needed)
- `isModuleType(uint256 moduleTypeId)`: Checks if module type is executor (type 2)

## Security Considerations

- The module allows anyone to approve tokens, but only to the predetermined Permit3 address
- Token approvals are set to `type(uint256).max` (infinite allowance)
- The module uses `forceApprove` to ensure approvals are set correctly regardless of current allowance
- Only the smart account itself can call the `execute` function

## Integration Example

```solidity
// Deploy the module with Permit3 address
Permit3ApproverModule module = new Permit3ApproverModule(PERMIT3_ADDRESS);

// Install on smart account
ISmartAccount(smartAccount).installModule(2, address(module), "");

// Now anyone can trigger approvals through the smart account
address[] memory tokensToApprove = new address[](1);
tokensToApprove[0] = tokenAddress;

bytes memory execData = module.getExecutionData(tokensToApprove);
ISmartAccount(smartAccount).executeFromExecutor(address(module), execData);
```

## Benefits Over ERC-7702 Approach

- **Preserves Smart Account Features**: Unlike ERC-7702 delegation which replaces account logic, this module adds functionality
- **Modular**: Can be installed/uninstalled without affecting other account features
- **Compatible**: Works with existing smart account infrastructure and standards
- **Flexible**: Smart accounts can have multiple modules for different purposes

## Deployment

### Deploy with Foundry

```bash
# Standard deployment
forge script scripts/DeployModule.s.sol:DeployModule --rpc-url <RPC_URL> --broadcast

# Deterministic deployment (same address across chains)
forge script scripts/DeployModule.s.sol:DeployModule --sig "runDeterministic()" --rpc-url <RPC_URL> --broadcast
```

### Environment Variables

```bash
PERMIT3_ADDRESS=0x000000000022D473030F116dDEE9F6B43aC78BA3  # Default Permit3 address
SALT=0x...  # Optional salt for deterministic deployment
```

### Compute Deterministic Address

```bash
forge script scripts/DeployModule.s.sol:DeployModule --sig "computeAddress(address,bytes32)" <PERMIT3_ADDRESS> <SALT>
```

## Gas Costs

- Module deployment: ~500k gas
- Module installation: ~50k gas  
- Token approval execution: ~45k gas per token
- Module uninstallation: ~25k gas

## Audits & Security

This module should be audited before production use. Key security considerations:

- The module allows anyone to approve tokens, but only to the predetermined Permit3 address
- Smart accounts should carefully consider the security implications before installing
- The module uses standard OpenZeppelin contracts for token interactions