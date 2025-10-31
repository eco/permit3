const { ethers } = require('ethers');

/**
 * @typedef {Object} AllowanceOrTransfer
 * @property {number} modeOrExpiration - Mode (for allowances) or expiration timestamp (for transfers)
 * @property {string} tokenKey - bytes32 hex string representing the token
 * @property {string} account - address hex string of the account
 * @property {number} amountDelta - Amount to change (positive or negative)
 */

/**
 * @typedef {Object} ChainPermits
 * @property {number} chainId - Chain ID for these permits
 * @property {AllowanceOrTransfer[]} permits - Array of permit operations for this chain
 */

/**
 * @typedef {Object} PermitNode
 * @property {PermitNode[]} nodes - Child nodes (nested structures)
 * @property {ChainPermits[]} permits - Leaf chain permits
 */

/**
 * @typedef {Object} TreeStructureEncoding
 * @property {string} proofStructure - bytes32 encoded structure with position and type flags
 * @property {string[]} proof - Array of bytes32 hashes forming the Merkle path
 * @property {ChainPermits} currentChainPermits - The ChainPermits for the target chain
 */

/**
 * @typedef {Object} MerklePathInfo
 * @property {string[]} proof - Array of sibling hashes along the path to root
 * @property {number[]} typeFlags - Array indicating whether each proof element is a Node (1) or Permit (0)
 * @property {ChainPermits} chainPermits - The target chain's ChainPermits structure
 * @property {number} position - Position index of the target chain in the flattened structure
 */

/**
 * @typedef {Object} NonceNode
 * @property {NonceNode[]} nodes - Child nonce node structures
 * @property {string[]} nonces - Array of bytes32 nonce values
 */

/**
 * @typedef {Object} NonceTreeEncoding
 * @property {string} proofStructure - bytes32 encoded structure
 * @property {string[]} proof - Array of bytes32 hashes
 * @property {string[]} currentNonces - Nonces for current operation
 */

/**
 * @typedef {Object} NonceMerklePathInfo
 * @property {string[]} proof - Array of sibling hashes along the path to root
 * @property {number[]} typeFlags - Array indicating whether each proof element is a Node (1) or Nonce (0)
 * @property {string[]} nonces - The target nonces
 * @property {number} position - Position index of the target nonces in the flattened structure
 */

/**
 * Hash a ChainPermits structure using EIP-712
 * @param {ChainPermits} chainPermits - The ChainPermits structure
 * @returns {string} The EIP-712 hash of the ChainPermits
 */
function hashChainPermits(chainPermits) {
    const CHAIN_PERMITS_TYPEHASH = ethers.utils.keccak256(
        ethers.utils.toUtf8Bytes("ChainPermits(uint64 chainId,AllowanceOrTransfer[] permits)AllowanceOrTransfer(uint48 modeOrExpiration,bytes32 tokenKey,address account,uint160 amountDelta)")
    );

    // Hash each permit in the AllowanceOrTransfer array
    const permitHashes = chainPermits.permits.map(permit =>
        ethers.utils.keccak256(
            ethers.utils.defaultAbiCoder.encode(
                ['uint48', 'bytes32', 'address', 'uint160'],
                [permit.modeOrExpiration, permit.tokenKey, permit.account, permit.amountDelta]
            )
        )
    );

    const permitsArrayHash = ethers.utils.keccak256(ethers.utils.concat(permitHashes));

    return ethers.utils.keccak256(
        ethers.utils.defaultAbiCoder.encode(
            ['bytes32', 'uint64', 'bytes32'],
            [CHAIN_PERMITS_TYPEHASH, chainPermits.chainId, permitsArrayHash]
        )
    );
}

/**
 * Hash a PermitNode structure using EIP-712
 * @param {PermitNode} permitNode - The PermitNode structure
 * @returns {string} The EIP-712 hash of the PermitNode
 *
 * @example
 * const permitNode = {
 *   nodes: [],
 *   permits: [
 *     {
 *       chainId: 1,
 *       permits: [
 *         {
 *           modeOrExpiration: 1000,
 *           tokenKey: '0x...',
 *           account: '0x...',
 *           amountDelta: 100
 *         }
 *       ]
 *     }
 *   ]
 * };
 * const hash = hashPermitNode(permitNode);
 */
function hashPermitNode(permitNode) {
    // PERMIT_NODE_TYPEHASH must include all nested type definitions
    // This matches the Solidity implementation in PermitNodeLib.sol
    const PERMIT_NODE_TYPEHASH = ethers.utils.keccak256(
        ethers.utils.toUtf8Bytes("PermitNode(PermitNode[] nodes,ChainPermits[] permits)AllowanceOrTransfer(uint48 modeOrExpiration,bytes32 tokenKey,address account,uint160 amountDelta)ChainPermits(uint64 chainId,AllowanceOrTransfer[] permits)")
    );

    // Hash child nodes recursively
    const nodeHashes = permitNode.nodes.map(node => hashPermitNode(node));
    const nodesArrayHash = nodeHashes.length > 0
        ? ethers.utils.keccak256(ethers.utils.concat(nodeHashes))
        : ethers.utils.keccak256('0x'); // Empty array hash

    // Hash permits (using hashChainPermits for each)
    const permitHashes = permitNode.permits.map(chainPermits => hashChainPermits(chainPermits));
    const permitsArrayHash = permitHashes.length > 0
        ? ethers.utils.keccak256(ethers.utils.concat(permitHashes))
        : ethers.utils.keccak256('0x'); // Empty array hash

    // Encode and hash the PermitNode struct
    return ethers.utils.keccak256(
        ethers.utils.defaultAbiCoder.encode(
            ['bytes32', 'bytes32', 'bytes32'],
            [PERMIT_NODE_TYPEHASH, nodesArrayHash, permitsArrayHash]
        )
    );
}

