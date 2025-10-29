// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { TypedEncoder } from "../../src/lib/TypedEncoder.sol";
import "../utils/TestBase.sol";

/**
 * @title TypedEncoderPackedEncodingTest
 * @notice Tests for the Packed encoding type which computes abi.encodePacked(all_fields) without hashing
 * @dev Tests verify that Packed encoding produces correct compact byte sequences without intermediate hashing
 */
contract TypedEncoderPackedEncodingTest is TestBase {
    using TypedEncoder for TypedEncoder.Struct;

    function setUp() public override {
        super.setUp();
    }

    // ============ Section 1: Basic Primitives ============

    struct PackedStatic {
        uint256 value;
        address addr;
    }

    function testPackedStaticFieldsOnly() public pure {
        TypedEncoder.Struct memory encoded = TypedEncoder.Struct({
            typeHash: keccak256("PackedStatic(uint256 value,address addr)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Packed
        });
        encoded.chunks[0].primitives = new TypedEncoder.Primitive[](2);
        encoded.chunks[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(42)) });
        encoded.chunks[0].primitives[1] = TypedEncoder.Primitive({
            isDynamic: false, data: abi.encode(address(0x1234567890123456789012345678901234567890))
        });

        // Expected: abi.encodePacked(abi.encode(uint256(42)), abi.encode(address(0x1234...)))
        // Static types use abi.encode (32-byte padded)
        bytes memory expected =
            abi.encodePacked(abi.encode(uint256(42)), abi.encode(address(0x1234567890123456789012345678901234567890)));
        bytes memory actual = encoded.encode();

        // Verify length (64 bytes: 32 for uint256 + 32 for address)
        assertEq(actual.length, 64, "Length mismatch");
        assertEq(actual, expected, "Packed encoding mismatch");
    }

    struct PackedDynamic {
        string text;
    }

    function testPackedDynamicFieldOnly() public pure {
        TypedEncoder.Struct memory encoded = TypedEncoder.Struct({
            typeHash: keccak256("PackedDynamic(string text)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Packed
        });
        encoded.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        encoded.chunks[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: true, data: abi.encodePacked("hello") });

        // Expected: abi.encodePacked("hello")
        // Dynamic types use raw bytes (no length prefix)
        bytes memory expected = abi.encodePacked("hello");
        bytes memory actual = encoded.encode();

        // Verify length (5 bytes for "hello")
        assertEq(actual.length, 5, "Length mismatch");
        assertEq(actual, expected, "Packed encoding mismatch");
    }

    struct PackedMixed {
        uint256 id;
        string name;
    }

    function testPackedMixedStaticDynamic() public pure {
        TypedEncoder.Struct memory encoded = TypedEncoder.Struct({
            typeHash: keccak256("PackedMixed(uint256 id,string name)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Packed
        });
        encoded.chunks[0].primitives = new TypedEncoder.Primitive[](2);
        encoded.chunks[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(123)) });
        encoded.chunks[0].primitives[1] = TypedEncoder.Primitive({ isDynamic: true, data: abi.encodePacked("Alice") });

        // Expected: abi.encodePacked(abi.encode(uint256(123)), "Alice")
        bytes memory expected = abi.encodePacked(abi.encode(uint256(123)), "Alice");
        bytes memory actual = encoded.encode();

        // Verify length (32 bytes for uint256 + 5 bytes for "Alice")
        assertEq(actual.length, 37, "Length mismatch");
        assertEq(actual, expected, "Packed encoding mismatch");
    }

    struct PackedFixedBytes {
        bytes32 hash;
        uint256 value;
    }

    function testPackedFixedBytes() public pure {
        bytes32 testHash = keccak256("test");

        TypedEncoder.Struct memory encoded = TypedEncoder.Struct({
            typeHash: keccak256("PackedFixedBytes(bytes32 hash,uint256 value)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Packed
        });
        encoded.chunks[0].primitives = new TypedEncoder.Primitive[](2);
        encoded.chunks[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(testHash) });
        encoded.chunks[0].primitives[1] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(999)) });

        // Expected: abi.encodePacked(abi.encode(testHash), abi.encode(uint256(999)))
        bytes memory expected = abi.encodePacked(abi.encode(testHash), abi.encode(uint256(999)));
        bytes memory actual = encoded.encode();

        // Verify length (64 bytes: 32 + 32)
        assertEq(actual.length, 64, "Length mismatch");
        assertEq(actual, expected, "Packed encoding mismatch");
    }

    struct PackedEmptyDynamic {
        string text;
        bytes data;
    }

    function testPackedEmptyDynamic() public pure {
        TypedEncoder.Struct memory encoded = TypedEncoder.Struct({
            typeHash: keccak256("PackedEmptyDynamic(string text,bytes data)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Packed
        });
        encoded.chunks[0].primitives = new TypedEncoder.Primitive[](2);
        encoded.chunks[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: true, data: "" });
        encoded.chunks[0].primitives[1] = TypedEncoder.Primitive({ isDynamic: true, data: "" });

        // Expected: abi.encodePacked("", "") = empty bytes
        bytes memory expected = abi.encodePacked("", "");
        bytes memory actual = encoded.encode();

        // Verify zero length
        assertEq(actual.length, 0, "Length mismatch");
        assertEq(actual, expected, "Packed encoding mismatch");
    }

    // ============ Section 2: Multiple Chunks ============

    struct PackedMultiChunk {
        uint256 a;
        string b;
        uint256 c;
    }

    function testPackedMultipleChunks() public pure {
        TypedEncoder.Struct memory encoded = TypedEncoder.Struct({
            typeHash: keccak256("PackedMultiChunk(uint256 a,string b,uint256 c)"),
            chunks: new TypedEncoder.Chunk[](3),
            encodingType: TypedEncoder.EncodingType.Packed
        });

        // Chunk 0: first uint256
        encoded.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        encoded.chunks[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(100)) });

        // Chunk 1: string
        encoded.chunks[1].primitives = new TypedEncoder.Primitive[](1);
        encoded.chunks[1].primitives[0] = TypedEncoder.Primitive({ isDynamic: true, data: abi.encodePacked("middle") });

        // Chunk 2: second uint256
        encoded.chunks[2].primitives = new TypedEncoder.Primitive[](1);
        encoded.chunks[2].primitives[0] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(200)) });

        // Expected: abi.encodePacked(abi.encode(uint256(100)), "middle", abi.encode(uint256(200)))
        // Verify field ordering is preserved across chunks
        bytes memory expected = abi.encodePacked(abi.encode(uint256(100)), "middle", abi.encode(uint256(200)));
        bytes memory actual = encoded.encode();

        // Verify length (32 + 6 + 32 = 70 bytes)
        assertEq(actual.length, 70, "Length mismatch");
        assertEq(actual, expected, "Packed encoding mismatch");
    }

    // ============ Section 3: Nested Packed Structs ============

    struct InnerPacked {
        uint256 value;
    }

    struct OuterPacked {
        uint256 id;
        InnerPacked inner;
    }

    function testPackedNestedPackedStruct() public pure {
        // Create inner struct with Packed encoding
        TypedEncoder.Struct memory inner = TypedEncoder.Struct({
            typeHash: keccak256("InnerPacked(uint256 value)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Packed
        });
        inner.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        inner.chunks[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(42)) });

        // Create outer struct with Packed encoding
        TypedEncoder.Struct memory outer = TypedEncoder.Struct({
            typeHash: keccak256("OuterPacked(uint256 id,InnerPacked inner)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Packed
        });
        outer.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        outer.chunks[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(123)) });
        outer.chunks[0].structs = new TypedEncoder.Struct[](1);
        outer.chunks[0].structs[0] = inner;

        // Expected: inner packs to abi.encodePacked(abi.encode(uint256(42)))
        // Then outer packs to abi.encodePacked(abi.encode(uint256(123)), inner_packed)
        // Recursive packing without intermediate hashing
        bytes memory innerPacked = abi.encodePacked(abi.encode(uint256(42)));
        bytes memory expected = abi.encodePacked(abi.encode(uint256(123)), innerPacked);
        bytes memory actual = outer.encode();

        // Verify length (32 + 32 = 64 bytes)
        assertEq(actual.length, 64, "Length mismatch");
        assertEq(actual, expected, "Packed encoding mismatch");
    }

    struct InnerHash {
        uint256 value;
    }

    struct OuterWithHash {
        uint256 id;
        InnerHash inner;
    }

    function testPackedNestedHashStruct() public pure {
        // Create inner struct with Hash encoding
        TypedEncoder.Struct memory inner = TypedEncoder.Struct({
            typeHash: keccak256("InnerHash(uint256 value)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Hash
        });
        inner.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        inner.chunks[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(42)) });

        // Create outer struct with Packed encoding
        TypedEncoder.Struct memory outer = TypedEncoder.Struct({
            typeHash: keccak256("OuterWithHash(uint256 id,InnerHash inner)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Packed
        });
        outer.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        outer.chunks[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(123)) });
        outer.chunks[0].structs = new TypedEncoder.Struct[](1);
        outer.chunks[0].structs[0] = inner;

        // Expected: inner is hashed first, then bytes32 is packed
        bytes32 innerHash = keccak256(abi.encodePacked(abi.encode(uint256(42))));
        bytes memory expected = abi.encodePacked(abi.encode(uint256(123)), innerHash);
        bytes memory actual = outer.encode();

        // Verify length (32 + 32 = 64 bytes)
        assertEq(actual.length, 64, "Length mismatch");
        assertEq(actual, expected, "Packed encoding mismatch");
    }

    // ============ Section 4: Arrays in Packed Encoding ============

    struct PackedWithArray {
        uint256 id;
        uint256[] values;
    }

    function testPackedWithArrays() public pure {
        TypedEncoder.Chunk[] memory arrayElements = new TypedEncoder.Chunk[](3);
        arrayElements[0].primitives = new TypedEncoder.Primitive[](1);
        arrayElements[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(1)) });
        arrayElements[1].primitives = new TypedEncoder.Primitive[](1);
        arrayElements[1].primitives[0] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(2)) });
        arrayElements[2].primitives = new TypedEncoder.Primitive[](1);
        arrayElements[2].primitives[0] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(3)) });

        TypedEncoder.Struct memory encoded = TypedEncoder.Struct({
            typeHash: keccak256("PackedWithArray(uint256 id,uint256[] values)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Packed
        });
        encoded.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        encoded.chunks[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(999)) });
        encoded.chunks[0].arrays = new TypedEncoder.Array[](1);
        encoded.chunks[0].arrays[0] = TypedEncoder.Array({ isDynamic: true, data: arrayElements });

        // Expected: abi.encodePacked(abi.encode(uint256(999)), abi.encode(uint256(1)), abi.encode(uint256(2)),
        // abi.encode(uint256(3)))
        // Arrays are packed without length prefix
        bytes memory expected = abi.encodePacked(
            abi.encode(uint256(999)), abi.encode(uint256(1)), abi.encode(uint256(2)), abi.encode(uint256(3))
        );
        bytes memory actual = encoded.encode();

        // Verify length (32 * 4 = 128 bytes)
        assertEq(actual.length, 128, "Length mismatch");
        assertEq(actual, expected, "Packed encoding mismatch");
    }

    // ============ Section 5: Packed as Nested Field ============

    struct ParentWithPacked {
        uint256 id;
        bytes packedData;
    }

    function testPackedAsNestedField() public pure {
        // Create Packed-encoded struct
        TypedEncoder.Struct memory packedStruct = TypedEncoder.Struct({
            typeHash: keccak256("Data(uint256 value,string name)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Packed
        });
        packedStruct.chunks[0].primitives = new TypedEncoder.Primitive[](2);
        packedStruct.chunks[0].primitives[0] =
            TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(42)) });
        packedStruct.chunks[0].primitives[1] =
            TypedEncoder.Primitive({ isDynamic: true, data: abi.encodePacked("test") });

        // Create parent struct with Struct encoding that includes the packed data
        TypedEncoder.Struct memory parent = TypedEncoder.Struct({
            typeHash: keccak256("ParentWithPacked(uint256 id,bytes packedData)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Struct
        });
        parent.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        parent.chunks[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(999)) });
        parent.chunks[0].structs = new TypedEncoder.Struct[](1);
        parent.chunks[0].structs[0] = packedStruct;

        // Expected packed data from inner struct
        bytes memory innerPacked = abi.encodePacked(abi.encode(uint256(42)), "test");

        // Expected parent encoding (Packed struct is wrapped as dynamic bytes in parent)
        // Parent is dynamic, so it includes offset wrapper
        // Format: [offset to struct (32)][id (32 bytes)][offset to bytes (32 bytes)][bytes length (32 bytes)][bytes
        // data][padding]
        bytes memory innerEncoding = abi.encode(uint256(999), innerPacked);
        bytes memory expected = abi.encodePacked(abi.encode(uint256(32)), innerEncoding);
        bytes memory actual = parent.encode();

        assertEq(actual, expected, "Packed as nested field mismatch");
    }

    // ============ Section 6: Edge Cases ============

    function testPackedEmptyStruct() public pure {
        TypedEncoder.Struct memory encoded = TypedEncoder.Struct({
            typeHash: keccak256("Empty()"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Packed
        });

        // Expected: abi.encodePacked() = empty bytes
        bytes memory expected = abi.encodePacked("");
        bytes memory actual = encoded.encode();

        // Verify zero length
        assertEq(actual.length, 0, "Length mismatch");
        assertEq(actual, expected, "Packed encoding mismatch");
    }

    struct PackedLargeData {
        string data;
        uint256[] values;
    }

    function testPackedVeryLargeData() public pure {
        // Create a large string (100 bytes)
        bytes memory largeString = new bytes(100);
        for (uint256 i = 0; i < 100; i++) {
            largeString[i] = bytes1(uint8(65 + (i % 26))); // A-Z repeated
        }

        // Create array with 10 uint256 values
        TypedEncoder.Chunk[] memory arrayElements = new TypedEncoder.Chunk[](10);
        for (uint256 i = 0; i < 10; i++) {
            arrayElements[i].primitives = new TypedEncoder.Primitive[](1);
            arrayElements[i].primitives[0] =
                TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(i * 100)) });
        }

        TypedEncoder.Struct memory encoded = TypedEncoder.Struct({
            typeHash: keccak256("PackedLargeData(string data,uint256[] values)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Packed
        });
        encoded.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        encoded.chunks[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: true, data: largeString });
        encoded.chunks[0].arrays = new TypedEncoder.Array[](1);
        encoded.chunks[0].arrays[0] = TypedEncoder.Array({ isDynamic: true, data: arrayElements });

        // Expected: abi.encodePacked(largeString, all_array_elements)
        bytes memory expected = largeString;
        for (uint256 i = 0; i < 10; i++) {
            expected = abi.encodePacked(expected, abi.encode(uint256(i * 100)));
        }
        bytes memory actual = encoded.encode();

        // Verify length (100 bytes for string + 320 bytes for 10 uint256s = 420 bytes)
        assertEq(actual.length, 420, "Length mismatch");
        assertEq(actual, expected, "Packed encoding mismatch");
    }

    struct PackedWithBytes {
        bytes data;
    }

    function testPackedWithBytesData() public pure {
        TypedEncoder.Struct memory encoded = TypedEncoder.Struct({
            typeHash: keccak256("PackedWithBytes(bytes data)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Packed
        });
        encoded.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        encoded.chunks[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: true, data: hex"deadbeef" });

        // Expected: abi.encodePacked(hex"deadbeef")
        bytes memory expected = abi.encodePacked(hex"deadbeef");
        bytes memory actual = encoded.encode();

        // Verify length (4 bytes)
        assertEq(actual.length, 4, "Length mismatch");
        assertEq(actual, expected, "Packed encoding mismatch");
    }

    struct PackedMultipleTypes {
        uint256 a;
        address b;
        bool c;
        bytes32 d;
        string e;
    }

    function testPackedMultipleTypes() public pure {
        TypedEncoder.Struct memory encoded = TypedEncoder.Struct({
            typeHash: keccak256("PackedMultipleTypes(uint256 a,address b,bool c,bytes32 d,string e)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Packed
        });
        encoded.chunks[0].primitives = new TypedEncoder.Primitive[](5);
        encoded.chunks[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(42)) });
        encoded.chunks[0].primitives[1] = TypedEncoder.Primitive({
            isDynamic: false, data: abi.encode(address(0x1111111111111111111111111111111111111111))
        });
        encoded.chunks[0].primitives[2] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(true) });
        encoded.chunks[0].primitives[3] =
            TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(bytes32("test")) });
        encoded.chunks[0].primitives[4] = TypedEncoder.Primitive({ isDynamic: true, data: abi.encodePacked("hello") });

        // Expected: all fields packed in order
        bytes memory expected = abi.encodePacked(
            abi.encode(uint256(42)),
            abi.encode(address(0x1111111111111111111111111111111111111111)),
            abi.encode(true),
            abi.encode(bytes32("test")),
            "hello"
        );
        bytes memory actual = encoded.encode();

        // Verify length (32 + 32 + 32 + 32 + 5 = 133 bytes)
        assertEq(actual.length, 133, "Length mismatch");
        assertEq(actual, expected, "Packed encoding mismatch");
    }

    struct PackedStringArray {
        string[] tags;
    }

    function testPackedWithDynamicArray() public pure {
        TypedEncoder.Chunk[] memory arrayElements = new TypedEncoder.Chunk[](2);
        arrayElements[0].primitives = new TypedEncoder.Primitive[](1);
        arrayElements[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: true, data: abi.encodePacked("tag1") });
        arrayElements[1].primitives = new TypedEncoder.Primitive[](1);
        arrayElements[1].primitives[0] = TypedEncoder.Primitive({ isDynamic: true, data: abi.encodePacked("tag2") });

        TypedEncoder.Struct memory encoded = TypedEncoder.Struct({
            typeHash: keccak256("PackedStringArray(string[] tags)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Packed
        });
        encoded.chunks[0].arrays = new TypedEncoder.Array[](1);
        encoded.chunks[0].arrays[0] = TypedEncoder.Array({ isDynamic: true, data: arrayElements });

        // Expected: abi.encodePacked("tag1", "tag2")
        bytes memory expected = abi.encodePacked("tag1", "tag2");
        bytes memory actual = encoded.encode();

        // Verify length (8 bytes)
        assertEq(actual.length, 8, "Length mismatch");
        assertEq(actual, expected, "Packed encoding mismatch");
    }
}
