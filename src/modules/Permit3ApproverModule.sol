// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IERC7579Module } from "./interfaces/IERC7579Module.sol";
import { IExecutorModule } from "./interfaces/IExecutorModule.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

/**
 * @title Permit3ApproverModule
 * @notice ERC-7579 executor module that allows anyone to approve tokens to Permit3 on behalf of the account
 * @dev This module integrates with smart accounts instead of replacing them
 *      It allows permissionless approval of tokens to the Permit3 contract
 */
contract Permit3ApproverModule is IERC7579Module, IExecutorModule {
    /// @notice The Permit3 contract address that will receive approvals
    address public immutable PERMIT3;

    /// @notice Module type identifier for ERC-7579
    uint256 public constant MODULE_TYPE = 2; // Executor module

    /// @notice Name of the module
    string public constant NAME = "Permit3ApproverModule";

    /// @notice Version of the module
    string public constant VERSION = "1.0.0";

    /// @notice Thrown when no tokens are provided for approval
    error NoTokensProvided();

    /// @notice Thrown when the permit3 address is zero
    error ZeroPermit3();

    /// @notice Thrown when a token address is zero
    error ZeroToken();

    /// @notice Thrown when a zero address is provided where it's not allowed (deprecated)
    /// @param parameterName The name of the parameter that contained the zero address
    /// @dev This error is deprecated in favor of specific error types above
    error ZeroAddress(string parameterName);

    /**
     * @notice Constructor to set the Permit3 contract address
     * @param permit3 Address of the Permit3 contract
     */
    constructor(
        address permit3
    ) {
        if (permit3 == address(0)) {
            revert ZeroPermit3();
        }
        PERMIT3 = permit3;
    }

    /**
     * @notice Initialize the module for an account
     * @dev No initialization data needed for this module
     * @param data Initialization data (unused)
     */
    function onInstall(
        bytes calldata data
    ) external override {
        // No initialization needed
    }

    /**
     * @notice Deinitialize the module for an account
     * @dev No cleanup needed for this module
     * @param data Deinitialization data (unused)
     */
    function onUninstall(
        bytes calldata data
    ) external override {
        // No cleanup needed
    }

    /**
     * @notice Check if the module is initialized for an account
     * @param smartAccount The smart account to check
     * @return True if initialized (always true for this module)
     */
    function isInitialized(
        address smartAccount
    ) external pure override returns (bool) {
        return true;
    }

    /**
     * @notice Get the type of the module
     * @return moduleTypeId The module type identifier
     */
    function isModuleType(
        uint256 moduleTypeId
    ) external pure override returns (bool) {
        return moduleTypeId == MODULE_TYPE;
    }

    /**
     * @notice Execute approval of tokens to Permit3
     * @dev Returns the execution array for the smart account to execute
     * @param account The smart account executing the approval
     * @param data Encoded array of token addresses to approve
     * @return executions Array of executions for the smart account
     */
    function execute(
        address account,
        bytes calldata data
    ) external view override returns (Execution[] memory executions) {
        // Decode the token addresses from the data
        address[] memory tokens = abi.decode(data, (address[]));

        uint256 tokensLength = tokens.length;
        if (tokensLength == 0) {
            revert NoTokensProvided();
        }

        // Create execution array for approvals
        executions = new Execution[](tokensLength);

        for (uint256 i = 0; i < tokensLength; ++i) {
            if (tokens[i] == address(0)) {
                revert ZeroToken();
            }

            // Create execution for each token approval
            executions[i] = Execution({
                target: tokens[i],
                value: 0,
                data: abi.encodeCall(IERC20.approve, (PERMIT3, type(uint256).max))
            });
        }
    }

    /**
     * @notice Get the execution data for approving tokens
     * @dev Helper function to encode the data for the execute function
     * @param tokens Array of token addresses to approve
     * @return data Encoded data for the execute function
     */
    function getExecutionData(
        address[] calldata tokens
    ) external pure returns (bytes memory data) {
        return abi.encode(tokens);
    }

    /**
     * @notice Check if a specific module type is supported
     * @param interfaceId The interface identifier to check
     * @return True if the interface is supported
     */
    function supportsInterface(
        bytes4 interfaceId
    ) external pure returns (bool) {
        return interfaceId == type(IERC7579Module).interfaceId || interfaceId == type(IExecutorModule).interfaceId;
    }
}