/**
 * Find the Merkle path from a target chain's ChainPermits leaf to the root
 *
 * This function implements the core algorithm for building proofs that work with
 * the on-chain _reconstructPermitNodeHash() function in PermitNodeLib.sol.
 *
 * ALGORITHM:
 * 1. Recursively search the tree for the target chainId
 * 2. When found, build the path from leaf to root
 * 3. At each level, identify the sibling that will be combined during reconstruction
 * 4. Track whether each sibling is a Node or Permit (type flag)
 * 5. Return the complete path information
 *
 * IMPORTANT: This function must handle the tree structure correctly:
 * - PermitNode has two arrays: nodes[] and permits[]
 * - During reconstruction, siblings are combined based on their types:
 *   - Permit+Permit: alphabetically sorted
 *   - Node+Node: alphabetically sorted
 *   - Node+Permit: struct order (nodes first, no sorting)
 *
 * @param {PermitNode} permitNode - The PermitNode structure to search
 * @param {number} targetChainId - The chain ID to find
 * @param {number} depth - Current recursion depth (internal use)
 * @returns {MerklePathInfo|null} Path info or null if chain not found
 */
function findMerklePathToRoot(permitNode, targetChainId, depth = 0) {
    // First, check if the target chain is directly in this node's permits
    for (let i = 0; i < permitNode.permits.length; i++) {
        if (permitNode.permits[i].chainId === targetChainId) {
            // Found the target! Now build the proof path
            const proof = [];
            const typeFlags = [];

            // Check if there are nodes at this level (mixed Node+Permit case)
            if (permitNode.nodes.length > 0 && permitNode.permits.length === 1) {
                // Node+Permit combination: sibling is the node
                proof.push(hashPermitNode(permitNode.nodes[0]));
                typeFlags.push(1); // Sibling is a Node
            } else if (permitNode.permits.length === 2 && permitNode.nodes.length === 0) {
                // Permit+Permit combination: sibling is the other permit
                const siblingIndex = i === 0 ? 1 : 0;
                proof.push(hashChainPermits(permitNode.permits[siblingIndex]));
                typeFlags.push(0); // Sibling is a Permit
            } else if (permitNode.permits.length > 2 || (permitNode.permits.length > 1 && permitNode.nodes.length > 0)) {
                // Complex case: multiple permits or mixed with too many children
                throw new Error('PermitNode with more than 2 children (nodes + permits) is not yet supported. Please restructure as a binary tree.');
            }
            // else: single permit, no nodes -> empty proof (handled below)

            return {
                proof,
                typeFlags,
                chainPermits: permitNode.permits[i],
                position: i
            };
        }
    }

    // Not found in direct permits, search in child nodes
    for (let i = 0; i < permitNode.nodes.length; i++) {
        const childResult = findMerklePathToRoot(permitNode.nodes[i], targetChainId, depth + 1);

        if (childResult) {
            // Found in this child! Now add the sibling to the proof
            const proof = [...childResult.proof];
            const typeFlags = [...childResult.typeFlags];

            // Determine the sibling
            if (permitNode.nodes.length === 2 && permitNode.permits.length === 0) {
                // Two nodes, no permits - Node+Node combination
                const siblingIndex = i === 0 ? 1 : 0;
                proof.push(hashPermitNode(permitNode.nodes[siblingIndex]));
                typeFlags.push(1); // Sibling is a Node
            } else if (permitNode.nodes.length === 1 && permitNode.permits.length === 1) {
                // One node, one permit - Node+Permit combination (struct order)
                // The sibling is the permit
                proof.push(hashChainPermits(permitNode.permits[0]));
                typeFlags.push(0); // Sibling is a Permit
            } else if (permitNode.nodes.length > 2 || permitNode.permits.length > 2) {
                throw new Error('PermitNode with more than 2 children (nodes + permits) is not yet supported. Please restructure as a binary tree.');
            }

            return {
                proof,
                typeFlags,
                chainPermits: childResult.chainPermits,
                position: childResult.position
            };
        }
    }

    // Also check if target is in permits when there are nodes present
    // This handles the case where we have both nodes and permits at the same level
    if (permitNode.nodes.length > 0 && permitNode.permits.length > 0) {
        for (let i = 0; i < permitNode.permits.length; i++) {
            if (permitNode.permits[i].chainId === targetChainId) {
                // Found it! The sibling is the node
                const proof = [hashPermitNode(permitNode.nodes[0])];
                const typeFlags = [1]; // Sibling is a Node

                return {
                    proof,
                    typeFlags,
                    chainPermits: permitNode.permits[i],
                    position: i
                };
            }
        }
    }

    // Not found in this subtree
    return null;
}

