// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @notice Error thrown when token data is invalid for the specified token standard
 * @param tokenStandard The token standard being used
 * @param tokenData The invalid token data that caused the error
 */
error InvalidTokenData(TokenStandard tokenStandard, bytes tokenData);

/**
 * @notice Error thrown when array lengths don't match in batch operations
 */
error InvalidArrayLength();

/**
 * @notice Enum representing different token standards
 * @param ERC20 Standard fungible tokens with divisible amounts
 * @param ERC721 Non-fungible tokens with unique token IDs
 * @param ERC1155 Semi-fungible tokens with both ID and amount
 */
enum TokenStandard {
    ERC20,
    ERC721,
    ERC1155
}