// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title TreeNodeLib
 * @notice Generic library for EIP-712 tree node hash reconstruction
 * @dev Provides parameterized tree reconstruction algorithm for any EIP-712 nested structure
 *      following the pattern: struct Node { Node[] nodes; LeafType[] leaves; }
 *
 * This library generalizes the tree reconstruction pattern used in both PermitNode and NonceNode,
 * eliminating code duplication while maintaining full EIP-712 compatibility.
 *
 * Key Concepts:
 * - Parameterized typehash: Caller provides EIP-712 typehash for their specific struct
 * - Three combination rules: Leaf+Leaf (sort), Node+Node (sort), Node+Leaf (struct order)
 * - Compact encoding: Position index + type flags for efficient on-chain reconstruction
 * - Gas efficient: O(log n) proof size, linear scaling with proof length
 *
 * Algorithm Overview:
 * The reconstruction algorithm combines a starting leaf with proof elements iteratively,
 * using type flags to determine which combination rule to apply. Each combination produces
 * a valid EIP-712 hash that matches the off-chain tree structure.
 *
 * Usage Example:
 * ```solidity
 * // In PermitNode context:
 * bytes32 hash = TreeNodeLib.computeTreeHash(
 *     PERMIT_NODE_TYPEHASH,
 *     proofStructure,
 *     proof,
 *     currentChainHash
 * );
 *
 * // In NonceNode context:
 * bytes32 hash = TreeNodeLib.computeTreeHash(
 *     NONCE_NODE_TYPEHASH,
 *     proofStructure,
 *     proof,
 *     currentNonce
 * );
 * ```
 */