/**
 * Encode tree structure into bytes32 format for on-chain reconstruction
 *
 * This function generates the compact proof encoding that the Solidity
 * _reconstructPermitNodeHash() function expects.
 *
 * ENCODING FORMAT (bytes32):
 * - Byte 0 (bits 255-248): Position index (where current chain appears)
 * - Bytes 1-31 (bits 247-0): Type flags (1 bit per proof element)
 *   - Bit i: 0 = proof[i] is a Permit (ChainPermits leaf)
 *   - Bit i: 1 = proof[i] is a Node (PermitNode)
 *
 * RECONSTRUCTION PROCESS:
 * The on-chain code starts with currentChainHash and iterates through
 * the proof array, combining hashes based on type flags:
 * - Permit+Permit: Use _combinePermitAndPermit() with alphabetical sort
 * - Node+Node: Use _combineNodeAndNode() with alphabetical sort
 * - Node+Permit: Use _combineNodeAndPermit() with struct order (no sort)
 *
 * @param {PermitNode} permitNode - The PermitNode structure
 * @param {number} currentChainId - The chain ID we're executing on
 * @returns {TreeStructureEncoding} Object containing proofStructure, proof, and currentChainPermits
 *
 * @example
 * const result = encodeProofStructure(permitNode, 1);
 * // result.proofStructure: '0x...' - bytes32 with position and type flags
 * // result.proof: ['0x...', '0x...'] - proof array
 * // result.currentChainPermits: { chainId: 1, permits: [...] }
 */
function encodeProofStructure(permitNode, currentChainId) {
    // Use the new algorithm to find the Merkle path
    const pathInfo = findMerklePathToRoot(permitNode, currentChainId);

    if (!pathInfo) {
        throw new Error(`Chain ID ${currentChainId} not found in PermitNode`);
    }

    // Extract components from path
    const proof = pathInfo.proof;
    const typeFlags = pathInfo.typeFlags;
    const currentChainPermits = pathInfo.chainPermits;
    const position = pathInfo.position;

    // Encode proofStructure as bytes32
    // Byte 0: position index (where current chain appears in ordering)
    // Bytes 1-31: type flags packed as bits
    let proofStructureValue = BigInt(position) << 248n; // Position in byte 0

    // Pack type flags starting from bit 247 down
    // Bit position: 255 - 8 - i = 247 - i
    for (let i = 0; i < typeFlags.length; i++) {
        if (typeFlags[i] === 1) {
            const bitPosition = 255n - 8n - BigInt(i);
            proofStructureValue |= (1n << bitPosition);
        }
    }

    const proofStructure = '0x' + proofStructureValue.toString(16).padStart(64, '0');

    return {
        proofStructure,
        proof,
        currentChainPermits
    };
}

/**
 * Build proof array for a specific chain without full encoding
 * This is a convenience function that extracts just the proof for a given chain.
 *
 * @param {PermitNode} permitNode - The PermitNode structure
 * @param {number} currentChainId - The chain ID to build proof for
 * @returns {Array<string>} Array of bytes32 hashes for the proof
 *
 * @example
 * const proof = buildProofForChain(permitNode, 1);
 * // proof: ['0x...', '0x...'] - hashes of sibling nodes/permits
 */
function buildProofForChain(permitNode, currentChainId) {
    const { proof } = encodeProofStructure(permitNode, currentChainId);
    return proof;
}

/**
 * Build an optimal balanced PermitNode tree from chain permits
 *
 * This function creates a balanced binary tree structure from an array
 * of ChainPermits, which is optimal for proof sizes and reconstruction gas costs.
 *
 * ALGORITHM:
 * 1. Sort chainPermits by hash for deterministic structure
 * 2. Recursively split into left and right halves
 * 3. Build balanced tree bottom-up
 *
 * @param {ChainPermits[]} chainPermitsArray - Array of ChainPermits
 * @returns {PermitNode} Optimally structured tree
 *
 * @example
 * const chainPermits = [
 *   { chainId: 1, permits: [...] },
 *   { chainId: 42161, permits: [...] },
 *   { chainId: 10, permits: [...] }
 * ];
 * const tree = buildOptimalPermitTree(chainPermits);
 */
function buildOptimalPermitTree(chainPermitsArray) {
    if (chainPermitsArray.length === 0) {
        return { nodes: [], permits: [] };
    }

    if (chainPermitsArray.length === 1) {
        return { nodes: [], permits: [chainPermitsArray[0]] };
    }

    if (chainPermitsArray.length === 2) {
        // Two permits - create simple flat structure
        // Sort by hash for deterministic ordering
        const hashes = chainPermitsArray.map((cp, idx) => ({
            hash: hashChainPermits(cp),
            permits: cp,
            idx
        }));
        hashes.sort((a, b) => a.hash < b.hash ? -1 : 1);

        return {
            nodes: [],
            permits: [hashes[0].permits, hashes[1].permits]
        };
    }

    // For more than 2 permits, build a balanced binary tree
    // Split into two halves
    const mid = Math.floor(chainPermitsArray.length / 2);
    const leftPermits = chainPermitsArray.slice(0, mid);
    const rightPermits = chainPermitsArray.slice(mid);

    // Recursively build left and right subtrees
    const leftNode = buildOptimalPermitTree(leftPermits);
    const rightNode = buildOptimalPermitTree(rightPermits);

    // Combine into parent node
    // Sort child nodes by hash for deterministic ordering
    const leftHash = hashPermitNode(leftNode);
    const rightHash = hashPermitNode(rightNode);

    const nodes = leftHash < rightHash ? [leftNode, rightNode] : [rightNode, leftNode];

    return {
        nodes,
        permits: []
    };
}

/**
 * Validate that a PermitNode tree is correctly structured
 *
 * This function checks that the tree follows the required constraints:
 * - No more than 2 children at any level (binary tree)
 * - No duplicate chain IDs
 * - All child nodes are valid
 *
 * @param {PermitNode} permitNode - The tree to validate
 * @returns {Object} { valid: boolean, errors: string[] }
 *
 * @example
 * const result = validateProofStructure(permitNode);
 * if (!result.valid) {
 *   console.error('Tree validation failed:', result.errors);
 * }
 */
