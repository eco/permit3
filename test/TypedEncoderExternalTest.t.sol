// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "../src/lib/TypedEncoder.sol";
import "./utils/TypedEncoderExternalHarness.sol";
import "forge-std/Test.sol";

/**
 * @title TypedEncoderExternalTest
 * @notice Tests for external function usage patterns with TypedEncoder
 */
contract TypedEncoderExternalTest is Test {
    using TypedEncoder for TypedEncoder.Struct;

    TypedEncoderExternalHarness harness;

    function setUp() public {
        harness = new TypedEncoderExternalHarness();
    }

    /**
     * @notice Test Approach 3: Building TypedEncoder.Struct internally from primitive data
     * @dev This approach WORKS because we never pass TypedEncoder.Struct as external parameter
     */
    function test_encodeFromPrimitives() public view {
        // Create test data - simple struct with two uint256 values
        bytes32 typeHash = keccak256("TestStruct(uint256 a,uint256 b)");
        bytes[] memory primitiveData = new bytes[](2);
        primitiveData[0] = abi.encode(uint256(42));
        primitiveData[1] = abi.encode(uint256(100));

        // Call external function that builds TypedEncoder.Struct internally
        bytes memory result = harness.encodeFromPrimitives(typeHash, primitiveData);

        // Verify it produced output
        assertTrue(result.length > 0, "Should produce encoded output");

        // Verify against direct internal usage
        TypedEncoder.Struct memory s = TypedEncoder.Struct({
            typeHash: typeHash, encodingType: TypedEncoder.EncodingType.Struct, chunks: new TypedEncoder.Chunk[](1)
        });

        s.chunks[0].primitives = new TypedEncoder.Primitive[](2);
        s.chunks[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(42)) });
        s.chunks[0].primitives[1] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(100)) });

        bytes memory expected = s.encode();

        // Should produce same result
        assertEq(result, expected, "External harness should produce same encoding as internal");
    }

    /**
     * @notice Demonstrate that we CANNOT use abi.encode/decode with TypedEncoder.Struct
     * @dev This test documents the complete limitation
     */
    function test_cannotAbiEncodeOrDecodeStruct() public pure {
        // Build a TypedEncoder.Struct internally
        TypedEncoder.Struct memory s = TypedEncoder.Struct({
            typeHash: keccak256("Test(uint256 x)"),
            encodingType: TypedEncoder.EncodingType.Struct,
            chunks: new TypedEncoder.Chunk[](0)
        });

        // CANNOT abi.encode (Error 2056: "This type cannot be encoded"):
        // bytes memory encoded = abi.encode(s);

        // CANNOT abi.decode (Error 9611: "Decoding type not supported"):
        // TypedEncoder.Struct memory decoded = abi.decode(someBytes, (TypedEncoder.Struct));

        // Workaround: Build internally from non-recursive parameters
        // (See test_encodeFromPrimitives)

        // Just to make this a valid test function
        assertTrue(s.typeHash != bytes32(0), "Struct exists internally");
    }

    /**
     * @notice Test that TypedEncoder.Struct works fine in internal functions
     * @dev This is the current pattern used throughout the test suite
     */
    function test_internalUsageWorks() public pure {
        TypedEncoder.Struct memory s = TypedEncoder.Struct({
            typeHash: keccak256("Test(uint256 x)"),
            encodingType: TypedEncoder.EncodingType.Struct,
            chunks: new TypedEncoder.Chunk[](1)
        });

        s.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        s.chunks[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(123)) });

        // All these internal operations work perfectly
        bytes memory encoded = s.encode();
        bytes32 hashed = s.hash();

        assertTrue(encoded.length > 0, "Encoding works internally");
        assertTrue(hashed != bytes32(0), "Hashing works internally");
    }
}
