/**
 * Merkle Tree Helpers for Permit3
 *
 * This module provides utility functions for working with merkle trees
 * in the context of Permit3's Unbalanced Merkle tree methodology using OpenZeppelin's MerkleProof.
 * Now includes support for Nested structures for UI-readable tree representations.
 */

const { MerkleTree } = require('merkletreejs');
const { ethers } = require('ethers');
const keccak256 = require('keccak256');

/**
 * Build a standard merkle tree with ordered hashing
 * @param {Array<string|Buffer>} leaves - Array of leaf nodes (hashes)
 * @returns {MerkleTree} The constructed merkle tree
 */
function buildMerkleTree(leaves) {
    // Convert string hashes to buffers if needed
    const leafBuffers = leaves.map(leaf => {
        if (typeof leaf === 'string') {
            return Buffer.from(leaf.slice(2), 'hex'); // Remove '0x' prefix
        }
        return leaf;
    });
    
    // Create tree with sorted pairs for consistency
    return new MerkleTree(leafBuffers, keccak256, { 
        sortPairs: true  // IMPORTANT: This ensures ordered hashing
    });
}

/**
 * Generate merkle proof for a specific leaf
 * @param {MerkleTree} tree - The merkle tree
 * @param {string|Buffer} leaf - The leaf to generate proof for
 * @returns {string[]} Array of proof hashes in hex format
 */
function generateMerkleProof(tree, leaf) {
    const leafBuffer = typeof leaf === 'string' 
        ? Buffer.from(leaf.slice(2), 'hex') 
        : leaf;
    
    const proof = tree.getProof(leafBuffer);
    
    // Convert to hex strings for contract compatibility
    return proof.map(p => '0x' + p.data.toString('hex'));
}

/**
 * Get merkle root in hex format
 * @param {MerkleTree} tree - The merkle tree
 * @returns {string} The root hash in hex format
 */
function getMerkleRoot(tree) {
    return '0x' + tree.getRoot().toString('hex');
}

/**
 * Build cross-chain permit merkle tree
 * @param {Object} chainPermits - Object mapping chain names to permit data
 * @param {Object} permit3Contracts - Object mapping chain names to Permit3 contract instances
 * @returns {Promise<{tree: MerkleTree, leaves: Object, root: string}>}
 */
async function buildCrossChainPermitTree(chainPermits, permit3Contracts) {
    const orderedChains = Object.keys(chainPermits).sort();
    const leaves = {};
    const leafArray = [];
    
    // Hash each chain's permits
    for (const chain of orderedChains) {
        const contract = permit3Contracts[chain];
        const permitData = chainPermits[chain];
        
        const leaf = await contract.hashChainPermits(permitData);
        leaves[chain] = leaf;
        leafArray.push(leaf);
    }
    
    // Build the merkle tree
    const tree = buildMerkleTree(leafArray);
    const root = getMerkleRoot(tree);
    
    return {
        tree,
        leaves,
        root,
        chains: orderedChains
    };
}

/**
 * Generate all proofs for cross-chain permits
 * @param {MerkleTree} tree - The merkle tree
 * @param {Object} leaves - Object mapping chain names to leaf hashes
 * @param {Object} chainPermits - Object mapping chain names to permit data
 * @returns {Object} Object mapping chain names to UnbalancedPermitProof structures
 */
function generateAllProofs(tree, leaves, chainPermits) {
    const proofs = {};
    
    for (const [chain, leaf] of Object.entries(leaves)) {
        proofs[chain] = {
            permits: chainPermits[chain],
            proof: generateMerkleProof(tree, leaf)
        };
    }
    
    return proofs;
}

/**
 * Verify a merkle proof locally (for testing/debugging)
 * @param {string[]} proof - Array of proof hashes
 * @param {string} leaf - The leaf hash
 * @param {string} root - The expected root hash
 * @returns {boolean} True if proof is valid
 */