function validateProofStructure(permitNode) {
    const errors = [];
    const seenChainIds = new Set();

    function validateNode(node, path = 'root') {
        // Check binary tree constraint
        const totalChildren = node.nodes.length + node.permits.length;
        if (totalChildren > 2) {
            errors.push(`${path}: Node has ${totalChildren} children (max 2 allowed for binary tree)`);
        }

        // Check for duplicate chain IDs in permits
        for (let i = 0; i < node.permits.length; i++) {
            const chainId = node.permits[i].chainId;
            if (seenChainIds.has(chainId)) {
                errors.push(`${path}: Duplicate chain ID ${chainId}`);
            }
            seenChainIds.add(chainId);
        }

        // Recursively validate child nodes
        for (let i = 0; i < node.nodes.length; i++) {
            validateNode(node.nodes[i], `${path}.nodes[${i}]`);
        }
    }

    validateNode(permitNode);

    return {
        valid: errors.length === 0,
        errors
    };
}

/**
 * Create a visual representation of the tree structure
 *
 * This function generates a human-readable tree diagram showing:
 * - Tree structure with indentation
 * - Node types (PermitNode vs ChainPermits)
 * - Chain IDs for leaf permits
 * - Hashes (truncated) for each element
 *
 * @param {PermitNode} permitNode - The tree to visualize
 * @param {number} indent - Current indentation level (internal use)
 * @returns {string} Tree visualization
 *
 * @example
 * const tree = buildOptimalPermitTree(chainPermits);
 * console.log(visualizeTree(tree));
 * // Output:
 * // PermitNode (hash: 0x1234...)
 * //   ├─ PermitNode (hash: 0x5678...)
 * //   │  ├─ ChainPermits (chainId: 1, hash: 0xabcd...)
 * //   │  └─ ChainPermits (chainId: 42161, hash: 0xef01...)
 * //   └─ ChainPermits (chainId: 10, hash: 0x2345...)
 */
function visualizeTree(permitNode, indent = 0) {
    const prefix = '  '.repeat(indent);
    const hash = hashPermitNode(permitNode).slice(0, 10) + '...';
    let output = `${prefix}PermitNode (hash: ${hash})\n`;

    // Show child nodes
    for (let i = 0; i < permitNode.nodes.length; i++) {
        const isLast = i === permitNode.nodes.length - 1 && permitNode.permits.length === 0;
        const connector = isLast ? '└─ ' : '├─ ';
        output += `${prefix}${connector}`;
        output += visualizeTree(permitNode.nodes[i], indent + 1).trimStart();
    }

    // Show permits
    for (let i = 0; i < permitNode.permits.length; i++) {
        const isLast = i === permitNode.permits.length - 1;
        const connector = isLast ? '└─ ' : '├─ ';
        const permit = permitNode.permits[i];
        const permitHash = hashChainPermits(permit).slice(0, 10) + '...';
        output += `${prefix}${connector}ChainPermits (chainId: ${permit.chainId}, hash: ${permitHash})\n`;
    }

    return output;
}

/**
 * Verify that off-chain encoding matches on-chain reconstruction
 *
 * This function simulates the on-chain _reconstructPermitNodeHash() algorithm
 * to verify that the generated proof correctly reconstructs to the expected root.
 *
 * VERIFICATION ALGORITHM:
 * 1. Start with currentChainHash (the target leaf)
 * 2. Iterate through proof array, combining based on type flags
 * 3. Simulate the three combination functions:
 *    - _combinePermitAndPermit(): alphabetical sort
 *    - _combineNodeAndNode(): alphabetical sort
 *    - _combineNodeAndPermit(): struct order (no sort)
 * 4. Compare final hash with expected root from hashPermitNode()
 *
 * @param {PermitNode} permitNode - The full tree structure
 * @param {number} chainId - The chain ID to verify
 * @param {TreeStructureEncoding} encoding - The encoding to verify
 * @returns {boolean} True if encoding correctly reconstructs to root
 *
 * @example
 * const encoding = encodeProofStructure(permitNode, 1);
 * const isValid = verifyTreeEncoding(permitNode, 1, encoding);
 * if (!isValid) {
 *   console.error('Encoding verification failed!');
 * }
 */
