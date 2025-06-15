// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IERC7702TokenApprover } from "./interfaces/IERC7702TokenApprover.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

/**
 * @title ERC7702TokenApprover
 * @notice Contract designed to work with ERC-7702 to batch approve infinite allowances to Permit3
 * @dev This contract is intended to be used as delegation target for EOAs using ERC-7702
 *      Users authorize their EOA to delegatecall to this contract, which then sets infinite
 *      allowances for specified ERC20 tokens to the Permit3 contract.
 */
contract ERC7702TokenApprover is IERC7702TokenApprover {
    /// @notice The Permit3 contract address that will receive infinite approvals
    address public immutable PERMIT3;

    /**
     * @notice Constructor to set the Permit3 contract address
     * @param permit3 Address of the Permit3 contract
     */
    constructor(
        address permit3
    ) {
        PERMIT3 = permit3;
    }

    /**
     * @notice Batch approve infinite allowances for multiple ERC20 tokens to Permit3
     * @dev This function is designed to be called via ERC-7702 delegatecall from an EOA
     *      The EOA must have authorized delegation to this contract in the same transaction
     * @param tokens Array of ERC20 token addresses to approve
     */
    function approve(
        address[] calldata tokens
    ) external {
        if (tokens.length == 0) {
            revert NoTokensProvided();
        }

        uint256 length = tokens.length;

        for (uint256 i = 0; i < length; ++i) {
            address token = tokens[i];

            // Set infinite allowance (type(uint256).max) regardless of current allowance
            bool success = IERC20(token).approve(PERMIT3, type(uint256).max);

            if (!success) {
                revert ApprovalFailed(token);
            }
        }
    }
}
