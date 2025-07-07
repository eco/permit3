// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @title IERC7702TokenApprover
 * @notice Interface for the ERC-7702 Token Approver contract
 * @dev This interface defines the contract designed to work with ERC-7702
 *      to enable EOAs to batch approve infinite allowances to Permit3
 */
interface IERC7702TokenApprover {
    /// @notice Thrown when no tokens are provided for approval
    error NoTokensProvided();

    /**
     * @notice The Permit3 contract address that will receive infinite approvals
     * @return The address of the Permit3 contract
     */
    function PERMIT3() external view returns (address);

    /**
     * @notice Batch approve infinite allowances for multiple ERC20 tokens to Permit3
     * @dev This function is designed to be called via ERC-7702 delegatecall from an EOA
     *      The EOA must have authorized delegation to this contract in the same transaction
     * @param tokens Array of ERC20 token addresses to approve
     */
    function approve(
        address[] calldata tokens
    ) external;
}
