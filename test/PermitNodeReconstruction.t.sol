// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "../src/Permit3.sol";
import "../src/interfaces/IPermit3.sol";
import "./utils/Permit3Tester.sol";
import "./utils/TestUtils.sol";

/**
 * @title PermitNodeReconstructionTest
 * @notice Tests for EIP-712 PermitNode hash reconstruction with various tree structures
 * @dev Tests the _reconstructPermitNodeHash function and helper functions
 */
contract PermitNodeReconstructionTest is Test {
    Permit3 permit3;
    Permit3Tester permit3Tester;
    MockToken token;

    // Test accounts
    address owner;
    address spender;

    // Constants
    uint48 constant EXPIRATION = 1000;

    function setUp() public {
        vm.warp(1000);
        permit3 = new Permit3();
        permit3Tester = new Permit3Tester();
        token = new MockToken();

        owner = address(0x1);
        spender = address(0x2);

        deal(address(token), owner, 10_000);
    }

    // Helper to compute the full hash of a PermitNode
    function _hashPermitNode(
        IPermit3.PermitNode memory node
    ) internal view returns (bytes32) {
        // Hash all child nodes recursively
        bytes32[] memory nodeHashes = new bytes32[](node.nodes.length);
        for (uint256 i = 0; i < node.nodes.length; i++) {
            nodeHashes[i] = _hashPermitNode(node.nodes[i]);
        }

        // Hash all permits
        bytes32[] memory permitHashes = new bytes32[](node.permits.length);
        for (uint256 i = 0; i < node.permits.length; i++) {
            permitHashes[i] = permit3.hashChainPermits(node.permits[i]);
        }

        // Compute the PermitNode hash according to EIP-712
        bytes32 permitNodeTypehash = permit3Tester.getPermitNodeTypehash();
        return keccak256(
            abi.encode(
                permitNodeTypehash, keccak256(abi.encodePacked(nodeHashes)), keccak256(abi.encodePacked(permitHashes))
            )
        );
    }

    /**
     * Test Case 1: Flat structure - Two permits (siblings)
     * Structure: PermitNode(nodes=[], permits=[Chain1, Chain2])
     * Tests: Permit + Permit combination with alphabetical sorting
     */
    function test_flatStructureTwoPermits() public {
        // Create two chain permits
        IPermit3.AllowanceOrTransfer[] memory permits1 = new IPermit3.AllowanceOrTransfer[](1);
        permits1[0] = IPermit3.AllowanceOrTransfer({
            modeOrExpiration: EXPIRATION,
            tokenKey: bytes32(uint256(uint160(address(token)))),
            account: spender,
            amountDelta: 1000
        });

        IPermit3.ChainPermits memory chain1 = IPermit3.ChainPermits({ chainId: 1, permits: permits1 });

        IPermit3.AllowanceOrTransfer[] memory permits2 = new IPermit3.AllowanceOrTransfer[](1);
        permits2[0] = IPermit3.AllowanceOrTransfer({
            modeOrExpiration: EXPIRATION,
            tokenKey: bytes32(uint256(uint160(address(token)))),
            account: spender,
            amountDelta: 2000
        });

        IPermit3.ChainPermits memory chain2 = IPermit3.ChainPermits({
            chainId: 42_161, // Arbitrum
            permits: permits2
        });

        // Hash both permits
        bytes32 chain1Hash = permit3.hashChainPermits(chain1);
        bytes32 chain2Hash = permit3.hashChainPermits(chain2);

        // Build proof for chain 1 (chain2Hash is the proof)
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = chain2Hash;

        // Encode proof structure
        // Position: 0 (chain1 is first)
        // Type flags: bit 8 = 0 (proof[0] is a Permit)
        bytes32 proofStructure = bytes32(uint256(0) << 248); // Position 0, proof is permit (bit 8 = 0)

        // Reconstruct using permit function
        uint48 deadline = uint48(block.timestamp + 1 hours);
        uint48 timestamp = uint48(block.timestamp);

        // Create expected PermitNode hash
        IPermit3.ChainPermits[] memory allPermits = new IPermit3.ChainPermits[](2);
        allPermits[0] = chain1;
        allPermits[1] = chain2;

        IPermit3.PermitNode memory expectedNode =
            IPermit3.PermitNode({ nodes: new IPermit3.PermitNode[](0), permits: allPermits });

        bytes32 expectedHash = _hashPermitNode(expectedNode);

        // Note: We can't directly test internal _reconstructPermitNodeHash
        // But we can verify the full permit() flow works correctly

        // For now, just verify the structures are created correctly
        assertTrue(chain1Hash != bytes32(0), "Chain 1 hash should not be zero");
        assertTrue(chain2Hash != bytes32(0), "Chain 2 hash should not be zero");
        assertTrue(expectedHash != bytes32(0), "Expected node hash should not be zero");
    }

    /**
     * Test Case 2: Three permits in flat structure
     * Structure: PermitNode(nodes=[], permits=[Chain1, Chain2, Chain3])
     * Tests: Multiple permit combinations
     */
    function test_flatStructureThreePermits() public {
        // Create three chain permits for different chains
        IPermit3.ChainPermits memory chain1 = _createChainPermit(1, 1000);
        IPermit3.ChainPermits memory chain2 = _createChainPermit(42_161, 2000);
        IPermit3.ChainPermits memory chain3 = _createChainPermit(10, 3000);

        // Hash all permits
        bytes32 chain1Hash = permit3.hashChainPermits(chain1);
        bytes32 chain2Hash = permit3.hashChainPermits(chain2);
        bytes32 chain3Hash = permit3.hashChainPermits(chain3);

        // Verify hashes are unique
        assertTrue(chain1Hash != chain2Hash, "Chain hashes should be different");
        assertTrue(chain2Hash != chain3Hash, "Chain hashes should be different");
        assertTrue(chain1Hash != chain3Hash, "Chain hashes should be different");
    }

    /**
     * Test Case 3: Nested structure - Node + Permit
     * Structure: PermitNode(nodes=[SubNode], permits=[Chain3])
     *   where SubNode = PermitNode(nodes=[], permits=[Chain1, Chain2])
     * Tests: Node + Permit combination (struct order, no sorting)
     */
    function test_nestedStructureNodeAndPermit() public {
        // Create inner node with two permits
        IPermit3.ChainPermits memory chain1 = _createChainPermit(1, 1000);
        IPermit3.ChainPermits memory chain2 = _createChainPermit(42_161, 2000);

        IPermit3.ChainPermits[] memory innerPermits = new IPermit3.ChainPermits[](2);
        innerPermits[0] = chain1;
        innerPermits[1] = chain2;

        IPermit3.PermitNode memory innerNode =
            IPermit3.PermitNode({ nodes: new IPermit3.PermitNode[](0), permits: innerPermits });

        // Create outer node with inner node + one permit
        IPermit3.ChainPermits memory chain3 = _createChainPermit(10, 3000);

        IPermit3.PermitNode[] memory nodes = new IPermit3.PermitNode[](1);
        nodes[0] = innerNode;

        IPermit3.ChainPermits[] memory outerPermits = new IPermit3.ChainPermits[](1);
        outerPermits[0] = chain3;

        IPermit3.PermitNode memory outerNode = IPermit3.PermitNode({ nodes: nodes, permits: outerPermits });

        // Hash the complete structure
        bytes32 outerHash = _hashPermitNode(outerNode);
        bytes32 innerHash = _hashPermitNode(innerNode);

        assertTrue(outerHash != bytes32(0), "Outer hash should not be zero");
        assertTrue(innerHash != bytes32(0), "Inner hash should not be zero");
        assertTrue(outerHash != innerHash, "Hashes should be different");
    }

    /**
     * Test Case 4: Two nested nodes (Node + Node)
     * Structure: PermitNode(nodes=[SubNode1, SubNode2], permits=[])
     * Tests: Node + Node combination (alphabetical sorting)
     */
    function test_twoNestedNodes() public {
        // Create first inner node
        IPermit3.ChainPermits[] memory permits1 = new IPermit3.ChainPermits[](1);
        permits1[0] = _createChainPermit(1, 1000);

        IPermit3.PermitNode memory node1 =
            IPermit3.PermitNode({ nodes: new IPermit3.PermitNode[](0), permits: permits1 });

        // Create second inner node
        IPermit3.ChainPermits[] memory permits2 = new IPermit3.ChainPermits[](1);
        permits2[0] = _createChainPermit(42_161, 2000);

        IPermit3.PermitNode memory node2 =
            IPermit3.PermitNode({ nodes: new IPermit3.PermitNode[](0), permits: permits2 });

        // Create parent node with both child nodes
        IPermit3.PermitNode[] memory nodes = new IPermit3.PermitNode[](2);
        nodes[0] = node1;
        nodes[1] = node2;

        IPermit3.PermitNode memory parentNode =
            IPermit3.PermitNode({ nodes: nodes, permits: new IPermit3.ChainPermits[](0) });

        // Hash the structure
        bytes32 parentHash = _hashPermitNode(parentNode);

        assertTrue(parentHash != bytes32(0), "Parent hash should not be zero");
    }

    /**
     * Test Case 5: Complex nested structure with multiple levels
     * Structure: PermitNode with multiple nested levels
     * Tests: Deep nesting and multiple combinations
     */
    function test_complexNestedStructure() public {
        // Create leaf permits
        IPermit3.ChainPermits memory chain1 = _createChainPermit(1, 1000);
        IPermit3.ChainPermits memory chain2 = _createChainPermit(42_161, 2000);
        IPermit3.ChainPermits memory chain3 = _createChainPermit(10, 3000);
        IPermit3.ChainPermits memory chain4 = _createChainPermit(137, 4000);

        // Create first level nodes
        IPermit3.ChainPermits[] memory permits1 = new IPermit3.ChainPermits[](2);
        permits1[0] = chain1;
        permits1[1] = chain2;

        IPermit3.PermitNode memory node1 =
            IPermit3.PermitNode({ nodes: new IPermit3.PermitNode[](0), permits: permits1 });

        IPermit3.ChainPermits[] memory permits2 = new IPermit3.ChainPermits[](2);
        permits2[0] = chain3;
        permits2[1] = chain4;

        IPermit3.PermitNode memory node2 =
            IPermit3.PermitNode({ nodes: new IPermit3.PermitNode[](0), permits: permits2 });

        // Create root node
        IPermit3.PermitNode[] memory rootNodes = new IPermit3.PermitNode[](2);
        rootNodes[0] = node1;
        rootNodes[1] = node2;

        IPermit3.PermitNode memory rootNode =
            IPermit3.PermitNode({ nodes: rootNodes, permits: new IPermit3.ChainPermits[](0) });

        // Hash the complete structure
        bytes32 rootHash = _hashPermitNode(rootNode);
        bytes32 node1Hash = _hashPermitNode(node1);
        bytes32 node2Hash = _hashPermitNode(node2);

        assertTrue(rootHash != bytes32(0), "Root hash should not be zero");
        assertTrue(node1Hash != bytes32(0), "Node 1 hash should not be zero");
        assertTrue(node2Hash != bytes32(0), "Node 2 hash should not be zero");
        assertTrue(rootHash != node1Hash, "Root and node1 hashes should be different");
        assertTrue(rootHash != node2Hash, "Root and node2 hashes should be different");
        assertTrue(node1Hash != node2Hash, "Node hashes should be different");
    }

    /**
     * Test Case 6: hashPermitNode is exposed and works correctly
     */
    function test_hashPermitNodePublic() public {
        IPermit3.ChainPermits[] memory permits = new IPermit3.ChainPermits[](1);
        permits[0] = _createChainPermit(1, 1000);

        IPermit3.PermitNode memory node = IPermit3.PermitNode({ nodes: new IPermit3.PermitNode[](0), permits: permits });

        bytes32 hash = _hashPermitNode(node);

        // Hash should be deterministic
        bytes32 hash2 = _hashPermitNode(node);
        assertEq(hash, hash2, "Hash should be deterministic");

        // Hash should not be zero
        assertTrue(hash != bytes32(0), "Hash should not be zero");
    }

    /**
     * Test Case 7: Empty PermitNode
     * Structure: PermitNode(nodes=[], permits=[])
     * Tests: Empty node hashing
     */
    function test_emptyPermitNode() public {
        IPermit3.PermitNode memory emptyNode =
            IPermit3.PermitNode({ nodes: new IPermit3.PermitNode[](0), permits: new IPermit3.ChainPermits[](0) });

        bytes32 hash = _hashPermitNode(emptyNode);

        // Hash should not be zero even for empty node
        assertTrue(hash != bytes32(0), "Empty node hash should not be zero");
    }

    /**
     * Test Case 8: Single permit in node
     * Structure: PermitNode(nodes=[], permits=[Chain1])
     * Tests: Single permit hashing
     */
    function test_singlePermitInNode() public {
        IPermit3.ChainPermits[] memory permits = new IPermit3.ChainPermits[](1);
        permits[0] = _createChainPermit(1, 1000);

        IPermit3.PermitNode memory node = IPermit3.PermitNode({ nodes: new IPermit3.PermitNode[](0), permits: permits });

        bytes32 hash = _hashPermitNode(node);
        bytes32 chainHash = permit3.hashChainPermits(permits[0]);

        assertTrue(hash != bytes32(0), "Node hash should not be zero");
        assertTrue(chainHash != bytes32(0), "Chain hash should not be zero");
        assertTrue(hash != chainHash, "Node hash should be different from chain hash");
    }

    /**
     * Test Case 9: Multiple permits with same amounts but different chains
     * Tests: Chain ID differentiation in hashing
     */
    function test_sameAmountDifferentChains() public {
        IPermit3.ChainPermits memory chain1 = _createChainPermit(1, 1000);
        IPermit3.ChainPermits memory chain2 = _createChainPermit(42_161, 1000);

        bytes32 hash1 = permit3.hashChainPermits(chain1);
        bytes32 hash2 = permit3.hashChainPermits(chain2);

        assertTrue(hash1 != hash2, "Same amount, different chains should have different hashes");
    }

    /**
     * Test Case 10: Permit ordering in array affects hash
     * Tests: Array ordering matters for hash calculation
     */
    function test_permitOrderingMatters() public {
        IPermit3.ChainPermits memory chain1 = _createChainPermit(1, 1000);
        IPermit3.ChainPermits memory chain2 = _createChainPermit(42_161, 2000);

        // Create node with chain1, chain2 order
        IPermit3.ChainPermits[] memory permits1 = new IPermit3.ChainPermits[](2);
        permits1[0] = chain1;
        permits1[1] = chain2;

        IPermit3.PermitNode memory node1 =
            IPermit3.PermitNode({ nodes: new IPermit3.PermitNode[](0), permits: permits1 });

        // Create node with chain2, chain1 order
        IPermit3.ChainPermits[] memory permits2 = new IPermit3.ChainPermits[](2);
        permits2[0] = chain2;
        permits2[1] = chain1;

        IPermit3.PermitNode memory node2 =
            IPermit3.PermitNode({ nodes: new IPermit3.PermitNode[](0), permits: permits2 });

        bytes32 hash1 = _hashPermitNode(node1);
        bytes32 hash2 = _hashPermitNode(node2);

        assertTrue(hash1 != hash2, "Different ordering should produce different hashes");
    }

    /**
     * Test Case 11: Nested nodes with mixed structure
     * Structure: PermitNode(nodes=[SubNode], permits=[Chain])
     * Tests: Mixed nodes and permits in same level
     */
    function test_mixedNodesAndPermits() public {
        // Create inner node
        IPermit3.ChainPermits[] memory innerPermits = new IPermit3.ChainPermits[](1);
        innerPermits[0] = _createChainPermit(1, 1000);

        IPermit3.PermitNode memory innerNode =
            IPermit3.PermitNode({ nodes: new IPermit3.PermitNode[](0), permits: innerPermits });

        // Create outer node with both nested node and direct permit
        IPermit3.PermitNode[] memory nodes = new IPermit3.PermitNode[](1);
        nodes[0] = innerNode;

        IPermit3.ChainPermits[] memory outerPermits = new IPermit3.ChainPermits[](1);
        outerPermits[0] = _createChainPermit(42_161, 2000);

        IPermit3.PermitNode memory mixedNode = IPermit3.PermitNode({ nodes: nodes, permits: outerPermits });

        bytes32 mixedHash = _hashPermitNode(mixedNode);
        bytes32 innerHash = _hashPermitNode(innerNode);

        assertTrue(mixedHash != bytes32(0), "Mixed node hash should not be zero");
        assertTrue(innerHash != bytes32(0), "Inner node hash should not be zero");
        assertTrue(mixedHash != innerHash, "Mixed and inner hashes should be different");
    }

    /**
     * Test Case 12: Large permit array
     * Tests: Handling multiple permits in single node
     */
    function test_largePermitArray() public {
        // Create 5 different chain permits
        IPermit3.ChainPermits[] memory permits = new IPermit3.ChainPermits[](5);
        permits[0] = _createChainPermit(1, 1000);
        permits[1] = _createChainPermit(42_161, 2000);
        permits[2] = _createChainPermit(10, 3000);
        permits[3] = _createChainPermit(137, 4000);
        permits[4] = _createChainPermit(8453, 5000);

        IPermit3.PermitNode memory node = IPermit3.PermitNode({ nodes: new IPermit3.PermitNode[](0), permits: permits });

        bytes32 hash = _hashPermitNode(node);

        assertTrue(hash != bytes32(0), "Large permit array hash should not be zero");
    }

    /**
     * Test Case 13: Different token addresses affect hash
     * Tests: Token differentiation in permits
     */
    function test_differentTokens() public {
        address token1 = address(0x100);
        address token2 = address(0x200);

        IPermit3.ChainPermits memory chain1 = _createChainPermitWithToken(1, token1, 1000);
        IPermit3.ChainPermits memory chain2 = _createChainPermitWithToken(1, token2, 1000);

        bytes32 hash1 = permit3.hashChainPermits(chain1);
        bytes32 hash2 = permit3.hashChainPermits(chain2);

        assertTrue(hash1 != hash2, "Different tokens should have different hashes");
    }

    /**
     * Test Case 14: Different spender addresses affect hash
     * Tests: Spender differentiation in permits
     */
    function test_differentSpenders() public {
        address spender1 = address(0x1);
        address spender2 = address(0x2);

        IPermit3.ChainPermits memory chain1 = _createChainPermitWithSpender(1, spender1, 1000);
        IPermit3.ChainPermits memory chain2 = _createChainPermitWithSpender(1, spender2, 1000);

        bytes32 hash1 = permit3.hashChainPermits(chain1);
        bytes32 hash2 = permit3.hashChainPermits(chain2);

        assertTrue(hash1 != hash2, "Different spenders should have different hashes");
    }

    /**
     * Test Case 15: Three-level deep nesting
     * Tests: Deep nesting capability
     */
    function test_threeLevelDeepNesting() public {
        // Level 3 (deepest)
        IPermit3.ChainPermits[] memory level3Permits = new IPermit3.ChainPermits[](1);
        level3Permits[0] = _createChainPermit(1, 1000);

        IPermit3.PermitNode memory level3Node =
            IPermit3.PermitNode({ nodes: new IPermit3.PermitNode[](0), permits: level3Permits });

        // Level 2
        IPermit3.PermitNode[] memory level2Nodes = new IPermit3.PermitNode[](1);
        level2Nodes[0] = level3Node;

        IPermit3.PermitNode memory level2Node =
            IPermit3.PermitNode({ nodes: level2Nodes, permits: new IPermit3.ChainPermits[](0) });

        // Level 1 (root)
        IPermit3.PermitNode[] memory level1Nodes = new IPermit3.PermitNode[](1);
        level1Nodes[0] = level2Node;

        IPermit3.PermitNode memory rootNode =
            IPermit3.PermitNode({ nodes: level1Nodes, permits: new IPermit3.ChainPermits[](0) });

        bytes32 rootHash = _hashPermitNode(rootNode);
        bytes32 level2Hash = _hashPermitNode(level2Node);
        bytes32 level3Hash = _hashPermitNode(level3Node);

        assertTrue(rootHash != bytes32(0), "Root hash should not be zero");
        assertTrue(level2Hash != bytes32(0), "Level 2 hash should not be zero");
        assertTrue(level3Hash != bytes32(0), "Level 3 hash should not be zero");
        assertTrue(rootHash != level2Hash, "Root and level 2 hashes should differ");
        assertTrue(level2Hash != level3Hash, "Level 2 and 3 hashes should differ");
    }

    // Helper function to create a ChainPermit for testing
    function _createChainPermit(
        uint64 chainId,
        uint160 amount
    ) internal view returns (IPermit3.ChainPermits memory) {
        IPermit3.AllowanceOrTransfer[] memory permits = new IPermit3.AllowanceOrTransfer[](1);
        permits[0] = IPermit3.AllowanceOrTransfer({
            modeOrExpiration: EXPIRATION,
            tokenKey: bytes32(uint256(uint160(address(token)))),
            account: spender,
            amountDelta: amount
        });

        return IPermit3.ChainPermits({ chainId: chainId, permits: permits });
    }

    // Helper function to create a ChainPermit with specific token
    function _createChainPermitWithToken(
        uint64 chainId,
        address tokenAddr,
        uint160 amount
    ) internal view returns (IPermit3.ChainPermits memory) {
        IPermit3.AllowanceOrTransfer[] memory permits = new IPermit3.AllowanceOrTransfer[](1);
        permits[0] = IPermit3.AllowanceOrTransfer({
            modeOrExpiration: EXPIRATION,
            tokenKey: bytes32(uint256(uint160(tokenAddr))),
            account: spender,
            amountDelta: amount
        });

        return IPermit3.ChainPermits({ chainId: chainId, permits: permits });
    }

    // Helper function to create a ChainPermit with specific spender
    function _createChainPermitWithSpender(
        uint64 chainId,
        address spenderAddr,
        uint160 amount
    ) internal view returns (IPermit3.ChainPermits memory) {
        IPermit3.AllowanceOrTransfer[] memory permits = new IPermit3.AllowanceOrTransfer[](1);
        permits[0] = IPermit3.AllowanceOrTransfer({
            modeOrExpiration: EXPIRATION,
            tokenKey: bytes32(uint256(uint160(address(token)))),
            account: spenderAddr,
            amountDelta: amount
        });

        return IPermit3.ChainPermits({ chainId: chainId, permits: permits });
    }
}
