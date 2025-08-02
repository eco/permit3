// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IUnhingedMerkleTree
 * @notice Interface for Unhinged Merkle Tree - a standard merkle tree structure for cross-chain proofs
 * @dev The Unhinged Merkle Tree uses standard merkle tree verification with ordered hashing
 */
interface IUnhingedMerkleTree {
    /**
     * @notice Error when the merkle proof verification fails
     */
    error InvalidMerkleProof();

    /**
     * @notice Error when input parameters are invalid
     */
    error InvalidParameters();
}