function verifyTreeEncoding(permitNode, chainId, encoding) {
    const PERMIT_NODE_TYPEHASH = ethers.utils.keccak256(
        ethers.utils.toUtf8Bytes("PermitNode(PermitNode[] nodes,ChainPermits[] permits)AllowanceOrTransfer(uint48 modeOrExpiration,bytes32 tokenKey,address account,uint160 amountDelta)ChainPermits(uint64 chainId,AllowanceOrTransfer[] permits)")
    );
    const EMPTY_ARRAY_HASH = ethers.utils.keccak256('0x');

    // Helper functions that match Solidity combination logic
    function combinePermitAndPermit(permit1, permit2) {
        // Alphabetical sort
        const first = permit1 < permit2 ? permit1 : permit2;
        const second = permit1 < permit2 ? permit2 : permit1;

        const permitsArrayHash = ethers.utils.keccak256(ethers.utils.concat([first, second]));

        return ethers.utils.keccak256(
            ethers.utils.defaultAbiCoder.encode(
                ['bytes32', 'bytes32', 'bytes32'],
                [PERMIT_NODE_TYPEHASH, EMPTY_ARRAY_HASH, permitsArrayHash]
            )
        );
    }

    function combineNodeAndNode(node1, node2) {
        // Alphabetical sort
        const first = node1 < node2 ? node1 : node2;
        const second = node1 < node2 ? node2 : node1;

        const nodesArrayHash = ethers.utils.keccak256(ethers.utils.concat([first, second]));

        return ethers.utils.keccak256(
            ethers.utils.defaultAbiCoder.encode(
                ['bytes32', 'bytes32', 'bytes32'],
                [PERMIT_NODE_TYPEHASH, nodesArrayHash, EMPTY_ARRAY_HASH]
            )
        );
    }

    function combineNodeAndPermit(nodeHash, permitHash) {
        // No sorting - struct order (node first)
        const nodesArrayHash = ethers.utils.keccak256(ethers.utils.solidityPack(['bytes32'], [nodeHash]));
        const permitsArrayHash = ethers.utils.keccak256(ethers.utils.solidityPack(['bytes32'], [permitHash]));

        return ethers.utils.keccak256(
            ethers.utils.defaultAbiCoder.encode(
                ['bytes32', 'bytes32', 'bytes32'],
                [PERMIT_NODE_TYPEHASH, nodesArrayHash, permitsArrayHash]
            )
        );
    }

    // Reconstruct the hash using the proof
    let currentHash = hashChainPermits(encoding.currentChainPermits);
    let currentIsNode = false;

    // Handle edge case: single chain with no proof
    if (encoding.proof.length === 0) {
        // For a single chain, the permitNode should be { nodes: [], permits: [singleChain] }
        // So the hash is just the permitNode hash containing that single chain
        const expectedRoot = hashPermitNode(permitNode);

        // The current hash is the ChainPermits hash, but we need to wrap it in a PermitNode
        // Create a PermitNode with single permit
        const PERMIT_NODE_TYPEHASH = ethers.utils.keccak256(
            ethers.utils.toUtf8Bytes("PermitNode(PermitNode[] nodes,ChainPermits[] permits)AllowanceOrTransfer(uint48 modeOrExpiration,bytes32 tokenKey,address account,uint160 amountDelta)ChainPermits(uint64 chainId,AllowanceOrTransfer[] permits)")
        );
        const EMPTY_ARRAY_HASH = ethers.utils.keccak256('0x');
        const permitsArrayHash = ethers.utils.keccak256(ethers.utils.solidityPack(['bytes32'], [currentHash]));

        currentHash = ethers.utils.keccak256(
            ethers.utils.defaultAbiCoder.encode(
                ['bytes32', 'bytes32', 'bytes32'],
                [PERMIT_NODE_TYPEHASH, EMPTY_ARRAY_HASH, permitsArrayHash]
            )
        );

        return currentHash === expectedRoot;
    }

    // Extract type flags from proofStructure
    const proofStructureValue = BigInt(encoding.proofStructure);

    for (let i = 0; i < encoding.proof.length; i++) {
        // Extract type flag for proof[i]
        const bitPosition = 255n - 8n - BigInt(i);
        const proofIsNode = ((proofStructureValue >> bitPosition) & 1n) === 1n;

        // Combine based on types
        if (!currentIsNode && !proofIsNode) {
            // Both are Permits
            currentHash = combinePermitAndPermit(currentHash, encoding.proof[i]);
        } else if (currentIsNode && proofIsNode) {
            // Both are Nodes
            currentHash = combineNodeAndNode(currentHash, encoding.proof[i]);
        } else {
            // Mixed: one Node, one Permit
            if (currentIsNode) {
                // current is Node, proof[i] is Permit
                currentHash = combineNodeAndPermit(currentHash, encoding.proof[i]);
            } else {
                // current is Permit, proof[i] is Node
                currentHash = combineNodeAndPermit(encoding.proof[i], currentHash);
            }
        }

        // After first combine, result is always a Node
        currentIsNode = true;
    }

    // Compare with expected root
    const expectedRoot = hashPermitNode(permitNode);

    return currentHash === expectedRoot;
}

/**
 * Test that tree structure can be correctly reconstructed for all chains
 *
 * This function verifies the entire tree by:
 * 1. Finding all chain IDs in the tree
 * 2. Generating encoding for each chain
 * 3. Verifying each encoding reconstructs correctly
 * 4. Returning detailed results
 *
 * @param {PermitNode} permitNode - The tree to test
 * @returns {Object} Test results for all chains
 *
 * @example
 * const results = testTreeReconstruction(permitNode);
 * console.log(`Tested ${results.total} chains`);
 * console.log(`Passed: ${results.passed}, Failed: ${results.failed}`);
 * if (results.failed > 0) {
 *   console.error('Failed chains:', results.failures);
 * }
 */
function testTreeReconstruction(permitNode) {
    // Find all chain IDs in the tree
    function findAllChainIds(node) {
        const chainIds = [];

        for (const permit of node.permits) {
            chainIds.push(permit.chainId);
        }

        for (const childNode of node.nodes) {
            chainIds.push(...findAllChainIds(childNode));
        }

        return chainIds;
    }

    const chainIds = findAllChainIds(permitNode);
    const results = {
        total: chainIds.length,
        passed: 0,
        failed: 0,
        failures: [],
        details: {}
    };

    for (const chainId of chainIds) {
        try {
            const encoding = encodeProofStructure(permitNode, chainId);
            const isValid = verifyTreeEncoding(permitNode, chainId, encoding);

            if (isValid) {
                results.passed++;
                results.details[chainId] = { success: true };
            } else {
                results.failed++;
                results.failures.push({
                    chainId,
                    error: 'Reconstruction verification failed'
                });
                results.details[chainId] = {
                    success: false,
                    error: 'Reconstruction verification failed'
                };
            }
        } catch (error) {
            results.failed++;
            results.failures.push({
                chainId,
                error: error.message
            });
            results.details[chainId] = {
                success: false,
                error: error.message
            };
        }
    }

    return results;
}

