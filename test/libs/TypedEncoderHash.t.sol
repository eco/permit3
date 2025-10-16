// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { TypedEncoder } from "../../src/lib/TypedEncoder.sol";
import "../utils/TestBase.sol";

contract TypedEncoderStructHashTest is TestBase {
    using TypedEncoder for TypedEncoder.Struct;

    function setUp() public override {
        super.setUp();
    }

    // ============ Section 1: Basic Primitives ============

    struct Static {
        uint256 value;
        address addr;
    }

    function testStaticFieldsOnly() public pure {
        TypedEncoder.Struct memory encoded = TypedEncoder.Struct({
            typeHash: keccak256("Static(uint256 value,address addr)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Struct
        });
        encoded.chunks[0].primitives = new TypedEncoder.Primitive[](2);
        encoded.chunks[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(42)) });
        encoded.chunks[0].primitives[1] = TypedEncoder.Primitive({
            isDynamic: false,
            data: abi.encode(address(0x1234567890123456789012345678901234567890))
        });

        bytes32 expected = keccak256(
            abi.encodePacked(
                keccak256("Static(uint256 value,address addr)"),
                abi.encode(uint256(42)),
                abi.encode(address(0x1234567890123456789012345678901234567890))
            )
        );
        bytes32 actual = encoded.hash();

        assertEq(actual, expected);
    }

    struct Dynamic {
        string text;
    }

    function testDynamicFieldOnly() public pure {
        TypedEncoder.Struct memory encoded = TypedEncoder.Struct({
            typeHash: keccak256("Dynamic(string text)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Struct
        });
        encoded.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        encoded.chunks[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: true, data: abi.encodePacked("hello") });

        bytes32 expected =
            keccak256(abi.encodePacked(keccak256("Dynamic(string text)"), keccak256(abi.encodePacked("hello"))));
        bytes32 actual = encoded.hash();

        assertEq(actual, expected);
    }

    struct Mixed {
        uint256 id;
        string name;
    }

    function testMixedStaticDynamic() public pure {
        TypedEncoder.Struct memory encoded = TypedEncoder.Struct({
            typeHash: keccak256("Mixed(uint256 id,string name)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Struct
        });
        encoded.chunks[0].primitives = new TypedEncoder.Primitive[](2);
        encoded.chunks[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(123)) });
        encoded.chunks[0].primitives[1] = TypedEncoder.Primitive({ isDynamic: true, data: abi.encodePacked("Alice") });

        bytes32 expected = keccak256(
            abi.encodePacked(
                keccak256("Mixed(uint256 id,string name)"),
                abi.encode(uint256(123)),
                keccak256(abi.encodePacked("Alice"))
            )
        );
        bytes32 actual = encoded.hash();

        assertEq(actual, expected);
    }

    struct FixedBytesStruct {
        bytes32 hash;
        uint256 value;
    }

    function testFixedBytes() public pure {
        bytes32 testHash = keccak256("test");

        TypedEncoder.Struct memory encoded = TypedEncoder.Struct({
            typeHash: keccak256("FixedBytesStruct(bytes32 hash,uint256 value)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Struct
        });
        encoded.chunks[0].primitives = new TypedEncoder.Primitive[](2);
        encoded.chunks[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(testHash) });
        encoded.chunks[0].primitives[1] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(999)) });

        bytes32 expected = keccak256(
            abi.encodePacked(
                keccak256("FixedBytesStruct(bytes32 hash,uint256 value)"),
                abi.encode(testHash),
                abi.encode(uint256(999))
            )
        );
        bytes32 actual = encoded.hash();

        assertEq(actual, expected);
    }

    struct EmptyDynamic {
        string text;
        bytes data;
    }

    function testEmptyDynamic() public pure {
        TypedEncoder.Struct memory encoded = TypedEncoder.Struct({
            typeHash: keccak256("EmptyDynamic(string text,bytes data)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Struct
        });
        encoded.chunks[0].primitives = new TypedEncoder.Primitive[](2);
        encoded.chunks[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: true, data: "" });
        encoded.chunks[0].primitives[1] = TypedEncoder.Primitive({ isDynamic: true, data: "" });

        bytes32 expected =
            keccak256(abi.encodePacked(keccak256("EmptyDynamic(string text,bytes data)"), keccak256(""), keccak256("")));
        bytes32 actual = encoded.hash();

        assertEq(actual, expected);
    }

    // ============ Section 2: Basic Arrays ============

    struct StaticArrayStruct {
        uint256 value;
        string tag;
    }

    function testDynamicArrayOfDynamicType() public pure {
        TypedEncoder.Chunk[] memory arrayChunks = new TypedEncoder.Chunk[](2);
        arrayChunks[0].primitives = new TypedEncoder.Primitive[](1);
        arrayChunks[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: true, data: abi.encodePacked("tag1") });
        arrayChunks[1].primitives = new TypedEncoder.Primitive[](1);
        arrayChunks[1].primitives[0] = TypedEncoder.Primitive({ isDynamic: true, data: abi.encodePacked("tag2") });

        TypedEncoder.Array memory tags = TypedEncoder.Array({ isDynamic: true, data: arrayChunks });

        TypedEncoder.Struct memory encoded = TypedEncoder.Struct({
            typeHash: keccak256("StaticArrayStruct(uint256 value,string[] tag)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Struct
        });
        encoded.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        encoded.chunks[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(42)) });
        encoded.chunks[0].arrays = new TypedEncoder.Array[](1);
        encoded.chunks[0].arrays[0] = tags;

        bytes32 arrayHash =
            keccak256(abi.encodePacked(keccak256(abi.encodePacked("tag1")), keccak256(abi.encodePacked("tag2"))));

        bytes32 expected = keccak256(
            abi.encodePacked(
                keccak256("StaticArrayStruct(uint256 value,string[] tag)"), abi.encode(uint256(42)), arrayHash
            )
        );
        bytes32 actual = encoded.hash();

        assertEq(actual, expected);
    }

    // ============ Section 3: Nested Structs ============

    struct Person {
        string name;
        address wallet;
    }

    struct Mail {
        Person from;
        Person to;
        string contents;
    }

    function testNestedStruct() public pure {
        TypedEncoder.Struct memory from = TypedEncoder.Struct({
            typeHash: keccak256("Person(string name,address wallet)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Struct
        });
        from.chunks[0].primitives = new TypedEncoder.Primitive[](2);
        from.chunks[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: true, data: abi.encodePacked("Alice") });
        from.chunks[0].primitives[1] = TypedEncoder.Primitive({
            isDynamic: false,
            data: abi.encode(address(0x1111111111111111111111111111111111111111))
        });

        TypedEncoder.Struct memory to = TypedEncoder.Struct({
            typeHash: keccak256("Person(string name,address wallet)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Struct
        });
        to.chunks[0].primitives = new TypedEncoder.Primitive[](2);
        to.chunks[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: true, data: abi.encodePacked("Bob") });
        to.chunks[0].primitives[1] = TypedEncoder.Primitive({
            isDynamic: false,
            data: abi.encode(address(0x2222222222222222222222222222222222222222))
        });

        TypedEncoder.Struct memory mail = TypedEncoder.Struct({
            typeHash: keccak256("Mail(Person from,Person to,string contents)Person(string name,address wallet)"),
            chunks: new TypedEncoder.Chunk[](2),
            encodingType: TypedEncoder.EncodingType.Struct
        });
        mail.chunks[0].structs = new TypedEncoder.Struct[](2);
        mail.chunks[0].structs[0] = from;
        mail.chunks[0].structs[1] = to;
        mail.chunks[1].primitives = new TypedEncoder.Primitive[](1);
        mail.chunks[1].primitives[0] = TypedEncoder.Primitive({ isDynamic: true, data: abi.encodePacked("Hello!") });

        bytes32 fromHash = keccak256(
            abi.encodePacked(
                keccak256("Person(string name,address wallet)"),
                keccak256(abi.encodePacked("Alice")),
                abi.encode(address(0x1111111111111111111111111111111111111111))
            )
        );

        bytes32 toHash = keccak256(
            abi.encodePacked(
                keccak256("Person(string name,address wallet)"),
                keccak256(abi.encodePacked("Bob")),
                abi.encode(address(0x2222222222222222222222222222222222222222))
            )
        );

        bytes32 expected = keccak256(
            abi.encodePacked(
                keccak256("Mail(Person from,Person to,string contents)Person(string name,address wallet)"),
                fromHash,
                toHash,
                keccak256(abi.encodePacked("Hello!"))
            )
        );
        bytes32 actual = mail.hash();

        assertEq(actual, expected);
    }

    // ============ Section 4: Struct with Array ============

    struct StructWithArray {
        string name;
        uint256[] values;
    }

    function testStructWithArray() public pure {
        TypedEncoder.Chunk[] memory arrayChunks = new TypedEncoder.Chunk[](3);
        arrayChunks[0].primitives = new TypedEncoder.Primitive[](1);
        arrayChunks[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(1)) });
        arrayChunks[1].primitives = new TypedEncoder.Primitive[](1);
        arrayChunks[1].primitives[0] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(2)) });
        arrayChunks[2].primitives = new TypedEncoder.Primitive[](1);
        arrayChunks[2].primitives[0] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(3)) });

        TypedEncoder.Array memory values = TypedEncoder.Array({ isDynamic: true, data: arrayChunks });

        TypedEncoder.Struct memory encoded = TypedEncoder.Struct({
            typeHash: keccak256("StructWithArray(string name,uint256[] values)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Struct
        });
        encoded.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        encoded.chunks[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: true, data: abi.encodePacked("test") });
        encoded.chunks[0].arrays = new TypedEncoder.Array[](1);
        encoded.chunks[0].arrays[0] = values;

        bytes32 arrayHash =
            keccak256(abi.encodePacked(abi.encode(uint256(1)), abi.encode(uint256(2)), abi.encode(uint256(3))));

        bytes32 expected = keccak256(
            abi.encodePacked(
                keccak256("StructWithArray(string name,uint256[] values)"),
                keccak256(abi.encodePacked("test")),
                arrayHash
            )
        );
        bytes32 actual = encoded.hash();

        assertEq(actual, expected);
    }

    // ============ Section 5: Nested Arrays (2D) ============

    struct NestedArrayStruct {
        string[][] data;
    }

    function testNestedArrays() public pure {
        TypedEncoder.Chunk[] memory innerArray0 = new TypedEncoder.Chunk[](2);
        innerArray0[0].primitives = new TypedEncoder.Primitive[](1);
        innerArray0[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: true, data: abi.encodePacked("a") });
        innerArray0[1].primitives = new TypedEncoder.Primitive[](1);
        innerArray0[1].primitives[0] = TypedEncoder.Primitive({ isDynamic: true, data: abi.encodePacked("b") });

        TypedEncoder.Chunk[] memory innerArray1 = new TypedEncoder.Chunk[](1);
        innerArray1[0].primitives = new TypedEncoder.Primitive[](1);
        innerArray1[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: true, data: abi.encodePacked("c") });

        TypedEncoder.Chunk[] memory outerArrayChunks = new TypedEncoder.Chunk[](2);
        outerArrayChunks[0].arrays = new TypedEncoder.Array[](1);
        outerArrayChunks[0].arrays[0] = TypedEncoder.Array({ isDynamic: true, data: innerArray0 });
        outerArrayChunks[1].arrays = new TypedEncoder.Array[](1);
        outerArrayChunks[1].arrays[0] = TypedEncoder.Array({ isDynamic: true, data: innerArray1 });

        TypedEncoder.Array memory nestedArray = TypedEncoder.Array({ isDynamic: true, data: outerArrayChunks });

        TypedEncoder.Struct memory encoded = TypedEncoder.Struct({
            typeHash: keccak256("NestedArrayStruct(string[][] data)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Struct
        });
        encoded.chunks[0].arrays = new TypedEncoder.Array[](1);
        encoded.chunks[0].arrays[0] = nestedArray;

        bytes32 innerArray0Hash =
            keccak256(abi.encodePacked(keccak256(abi.encodePacked("a")), keccak256(abi.encodePacked("b"))));

        bytes32 innerArray1Hash = keccak256(abi.encodePacked(keccak256(abi.encodePacked("c"))));

        bytes32 outerArrayHash = keccak256(abi.encodePacked(innerArray0Hash, innerArray1Hash));

        bytes32 expected = keccak256(abi.encodePacked(keccak256("NestedArrayStruct(string[][] data)"), outerArrayHash));
        bytes32 actual = encoded.hash();

        assertEq(actual, expected);
    }
}
