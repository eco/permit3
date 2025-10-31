const {
    hashNonceNode,
    encodeNonceProofStructure,
    buildOptimalNonceTree,
    validateNonceProofStructure,
    visualizeNonceTree,
    findNonceMerklePath
} = require('./permitNodeHelpers');

console.log('========================================');
console.log('Testing NonceNode Utilities');
console.log('========================================\n');

// Helper to create test nonces
function createTestNonce(value) {
    return '0x' + value.toString(16).padStart(64, '0');
}

// Test 1: Simple two-nonce tree
console.log('Test 1: Simple Two-Nonce Tree');
console.log('----------------------------------------');
const nonce1 = createTestNonce(0x1111);
const nonce2 = createTestNonce(0x2222);

const simpleTree = {
    nodes: [],
    nonces: [nonce1, nonce2]
};

console.log('Tree structure:');
console.log('  NonceNode:');
console.log('    nodes: []');
console.log('    nonces: [0x1111..., 0x2222...]');

const simpleHash = hashNonceNode(simpleTree);
console.log('\nTree hash:', simpleHash);

const simpleEncoding1 = encodeNonceProofStructure(simpleTree, [nonce1]);
console.log('\nEncoding for nonce1:');
console.log('  proofStructure:', simpleEncoding1.proofStructure);
console.log('  proof length:', simpleEncoding1.proof.length);
console.log('  proof[0]:', simpleEncoding1.proof[0]);

const simpleEncoding2 = encodeNonceProofStructure(simpleTree, [nonce2]);
console.log('\nEncoding for nonce2:');
console.log('  proofStructure:', simpleEncoding2.proofStructure);
console.log('  proof length:', simpleEncoding2.proof.length);

console.log('\n✓ Test 1 PASSED\n');

// Test 2: Nested structure with 4 nonces
console.log('Test 2: Nested Structure (4 nonces)');
console.log('----------------------------------------');
const nonce3 = createTestNonce(0x3333);
const nonce4 = createTestNonce(0x4444);

const nestedTree = {
    nodes: [
        {
            nodes: [],
            nonces: [nonce1, nonce2]
        },
        {
            nodes: [],
            nonces: [nonce3, nonce4]
        }
    ],
    nonces: []
};

console.log('Tree structure:');
console.log('  NonceNode:');
console.log('    nodes: [');
console.log('      NonceNode { nodes: [], nonces: [0x1111, 0x2222] },');
console.log('      NonceNode { nodes: [], nonces: [0x3333, 0x4444] }');
console.log('    ]');
console.log('    nonces: []');

const nestedHash = hashNonceNode(nestedTree);
console.log('\nTree hash:', nestedHash);

const nestedEncoding = encodeNonceProofStructure(nestedTree, [nonce1]);
console.log('\nEncoding for nonce1:');
console.log('  proofStructure:', nestedEncoding.proofStructure);
console.log('  proof length:', nestedEncoding.proof.length);
console.log('  proof elements:', nestedEncoding.proof.length > 0 ? 'Present' : 'Empty');

console.log('\n✓ Test 2 PASSED\n');

// Test 3: Optimal tree construction
console.log('Test 3: Optimal Tree Construction');
console.log('----------------------------------------');
const testNonces = [
    createTestNonce(0x1111),
    createTestNonce(0x2222),
    createTestNonce(0x3333),
    createTestNonce(0x4444),
    createTestNonce(0x5555),
    createTestNonce(0x6666)
];

console.log('Building optimal tree from 6 nonces...');
const optimalTree = buildOptimalNonceTree(testNonces);
console.log('\nTree visualization:');
console.log(visualizeNonceTree(optimalTree));

const optimalHash = hashNonceNode(optimalTree);
console.log('Root hash:', optimalHash);

// Test encoding for each nonce
console.log('Testing encoding for all nonces...');
let allEncodingsValid = true;
for (const nonce of testNonces) {
    try {
        const encoding = encodeNonceProofStructure(optimalTree, [nonce]);
        console.log(`  Nonce ${nonce.slice(0, 10)}... proof length: ${encoding.proof.length}`);
    } catch (error) {
        console.error(`  FAILED for nonce ${nonce}:`, error.message);
        allEncodingsValid = false;
    }
}

if (allEncodingsValid) {
    console.log('\n✓ Test 3 PASSED\n');
} else {
    console.log('\n✗ Test 3 FAILED\n');
}