/**
 * Sign a PermitNode permit using EIP-712
 * This creates a signature that authorizes the execution of permits in the tree structure.
 *
 * @param {PermitNode} permitNode - The complete PermitNode structure
 * @param {string} owner - Owner address (the account authorizing the permits)
 * @param {string} salt - Unique salt for replay protection (bytes32)
 * @param {number} deadline - Signature expiration timestamp (uint48)
 * @param {number} timestamp - Current timestamp (uint48)
 * @param {Object} signer - Ethers signer object (must be able to sign EIP-712)
 * @param {string} verifyingContract - Permit3 contract address
 * @returns {Promise<string>} The EIP-712 signature
 *
 * @example
 * const signature = await signPermitNodePermit(
 *   permitNode,
 *   '0x1234...', // owner
 *   ethers.randomBytes(32), // salt
 *   Math.floor(Date.now() / 1000) + 3600, // deadline (1 hour from now)
 *   Math.floor(Date.now() / 1000), // current timestamp
 *   signer,
 *   '0xPermit3Address...'
 * );
 */
async function signPermitNodePermit(permitNode, owner, salt, deadline, timestamp, signer, verifyingContract) {
    const permitNodeHash = hashPermitNode(permitNode);

    // EIP-712 domain
    const domain = {
        name: 'Permit3',
        version: '1',
        chainId: await signer.provider.getNetwork().then(n => n.chainId),
        verifyingContract: verifyingContract
    };

    // EIP-712 types for Permit3 signature
    const types = {
        Permit3: [
            { name: 'owner', type: 'address' },
            { name: 'salt', type: 'bytes32' },
            { name: 'deadline', type: 'uint48' },
            { name: 'timestamp', type: 'uint48' },
            { name: 'permitTree', type: 'bytes32' }
        ]
    };

    // Values to sign
    const value = {
        owner: owner,
        salt: salt,
        deadline: deadline,
        timestamp: timestamp,
        permitTree: permitNodeHash
    };

    // Sign using EIP-712
    return await signer.signTypedData(domain, types, value);
}

/**
 * Hash a NonceNode structure using EIP-712
 * @param {NonceNode} nonceNode - The NonceNode structure
 * @returns {string} The EIP-712 hash of the NonceNode
 *
 * @example
 * const nonceNode = {
 *   nodes: [],
 *   nonces: ['0x1111...', '0x2222...']
 * };
 * const hash = hashNonceNode(nonceNode);
 */
function hashNonceNode(nonceNode) {
    const NONCE_NODE_TYPEHASH = ethers.utils.keccak256(
        ethers.utils.toUtf8Bytes("NonceNode(NonceNode[] nodes,bytes32[] nonces)")
    );

    // Hash child nodes recursively
    const nodeHashes = nonceNode.nodes.map(node => hashNonceNode(node));
    const nodesArrayHash = nodeHashes.length > 0
        ? ethers.utils.keccak256(ethers.utils.concat(nodeHashes))
        : ethers.utils.keccak256('0x');

    // Hash nonces (already bytes32 values, no additional hashing needed)
    const nonceHashes = nonceNode.nonces.map(nonce => nonce);
    const noncesArrayHash = nonceHashes.length > 0
        ? ethers.utils.keccak256(ethers.utils.concat(nonceHashes))
        : ethers.utils.keccak256('0x');

    return ethers.utils.keccak256(
        ethers.utils.defaultAbiCoder.encode(
            ['bytes32', 'bytes32', 'bytes32'],
            [NONCE_NODE_TYPEHASH, nodesArrayHash, noncesArrayHash]
        )
    );
}

/**
 * Find the Merkle path from target nonces to the root
 *
 * This function implements the core algorithm for building proofs that work with
 * the on-chain _reconstructNonceNodeHash() function in NonceNodeLib.sol.
 *
 * @param {NonceNode} nonceNode - The NonceNode structure to search
 * @param {Array<string>} targetNonces - The nonces to find
 * @param {number} depth - Current recursion depth (internal use)
 * @returns {NonceMerklePathInfo|null} Path info or null if nonces not found
 */
