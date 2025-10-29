// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { TypedEncoder } from "../../src/lib/TypedEncoder.sol";
import "../utils/TestBase.sol";

/**
 * @title TypedEncoderHashEncodingTest
 * @notice Tests for the Hash encoding type which computes keccak256(abi.encodePacked(all_fields))
 * @dev Tests verify that Hash encoding produces correct compact hash commitments
 */
contract TypedEncoderHashEncodingTest is TestBase {
    using TypedEncoder for TypedEncoder.Struct;

    function setUp() public override {
        super.setUp();
    }

    // ============ Section 1: Basic Primitives ============

    struct HashStatic {
        uint256 value;
        address addr;
    }

    function testHashStaticFieldsOnly() public pure {
        TypedEncoder.Struct memory encoded = TypedEncoder.Struct({
            typeHash: keccak256("HashStatic(uint256 value,address addr)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Hash
        });
        encoded.chunks[0].primitives = new TypedEncoder.Primitive[](2);
        encoded.chunks[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(42)) });
        encoded.chunks[0].primitives[1] = TypedEncoder.Primitive({
            isDynamic: false, data: abi.encode(address(0x1234567890123456789012345678901234567890))
        });

        // Expected: keccak256(abi.encodePacked(uint256(42), address(0x1234...)))
        bytes32 expectedHash = keccak256(
            abi.encodePacked(abi.encode(uint256(42)), abi.encode(address(0x1234567890123456789012345678901234567890)))
        );
        bytes memory actual = encoded.encode();

        // Verify it returns 32 bytes
        assertEq(actual.length, 32);

        // Verify the hash value
        bytes32 actualHash;
        assembly {
            actualHash := mload(add(actual, 32))
        }
        assertEq(actualHash, expectedHash);
    }

    struct HashDynamic {
        string text;
    }

    function testHashDynamicFieldOnly() public pure {
        TypedEncoder.Struct memory encoded = TypedEncoder.Struct({
            typeHash: keccak256("HashDynamic(string text)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Hash
        });
        encoded.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        encoded.chunks[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: true, data: abi.encodePacked("hello") });

        // Expected: keccak256(abi.encodePacked("hello"))
        bytes32 expectedHash = keccak256(abi.encodePacked("hello"));
        bytes memory actual = encoded.encode();

        assertEq(actual.length, 32);

        bytes32 actualHash;
        assembly {
            actualHash := mload(add(actual, 32))
        }
        assertEq(actualHash, expectedHash);
    }

    struct HashMixed {
        uint256 id;
        string name;
        address owner;
    }

    function testHashMixedStaticDynamic() public pure {
        TypedEncoder.Struct memory encoded = TypedEncoder.Struct({
            typeHash: keccak256("HashMixed(uint256 id,string name,address owner)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Hash
        });
        encoded.chunks[0].primitives = new TypedEncoder.Primitive[](3);
        encoded.chunks[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(123)) });
        encoded.chunks[0].primitives[1] = TypedEncoder.Primitive({ isDynamic: true, data: abi.encodePacked("Alice") });
        encoded.chunks[0].primitives[2] = TypedEncoder.Primitive({
            isDynamic: false, data: abi.encode(address(0x1111111111111111111111111111111111111111))
        });

        // Expected: keccak256(abi.encodePacked(uint256(123), "Alice", address(0x1111...)))
        bytes32 expectedHash = keccak256(
            abi.encodePacked(
                abi.encode(uint256(123)), "Alice", abi.encode(address(0x1111111111111111111111111111111111111111))
            )
        );
        bytes memory actual = encoded.encode();

        assertEq(actual.length, 32);

        bytes32 actualHash;
        assembly {
            actualHash := mload(add(actual, 32))
        }
        assertEq(actualHash, expectedHash);
    }

    function testHashEmptyStruct() public pure {
        TypedEncoder.Struct memory encoded = TypedEncoder.Struct({
            typeHash: keccak256("Empty()"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Hash
        });

        // Expected: keccak256(abi.encodePacked()) = keccak256("")
        bytes32 expectedHash = keccak256("");
        bytes memory actual = encoded.encode();

        assertEq(actual.length, 32);

        bytes32 actualHash;
        assembly {
            actualHash := mload(add(actual, 32))
        }
        assertEq(actualHash, expectedHash);
    }

    // ============ Section 2: Multiple Chunks ============

    struct HashMultiChunk {
        uint256 a;
        string b;
        uint256 c;
    }

    function testHashMultipleChunks() public pure {
        TypedEncoder.Struct memory encoded = TypedEncoder.Struct({
            typeHash: keccak256("HashMultiChunk(uint256 a,string b,uint256 c)"),
            chunks: new TypedEncoder.Chunk[](3),
            encodingType: TypedEncoder.EncodingType.Hash
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

        // Expected: keccak256(abi.encodePacked(uint256(100), "middle", uint256(200)))
        bytes32 expectedHash = keccak256(abi.encodePacked(abi.encode(uint256(100)), "middle", abi.encode(uint256(200))));
        bytes memory actual = encoded.encode();

        assertEq(actual.length, 32);

        bytes32 actualHash;
        assembly {
            actualHash := mload(add(actual, 32))
        }
        assertEq(actualHash, expectedHash);
    }

    // ============ Section 3: Nested Hash Structs ============

    struct Inner {
        uint256 value;
    }

    struct Outer {
        uint256 id;
        Inner inner;
    }

    function testHashNestedHashStruct() public pure {
        // Create inner struct with Hash encoding
        TypedEncoder.Struct memory inner = TypedEncoder.Struct({
            typeHash: keccak256("Inner(uint256 value)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Hash
        });
        inner.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        inner.chunks[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(42)) });

        // Create outer struct with Hash encoding
        TypedEncoder.Struct memory outer = TypedEncoder.Struct({
            typeHash: keccak256("Outer(uint256 id,Inner inner)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Hash
        });
        outer.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        outer.chunks[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(123)) });
        outer.chunks[0].structs = new TypedEncoder.Struct[](1);
        outer.chunks[0].structs[0] = inner;

        // Expected: inner hash = keccak256(abi.encodePacked(uint256(42)))
        bytes32 innerHash = keccak256(abi.encodePacked(abi.encode(uint256(42))));
        // Expected: outer hash = keccak256(abi.encodePacked(uint256(123), innerHash))
        bytes32 expectedHash = keccak256(abi.encodePacked(abi.encode(uint256(123)), innerHash));

        bytes memory actual = outer.encode();

        assertEq(actual.length, 32);

        bytes32 actualHash;
        assembly {
            actualHash := mload(add(actual, 32))
        }
        assertEq(actualHash, expectedHash);
    }

    function testHashNestedNonHashStruct() public pure {
        // Create inner struct with Struct encoding (ABI)
        TypedEncoder.Struct memory inner = TypedEncoder.Struct({
            typeHash: keccak256("Inner(uint256 value)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Struct
        });
        inner.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        inner.chunks[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(42)) });

        // Create outer struct with Hash encoding
        TypedEncoder.Struct memory outer = TypedEncoder.Struct({
            typeHash: keccak256("Outer(uint256 id,Inner inner)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Hash
        });
        outer.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        outer.chunks[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(123)) });
        outer.chunks[0].structs = new TypedEncoder.Struct[](1);
        outer.chunks[0].structs[0] = inner;

        // Expected: inner ABI encoding = abi.encode(uint256(42))
        bytes memory innerEncoded = abi.encode(uint256(42));
        // Expected: outer hash = keccak256(abi.encodePacked(uint256(123), innerEncoded))
        bytes32 expectedHash = keccak256(abi.encodePacked(abi.encode(uint256(123)), innerEncoded));

        bytes memory actual = outer.encode();

        assertEq(actual.length, 32);

        bytes32 actualHash;
        assembly {
            actualHash := mload(add(actual, 32))
        }
        assertEq(actualHash, expectedHash);
    }

    // ============ Section 4: Arrays in Hash Encoding ============

    struct HashWithArray {
        uint256 id;
        uint256[] values;
    }

    function testHashWithArray() public pure {
        TypedEncoder.Chunk[] memory arrayElements = new TypedEncoder.Chunk[](3);
        arrayElements[0].primitives = new TypedEncoder.Primitive[](1);
        arrayElements[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(1)) });
        arrayElements[1].primitives = new TypedEncoder.Primitive[](1);
        arrayElements[1].primitives[0] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(2)) });
        arrayElements[2].primitives = new TypedEncoder.Primitive[](1);
        arrayElements[2].primitives[0] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(3)) });

        TypedEncoder.Struct memory encoded = TypedEncoder.Struct({
            typeHash: keccak256("HashWithArray(uint256 id,uint256[] values)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Hash
        });
        encoded.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        encoded.chunks[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(999)) });
        encoded.chunks[0].arrays = new TypedEncoder.Array[](1);
        encoded.chunks[0].arrays[0] = TypedEncoder.Array({ isDynamic: true, data: arrayElements });

        // Expected: keccak256(abi.encodePacked(uint256(999), uint256(1), uint256(2), uint256(3)))
        // Note: arrays are packed without length prefix
        bytes32 expectedHash = keccak256(
            abi.encodePacked(
                abi.encode(uint256(999)), abi.encode(uint256(1)), abi.encode(uint256(2)), abi.encode(uint256(3))
            )
        );

        bytes memory actual = encoded.encode();

        assertEq(actual.length, 32);

        bytes32 actualHash;
        assembly {
            actualHash := mload(add(actual, 32))
        }
        assertEq(actualHash, expectedHash);
    }

    struct HashWithStringArray {
        string[] tags;
    }

    function testHashWithDynamicArray() public pure {
        TypedEncoder.Chunk[] memory arrayElements = new TypedEncoder.Chunk[](2);
        arrayElements[0].primitives = new TypedEncoder.Primitive[](1);
        arrayElements[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: true, data: abi.encodePacked("tag1") });
        arrayElements[1].primitives = new TypedEncoder.Primitive[](1);
        arrayElements[1].primitives[0] = TypedEncoder.Primitive({ isDynamic: true, data: abi.encodePacked("tag2") });

        TypedEncoder.Struct memory encoded = TypedEncoder.Struct({
            typeHash: keccak256("HashWithStringArray(string[] tags)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Hash
        });
        encoded.chunks[0].arrays = new TypedEncoder.Array[](1);
        encoded.chunks[0].arrays[0] = TypedEncoder.Array({ isDynamic: true, data: arrayElements });

        // Expected: keccak256(abi.encodePacked("tag1", "tag2"))
        bytes32 expectedHash = keccak256(abi.encodePacked("tag1", "tag2"));

        bytes memory actual = encoded.encode();

        assertEq(actual.length, 32);

        bytes32 actualHash;
        assembly {
            actualHash := mload(add(actual, 32))
        }
        assertEq(actualHash, expectedHash);
    }

    // ============ Section 5: Hash as Nested Field in Parent Struct ============

    struct ParentWithHash {
        uint256 id;
        bytes32 commitment;
    }

    function testHashAsNestedStaticField() public pure {
        // Create Hash-encoded struct
        TypedEncoder.Struct memory hashStruct = TypedEncoder.Struct({
            typeHash: keccak256("Data(uint256 value)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Hash
        });
        hashStruct.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        hashStruct.chunks[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(42)) });

        // Create parent struct with Struct encoding that includes the hash
        TypedEncoder.Struct memory parent = TypedEncoder.Struct({
            typeHash: keccak256("ParentWithHash(uint256 id,bytes32 commitment)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Struct
        });
        parent.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        parent.chunks[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(999)) });
        parent.chunks[0].structs = new TypedEncoder.Struct[](1);
        parent.chunks[0].structs[0] = hashStruct;

        // Expected hash of inner struct
        bytes32 innerHash = keccak256(abi.encodePacked(abi.encode(uint256(42))));

        // Expected parent encoding (Hash struct is static 32 bytes in parent)
        bytes memory expected = abi.encode(ParentWithHash({ id: 999, commitment: innerHash }));
        bytes memory actual = parent.encode();

        assertEq(actual, expected);
    }

    // ============ Section 6: Complex Nested Scenarios ============

    struct DeepInner {
        uint256 value;
    }

    struct DeepMiddle {
        uint256 id;
        DeepInner inner;
    }

    struct DeepOuter {
        string name;
        DeepMiddle middle;
    }

    function testDeeplyNestedHashStructs() public pure {
        // Create deepest level - Hash encoding
        TypedEncoder.Struct memory deepInner = TypedEncoder.Struct({
            typeHash: keccak256("DeepInner(uint256 value)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Hash
        });
        deepInner.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        deepInner.chunks[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(42)) });

        // Create middle level - Hash encoding
        TypedEncoder.Struct memory deepMiddle = TypedEncoder.Struct({
            typeHash: keccak256("DeepMiddle(uint256 id,DeepInner inner)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Hash
        });
        deepMiddle.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        deepMiddle.chunks[0].primitives[0] =
            TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(123)) });
        deepMiddle.chunks[0].structs = new TypedEncoder.Struct[](1);
        deepMiddle.chunks[0].structs[0] = deepInner;

        // Create outer level - Hash encoding
        TypedEncoder.Struct memory deepOuter = TypedEncoder.Struct({
            typeHash: keccak256("DeepOuter(string name,DeepMiddle middle)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Hash
        });
        deepOuter.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        deepOuter.chunks[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: true, data: abi.encodePacked("test") });
        deepOuter.chunks[0].structs = new TypedEncoder.Struct[](1);
        deepOuter.chunks[0].structs[0] = deepMiddle;

        // Calculate expected hash
        bytes32 innerHash = keccak256(abi.encodePacked(abi.encode(uint256(42))));
        bytes32 middleHash = keccak256(abi.encodePacked(abi.encode(uint256(123)), innerHash));
        bytes32 expectedHash = keccak256(abi.encodePacked("test", middleHash));

        bytes memory actual = deepOuter.encode();

        assertEq(actual.length, 32);

        bytes32 actualHash;
        assembly {
            actualHash := mload(add(actual, 32))
        }
        assertEq(actualHash, expectedHash);
    }

    // ============ Section 7: Edge Cases ============

    function testHashWithFixedBytes() public pure {
        TypedEncoder.Struct memory encoded = TypedEncoder.Struct({
            typeHash: keccak256("FixedBytes(bytes32 data)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Hash
        });
        encoded.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        encoded.chunks[0].primitives[0] = TypedEncoder.Primitive({
            isDynamic: false,
            data: abi.encode(bytes32(0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef))
        });

        bytes32 expectedHash = keccak256(
            abi.encodePacked(abi.encode(bytes32(0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef)))
        );

        bytes memory actual = encoded.encode();

        assertEq(actual.length, 32);

        bytes32 actualHash;
        assembly {
            actualHash := mload(add(actual, 32))
        }
        assertEq(actualHash, expectedHash);
    }

    function testHashWithBytesData() public pure {
        TypedEncoder.Struct memory encoded = TypedEncoder.Struct({
            typeHash: keccak256("BytesData(bytes data)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Hash
        });
        encoded.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        encoded.chunks[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: true, data: hex"deadbeef" });

        bytes32 expectedHash = keccak256(abi.encodePacked(hex"deadbeef"));

        bytes memory actual = encoded.encode();

        assertEq(actual.length, 32);

        bytes32 actualHash;
        assembly {
            actualHash := mload(add(actual, 32))
        }
        assertEq(actualHash, expectedHash);
    }
}
