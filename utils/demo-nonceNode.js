const {
    hashNonceNode,
    encodeNonceProofStructure,
    buildOptimalNonceTree,
    validateNonceProofStructure,
    visualizeNonceTree,
} = require('./permitNodeHelpers');

console.log('=======================================================');
console.log('Permit3 NonceNode Utilities - Usage Demonstration');
console.log('=======================================================\n');

// Helper to create test nonces (bytes32)
function createNonce(value) {
    return '0x' + value.toString(16).padStart(64, '0');
}

console.log('SCENARIO: User wants to cancel multiple nonces efficiently\n');
console.log('-------------------------------------------------------\n');

// Step 1: Create nonces to cancel
console.log('Step 1: Create Nonces to Cancel');
console.log('-------------------------------------------------------');
const noncesToCancel = [
    createNonce(0xabcd1234),
    createNonce(0xdef56789),
    createNonce(0x11112222),
    createNonce(0x33334444),
    createNonce(0x55556666),
    createNonce(0x77778888)
];

console.log('Created 6 nonces:');
noncesToCancel.forEach((nonce, i) => {
    console.log(`  ${i + 1}. ${nonce.slice(0, 10)}...${nonce.slice(-8)}`);
});

// Step 2: Build optimal tree
console.log('\n\nStep 2: Build Optimal Merkle Tree');
console.log('-------------------------------------------------------');
console.log('Building balanced binary tree for gas-efficient cancellation...\n');

const nonceTree = buildOptimalNonceTree(noncesToCancel);

console.log('Tree structure:');
console.log(visualizeNonceTree(nonceTree));

const rootHash = hashNonceNode(nonceTree);
console.log('Root hash:', rootHash);

// Step 3: Validate tree
console.log('\n\nStep 3: Validate Tree Structure');
console.log('-------------------------------------------------------');
const validation = validateNonceProofStructure(nonceTree);
console.log('Validation result:', validation.valid ? '✓ VALID' : '✗ INVALID');
if (validation.errors.length > 0) {
    console.log('Errors:', validation.errors);
}

// Step 4: Generate proof for specific nonce
console.log('\n\nStep 4: Generate Proof for On-Chain Cancellation');
console.log('-------------------------------------------------------');
const targetNonce = noncesToCancel[2]; // Cancel the 3rd nonce
console.log('Target nonce to cancel:', targetNonce);

const encoding = encodeNonceProofStructure(nonceTree, [targetNonce]);

console.log('\nGenerated proof data:');
console.log('  proofStructure:', encoding.proofStructure);
console.log('  proof length:', encoding.proof.length);
console.log('  proof elements:');
encoding.proof.forEach((elem, i) => {
    console.log(`    [${i}] ${elem.slice(0, 10)}...${elem.slice(-8)}`);
});

// Step 5: Show how this would be used on-chain
console.log('\n\nStep 5: On-Chain Usage Example');
console.log('-------------------------------------------------------');
console.log('The generated data would be passed to cancelNonces():');
console.log('');
console.log('contract.cancelNonces(');
console.log('  owner,              // address - nonce owner');
console.log('  deadline,           // uint48 - signature deadline');
console.log(`  "${encoding.proofStructure}", // bytes32 - proof structure encoding`);
console.log(`  ["${encoding.currentNonces[0]}"], // bytes32[] - nonce to cancel`);
console.log(`  [${encoding.proof.map(p => `"${p}"`).join(', ')}], // bytes32[] - merkle proof`);
console.log('  signature           // bytes - EIP-712 signature');
console.log(')');

// Step 6: Gas efficiency comparison
console.log('\n\nStep 6: Gas Efficiency Benefits');
console.log('-------------------------------------------------------');
console.log('Tree-based approach benefits:');
console.log('  • User signs once for all 6 nonces (off-chain)');
console.log('  • Can cancel nonces individually over time');
console.log(`  • Each cancellation only sends ${encoding.proof.length + 1} hashes on-chain`);
console.log('  • No need to re-sign for each nonce cancellation');
console.log('  • Proof size scales logarithmically with tree size');
console.log('');
console.log('Comparison:');
console.log('  Traditional approach:');
console.log('    - 6 nonces = 6 separate signatures + 6 transactions');
console.log('    - Each transaction: 1 nonce + 1 signature');
console.log('');
console.log('  Tree-based approach:');
console.log('    - 6 nonces = 1 signature + up to 6 transactions');
console.log(`    - Each transaction: 1 nonce + ${encoding.proof.length} proof hashes`);
console.log('    - Sign once, cancel any subset later!');

// Step 7: Multiple nonce cancellation
console.log('\n\nStep 7: Cancel Multiple Nonces at Different Times');
console.log('-------------------------------------------------------');
console.log('Generate proofs for canceling different nonces:');

const noncesToTest = [noncesToCancel[0], noncesToCancel[3], noncesToCancel[5]];
noncesToTest.forEach((nonce, i) => {
    const enc = encodeNonceProofStructure(nonceTree, [nonce]);
    console.log(`\nNonce ${i + 1}: ${nonce.slice(0, 10)}...${nonce.slice(-8)}`);
    console.log(`  Proof size: ${enc.proof.length} hashes`);
    console.log(`  Gas cost: ~${21000 + enc.proof.length * 800} gas (estimate)`);
});

// Step 8: Summary
console.log('\n\n=======================================================');
console.log('Summary');
console.log('=======================================================');
console.log('✓ Built optimal tree with 6 nonces');
console.log('✓ Tree depth:', Math.ceil(Math.log2(noncesToCancel.length)));
console.log('✓ Max proof size:', encoding.proof.length, 'hashes');
console.log('✓ Root hash signed by user');
console.log('✓ Individual nonces can be cancelled independently');
console.log('✓ No additional signatures needed');
console.log('');
console.log('Integration Points:');
console.log('1. Off-chain: Build tree with buildOptimalNonceTree()');
console.log('2. Off-chain: Generate root hash with hashNonceNode()');
console.log('3. Off-chain: User signs root hash (EIP-712)');
console.log('4. Off-chain: Generate proof with encodeNonceProofStructure()');
console.log('5. On-chain: Submit to cancelNonces() with proof');
console.log('6. On-chain: Contract reconstructs root and verifies signature');
console.log('');
console.log('=======================================================');
console.log('Demo complete!');
console.log('=======================================================');