function verifyProof(proof, leaf, root) {
    // Reconstruct buffers
    const proofBuffers = proof.map(p => Buffer.from(p.slice(2), 'hex'));
    const leafBuffer = Buffer.from(leaf.slice(2), 'hex');
    const rootBuffer = Buffer.from(root.slice(2), 'hex');
    
    // Create a temporary tree just for verification
    const tree = new MerkleTree([], keccak256, { sortPairs: true });
    
    return tree.verify(proofBuffers, leafBuffer, rootBuffer);
}

/**
 * Debug helper to visualize merkle tree
 * @param {MerkleTree} tree - The merkle tree
 * @param {Object} chainNames - Optional mapping of leaf indices to chain names
 */
function debugMerkleTree(tree, chainNames = {}) {
    console.log('=== Merkle Tree Debug ===');
    console.log('Root:', getMerkleRoot(tree));
    console.log('Depth:', tree.getDepth());
    console.log('Leaves:', tree.getLeaveCount());
    
    // Print tree structure
    console.log('\nTree Structure:');
    const layers = tree.getLayers();
    layers.forEach((layer, depth) => {
        console.log(`Layer ${depth}:`, layer.map(node => '0x' + node.toString('hex').slice(0, 8) + '...'));
    });
    
    // Print proofs for each leaf
    if (Object.keys(chainNames).length > 0) {
        console.log('\nProofs:');
        Object.entries(chainNames).forEach(([index, name]) => {
            const leaf = tree.getLeaves()[index];
            const proof = tree.getProof(leaf);
            console.log(`${name} (leaf ${index}):`, proof.length, 'nodes');
        });
    }
}

/**
 * Create a cross-chain permit helper class
 */
class CrossChainPermitHelper {
    constructor(permit3Addresses, providers) {
        this.permit3Addresses = permit3Addresses;
        this.providers = providers;
        this.contracts = {};
        
        // Initialize contracts
        for (const [chain, address] of Object.entries(permit3Addresses)) {
            this.contracts[chain] = new ethers.Contract(
                address,
                PERMIT3_ABI, // You need to provide this
                providers[chain]
            );
        }
    }
    
    /**
     * Build a complete cross-chain permit
     */
    async buildPermit(chainPermits, signer) {
        // Build merkle tree
        const { tree, leaves, root, chains } = await buildCrossChainPermitTree(
            chainPermits,
            this.contracts
        );
        
        // Create signature data
        const salt = ethers.utils.randomBytes(32);
        const timestamp = Math.floor(Date.now() / 1000);
        const deadline = timestamp + 3600; // 1 hour
        
        // Sign using mainnet domain
        const domain = {
            name: "Permit3",
            version: "1",
            chainId: 1, // Always use mainnet for cross-chain
            verifyingContract: this.permit3Addresses.ethereum || Object.values(this.permit3Addresses)[0]
        };
        
        const types = {
            Permit3: [
                { name: "owner", type: "address" },
                { name: "salt", type: "bytes32" },
                { name: "deadline", type: "uint48" },
                { name: "timestamp", type: "uint48" },
                { name: "merkleRoot", type: "bytes32" }
            ]
        };
        
        const value = {
            owner: await signer.getAddress(),
            salt,
            deadline,
            timestamp,
            merkleRoot: root
        };
        
        const signature = await signer._signTypedData(domain, types, value);
        
        // Generate all proofs
        const proofs = generateAllProofs(tree, leaves, chainPermits);
        
        return {
            owner: value.owner,
            salt,
            deadline,
            timestamp,
            signature,
            root,
            proofs,
            chains,
            tree // Include for debugging
        };
    }
    
    /**
     * Execute permit on a specific chain
     */
    async executeOnChain(chain, permitData) {
        const contract = this.contracts[chain];
        const proof = permitData.proofs[chain];
        
        return contract.permit(
            permitData.owner,
            permitData.salt,
            permitData.deadline,
            permitData.timestamp,
            proof,
            permitData.signature
        );
    }
    
    /**
     * Execute on all chains in parallel
     */
    async executeOnAllChains(permitData) {
        const executions = permitData.chains.map(chain => 
            this.executeOnChain(chain, permitData)
                .then(tx => ({ chain, tx, status: 'success' }))
                .catch(error => ({ chain, error, status: 'failed' }))
        );
        
        return Promise.all(executions);
    }
}

