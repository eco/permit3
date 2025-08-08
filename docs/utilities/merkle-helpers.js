/**
 * Merkle Tree Helpers for Permit3
 * 
 * This module provides utility functions for working with merkle trees
 * in the context of Permit3's Unhinged Merkle tree methodology using OpenZeppelin's MerkleProof.
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
 * @returns {Object} Object mapping chain names to UnhingedPermitProof structures
 */
function generateAllProofs(tree, leaves, chainPermits) {
    const proofs = {};
    
    for (const [chain, leaf] of Object.entries(leaves)) {
        proofs[chain] = {
            permits: chainPermits[chain],
            unhingedProof: generateMerkleProof(tree, leaf)
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
                { name: "unhingedRoot", type: "bytes32" }
            ]
        };
        
        const value = {
            owner: await signer.getAddress(),
            salt,
            deadline,
            timestamp,
            unhingedRoot: root
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

// Export all utilities
module.exports = {
    buildMerkleTree,
    generateMerkleProof,
    getMerkleRoot,
    buildCrossChainPermitTree,
    generateAllProofs,
    verifyProof,
    debugMerkleTree,
    CrossChainPermitHelper
};

// Example usage
if (require.main === module) {
    // Example: Build a simple cross-chain permit
    async function example() {
        const { ethers } = require('ethers');
        
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
    }
    
    example().catch(console.error);
}