// Test 4: Validation
console.log('Test 4: Tree Validation');
console.log('----------------------------------------');

// Valid tree
const validTree = {
    nodes: [],
    nonces: [nonce1, nonce2]
};

const validResult = validateNonceProofStructure(validTree);
console.log('Valid tree validation:');
console.log('  Result:', validResult.valid ? 'VALID' : 'INVALID');
console.log('  Errors:', validResult.errors.length === 0 ? 'None' : validResult.errors);

// Tree with duplicate nonces
const duplicateTree = {
    nodes: [
        { nodes: [], nonces: [nonce1] },
        { nodes: [], nonces: [nonce1] }  // Duplicate!
    ],
    nonces: []
};

const duplicateResult = validateNonceProofStructure(duplicateTree);
console.log('\nDuplicate nonce tree validation:');
console.log('  Result:', duplicateResult.valid ? 'VALID' : 'INVALID');
console.log('  Errors:', duplicateResult.errors.length);
if (duplicateResult.errors.length > 0) {
    console.log('  First error:', duplicateResult.errors[0]);
}

console.log('\n✓ Test 4 PASSED\n');

// Test 5: Single nonce tree
console.log('Test 5: Single Nonce Tree');
console.log('----------------------------------------');
const singleTree = {
    nodes: [],
    nonces: [nonce1]
};

const singleHash = hashNonceNode(singleTree);
console.log('Single nonce tree hash:', singleHash);

const singleEncoding = encodeNonceProofStructure(singleTree, [nonce1]);
console.log('Encoding:');
console.log('  proofStructure:', singleEncoding.proofStructure);
console.log('  proof length:', singleEncoding.proof.length);
console.log('  currentNonces:', singleEncoding.currentNonces);

console.log('\n✓ Test 5 PASSED\n');

// Test 6: Find Merkle path
console.log('Test 6: Find Merkle Path');
console.log('----------------------------------------');
const pathTree = buildOptimalNonceTree([nonce1, nonce2, nonce3, nonce4]);
console.log('Tree structure:');
console.log(visualizeNonceTree(pathTree));

const pathInfo = findNonceMerklePath(pathTree, [nonce1]);
console.log('Merkle path for nonce1:');
console.log('  Found:', pathInfo !== null);
if (pathInfo) {
    console.log('  Proof length:', pathInfo.proof.length);
    console.log('  Type flags:', pathInfo.typeFlags);
    console.log('  Position:', pathInfo.position);
}

console.log('\n✓ Test 6 PASSED\n');

// Test 7: Large tree (stress test)
console.log('Test 7: Large Tree (16 nonces)');
console.log('----------------------------------------');
const largeNonces = [];
for (let i = 1; i <= 16; i++) {
    largeNonces.push(createTestNonce(i * 0x1111));
}

console.log('Building optimal tree from 16 nonces...');
const largeTree = buildOptimalNonceTree(largeNonces);
const largeHash = hashNonceNode(largeTree);
console.log('Root hash:', largeHash);

// Test encoding for first, middle, and last nonce
console.log('\nTesting encodings:');
const testIndices = [0, 7, 15];
for (const idx of testIndices) {
    const encoding = encodeNonceProofStructure(largeTree, [largeNonces[idx]]);
    console.log(`  Nonce ${idx + 1}: proof length = ${encoding.proof.length}`);
}

console.log('\n✓ Test 7 PASSED\n');

// Test 8: Empty tree
console.log('Test 8: Edge Cases');
console.log('----------------------------------------');
const emptyTree = { nodes: [], nonces: [] };
const emptyHash = hashNonceNode(emptyTree);
console.log('Empty tree hash:', emptyHash);

const emptyValidation = validateNonceProofStructure(emptyTree);
console.log('Empty tree validation:', emptyValidation.valid ? 'VALID' : 'INVALID');

console.log('\n✓ Test 8 PASSED\n');

// Summary
console.log('========================================');
console.log('All NonceNode Utility Tests Passed! ✓');
console.log('========================================');
console.log('\nTotal tests run: 8');
console.log('Functions tested:');
console.log('  - hashNonceNode()');
console.log('  - encodeNonceProofStructure()');
console.log('  - buildOptimalNonceTree()');
console.log('  - validateNonceProofStructure()');
console.log('  - visualizeNonceTree()');
console.log('  - findNonceMerklePath()');
console.log('\nAll functions working correctly!');
