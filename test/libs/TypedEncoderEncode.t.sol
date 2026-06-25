// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { TypedEncoder } from "../../src/libs/TypedEncoder.sol";
import "../utils/TestBase.sol";

contract TypedEncoderAbiEncodeTest is TestBase {
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
            typeHash: keccak256("Static(uint256 value,address addr)"), chunks: new TypedEncoder.Chunk[](1)
        });
        encoded.chunks[0].primitives = new TypedEncoder.Primitive[](2);
        encoded.chunks[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(42)) });
        encoded.chunks[0].primitives[1] = TypedEncoder.Primitive({
            isDynamic: false, data: abi.encode(address(0x1234567890123456789012345678901234567890))
        });

        bytes memory expected =
            abi.encode(Static({ value: 42, addr: address(0x1234567890123456789012345678901234567890) }));
        bytes memory actual = encoded.encode();

        assertEq(actual, expected);
    }

    struct Dynamic {
        string text;
    }

    function testDynamicFieldOnly() public pure {
        TypedEncoder.Struct memory encoded =
            TypedEncoder.Struct({ typeHash: keccak256("Dynamic(string text)"), chunks: new TypedEncoder.Chunk[](1) });
        encoded.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        encoded.chunks[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: true, data: abi.encodePacked("hello") });

        bytes memory expected = abi.encode(Dynamic({ text: "hello" }));
        bytes memory actual = encoded.encode();

        assertEq(actual, expected);
    }

    struct Mixed {
        uint256 id;
        string name;
    }

    function testMixedStaticDynamic() public pure {
        TypedEncoder.Struct memory encoded = TypedEncoder.Struct({
            typeHash: keccak256("Mixed(uint256 id,string name)"), chunks: new TypedEncoder.Chunk[](1)
        });
        encoded.chunks[0].primitives = new TypedEncoder.Primitive[](2);
        encoded.chunks[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(123)) });
        encoded.chunks[0].primitives[1] = TypedEncoder.Primitive({ isDynamic: true, data: abi.encodePacked("test") });

        bytes memory expected = abi.encode(Mixed({ id: 123, name: "test" }));
        bytes memory actual = encoded.encode();

        assertEq(actual, expected);
    }

    struct FixedBytes {
        bytes32 hash;
        uint256 value;
    }

    function testFixedBytes() public pure {
        TypedEncoder.Struct memory encoded = TypedEncoder.Struct({
            typeHash: keccak256("FixedBytes(bytes32 hash,uint256 value)"), chunks: new TypedEncoder.Chunk[](1)
        });
        encoded.chunks[0].primitives = new TypedEncoder.Primitive[](2);
        encoded.chunks[0].primitives[0] = TypedEncoder.Primitive({
            isDynamic: false,
            data: abi.encode(bytes32(0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef))
        });
        encoded.chunks[0].primitives[1] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(42)) });

        bytes memory expected = abi.encode(
            FixedBytes({ hash: bytes32(0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef), value: 42 })
        );
        bytes memory actual = encoded.encode();

        assertEq(actual, expected);
    }

    struct EmptyDynamic {
        string text;
        bytes data;
    }

    function testEmptyDynamic() public pure {
        TypedEncoder.Struct memory encoded = TypedEncoder.Struct({
            typeHash: keccak256("EmptyDynamic(string text,bytes data)"), chunks: new TypedEncoder.Chunk[](1)
        });
        encoded.chunks[0].primitives = new TypedEncoder.Primitive[](2);
        encoded.chunks[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: true, data: abi.encodePacked("") });
        encoded.chunks[0].primitives[1] = TypedEncoder.Primitive({ isDynamic: true, data: hex"" });

        bytes memory expected = abi.encode(EmptyDynamic({ text: "", data: hex"" }));
        bytes memory actual = encoded.encode();

        assertEq(actual, expected);
    }

    struct ComplexMixed {
        uint256 id;
        string name;
        address owner;
        bytes data;
    }

    function testComplexMixed() public pure {
        TypedEncoder.Struct memory encoded = TypedEncoder.Struct({
            typeHash: keccak256("ComplexMixed(uint256 id,string name,address owner,bytes data)"),
            chunks: new TypedEncoder.Chunk[](1)
        });
        encoded.chunks[0].primitives = new TypedEncoder.Primitive[](4);
        encoded.chunks[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(999)) });
        encoded.chunks[0].primitives[1] = TypedEncoder.Primitive({ isDynamic: true, data: abi.encodePacked("complex") });
        encoded.chunks[0].primitives[2] =
            TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(address(0xABCD)) });
        encoded.chunks[0].primitives[3] = TypedEncoder.Primitive({ isDynamic: true, data: hex"deadbeef" });

        bytes memory expected =
            abi.encode(ComplexMixed({ id: 999, name: "complex", owner: address(0xABCD), data: hex"deadbeef" }));
        bytes memory actual = encoded.encode();

        assertEq(actual, expected);
    }

    // ============ Section 2: Basic Arrays ============

    struct StaticArray {
        uint256[3] values;
    }

    function testStaticArray() public pure {
        TypedEncoder.Chunk[] memory arrayElements = new TypedEncoder.Chunk[](3);
        for (uint256 i = 0; i < 3; i++) {
            arrayElements[i].primitives = new TypedEncoder.Primitive[](1);
            arrayElements[i].primitives[0] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(i + 1) });
        }

        TypedEncoder.Struct memory encoded = TypedEncoder.Struct({
            typeHash: keccak256("StaticArray(uint256[3] values)"), chunks: new TypedEncoder.Chunk[](1)
        });
        encoded.chunks[0].arrays = new TypedEncoder.Array[](1);
        encoded.chunks[0].arrays[0] = TypedEncoder.Array({ isDynamic: false, data: arrayElements });

        bytes memory expected = abi.encode(StaticArray({ values: [uint256(1), 2, 3] }));
        bytes memory actual = encoded.encode();

        assertEq(actual, expected);
    }

    struct StaticArrayOfDynamic {
        string[2] names;
    }

    function testStaticArrayOfDynamic() public pure {
        TypedEncoder.Chunk[] memory arrayElements = new TypedEncoder.Chunk[](2);
        arrayElements[0].primitives = new TypedEncoder.Primitive[](1);
        arrayElements[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: true, data: abi.encodePacked("alice") });
        arrayElements[1].primitives = new TypedEncoder.Primitive[](1);
        arrayElements[1].primitives[0] = TypedEncoder.Primitive({ isDynamic: true, data: abi.encodePacked("bob") });

        TypedEncoder.Struct memory encoded = TypedEncoder.Struct({
            typeHash: keccak256("StaticArrayOfDynamic(string[2] names)"), chunks: new TypedEncoder.Chunk[](1)
        });
        encoded.chunks[0].arrays = new TypedEncoder.Array[](1);
        encoded.chunks[0].arrays[0] = TypedEncoder.Array({ isDynamic: false, data: arrayElements });

        bytes memory expected = abi.encode(StaticArrayOfDynamic({ names: [string("alice"), string("bob")] }));
        bytes memory actual = encoded.encode();

        assertEq(actual, expected);
    }

    struct DynamicArray {
        uint256[] values;
    }

    function testDynamicArray() public pure {
        TypedEncoder.Chunk[] memory arrayElements = new TypedEncoder.Chunk[](3);
        arrayElements[0].primitives = new TypedEncoder.Primitive[](1);
        arrayElements[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(10)) });
        arrayElements[1].primitives = new TypedEncoder.Primitive[](1);
        arrayElements[1].primitives[0] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(20)) });
        arrayElements[2].primitives = new TypedEncoder.Primitive[](1);
        arrayElements[2].primitives[0] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(30)) });

        TypedEncoder.Struct memory encoded = TypedEncoder.Struct({
            typeHash: keccak256("DynamicArray(uint256[] values)"), chunks: new TypedEncoder.Chunk[](1)
        });
        encoded.chunks[0].arrays = new TypedEncoder.Array[](1);
        encoded.chunks[0].arrays[0] = TypedEncoder.Array({ isDynamic: true, data: arrayElements });

        uint256[] memory vals = new uint256[](3);
        vals[0] = 10;
        vals[1] = 20;
        vals[2] = 30;
        bytes memory expected = abi.encode(DynamicArray({ values: vals }));
        bytes memory actual = encoded.encode();

        assertEq(actual, expected);
    }

    struct DynamicStringArray {
        string[] items;
    }

    function testDynamicArrayOfDynamicType() public pure {
        TypedEncoder.Chunk[] memory arrayElements = new TypedEncoder.Chunk[](2);
        arrayElements[0].primitives = new TypedEncoder.Primitive[](1);
        arrayElements[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: true, data: abi.encodePacked("foo") });
        arrayElements[1].primitives = new TypedEncoder.Primitive[](1);
        arrayElements[1].primitives[0] = TypedEncoder.Primitive({ isDynamic: true, data: abi.encodePacked("bar") });

        TypedEncoder.Struct memory encoded = TypedEncoder.Struct({
            typeHash: keccak256("DynamicStringArray(string[] items)"), chunks: new TypedEncoder.Chunk[](1)
        });
        encoded.chunks[0].arrays = new TypedEncoder.Array[](1);
        encoded.chunks[0].arrays[0] = TypedEncoder.Array({ isDynamic: true, data: arrayElements });

        string[] memory items = new string[](2);
        items[0] = "foo";
        items[1] = "bar";
        bytes memory expected = abi.encode(DynamicStringArray({ items: items }));
        bytes memory actual = encoded.encode();

        assertEq(actual, expected);
    }

    struct EmptyArray {
        string[] items;
    }

    function testEmptyArray() public pure {
        TypedEncoder.Struct memory encoded = TypedEncoder.Struct({
            typeHash: keccak256("EmptyArray(string[] items)"), chunks: new TypedEncoder.Chunk[](1)
        });
        encoded.chunks[0].arrays = new TypedEncoder.Array[](1);
        encoded.chunks[0].arrays[0] = TypedEncoder.Array({ isDynamic: true, data: new TypedEncoder.Chunk[](0) });

        bytes memory expected = abi.encode(EmptyArray({ items: new string[](0) }));
        bytes memory actual = encoded.encode();

        assertEq(actual, expected);
    }

    struct SingleElementArray {
        uint256[] values;
    }

    function testSingleElementArray() public pure {
        TypedEncoder.Chunk[] memory arrayElements = new TypedEncoder.Chunk[](1);
        arrayElements[0].primitives = new TypedEncoder.Primitive[](1);
        arrayElements[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(42)) });

        TypedEncoder.Struct memory encoded = TypedEncoder.Struct({
            typeHash: keccak256("SingleElementArray(uint256[] values)"), chunks: new TypedEncoder.Chunk[](1)
        });
        encoded.chunks[0].arrays = new TypedEncoder.Array[](1);
        encoded.chunks[0].arrays[0] = TypedEncoder.Array({ isDynamic: true, data: arrayElements });

        uint256[] memory values = new uint256[](1);
        values[0] = 42;
        bytes memory expected = abi.encode(SingleElementArray({ values: values }));
        bytes memory actual = encoded.encode();

        assertEq(actual, expected);
    }

    // ============ Section 3: Advanced Arrays ============

    struct NestedArrays {
        string[][] matrix;
    }

    function testNestedArrays() public pure {
        TypedEncoder.Chunk[] memory row0 = new TypedEncoder.Chunk[](2);
        row0[0].primitives = new TypedEncoder.Primitive[](1);
        row0[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: true, data: abi.encodePacked("a") });
        row0[1].primitives = new TypedEncoder.Primitive[](1);
        row0[1].primitives[0] = TypedEncoder.Primitive({ isDynamic: true, data: abi.encodePacked("b") });

        TypedEncoder.Chunk[] memory row1 = new TypedEncoder.Chunk[](1);
        row1[0].primitives = new TypedEncoder.Primitive[](1);
        row1[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: true, data: abi.encodePacked("c") });

        TypedEncoder.Chunk[] memory outerArray = new TypedEncoder.Chunk[](2);
        outerArray[0].arrays = new TypedEncoder.Array[](1);
        outerArray[0].arrays[0] = TypedEncoder.Array({ isDynamic: true, data: row0 });
        outerArray[1].arrays = new TypedEncoder.Array[](1);
        outerArray[1].arrays[0] = TypedEncoder.Array({ isDynamic: true, data: row1 });

        TypedEncoder.Struct memory encoded = TypedEncoder.Struct({
            typeHash: keccak256("NestedArrays(string[][] matrix)"), chunks: new TypedEncoder.Chunk[](1)
        });
        encoded.chunks[0].arrays = new TypedEncoder.Array[](1);
        encoded.chunks[0].arrays[0] = TypedEncoder.Array({ isDynamic: true, data: outerArray });

        string[][] memory matrix = new string[][](2);
        matrix[0] = new string[](2);
        matrix[0][0] = "a";
        matrix[0][1] = "b";
        matrix[1] = new string[](1);
        matrix[1][0] = "c";
        bytes memory expected = abi.encode(NestedArrays({ matrix: matrix }));
        bytes memory actual = encoded.encode();

        assertEq(actual, expected);
    }

    struct MultipleArrays {
        uint256[] numbers;
        string[] names;
    }

    function testMultipleArrays() public pure {
        TypedEncoder.Chunk[] memory numElements = new TypedEncoder.Chunk[](2);
        numElements[0].primitives = new TypedEncoder.Primitive[](1);
        numElements[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(1)) });
        numElements[1].primitives = new TypedEncoder.Primitive[](1);
        numElements[1].primitives[0] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(2)) });

        TypedEncoder.Chunk[] memory nameElements = new TypedEncoder.Chunk[](2);
        nameElements[0].primitives = new TypedEncoder.Primitive[](1);
        nameElements[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: true, data: abi.encodePacked("alice") });
        nameElements[1].primitives = new TypedEncoder.Primitive[](1);
        nameElements[1].primitives[0] = TypedEncoder.Primitive({ isDynamic: true, data: abi.encodePacked("bob") });

        TypedEncoder.Struct memory encoded = TypedEncoder.Struct({
            typeHash: keccak256("MultipleArrays(uint256[] numbers,string[] names)"), chunks: new TypedEncoder.Chunk[](2)
        });
        encoded.chunks[0].arrays = new TypedEncoder.Array[](1);
        encoded.chunks[0].arrays[0] = TypedEncoder.Array({ isDynamic: true, data: numElements });
        encoded.chunks[1].arrays = new TypedEncoder.Array[](1);
        encoded.chunks[1].arrays[0] = TypedEncoder.Array({ isDynamic: true, data: nameElements });

        uint256[] memory numbers = new uint256[](2);
        numbers[0] = 1;
        numbers[1] = 2;
        string[] memory names = new string[](2);
        names[0] = "alice";
        names[1] = "bob";
        bytes memory expected = abi.encode(MultipleArrays({ numbers: numbers, names: names }));
        bytes memory actual = encoded.encode();

        assertEq(actual, expected);
    }

    // ============ Section 4: Structs ============

    struct Inner {
        uint256 x;
    }

    struct Nested {
        Inner inner;
        uint256 y;
    }

    function testNestedStruct() public pure {
        TypedEncoder.Struct memory innerEncoded =
            TypedEncoder.Struct({ typeHash: keccak256("Inner(uint256 x)"), chunks: new TypedEncoder.Chunk[](1) });
        innerEncoded.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        innerEncoded.chunks[0].primitives[0] =
            TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(100)) });

        TypedEncoder.Struct memory encoded = TypedEncoder.Struct({
            typeHash: keccak256("Nested(Inner inner,uint256 y)Inner(uint256 x)"), chunks: new TypedEncoder.Chunk[](2)
        });
        encoded.chunks[0].structs = new TypedEncoder.Struct[](1);
        encoded.chunks[0].structs[0] = innerEncoded;
        encoded.chunks[1].primitives = new TypedEncoder.Primitive[](1);
        encoded.chunks[1].primitives[0] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(200)) });

        bytes memory expected = abi.encode(Nested({ inner: Inner({ x: 100 }), y: 200 }));
        bytes memory actual = encoded.encode();

        assertEq(actual, expected);
    }

    struct StructWithArray {
        uint256 id;
        string[] tags;
    }

    function testStructWithArray() public pure {
        TypedEncoder.Chunk[] memory tagElements = new TypedEncoder.Chunk[](2);
        tagElements[0].primitives = new TypedEncoder.Primitive[](1);
        tagElements[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: true, data: abi.encodePacked("tag1") });
        tagElements[1].primitives = new TypedEncoder.Primitive[](1);
        tagElements[1].primitives[0] = TypedEncoder.Primitive({ isDynamic: true, data: abi.encodePacked("tag2") });

        TypedEncoder.Struct memory encoded = TypedEncoder.Struct({
            typeHash: keccak256("StructWithArray(uint256 id,string[] tags)"), chunks: new TypedEncoder.Chunk[](2)
        });
        encoded.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        encoded.chunks[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(123)) });
        encoded.chunks[1].arrays = new TypedEncoder.Array[](1);
        encoded.chunks[1].arrays[0] = TypedEncoder.Array({ isDynamic: true, data: tagElements });

        string[] memory tags = new string[](2);
        tags[0] = "tag1";
        tags[1] = "tag2";
        bytes memory expected = abi.encode(StructWithArray({ id: 123, tags: tags }));
        bytes memory actual = encoded.encode();

        assertEq(actual, expected);
    }

    // ============ Section 5: Arrays of Structs ============

    struct Point {
        uint256 x;
        uint256 y;
    }

    struct ArrayOfStructs {
        Point[] points;
    }

    function testArrayOfStructs() public pure {
        TypedEncoder.Struct memory point0 = TypedEncoder.Struct({
            typeHash: keccak256("Point(uint256 x,uint256 y)"), chunks: new TypedEncoder.Chunk[](1)
        });
        point0.chunks[0].primitives = new TypedEncoder.Primitive[](2);
        point0.chunks[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(1)) });
        point0.chunks[0].primitives[1] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(2)) });

        TypedEncoder.Struct memory point1 = TypedEncoder.Struct({
            typeHash: keccak256("Point(uint256 x,uint256 y)"), chunks: new TypedEncoder.Chunk[](1)
        });
        point1.chunks[0].primitives = new TypedEncoder.Primitive[](2);
        point1.chunks[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(3)) });
        point1.chunks[0].primitives[1] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(4)) });

        TypedEncoder.Chunk[] memory arrayElements = new TypedEncoder.Chunk[](2);
        arrayElements[0].structs = new TypedEncoder.Struct[](1);
        arrayElements[0].structs[0] = point0;
        arrayElements[1].structs = new TypedEncoder.Struct[](1);
        arrayElements[1].structs[0] = point1;

        TypedEncoder.Struct memory encoded = TypedEncoder.Struct({
            typeHash: keccak256("ArrayOfStructs(Point[] points)Point(uint256 x,uint256 y)"),
            chunks: new TypedEncoder.Chunk[](1)
        });
        encoded.chunks[0].arrays = new TypedEncoder.Array[](1);
        encoded.chunks[0].arrays[0] = TypedEncoder.Array({ isDynamic: true, data: arrayElements });

        Point[] memory pts = new Point[](2);
        pts[0] = Point({ x: 1, y: 2 });
        pts[1] = Point({ x: 3, y: 4 });
        bytes memory expected = abi.encode(ArrayOfStructs({ points: pts }));
        bytes memory actual = encoded.encode();

        assertEq(actual, expected);
    }

    struct Record {
        string name;
        uint256 value;
    }

    struct ArrayOfDynamicStructs {
        Record[] records;
    }

    function testArrayOfDynamicStructs() public pure {
        TypedEncoder.Struct memory record0 = TypedEncoder.Struct({
            typeHash: keccak256("Record(string name,uint256 value)"), chunks: new TypedEncoder.Chunk[](1)
        });
        record0.chunks[0].primitives = new TypedEncoder.Primitive[](2);
        record0.chunks[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: true, data: abi.encodePacked("alice") });
        record0.chunks[0].primitives[1] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(100)) });

        TypedEncoder.Struct memory record1 = TypedEncoder.Struct({
            typeHash: keccak256("Record(string name,uint256 value)"), chunks: new TypedEncoder.Chunk[](1)
        });
        record1.chunks[0].primitives = new TypedEncoder.Primitive[](2);
        record1.chunks[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: true, data: abi.encodePacked("bob") });
        record1.chunks[0].primitives[1] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(200)) });

        TypedEncoder.Chunk[] memory arrayElements = new TypedEncoder.Chunk[](2);
        arrayElements[0].structs = new TypedEncoder.Struct[](1);
        arrayElements[0].structs[0] = record0;
        arrayElements[1].structs = new TypedEncoder.Struct[](1);
        arrayElements[1].structs[0] = record1;

        TypedEncoder.Struct memory encoded = TypedEncoder.Struct({
            typeHash: keccak256("ArrayOfDynamicStructs(Record[] records)Record(string name,uint256 value)"),
            chunks: new TypedEncoder.Chunk[](1)
        });
        encoded.chunks[0].arrays = new TypedEncoder.Array[](1);
        encoded.chunks[0].arrays[0] = TypedEncoder.Array({ isDynamic: true, data: arrayElements });

        Record[] memory records = new Record[](2);
        records[0] = Record({ name: "alice", value: 100 });
        records[1] = Record({ name: "bob", value: 200 });
        bytes memory expected = abi.encode(ArrayOfDynamicStructs({ records: records }));
        bytes memory actual = encoded.encode();

        assertEq(actual, expected);
    }

    // ============ Section 6: Complex ============

    struct MultiChunk {
        uint256 a;
        string b;
        uint256 c;
    }

    function testMultipleChunks() public pure {
        TypedEncoder.Struct memory encoded = TypedEncoder.Struct({
            typeHash: keccak256("MultiChunk(uint256 a,string b,uint256 c)"), chunks: new TypedEncoder.Chunk[](3)
        });

        encoded.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        encoded.chunks[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(111)) });

        encoded.chunks[1].primitives = new TypedEncoder.Primitive[](1);
        encoded.chunks[1].primitives[0] = TypedEncoder.Primitive({ isDynamic: true, data: abi.encodePacked("middle") });

        encoded.chunks[2].primitives = new TypedEncoder.Primitive[](1);
        encoded.chunks[2].primitives[0] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(222)) });

        bytes memory expected = abi.encode(MultiChunk({ a: 111, b: "middle", c: 222 }));
        bytes memory actual = encoded.encode();

        assertEq(actual, expected);
    }
}