/**
 * Build a PermitNode structure from chain permits for UI-readable signatures
 * @param {Object} chainPermits - Object mapping chain names to permit data
 * @param {Object} treeStructure - Optional tree structure configuration
 * @returns {Object} PermitNode structure for EIP-712 signing
 */
function buildPermitNodeStructure(chainPermits, treeStructure = null) {
    const chains = Object.keys(chainPermits);

    if (chains.length === 0) {
        return { nodes: [], permits: [] };
    }

    // Simple balanced structure if no custom structure provided
    if (!treeStructure) {
        // For 2 or fewer chains, create a flat structure
        if (chains.length <= 2) {
            return {
                nodes: [],
                permits: chains.map(chain => chainPermits[chain])
            };
        }

        // For more chains, create a simple binary structure
        const mid = Math.floor(chains.length / 2);
        const leftChains = chains.slice(0, mid);
        const rightChains = chains.slice(mid);

        const leftPermits = leftChains.map(chain => chainPermits[chain]);
        const rightPermits = rightChains.map(chain => chainPermits[chain]);

        return {
            nodes: [
                { nodes: [], permits: leftPermits },
                { nodes: [], permits: rightPermits }
            ],
            permits: []
        };
    }

    // Use custom tree structure
    return treeStructure;
}

/**
 * Hash a PermitNode structure for EIP-712 signing (JavaScript implementation)
 * @param {Object} permitNode - The permit node structure
 * @returns {string} Hash of the permit node structure
 */
function hashPermitNode(permitNode) {
    // Hash all child nodes recursively
    const nodeHashes = permitNode.nodes.map(node => hashPermitNode(node));

    // Hash all permits using ethers
    const permitHashes = permitNode.permits.map(permit => {
        return hashChainPermits(permit);
    });

    // Combine hashes using ABI encoding
    const PERMIT_NODE_TYPEHASH = ethers.utils.keccak256(
        ethers.utils.toUtf8Bytes("PermitNode(PermitNode[] nodes,ChainPermits[] permits)")
    );

    return ethers.utils.keccak256(
        ethers.utils.defaultAbiCoder.encode(
            ['bytes32', 'bytes32', 'bytes32'],
            [
                PERMIT_NODE_TYPEHASH,
                ethers.utils.keccak256(ethers.utils.concat(nodeHashes)),
                ethers.utils.keccak256(ethers.utils.concat(permitHashes))
            ]
        )
    );
}

/**
 * Hash ChainPermits structure (JavaScript implementation)
 * @param {Object} chainPermits - Chain permits structure
 * @returns {string} Hash of the chain permits
 */
function hashChainPermits(chainPermits) {
    const CHAIN_PERMITS_TYPEHASH = ethers.utils.keccak256(
        ethers.utils.toUtf8Bytes(
            "ChainPermits(uint64 chainId,AllowanceOrTransfer[] permits)AllowanceOrTransfer(uint48 modeOrExpiration,bytes32 tokenKey,address account,uint160 amountDelta)"
        )
    );

    const permitHashes = chainPermits.permits.map(permit => {
        return ethers.utils.keccak256(
            ethers.utils.defaultAbiCoder.encode(
                ['uint48', 'bytes32', 'address', 'uint160'],
                [permit.modeOrExpiration, permit.tokenKey, permit.account, permit.amountDelta]
            )
        );
    });

    return ethers.utils.keccak256(
        ethers.utils.defaultAbiCoder.encode(
            ['bytes32', 'uint64', 'bytes32'],
            [
                CHAIN_PERMITS_TYPEHASH,
                chainPermits.chainId,
                ethers.utils.keccak256(ethers.utils.concat(permitHashes))
            ]
        )
    );
}

/**
 * Encode proof structure into compact bytes32 representation
 * @param {Object} permitNode - The permit node structure
 * @returns {string} Compact encoding of the proof structure
 */
function encodeProofStructure(permitNode) {
    // Simple encoding: hash structure topology
    return ethers.utils.keccak256(
        ethers.utils.defaultAbiCoder.encode(
            ['uint256', 'uint256'],
            [permitNode.nodes.length, permitNode.permits.length]
        )
    );
}