library TreeNodeLib {
    /**
     * @dev Hash of an empty array in EIP-712 encoding: keccak256(abi.encodePacked())
     * Used when a node has an empty nodes[] or leaves[] array
     */
    bytes32 internal constant EMPTY_ARRAY_HASH = keccak256("");

    /**
     * @notice Reconstruct the EIP-712 hash of a tree structure from proof and tree structure encoding
     * @dev This is the core function that enables compact on-chain verification of tree-based structures.
     *      It reconstructs the full tree hash from a compact proof, avoiding the need to pass the
     *      entire tree structure on-chain.
     *
     * @dev ProofStructure Encoding Format (bytes32):
     *      - Byte 0 (bits 255-248): Position index (reserved for future use, currently unused)
     *      - Bytes 1-31 (bits 247-0): Type flags (packed bits, 1 bit per proof element)
     *          - 0 = proof[i] is a Leaf (e.g., ChainPermits or bytes32 nonce)
     *          - 1 = proof[i] is a Node (e.g., PermitNode or NonceNode)
     *
     * @dev Algorithm (Merkle-like path reconstruction):
     *      1. Start with currentLeaf (always a Leaf type initially)
     *      2. For each proof[i], extract type flag from proofStructure:
     *         - Bit i (at position 255-8-i) indicates if proof[i] is Node (1) or Leaf (0)
     *      3. Combine current with proof[i] based on types:
     *         - Leaf + Leaf: Sort alphabetically, use combineLeafAndLeaf()
     *         - Node + Node: Sort alphabetically, use combineNodeAndNode()
     *         - Node + Leaf: Struct order (no sort), use combineNodeAndLeaf()
     *      4. After first combine, current becomes a Node (important for subsequent combines)
     *      5. Continue until all proof elements are processed
     *      6. Return final hash (should match the hash user signed)
     *
     * @dev Security validations:
     *      - Proof length must not exceed 247 elements (max tree depth)
     *      - Unused type flag bits must be zero (prevents encoding ambiguity)
     *      - Each combination follows deterministic rules (ensures uniqueness)
     *
     * @dev Security: User signs complete tree off-chain, contract reconstructs from compact proof.
     *      Matching hash validates proof correctness. Any modification invalidates signature.
     *
     * @param typehash EIP-712 typehash for the specific struct (e.g., PERMIT_NODE_TYPEHASH or NONCE_NODE_TYPEHASH)
     * @param proofStructure Compact encoding (position + type flags)
     * @param proof Array of sibling hashes along the merkle path
     * @param currentLeaf Hash of current leaf element (computed on-chain, e.g., ChainPermits hash or nonce)
     * @return bytes32 The reconstructed tree root hash (EIP-712 style)
     *
     * @dev Example: For 2 leaves with currentLeaf=H(Leaf1), proof[0]=H(Leaf2), typeFlag=0:
     *      Result = combineLeafAndLeaf(typehash, H(Leaf1), H(Leaf2))
     *             = H(Node(nodes=[], leaves=[sorted(Leaf1, Leaf2)]))
     *
     * @dev Uses combineLeafAndLeaf(), combineNodeAndNode(), and combineNodeAndLeaf() internally
     */
    function computeTreeHash(
        bytes32 typehash,
        bytes32 proofStructure,
        bytes32[] calldata proof,
        bytes32 currentLeaf
    ) internal pure returns (bytes32) {
        // Validate proof length does not exceed maximum tree depth
        // Maximum depth is 247 (256 bits - 8 bits for position index - 1 for current element)
        require(proof.length <= 247, "Proof exceeds maximum depth");

        // Validate that unused type flag bits are zero
        // Type flags occupy bits 247 down to (247 - proof.length + 1)
        // This validates that bits (247 - proof.length) down to 0 are all zero
        if (proof.length < 247) {
            uint256 mask = type(uint256).max << (256 - 8 - proof.length);
            uint256 flagBits = uint256(proofStructure) & ~mask;
            uint256 unusedMask = type(uint256).max >> (8 + proof.length);
            require((flagBits & unusedMask) == 0, "Unused type flags must be zero");
        }

        // Position index (byte 0, bits 255-248) is reserved for future use
        // Currently ignored - any value is accepted but not validated
        // Future versions may enforce position validation to ensure currentLeaf
        // appears at the expected index in the flattened tree structure
        // uint8 position = uint8(uint256(proofStructure) >> 248);

        bytes32 currentHash = currentLeaf;
        bool currentIsNode = false; // Starts as Leaf (ChainPermits, nonce, etc.)

        // Process each proof element, combining with current hash
        for (uint256 i = 0; i < proof.length; i++) {
            // Extract type flag for proof[i] from bit position (247 - i)
            // Bits numbered 255 (MSB) down to 0 (LSB), bits 255-248 reserved for position
            // Example: proof[0] uses bit 247, proof[1] uses bit 246, etc.
            bool proofIsNode = (uint256(proofStructure) >> (255 - 8 - i)) & 1 == 1;

            // Combine based on types
            if (!currentIsNode && !proofIsNode) {
                currentHash = combineLeafAndLeaf(typehash, currentHash, proof[i]);
            } else if (currentIsNode && proofIsNode) {
                currentHash = combineNodeAndNode(typehash, currentHash, proof[i]);
            } else {
                if (currentIsNode) {
                    currentHash = combineNodeAndLeaf(typehash, currentHash, proof[i]);
                } else {
                    currentHash = combineNodeAndLeaf(typehash, proof[i], currentHash);
                }
            }

            // After first combine, result is always a Node
            currentIsNode = true;
        }

        return currentHash;
    }

    /**
     * @notice Combine two leaf hashes into a parent node hash
     * @dev Used when both siblings are leaf elements (e.g., ChainPermits, nonces)
     * @dev Hashes are sorted alphabetically for deterministic tree construction
     * @dev Result: Node(nodes=[], leaves=[sorted hashes])
     *
     * @param typehash EIP-712 typehash for the specific struct (e.g., PERMIT_NODE_TYPEHASH or NONCE_NODE_TYPEHASH)
     * @param leaf1 First leaf hash
     * @param leaf2 Second leaf hash
     * @return bytes32 EIP-712 hash of Node containing both leaves
     */
    function combineLeafAndLeaf(
        bytes32 typehash,
        bytes32 leaf1,
        bytes32 leaf2
    ) internal pure returns (bytes32) {
        bytes32 first = leaf1 < leaf2 ? leaf1 : leaf2;
        bytes32 second = leaf1 < leaf2 ? leaf2 : leaf1;

        // Create Node(nodes=[], leaves=[first, second])
        bytes32 leavesArrayHash = keccak256(abi.encodePacked(first, second));

        return
            keccak256(
                abi.encode(
                    typehash,
                    EMPTY_ARRAY_HASH, // nodes = []
                    leavesArrayHash // leaves = [first, second]
                )
            );
    }

    /**
     * @notice Combine two node hashes into a parent node hash
     * @dev Used when both siblings are nested node structures
     * @dev Hashes are sorted alphabetically for deterministic tree construction
     * @dev Result: Node(nodes=[sorted hashes], leaves=[])
     *
     * @param typehash EIP-712 typehash for the specific struct (e.g., PERMIT_NODE_TYPEHASH or NONCE_NODE_TYPEHASH)
     * @param node1 First Node hash
     * @param node2 Second Node hash
     * @return bytes32 EIP-712 hash of parent Node containing both child nodes
     */
    function combineNodeAndNode(
        bytes32 typehash,
        bytes32 node1,
        bytes32 node2
    ) internal pure returns (bytes32) {
        bytes32 first = node1 < node2 ? node1 : node2;
        bytes32 second = node1 < node2 ? node2 : node1;

        // Create Node(nodes=[first, second], leaves=[])
        bytes32 nodesArrayHash = keccak256(abi.encodePacked(first, second));

        return
            keccak256(
                abi.encode(
                    typehash,
                    nodesArrayHash, // nodes = [first, second]
                    EMPTY_ARRAY_HASH // leaves = []
                )
            );
    }

    /**
     * @notice Combine a node hash and a leaf hash (mixed types)
     * @dev Used when one sibling is a node and the other is a leaf element
     * @dev IMPORTANT: Unlike other combinations, hashes are NOT sorted
     * @dev Order follows EIP-712 struct definition: nodes before leaves
     * @dev Result: Node(nodes=[nodeHash], leaves=[leafHash])
     *
     * @param typehash EIP-712 typehash for the specific struct (e.g., PERMIT_NODE_TYPEHASH or NONCE_NODE_TYPEHASH)
     * @param nodeHash The Node hash (always first per struct definition)
     * @param leafHash The leaf hash (always second per struct definition)
     * @return bytes32 EIP-712 hash of Node with mixed children
     */
    function combineNodeAndLeaf(
        bytes32 typehash,
        bytes32 nodeHash,
        bytes32 leafHash
    ) internal pure returns (bytes32) {
        bytes32 nodesArrayHash = keccak256(abi.encodePacked(nodeHash));
        bytes32 leavesArrayHash = keccak256(abi.encodePacked(leafHash));

        return keccak256(
            abi.encode(
                typehash,
                nodesArrayHash, // nodes = [nodeHash]
                leavesArrayHash // leaves = [leafHash]
            )
        );
    }
}