function findNonceMerklePath(nonceNode, targetNonces, depth = 0) {
    // Check if targetNonces match this node's nonces exactly
    if (nonceNode.nonces.length > 0 && arraysEqual(nonceNode.nonces, targetNonces)) {
        // Found the target! Now build the proof path
        const proof = [];
        const typeFlags = [];

        // Check if there are nodes at this level (mixed Node+Nonce case)
        if (nonceNode.nodes.length > 0 && nonceNode.nonces.length === targetNonces.length) {
            // Node+Nonce combination: sibling is the node
            proof.push(hashNonceNode(nonceNode.nodes[0]));
            typeFlags.push(1); // Sibling is a Node
        } else if (nonceNode.nonces.length === 2 && targetNonces.length === 1 && nonceNode.nodes.length === 0) {
            // Nonce+Nonce combination: sibling is the other nonce
            const targetIndex = nonceNode.nonces.indexOf(targetNonces[0]);
            if (targetIndex !== -1) {
                const siblingIndex = targetIndex === 0 ? 1 : 0;
                proof.push(nonceNode.nonces[siblingIndex]);
                typeFlags.push(0); // Sibling is a Nonce
            }
        } else if (nonceNode.nonces.length > 2 || (nonceNode.nonces.length > 1 && nonceNode.nodes.length > 0 && nonceNode.nonces.length !== targetNonces.length)) {
            throw new Error('NonceNode with more than 2 children (nodes + nonces) is not yet supported. Please restructure as a binary tree.');
        }

        return {
            proof,
            typeFlags,
            nonces: targetNonces,
            position: 0
        };
    }

    // Check if targetNonces is a single nonce that exists in this node's nonces array
    if (targetNonces.length === 1 && nonceNode.nonces.length > 1) {
        const targetIndex = nonceNode.nonces.indexOf(targetNonces[0]);
        if (targetIndex !== -1) {
            const proof = [];
            const typeFlags = [];

            // Found a single nonce in a multi-nonce node
            if (nonceNode.nonces.length === 2 && nonceNode.nodes.length === 0) {
                const siblingIndex = targetIndex === 0 ? 1 : 0;
                proof.push(nonceNode.nonces[siblingIndex]);
                typeFlags.push(0); // Sibling is a Nonce
            } else {
                throw new Error('NonceNode with more than 2 nonces is not supported');
            }

            return {
                proof,
                typeFlags,
                nonces: targetNonces,
                position: targetIndex
            };
        }
    }

    // Not found in direct nonces, search in child nodes
    for (let i = 0; i < nonceNode.nodes.length; i++) {
        const childResult = findNonceMerklePath(nonceNode.nodes[i], targetNonces, depth + 1);

        if (childResult) {
            // Found in this child! Now add the sibling to the proof
            const proof = [...childResult.proof];
            const typeFlags = [...childResult.typeFlags];

            // Determine the sibling
            if (nonceNode.nodes.length === 2 && nonceNode.nonces.length === 0) {
                // Two nodes, no nonces - Node+Node combination
                const siblingIndex = i === 0 ? 1 : 0;
                proof.push(hashNonceNode(nonceNode.nodes[siblingIndex]));
                typeFlags.push(1); // Sibling is a Node
            } else if (nonceNode.nodes.length === 1 && nonceNode.nonces.length > 0) {
                // One node, some nonces - Node+Nonce combination (struct order)
                // The sibling is the nonces (as a NonceNode hash)
                const noncesHash = hashNonceNode({ nodes: [], nonces: nonceNode.nonces });
                proof.push(noncesHash);
                typeFlags.push(0); // Sibling is treated as Nonce
            } else if (nonceNode.nodes.length > 2) {
                throw new Error('NonceNode with more than 2 children (nodes + nonces) is not yet supported. Please restructure as a binary tree.');
            }

            return {
                proof,
                typeFlags,
                nonces: childResult.nonces,
                position: childResult.position
            };
        }
    }

    // Not found in this subtree
    return null;
}

/**
 * Helper function to check if two arrays are equal
 * @param {Array} arr1 - First array
 * @param {Array} arr2 - Second array
 * @returns {boolean} True if arrays are equal
 */
function arraysEqual(arr1, arr2) {
    if (arr1.length !== arr2.length) return false;
    const sorted1 = [...arr1].sort();
    const sorted2 = [...arr2].sort();
    return sorted1.every((val, idx) => val === sorted2[idx]);
}

/**
 * Encode NonceNode tree structure for on-chain reconstruction
 * @param {NonceNode} nonceNode - The NonceNode structure
 * @param {Array<string>} targetNonces - The nonces for current operation
 * @returns {NonceTreeEncoding} { proofStructure, proof, currentNonces }
 *
 * @example
 * const result = encodeNonceProofStructure(nonceNode, ['0x1111...']);
 * // result.proofStructure: '0x...'
 * // result.proof: ['0x...']
 * // result.currentNonces: ['0x1111...']
 */
function encodeNonceProofStructure(nonceNode, targetNonces) {
    // Find the Merkle path for target nonces
    const pathInfo = findNonceMerklePath(nonceNode, targetNonces);

    if (!pathInfo) {
        throw new Error(`Nonces not found in NonceNode: ${targetNonces}`);
    }

    // Encode proofStructure
    let proofStructureValue = BigInt(pathInfo.position) << 248n;

    for (let i = 0; i < pathInfo.typeFlags.length; i++) {
        if (pathInfo.typeFlags[i] === 1) {
            const bitPosition = 255n - 8n - BigInt(i);
            proofStructureValue |= (1n << bitPosition);
        }
    }

    const proofStructure = '0x' + proofStructureValue.toString(16).padStart(64, '0');

    return {
        proofStructure,
        proof: pathInfo.proof,
        currentNonces: targetNonces
    };
}

/**
 * Build an optimal balanced NonceNode tree from nonce array
 * @param {Array<string>} nonces - Array of nonce bytes32 values
 * @returns {NonceNode} Optimally structured NonceNode tree
 *
 * @example
 * const tree = buildOptimalNonceTree(['0x111...', '0x222...', '0x333...', '0x444...']);
 * // Returns balanced binary tree structure
 */