/**
 * Generate EIP-712 signature for PermitNode structure
 * @param {Object} permitData - Permit data including permit node structure
 * @param {Object} signer - Ethers signer instance
 * @param {Object} domain - EIP-712 domain
 * @returns {Promise<string>} The signature
 */
async function signPermitNodePermit(permitData, signer, domain) {
    const types = {
        Permit3: [
            { name: 'owner', type: 'address' },
            { name: 'salt', type: 'bytes32' },
            { name: 'deadline', type: 'uint48' },
            { name: 'timestamp', type: 'uint48' },
            { name: 'permitNode', type: 'PermitNode' }
        ],
        PermitNode: [
            { name: 'nodes', type: 'PermitNode[]' },
            { name: 'permits', type: 'ChainPermits[]' }
        ],
        ChainPermits: [
            { name: 'chainId', type: 'uint64' },
            { name: 'permits', type: 'AllowanceOrTransfer[]' }
        ],
        AllowanceOrTransfer: [
            { name: 'modeOrExpiration', type: 'uint48' },
            { name: 'tokenKey', type: 'bytes32' },
            { name: 'account', type: 'address' },
            { name: 'amountDelta', type: 'uint160' }
        ]
    };

    return await signer._signTypedData(domain, types, permitData);
}

/**
 * Create cross-chain permit with PermitNode structure for UI transparency
 * @param {Object} chainPermits - Chain permits mapping
 * @param {Object} signer - Ethers signer
 * @param {Object} options - Additional options
 * @returns {Promise<Object>} Complete permit data with permit node structure
 */
async function buildPermitNodeCrossChainPermit(chainPermits, signer, options = {}) {
    // Build permit node structure
    const permitNode = buildPermitNodeStructure(chainPermits, options.treeStructure);

    // Create permit data
    const permitData = {
        owner: await signer.getAddress(),
        salt: options.salt || ethers.utils.randomBytes(32),
        deadline: options.deadline || Math.floor(Date.now() / 1000) + 3600,
        timestamp: options.timestamp || Math.floor(Date.now() / 1000),
        permitNode
    };

    // Set up domain
    const domain = {
        name: 'Permit3',
        version: '1',
        chainId: options.chainId || 1,
        verifyingContract: options.verifyingContract
    };

    // Sign the permit
    const signature = await signPermitNodePermit(permitData, signer, domain);

    // Generate proof structure encoding
    const proofStructure = encodeProofStructure(permitNode);

    // Generate proofs for each chain
    const proofs = {};
    const merkleRoot = reconstructMerkleRootFromPermitNode(permitNode);

    // For each chain, generate its proof
    for (const [chainName, chainPermit] of Object.entries(chainPermits)) {
        const chainHash = hashChainPermits(chainPermit);

        // Build tree and generate proof
        const allHashes = flattenPermitNodeToHashes(permitNode);
        const tree = buildMerkleTree(allHashes);
        const proof = generateMerkleProof(tree, chainHash);

        proofs[chainName] = {
            chainPermits: chainPermit,
            proof,
            proofStructure
        };
    }

    return {
        ...permitData,
        signature,
        proofStructure,
        proofs,
        merkleRoot
    };
}

/**
 * Reconstruct merkle root from permit node structure (JavaScript implementation)
 * @param {Object} permitNode - The permit node structure
 * @returns {string} The merkle root
 */
function reconstructMerkleRootFromPermitNode(permitNode) {
    const allHashes = flattenPermitNodeToHashes(permitNode);

    if (allHashes.length === 0) return ethers.constants.HashZero;
    if (allHashes.length === 1) return allHashes[0];

    const tree = buildMerkleTree(allHashes);
    return getMerkleRoot(tree);
}

/**
 * Flatten permit node structure to array of hashes
 * @param {Object} permitNode - The permit node structure
 * @returns {string[]} Array of all hashes in the structure
 */
