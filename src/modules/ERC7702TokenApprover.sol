// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import { IERC7702TokenApprover } from "../interfaces/IERC7702TokenApprover.sol";

/**
 * @title ERC7702TokenApprover
 * @notice Contract designed to work with ERC-7702 to batch approve tokens to Permit3
 * @dev This contract is intended to be used as delegation target for EOAs using ERC-7702
 *      Users authorize their EOA to delegatecall to this contract, which then sets
 *      approvals for ERC20, ERC721, and ERC1155 tokens to the Permit3 contract.
 */
contract ERC7702TokenApprover is IERC7702TokenApprover {
    using SafeERC20 for IERC20;

    /// @notice The Permit3 contract address that will receive approvals
    address public immutable PERMIT3;

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
     * @notice Approve multiple token types to Permit3 in a single transaction
     * @dev This function is designed to be called via ERC-7702 delegatecall from an EOA
     *      - ERC20 tokens: Sets infinite allowance (type(uint256).max)
     *      - ERC721 tokens: Calls setApprovalForAll(permit3, true)
     *      - ERC1155 tokens: Calls setApprovalForAll(permit3, true)
     * @param erc20Tokens Array of ERC20 token addresses to approve
     * @param erc721Tokens Array of ERC721 token contract addresses to approve
     * @param erc1155Tokens Array of ERC1155 token contract addresses to approve
     */
    function approve(
        address[] calldata erc20Tokens,
        address[] calldata erc721Tokens,
        address[] calldata erc1155Tokens
    ) external {
        // Check that at least one token was provided
        if (erc20Tokens.length + erc721Tokens.length + erc1155Tokens.length == 0) {
            revert NoTokensProvided();
        }

        // Approve ERC20 tokens
        uint256 erc20Length = erc20Tokens.length;
        for (uint256 i = 0; i < erc20Length; ++i) {
            if (erc20Tokens[i] == address(0)) {
                revert ZeroAddress();
            }
            IERC20(erc20Tokens[i]).forceApprove(PERMIT3, type(uint256).max);
        }

        // Approve ERC721 tokens
        uint256 erc721Length = erc721Tokens.length;
        for (uint256 i = 0; i < erc721Length; ++i) {
            if (erc721Tokens[i] == address(0)) {
                revert ZeroAddress();
            }
            IERC721(erc721Tokens[i]).setApprovalForAll(PERMIT3, true);
        }

        // Approve ERC1155 tokens
        uint256 erc1155Length = erc1155Tokens.length;
        for (uint256 i = 0; i < erc1155Length; ++i) {
            if (erc1155Tokens[i] == address(0)) {
                revert ZeroAddress();
            }
            IERC1155(erc1155Tokens[i]).setApprovalForAll(PERMIT3, true);
        }
    }
}
