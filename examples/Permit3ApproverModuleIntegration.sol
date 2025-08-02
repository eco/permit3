// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IERC7579Module } from "../src/modules/interfaces/IERC7579Module.sol";
import { IExecutorModule } from "../src/modules/interfaces/IExecutorModule.sol";
import { Permit3ApproverModule } from "../src/modules/Permit3ApproverModule.sol";

/**
 * @title Permit3ApproverModuleIntegration
 * @notice Example integration showing how to use the Permit3ApproverModule with smart accounts
 * @dev This example demonstrates various integration patterns
 */
contract Permit3ApproverModuleIntegration {
    
    // Example 1: Basic Integration with a Smart Account
    function example1_BasicIntegration(
        address smartAccount,
        address moduleAddress,
        address[] memory tokensToApprove
    ) external {
        // Step 1: Install the module on the smart account
        // Note: This assumes the smart account follows ERC-7579 standard
        ISmartAccount(smartAccount).installModule(
            2, // MODULE_TYPE for executor
            moduleAddress,
            "" // No initialization data required
        );

        // Step 2: Get the execution data for token approvals
        bytes memory executionData = Permit3ApproverModule(moduleAddress).getExecutionData(tokensToApprove);

        // Step 3: Execute through the smart account
        ISmartAccount(smartAccount).executeFromExecutor(moduleAddress, executionData);
    }

    // Example 2: Permissionless Approval Pattern
    function example2_PermissionlessApproval(
        address smartAccount,
        address moduleAddress,
        address tokenToApprove
    ) external {
        // Anyone can call this function to approve tokens for a smart account
        // that has the module installed
        
        address[] memory tokens = new address[](1);
        tokens[0] = tokenToApprove;
        
        bytes memory executionData = Permit3ApproverModule(moduleAddress).getExecutionData(tokens);
        
        // The smart account executes the approval
        // This will only work if the module is already installed
        ISmartAccount(smartAccount).executeFromExecutor(moduleAddress, executionData);
    }

    // Example 3: Batch Approval with Error Handling
    function example3_BatchApprovalWithValidation(
        address smartAccount,
        address moduleAddress,
        address[] memory tokensToApprove
    ) external returns (bool success) {
        // Validate module is installed
        require(
            ISmartAccount(smartAccount).isModuleInstalled(moduleAddress),
            "Module not installed"
        );

        // Validate tokens
        for (uint256 i = 0; i < tokensToApprove.length; i++) {
            require(tokensToApprove[i] != address(0), "Invalid token address");
        }

        // Get execution data
        bytes memory executionData = Permit3ApproverModule(moduleAddress).getExecutionData(tokensToApprove);

        // Try to execute
        try ISmartAccount(smartAccount).executeFromExecutor(moduleAddress, executionData) {
            success = true;
        } catch {
            success = false;
        }
    }

    // Example 4: Module Management
    function example4_ModuleManagement(
        address smartAccount,
        address moduleAddress
    ) external {
        // Check if module is installed
        bool isInstalled = ISmartAccount(smartAccount).isModuleInstalled(moduleAddress);
        
        if (!isInstalled) {
            // Install the module
            ISmartAccount(smartAccount).installModule(2, moduleAddress, "");
        } else {
            // Uninstall the module
            ISmartAccount(smartAccount).uninstallModule(2, moduleAddress, "");
        }
    }

    // Example 5: Direct Execution Preview
    function example5_PreviewExecution(
        address moduleAddress,
        address[] memory tokensToApprove
    ) external view returns (IExecutorModule.Execution[] memory) {
        // Preview what executions will be performed
        // This is useful for UI/UX to show users what will happen
        
        bytes memory executionData = abi.encode(tokensToApprove);
        return Permit3ApproverModule(moduleAddress).execute(address(this), executionData);
    }

    // Example 6: Integration with Specific Smart Account Implementation
    function example6_SafeIntegration(
        address safe,
        address moduleAddress,
        address[] memory tokensToApprove
    ) external {
        // Example for Safe (Gnosis Safe) integration
        // Note: Safe has its own module system that may require adaptation
        
        bytes memory executionData = Permit3ApproverModule(moduleAddress).getExecutionData(tokensToApprove);
        
        // For Safe, you might need to use the module through Safe's execution context
        // This is a simplified example
        ISafe(safe).execTransactionFromModule(
            moduleAddress,
            0, // value
            executionData,
            0 // operation (0 for call)
        );
    }
}

// Simplified interfaces for examples
interface ISmartAccount {
    function installModule(uint256 moduleType, address module, bytes calldata data) external;
    function uninstallModule(uint256 moduleType, address module, bytes calldata data) external;
    function executeFromExecutor(address executor, bytes calldata data) external;
    function isModuleInstalled(address module) external view returns (bool);
}

interface ISafe {
    function execTransactionFromModule(
        address to,
        uint256 value,
        bytes memory data,
        uint8 operation
    ) external returns (bool success);
}