function flattenPermitNodeToHashes(permitNode) {
    const hashes = [];

    // Add hashes from child nodes recursively
    for (const node of permitNode.nodes) {
        const childHash = reconstructMerkleRootFromPermitNode(node);
        hashes.push(childHash);
    }

    // Add hashes from permits
    for (const permit of permitNode.permits) {
        hashes.push(hashChainPermits(permit));
    }

    // Sort hashes for consistent ordering
    return hashes.sort();
}

// Export all utilities
module.exports = {
    buildMerkleTree,
    generateMerkleProof,
    getMerkleRoot,
    buildCrossChainPermitTree,
    generateAllProofs,
    verifyProof,
    debugMerkleTree,
    CrossChainPermitHelper,
    // New PermitNode structure functions
    buildPermitNodeStructure,
    hashPermitNode,
    hashChainPermits,
    encodeProofStructure,
    signPermitNodePermit,
    buildPermitNodeCrossChainPermit,
    reconstructMerkleRootFromPermitNode,
    flattenPermitNodeToHashes,
    // Legacy aliases for backward compatibility
    buildNestedStructure: buildPermitNodeStructure,
    hashNested: hashPermitNode,
    signNestedPermit: signPermitNodePermit,
    buildNestedCrossChainPermit: buildPermitNodeCrossChainPermit,
    reconstructMerkleRootFromNested: reconstructMerkleRootFromPermitNode,
    flattenNestedToHashes: flattenPermitNodeToHashes
};

// Example usage
if (require.main === module) {
    // Example: Build a nested cross-chain permit
    async function example() {
        const { ethers } = require('ethers');

        console.log('=== Traditional Merkle Tree Example ===');

        // Mock data
        const leaves = [
            '0x1234567890123456789012345678901234567890123456789012345678901234',
            '0x2345678901234567890123456789012345678901234567890123456789012345',
            '0x3456789012345678901234567890123456789012345678901234567890123456'
        ];

        // Build tree
        const tree = buildMerkleTree(leaves);
        const root = getMerkleRoot(tree);

        console.log('Root:', root);

        // Generate proof for second leaf
        const proof = generateMerkleProof(tree, leaves[1]);
        console.log('Proof for leaf 1:', proof);

        // Verify proof
        const isValid = verifyProof(proof, leaves[1], root);
        console.log('Proof valid:', isValid);

        // Debug tree
        debugMerkleTree(tree, { 0: 'Ethereum', 1: 'Arbitrum', 2: 'Optimism' });

        console.log('\n=== PermitNode Structure Example ===');

        // Example permit node structure for UI transparency
        const chainPermits = {
            ethereum: {
                chainId: 1,
                permits: [
                    {
                        modeOrExpiration: Math.floor(Date.now() / 1000) + 86400,
                        tokenKey: '0x000000000000000000000000a0b86a33e6ba3e8b67b8c8b6e0d6e3f7f7e8c8b6',
                        account: '0x1234567890123456789012345678901234567890',
                        amountDelta: ethers.utils.parseEther('100').toString()
                    }
                ]
            },
            arbitrum: {
                chainId: 42161,
                permits: [
                    {
                        modeOrExpiration: Math.floor(Date.now() / 1000) + 86400,
                        tokenKey: '0x000000000000000000000000da10009cbd5d07dd0cecc66161fc93d7c9000da1',
                        account: '0x1234567890123456789012345678901234567890',
                        amountDelta: ethers.utils.parseEther('50').toString()
                    }
                ]
            }
        };

        // Build permit node structure
        const permitNode = buildPermitNodeStructure(chainPermits);
        console.log('PermitNode structure:', JSON.stringify(permitNode, null, 2));

        // Encode proof structure for contract
        const proofStructure = encodeProofStructure(permitNode);
        console.log('Proof structure encoding:', proofStructure);

        // Reconstruct merkle root
        const permitNodeRoot = reconstructMerkleRootFromPermitNode(permitNode);
        console.log('Reconstructed root:', permitNodeRoot);

        console.log('\n=== User Experience Benefits ===');
        console.log('1. Users can see all allowances they\'re signing in MetaMask');
        console.log('2. Tree structure is transparent and readable');
        console.log('3. Gas-efficient on-chain processing with compact encoding');
        console.log('4. Maintains all security properties of merkle trees');
    }

    example().catch(console.error);
}