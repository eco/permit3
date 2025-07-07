// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IUnhingedMerkleTree
 * @notice Interface for Unhinged Merkle Tree - an optimized data structure for cross-chain proofs
 * @dev The Unhinged Merkle Tree is designed for efficient cross-chain proofs where each chain only needs to process
 * what's relevant to it
 */
interface IUnhingedMerkleTree {
    /**
     * @notice Optimized proof structure for Unhinged Merkle Tree
     * @param counts Packed bytes32 that contains all auxiliary data:
     *        - First 120 bits: Number of nodes in subtreeProof
     *        - Next 120 bits: Number of nodes in followingHashes
     *        - Next 15 bits: Reserved for future use
     *        - Last bit: Flag indicating if preHash is present (1) or not (0)
     * @param nodes Array of all proof nodes in sequence: [preHash (if present), subtreeProof nodes...,
     * followingHashes...]
     * @dev When hasPreHash=false (last bit=0), the preHash is completely omitted from the
     *      nodes array rather than included as a zero value. This optimization significantly improves
     *      gas efficiency by reducing calldata size and simplifying verification logic.
     */
    struct UnhingedProof {
        bytes32 counts;
        bytes32[] nodes;
    }

    /**
     * @notice Error when the subtree proof verification fails
     */
    error InvalidSubtreeProof();

    /**
     * @notice Error when the unhinged chain verification fails
     */
    error InvalidUnhingedProof();

    /**
     * @notice Error when input parameters are invalid
     */
    error InvalidParameters();

    /**
     * @notice Error when preHash flag is true but the nodes array is empty
     */
    error HasPreHashButEmptyNodes();

    /**
     * @notice Error when nodes array length doesn't match the counts in the proof
     */
    error InvalidNodeArrayLength(uint256 expected, uint256 actual);

    /**
     * @notice Error when the hasPreHash flag and preHash value are inconsistent
     * @dev This error occurs when hasPreHash=true but preHash=0, which is a suspicious configuration.
     *      Using a zero preHash with hasPreHash=true negates the gas benefits of the
     *      hasPreHash optimization and may indicate an error in proof construction.
     */
    error InconsistentPreHashFlag(bool hasPreHash, bytes32 preHashValue);
}
