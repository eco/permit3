// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IMultiTokenPermit } from "../interfaces/IMultiTokenPermit.sol";

/**
 * @title TokenType
 * @notice Token type definitions and errors for multi-token support
 */

/**
 * @notice Error thrown when invalid token data is provided
 * @param tokenType The token type that had invalid data
 * @param data The invalid data that was provided
 */
error InvalidTokenData(IMultiTokenPermit.TokenStandard tokenType, bytes data);

/**
 * @notice Error thrown when array lengths don't match
 * @dev Fixed typo from original IvalidArrayLength
 */
error InvalidArrayLength();