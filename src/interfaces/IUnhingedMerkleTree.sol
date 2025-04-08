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
     * @param nodes Array of all proof nodes in sequence: [preHash (if present), subtreeProof nodes...,
     * followingHashes...]
     * @param counts Packed bytes32 that contains all auxiliary data:
     *        - First 120 bits: Number of nodes in subtreeProof
     *        - Next 120 bits: Number of nodes in followingHashes
     *        - Next 15 bits: Reserved for future use
     *        - Last bit: Flag indicating if preHash is present (1) or not (0)
     * @dev When hasPreHash=false (last bit=0), the preHash is completely omitted from the
     *      nodes array rather than included as a zero value. This optimization significantly improves
     *      gas efficiency by reducing calldata size and simplifying verification logic.
     */
    struct UnhingedProof {
        bytes32[] nodes;
        bytes32 counts;
    }

    /**
     * @notice Helper function to extract counts from packed bytes32
     * @param counts The packed counts value
     * @return subtreeProofCount Number of nodes in the subtree proof
     * @return followingHashesCount Number of nodes in the following hashes
     * @return hasPreHash Flag indicating if preHash is present (true) or not (false)
     */
    function extractCounts(
        bytes32 counts
    ) external pure returns (uint120 subtreeProofCount, uint120 followingHashesCount, bool hasPreHash);

    /**
     * @notice Helper function to pack counts into a single bytes32
     * @param subtreeProofCount Number of nodes in the subtree proof
     * @param followingHashesCount Number of nodes in the following hashes
     * @param hasPreHash Flag indicating if preHash is present or not
     * @return counts The packed counts value
     */
    function packCounts(
        uint120 subtreeProofCount,
        uint120 followingHashesCount,
        bool hasPreHash
    ) external pure returns (bytes32 counts);

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

    /**
     * @notice Verifies a leaf is part of an unhinged merkle tree
     * @param leaf The leaf node data to verify
     * @param proof The proof containing all necessary verification components
     * @param unhingedRoot The root of the entire unhinged merkle tree
     * @return bool True if the proof is valid, false otherwise
     */
    function verify(bytes32 leaf, UnhingedProof calldata proof, bytes32 unhingedRoot) external pure returns (bool);

    /**
     * @notice Verifies a leaf is part of a balanced merkle subtree
     * @param leaf The leaf node data to verify
     * @param proof The array of sibling hashes needed for verification
     * @return bytes32 The calculated root of the balanced subtree
     */
    function verifyBalancedSubtree(bytes32 leaf, bytes32[] calldata proof) external pure returns (bytes32);

    /**
     * @notice Creates an unhinged root from a list of balanced subtree roots
     * @param subtreeRoots Array of balanced subtree roots in sequential order
     * @return bytes32 The calculated unhinged root
     */
    function createUnhingedRoot(
        bytes32[] calldata subtreeRoots
    ) external pure returns (bytes32);

    /**
     * @notice Combines two hashes to form a single hash in the unhinged chain
     * @param previousHash The hash of previous operations
     * @param currentHash The hash to append
     * @return bytes32 The combined hash
     */
    function hashLink(bytes32 previousHash, bytes32 currentHash) external pure returns (bytes32);

    /**
     * @notice Helper function to create an optimized proof from component parts
     * @param preHash Previous hashes combined (can be zero to indicate no preHash)
     * @param subtreeProof The balanced merkle proof
     * @param followingHashes The array of following hashes
     * @return The compact proof structure
     */
    function createOptimizedProof(
        bytes32 preHash,
        bytes32[] calldata subtreeProof,
        bytes32[] calldata followingHashes
    ) external pure returns (UnhingedProof memory);
}