function buildOptimalNonceTree(nonces) {
    if (nonces.length === 0) {
        return { nodes: [], nonces: [] };
    }

    if (nonces.length === 1) {
        return { nodes: [], nonces: nonces };
    }

    if (nonces.length === 2) {
        // Two nonces - create simple flat structure
        // Sort by value for deterministic ordering
        const sorted = [...nonces].sort();
        return {
            nodes: [],
            nonces: sorted
        };
    }

    // For more than 2 nonces, build a balanced binary tree
    // Split into two halves
    const mid = Math.floor(nonces.length / 2);
    const leftNonces = nonces.slice(0, mid);
    const rightNonces = nonces.slice(mid);

    // Recursively build left and right subtrees
    const leftNode = buildOptimalNonceTree(leftNonces);
    const rightNode = buildOptimalNonceTree(rightNonces);

    // Combine into parent node
    // Sort child nodes by hash for deterministic ordering
    const leftHash = hashNonceNode(leftNode);
    const rightHash = hashNonceNode(rightNode);

    const nodes = leftHash < rightHash ? [leftNode, rightNode] : [rightNode, leftNode];

    return {
        nodes,
        nonces: []
    };
}

/**
 * Validate that a NonceNode tree is correctly structured
 * @param {NonceNode} nonceNode - The tree to validate
 * @returns {Object} { valid: boolean, errors: string[] }
 *
 * @example
 * const result = validateNonceProofStructure(nonceNode);
 * if (!result.valid) {
 *   console.error('Tree validation failed:', result.errors);
 * }
 */
function validateNonceProofStructure(nonceNode) {
    const errors = [];
    const seenNonces = new Set();

    function validateNode(node, path = 'root') {
        // Check binary tree constraint
        const totalChildren = node.nodes.length + (node.nonces.length > 0 ? 1 : 0);
        if (totalChildren > 2) {
            errors.push(`${path}: Node has ${totalChildren} effective children (max 2 allowed for binary tree)`);
        }

        // Check for duplicate nonces
        for (const nonce of node.nonces) {
            if (seenNonces.has(nonce)) {
                errors.push(`${path}: Duplicate nonce ${nonce}`);
            }
            seenNonces.add(nonce);
        }

        // Recursively validate child nodes
        for (let i = 0; i < node.nodes.length; i++) {
            validateNode(node.nodes[i], `${path}.nodes[${i}]`);
        }
    }

    validateNode(nonceNode);

    return {
        valid: errors.length === 0,
        errors
    };
}

/**
 * Sign a NonceNode tree for cancellation using EIP-712
 * @param {NonceNode} nonceNode - The complete NonceNode structure
 * @param {string} owner - Owner address
 * @param {number} deadline - Signature expiration timestamp
 * @param {Object} signer - Ethers signer object
 * @param {string} verifyingContract - Permit3 contract address
 * @returns {Promise<string>} The EIP-712 signature
 *
 * @example
 * const signature = await signNonceTreeCancellation(
 *   nonceNode,
 *   '0x1234...',
 *   Math.floor(Date.now() / 1000) + 3600,
 *   signer,
 *   '0xPermit3Address...'
 * );
 */
async function signNonceTreeCancellation(nonceNode, owner, deadline, signer, verifyingContract) {
    const nonceNodeHash = hashNonceNode(nonceNode);

    // EIP-712 domain
    const domain = {
        name: 'Permit3',
        version: '1',
        chainId: await signer.provider.getNetwork().then(n => n.chainId),
        verifyingContract: verifyingContract
    };

    // EIP-712 types
    const types = {
        CancelNonces: [
            { name: 'owner', type: 'address' },
            { name: 'deadline', type: 'uint48' },
            { name: 'nonceTree', type: 'bytes32' }
        ]
    };

    // Values to sign
    const value = {
        owner: owner,
        deadline: deadline,
        nonceTree: nonceNodeHash
    };

    return await signer.signTypedData(domain, types, value);
}

/**
 * Visualize a NonceNode tree structure
 * @param {NonceNode} nonceNode - The tree to visualize
 * @param {number} indent - Current indentation level (internal use)
 * @returns {string} Tree visualization
 *
 * @example
 * const tree = buildOptimalNonceTree(nonces);
 * console.log(visualizeNonceTree(tree));
 */
function visualizeNonceTree(nonceNode, indent = 0) {
    const prefix = '  '.repeat(indent);
    const hash = hashNonceNode(nonceNode).slice(0, 10) + '...';
    let output = `${prefix}NonceNode (hash: ${hash})\n`;

    // Show child nodes
    for (let i = 0; i < nonceNode.nodes.length; i++) {
        const isLast = i === nonceNode.nodes.length - 1 && nonceNode.nonces.length === 0;
        const connector = isLast ? '└─ ' : '├─ ';
        output += `${prefix}${connector}`;
        output += visualizeNonceTree(nonceNode.nodes[i], indent + 1).trimStart();
    }

    // Show nonces
    for (let i = 0; i < nonceNode.nonces.length; i++) {
        const isLast = i === nonceNode.nonces.length - 1;
        const connector = isLast ? '└─ ' : '├─ ';
        const nonce = nonceNode.nonces[i];
        const nonceShort = nonce.slice(0, 10) + '...' + nonce.slice(-6);
        output += `${prefix}${connector}Nonce: ${nonceShort}\n`;
    }

    return output;
}

module.exports = {
    // Core hashing functions
    hashPermitNode,
    hashChainPermits,

    // Tree encoding and proof generation
    encodeProofStructure,
    buildProofForChain,
    findMerklePathToRoot,

    // Tree construction utilities
    buildOptimalPermitTree,

    // Validation and testing
    validateProofStructure,
    verifyTreeEncoding,
    testTreeReconstruction,

    // Visualization
    visualizeTree,

    // Signing
    signPermitNodePermit,

    // NonceNode functions
    hashNonceNode,
    findNonceMerklePath,
    encodeNonceProofStructure,
    buildOptimalNonceTree,
    validateNonceProofStructure,
    signNonceTreeCancellation,
    visualizeNonceTree
};
