// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "../src/Permit3.sol";
import "../src/interfaces/IPermit3.sol";

/**
 * @title NestedStructureTest
 * @notice Tests for the new Nested structure functionality in Permit3
 * @dev Tests the public interface and integration of nested structures
 */
contract NestedStructureTest is Test {
    Permit3 permit3;

    // Test accounts
    address owner = address(0x1);
    address spender = address(0x2);
    address token1 = address(0x100);
    address token2 = address(0x200);

    // Test data
    bytes32 salt = bytes32(uint256(0x12345));
    uint48 deadline;
    uint48 timestamp;

    function setUp() public {
        permit3 = new Permit3();
        deadline = uint48(block.timestamp + 1000);
        timestamp = uint48(block.timestamp);
    }

    function test_permitNodeTypehashDefined() public {
        // Test that the permit node typehash constant is properly defined
        bytes32 permitNodeTypehash = permit3.MULTICHAIN_PERMIT3_TYPEHASH();
        assertTrue(permitNodeTypehash != bytes32(0), "PermitNode typehash should be defined");
    }

    function test_chainPermitsHashing() public {
        // Test that chain permits can be hashed consistently
        IPermit3.AllowanceOrTransfer[] memory permits = _createSinglePermit(token1, spender, 1000);
        IPermit3.ChainPermits memory chainPermits = IPermit3.ChainPermits({ chainId: 1, permits: permits });

        bytes32 hash1 = permit3.hashChainPermits(chainPermits);
        bytes32 hash2 = permit3.hashChainPermits(chainPermits);

        assertEq(hash1, hash2, "Chain permits hashing should be deterministic");
        assertTrue(hash1 != bytes32(0), "Hash should not be zero");
    }

    function test_permitWithProofStructureExists() public {
        // Test that the new permit function with proofStructure exists and has correct signature
        // This test just verifies the function exists without calling internal functions

        // Create chain permits for current chain
        IPermit3.AllowanceOrTransfer[] memory currentPermits = _createSinglePermit(token1, spender, 1000);
        IPermit3.ChainPermits memory currentChainPermits =
            IPermit3.ChainPermits({ chainId: uint64(block.chainid), permits: currentPermits });

        // Use a simple proof structure encoding (just a hash)
        bytes32 proofStructure = keccak256("test_proof_structure");

        // Create a simple proof
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = keccak256("test_proof");

        // Mock signature
        bytes memory signature = "mock_signature";

        // Test that the function exists and accepts the parameters
        // Expected to revert due to invalid signature, but shows function exists
        vm.expectRevert();
        permit3.permit(
            IPermit3.PermitTree({
                proofStructure: proofStructure, currentChainPermits: currentChainPermits, proof: proof
            }),
            IPermit3.Signature({
                    owner: owner, salt: salt, deadline: deadline, timestamp: timestamp, signature: signature
                })
        );
    }

    function test_permitNodeStructureCompiles() public {
        // Test that we can create PermitNode structures without compilation errors
        IPermit3.PermitNode[] memory nodes = new IPermit3.PermitNode[](0);
        IPermit3.ChainPermits[] memory permits = new IPermit3.ChainPermits[](1);

        permits[0] = IPermit3.ChainPermits({ chainId: 1, permits: _createSinglePermit(token1, spender, 1000) });

        IPermit3.PermitNode memory permitNode = IPermit3.PermitNode({ nodes: nodes, permits: permits });

        // Test that we can access the fields
        assertEq(permitNode.nodes.length, 0, "Should have no child nodes");
        assertEq(permitNode.permits.length, 1, "Should have one permit");
        assertEq(permitNode.permits[0].chainId, 1, "Should have correct chain ID");
    }

    function test_complexPermitNodeStructure() public {
        // Test creating a more complex permit node structure
        IPermit3.ChainPermits[] memory permits1 = new IPermit3.ChainPermits[](1);
        permits1[0] = IPermit3.ChainPermits({ chainId: 1, permits: _createSinglePermit(token1, spender, 1000) });

        IPermit3.ChainPermits[] memory permits2 = new IPermit3.ChainPermits[](1);
        permits2[0] = IPermit3.ChainPermits({ chainId: 42_161, permits: _createSinglePermit(token2, spender, 500) });

        // Create child nodes
        IPermit3.PermitNode[] memory nodes = new IPermit3.PermitNode[](2);
        nodes[0] = IPermit3.PermitNode({ nodes: new IPermit3.PermitNode[](0), permits: permits1 });
        nodes[1] = IPermit3.PermitNode({ nodes: new IPermit3.PermitNode[](0), permits: permits2 });

        IPermit3.PermitNode memory rootNode =
            IPermit3.PermitNode({ nodes: nodes, permits: new IPermit3.ChainPermits[](0) });

        // Verify structure
        assertEq(rootNode.nodes.length, 2, "Should have two child nodes");
        assertEq(rootNode.permits.length, 0, "Root should have no direct permits");
        assertEq(rootNode.nodes[0].permits.length, 1, "First child should have one permit");
        assertEq(rootNode.nodes[1].permits.length, 1, "Second child should have one permit");
    }

    // Helper function to create a single permit
    function _createSinglePermit(
        address token,
        address account,
        uint160 amount
    ) internal view returns (IPermit3.AllowanceOrTransfer[] memory) {
        IPermit3.AllowanceOrTransfer[] memory permits = new IPermit3.AllowanceOrTransfer[](1);
        permits[0] = IPermit3.AllowanceOrTransfer({
            modeOrExpiration: uint48(block.timestamp + 1000),
            tokenKey: bytes32(uint256(uint160(token))),
            account: account,
            amountDelta: amount
        });
        return permits;
    }
}
