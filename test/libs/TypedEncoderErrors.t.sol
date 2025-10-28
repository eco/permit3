// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { TypedEncoder } from "../../src/lib/TypedEncoder.sol";
import "forge-std/Test.sol";

contract TypedEncoderErrorsTest is Test {
    using TypedEncoder for TypedEncoder.Struct;

    // ============ Struct Definitions (minimal, for error testing) ============

    struct SimpleStruct {
        uint256 value;
    }

    struct CallStruct {
        bytes4 selector;
        bytes params;
    }

    // ============ Error Test Functions ============

    /**
     * @notice Tests that Array encoding reverts when chunks contain primitive fields
     * @dev Error: UnsupportedArrayType
     * Why: Array encoding type (used for polymorphic arrays) requires chunks to contain
     *      only struct fields. Primitives are not supported because each array element
     *      must be a struct with its own type hash for proper EIP-712 encoding.
     * TODO: Implement test
     */
    function testArrayEncodingWithPrimitives() public {
        // Create Array-encoded struct with primitive field (violates structs-only rule)
        TypedEncoder.Struct memory invalidArray = TypedEncoder.Struct({
            typeHash: keccak256("InvalidArray(uint256 value)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Array
        });

        // Add primitive to chunk (should fail - Array encoding requires only structs)
        invalidArray.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        invalidArray.chunks[0].primitives[0] =
            TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(100)) });

        // Expect revert with UnsupportedArrayType
        vm.expectRevert(TypedEncoder.UnsupportedArrayType.selector);
        invalidArray.encode();
    }

    /**
     * @notice Tests that Array encoding reverts when chunks contain array fields
     * @dev Error: UnsupportedArrayType
     * Why: Array encoding type requires chunks to contain only struct fields.
     *      Nested arrays are not supported in the chunk because the Array encoding
     *      is specifically designed for polymorphic struct arrays where each element
     *      is a complete struct with its own EIP-712 type hash.
     * TODO: Implement test
     */
    function testArrayEncodingWithArrays() public {
        // Create Array-encoded struct with array field (violates structs-only rule)
        TypedEncoder.Struct memory invalidArray = TypedEncoder.Struct({
            typeHash: keccak256("InvalidArray(uint256[] values)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Array
        });

        // Add array to chunk (should fail - Array encoding requires only structs)
        invalidArray.chunks[0].arrays = new TypedEncoder.Array[](1);
        invalidArray.chunks[0].arrays[0] = TypedEncoder.Array({ isDynamic: true, data: new TypedEncoder.Chunk[](2) });
        // Populate array elements
        invalidArray.chunks[0].arrays[0].data[0].primitives = new TypedEncoder.Primitive[](1);
        invalidArray.chunks[0].arrays[0].data[0].primitives[0] =
            TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(1)) });
        invalidArray.chunks[0].arrays[0].data[1].primitives = new TypedEncoder.Primitive[](1);
        invalidArray.chunks[0].arrays[0].data[1].primitives[0] =
            TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(2)) });

        // Expect revert with UnsupportedArrayType
        vm.expectRevert(TypedEncoder.UnsupportedArrayType.selector);
        invalidArray.encode();
    }

    /**
     * @notice Tests that Array encoding reverts when using multiple chunks
     * @dev Error: UnsupportedArrayType
     * Why: Array encoding requires exactly 1 chunk. Multiple chunks would break the array
     *      structure since chunks are for organizing field order within a struct, not for
     *      defining array elements. Array elements should be defined as structs within the
     *      single chunk. This validation ensures proper array structure.
     */
    function testArrayEncodingWithMultipleChunks() public {
        // Create Array-encoded struct with 2 chunks (violates exactly-1-chunk rule)
        TypedEncoder.Struct memory invalidArray = TypedEncoder.Struct({
            typeHash: keccak256("InvalidArray(SimpleStruct s1,SimpleStruct s2)"),
            chunks: new TypedEncoder.Chunk[](2),
            encodingType: TypedEncoder.EncodingType.Array
        });

        // Add struct to first chunk
        invalidArray.chunks[0].structs = new TypedEncoder.Struct[](1);
        invalidArray.chunks[0].structs[0] = TypedEncoder.Struct({
            typeHash: keccak256("SimpleStruct(uint256 value)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Struct
        });
        invalidArray.chunks[0].structs[0].chunks[0].primitives = new TypedEncoder.Primitive[](1);
        invalidArray.chunks[0].structs[0].chunks[0].primitives[0] =
            TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(1)) });

        // Add struct to second chunk (invalid - Array encoding requires exactly 1 chunk)
        invalidArray.chunks[1].structs = new TypedEncoder.Struct[](1);
        invalidArray.chunks[1].structs[0] = TypedEncoder.Struct({
            typeHash: keccak256("SimpleStruct(uint256 value)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Struct
        });
        invalidArray.chunks[1].structs[0].chunks[0].primitives = new TypedEncoder.Primitive[](1);
        invalidArray.chunks[1].structs[0].chunks[0].primitives[0] =
            TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(2)) });

        // Expect revert with UnsupportedArrayType (must have exactly 1 chunk)
        vm.expectRevert(TypedEncoder.UnsupportedArrayType.selector);
        invalidArray.encode();
    }

    /**
     * @notice Tests that Array encoding reverts when chunk has both structs and primitives/arrays
     * @dev Error: UnsupportedArrayType
     * Why: The single chunk in Array encoding must contain ONLY struct fields.
     *      Any primitive or array fields in the chunk violate this constraint.
     *      This ensures the output is a clean struct array, not a mixed-type array.
     * TODO: Implement test
     */
    function testArrayEncodingWithMixedFields() public {
        // Create Array-encoded struct with mixed fields (violates structs-only rule)
        TypedEncoder.Struct memory invalidArray = TypedEncoder.Struct({
            typeHash: keccak256("InvalidArray(uint256 value,SimpleStruct s)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Array
        });

        // Add primitive to chunk (invalid - Array encoding requires only structs)
        invalidArray.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        invalidArray.chunks[0].primitives[0] =
            TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(100)) });

        // Add struct to chunk (invalid when combined with primitive)
        invalidArray.chunks[0].structs = new TypedEncoder.Struct[](1);
        invalidArray.chunks[0].structs[0] = TypedEncoder.Struct({
            typeHash: keccak256("SimpleStruct(uint256 value)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Struct
        });
        invalidArray.chunks[0].structs[0].chunks[0].primitives = new TypedEncoder.Primitive[](1);
        invalidArray.chunks[0].structs[0].chunks[0].primitives[0] =
            TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(200)) });

        // Expect revert with UnsupportedArrayType (must have only structs, no primitives)
        vm.expectRevert(TypedEncoder.UnsupportedArrayType.selector);
        invalidArray.encode();
    }

    /**
     * @notice Tests that CallWithSelector reverts when selector is not exactly 4 bytes
     * @dev Error: InvalidCallEncodingStructure
     * Why: Function selectors in Solidity are always bytes4 (4 bytes). Using any other
     *      size (e.g., bytes8, bytes32, or bytes2) would produce invalid calldata that
     *      cannot be interpreted by the target contract. This validation ensures the
     *      encoded calldata has the correct 4-byte selector prefix.
     * TODO: Implement test
     */
    function testCallWithSelectorInvalidSelector() public {
        // Create params struct
        TypedEncoder.Struct memory paramsStruct = TypedEncoder.Struct({
            typeHash: keccak256("TransferParams(address to,uint256 amount)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Struct
        });
        paramsStruct.chunks[0].primitives = new TypedEncoder.Primitive[](2);
        paramsStruct.chunks[0].primitives[0] =
            TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(address(0x1234)) });
        paramsStruct.chunks[0].primitives[1] =
            TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(1000)) });

        // Create CallWithSelector with invalid 5-byte selector (should be 4 bytes)
        TypedEncoder.Struct memory invalidCall = TypedEncoder.Struct({
            typeHash: keccak256("InvalidCall(bytes5 selector,TransferParams params)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.CallWithSelector
        });
        invalidCall.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        // Use 5 bytes instead of 4 (invalid)
        invalidCall.chunks[0].primitives[0] =
            TypedEncoder.Primitive({ isDynamic: false, data: abi.encodePacked(bytes5(0x1234567890)) });
        invalidCall.chunks[0].structs = new TypedEncoder.Struct[](1);
        invalidCall.chunks[0].structs[0] = paramsStruct;

        // Expect revert with InvalidCallEncodingStructure
        vm.expectRevert(TypedEncoder.InvalidCallEncodingStructure.selector);
        invalidCall.encode();
    }

    /**
     * @notice Tests that CallWithSelector reverts when selector is marked as dynamic
     * @dev Error: InvalidCallEncodingStructure
     * Why: Function selectors are always static (bytes4). A dynamic selector would
     *      indicate incorrect construction of the Call structure. The selector primitive
     *      must have isDynamic=false because bytes4 is a fixed-size type, not a dynamic
     *      type like bytes or string.
     * TODO: Implement test
     */
    function testCallWithSelectorDynamicSelector() public {
        // Create params struct
        TypedEncoder.Struct memory paramsStruct = TypedEncoder.Struct({
            typeHash: keccak256("TransferParams(address to,uint256 amount)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Struct
        });
        paramsStruct.chunks[0].primitives = new TypedEncoder.Primitive[](2);
        paramsStruct.chunks[0].primitives[0] =
            TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(address(0x1234)) });
        paramsStruct.chunks[0].primitives[1] =
            TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(1000)) });

        // Create CallWithSelector with dynamic selector (should be static)
        TypedEncoder.Struct memory invalidCall = TypedEncoder.Struct({
            typeHash: keccak256("InvalidCall(bytes selector,TransferParams params)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.CallWithSelector
        });
        invalidCall.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        // Mark selector as dynamic (invalid - must be static)
        invalidCall.chunks[0].primitives[0] =
            TypedEncoder.Primitive({ isDynamic: true, data: abi.encodePacked(bytes4(0x12345678)) });
        invalidCall.chunks[0].structs = new TypedEncoder.Struct[](1);
        invalidCall.chunks[0].structs[0] = paramsStruct;

        // Expect revert with InvalidCallEncodingStructure
        vm.expectRevert(TypedEncoder.InvalidCallEncodingStructure.selector);
        invalidCall.encode();
    }

    /**
     * @notice Tests that CallWithSelector reverts when using multiple chunks
     * @dev Error: InvalidCallEncodingStructure
     * Why: CallWithSelector requires exactly 1 chunk containing the selector and params.
     *      Multiple chunks would break the expected structure and make it impossible to
     *      extract the selector and parameters in the correct order. The validation
     *      ensures the call structure is properly formed with all required components
     *      in a single chunk.
     * TODO: Implement test
     */
    function testCallWithSelectorMultipleChunks() public {
        // Create params struct
        TypedEncoder.Struct memory paramsStruct = TypedEncoder.Struct({
            typeHash: keccak256("TransferParams(address to,uint256 amount)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Struct
        });
        paramsStruct.chunks[0].primitives = new TypedEncoder.Primitive[](2);
        paramsStruct.chunks[0].primitives[0] =
            TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(address(0x1234)) });
        paramsStruct.chunks[0].primitives[1] =
            TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(1000)) });

        // Create CallWithSelector with 2 chunks (violates exactly-1-chunk rule)
        TypedEncoder.Struct memory invalidCall = TypedEncoder.Struct({
            typeHash: keccak256("InvalidCall(bytes4 selector,TransferParams params)"),
            chunks: new TypedEncoder.Chunk[](2),
            encodingType: TypedEncoder.EncodingType.CallWithSelector
        });

        // Put selector in first chunk
        invalidCall.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        invalidCall.chunks[0].primitives[0] =
            TypedEncoder.Primitive({ isDynamic: false, data: abi.encodePacked(bytes4(0x12345678)) });

        // Put params in second chunk (invalid - must be all in one chunk)
        invalidCall.chunks[1].structs = new TypedEncoder.Struct[](1);
        invalidCall.chunks[1].structs[0] = paramsStruct;

        // Expect revert with InvalidCallEncodingStructure (must have exactly 1 chunk)
        vm.expectRevert(TypedEncoder.InvalidCallEncodingStructure.selector);
        invalidCall.encode();
    }

    /**
     * @notice Tests that CallWithSelector reverts when chunk doesn't have exactly 1 primitive and 1 struct
     * @dev Error: InvalidCallEncodingStructure
     * Why: CallWithSelector must have exactly 1 primitive (the bytes4 selector) and
     *      exactly 1 struct (the function parameters). Having 2 primitives, 0 structs,
     *      2 structs, or any array fields violates the expected structure. This validation
     *      ensures the encoded output matches abi.encodeWithSelector(selector, ...params).
     * TODO: Implement test
     */
    function testCallWithSelectorWrongFieldCount() public {
        // Test Case A: 2 primitives + 1 struct (should be 1 + 1)
        TypedEncoder.Struct memory paramsStruct = TypedEncoder.Struct({
            typeHash: keccak256("Params(uint256 value)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Struct
        });
        paramsStruct.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        paramsStruct.chunks[0].primitives[0] =
            TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(100)) });

        TypedEncoder.Struct memory invalidCallA = TypedEncoder.Struct({
            typeHash: keccak256("InvalidCall(bytes4 selector,uint256 extra,Params params)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.CallWithSelector
        });
        invalidCallA.chunks[0].primitives = new TypedEncoder.Primitive[](2);
        invalidCallA.chunks[0].primitives[0] =
            TypedEncoder.Primitive({ isDynamic: false, data: abi.encodePacked(bytes4(0x12345678)) });
        invalidCallA.chunks[0].primitives[1] =
            TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(999)) });
        invalidCallA.chunks[0].structs = new TypedEncoder.Struct[](1);
        invalidCallA.chunks[0].structs[0] = paramsStruct;

        vm.expectRevert(TypedEncoder.InvalidCallEncodingStructure.selector);
        invalidCallA.encode();

        // Test Case B: 1 primitive + 2 structs (should be 1 + 1)
        TypedEncoder.Struct memory paramsStruct2 = TypedEncoder.Struct({
            typeHash: keccak256("Params2(address addr)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Struct
        });
        paramsStruct2.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        paramsStruct2.chunks[0].primitives[0] =
            TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(address(0x1234)) });

        TypedEncoder.Struct memory invalidCallB = TypedEncoder.Struct({
            typeHash: keccak256("InvalidCall(bytes4 selector,Params params,Params2 params2)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.CallWithSelector
        });
        invalidCallB.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        invalidCallB.chunks[0].primitives[0] =
            TypedEncoder.Primitive({ isDynamic: false, data: abi.encodePacked(bytes4(0x12345678)) });
        invalidCallB.chunks[0].structs = new TypedEncoder.Struct[](2);
        invalidCallB.chunks[0].structs[0] = paramsStruct;
        invalidCallB.chunks[0].structs[1] = paramsStruct2;

        vm.expectRevert(TypedEncoder.InvalidCallEncodingStructure.selector);
        invalidCallB.encode();

        // Test Case C: 1 primitive + 1 struct + 1 array (arrays not allowed)
        TypedEncoder.Struct memory invalidCallC = TypedEncoder.Struct({
            typeHash: keccak256("InvalidCall(bytes4 selector,Params params,uint256[] arr)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.CallWithSelector
        });
        invalidCallC.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        invalidCallC.chunks[0].primitives[0] =
            TypedEncoder.Primitive({ isDynamic: false, data: abi.encodePacked(bytes4(0x12345678)) });
        invalidCallC.chunks[0].structs = new TypedEncoder.Struct[](1);
        invalidCallC.chunks[0].structs[0] = paramsStruct;
        invalidCallC.chunks[0].arrays = new TypedEncoder.Array[](1);
        invalidCallC.chunks[0].arrays[0] = TypedEncoder.Array({ isDynamic: true, data: new TypedEncoder.Chunk[](0) });

        vm.expectRevert(TypedEncoder.InvalidCallEncodingStructure.selector);
        invalidCallC.encode();
    }

    /**
     * @notice Tests that CallWithSignature reverts when signature is static instead of dynamic
     * @dev Error: InvalidCallEncodingStructure
     * Why: Function signatures are strings (e.g., "transfer(address,uint256)"), which are
     *      dynamic types in Solidity. A static primitive would indicate the signature was
     *      incorrectly constructed (e.g., using bytes32 instead of string/bytes). The
     *      validation ensures isDynamic=true for the signature primitive to match the
     *      expected behavior of abi.encodeWithSignature.
     * TODO: Implement test
     */
    function testCallWithSignatureStaticSignature() public {
        // Create params struct
        TypedEncoder.Struct memory paramsStruct = TypedEncoder.Struct({
            typeHash: keccak256("TransferParams(address to,uint256 amount)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Struct
        });
        paramsStruct.chunks[0].primitives = new TypedEncoder.Primitive[](2);
        paramsStruct.chunks[0].primitives[0] =
            TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(address(0x1234)) });
        paramsStruct.chunks[0].primitives[1] =
            TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(1000)) });

        // Create CallWithSignature with static signature (should be dynamic)
        TypedEncoder.Struct memory invalidCall = TypedEncoder.Struct({
            typeHash: keccak256("InvalidCall(bytes32 signature,TransferParams params)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.CallWithSignature
        });
        invalidCall.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        // Mark signature as static (invalid - must be dynamic)
        invalidCall.chunks[0].primitives[0] =
            TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(bytes32("transfer(address,uint256)")) });
        invalidCall.chunks[0].structs = new TypedEncoder.Struct[](1);
        invalidCall.chunks[0].structs[0] = paramsStruct;

        // Expect revert with InvalidCallEncodingStructure
        vm.expectRevert(TypedEncoder.InvalidCallEncodingStructure.selector);
        invalidCall.encode();
    }

    /**
     * @notice Tests that CallWithSignature reverts with invalid structure (wrong field counts)
     * @dev Error: InvalidCallEncodingStructure
     * Why: CallWithSignature requires exactly 1 primitive (the signature string) and
     *      exactly 1 struct (the function parameters). Any deviation from this structure
     *      (e.g., 0 primitives, 2 structs, array fields) would produce invalid calldata
     *      that doesn't match abi.encodeWithSignature output. This validation ensures
     *      the call can be properly encoded with the signature-derived selector.
     * TODO: Implement test
     */
    function testCallWithSignatureInvalidStructure() public {
        // Test Case A: Multiple chunks (should be exactly 1)
        TypedEncoder.Struct memory paramsStruct = TypedEncoder.Struct({
            typeHash: keccak256("Params(uint256 value)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Struct
        });
        paramsStruct.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        paramsStruct.chunks[0].primitives[0] =
            TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(100)) });

        TypedEncoder.Struct memory invalidCallA = TypedEncoder.Struct({
            typeHash: keccak256("InvalidCall(string signature,Params params)"),
            chunks: new TypedEncoder.Chunk[](2),
            encodingType: TypedEncoder.EncodingType.CallWithSignature
        });
        invalidCallA.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        invalidCallA.chunks[0].primitives[0] =
            TypedEncoder.Primitive({ isDynamic: true, data: abi.encodePacked("transfer(address,uint256)") });
        invalidCallA.chunks[1].structs = new TypedEncoder.Struct[](1);
        invalidCallA.chunks[1].structs[0] = paramsStruct;

        vm.expectRevert(TypedEncoder.InvalidCallEncodingStructure.selector);
        invalidCallA.encode();

        // Test Case B: Wrong primitive count - 0 primitives (should be 1)
        TypedEncoder.Struct memory invalidCallB = TypedEncoder.Struct({
            typeHash: keccak256("InvalidCall(Params params)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.CallWithSignature
        });
        invalidCallB.chunks[0].structs = new TypedEncoder.Struct[](1);
        invalidCallB.chunks[0].structs[0] = paramsStruct;

        vm.expectRevert(TypedEncoder.InvalidCallEncodingStructure.selector);
        invalidCallB.encode();

        // Test Case C: Wrong primitive count - 2 primitives (should be 1)
        TypedEncoder.Struct memory invalidCallC = TypedEncoder.Struct({
            typeHash: keccak256("InvalidCall(string signature,string extra,Params params)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.CallWithSignature
        });
        invalidCallC.chunks[0].primitives = new TypedEncoder.Primitive[](2);
        invalidCallC.chunks[0].primitives[0] =
            TypedEncoder.Primitive({ isDynamic: true, data: abi.encodePacked("transfer(address,uint256)") });
        invalidCallC.chunks[0].primitives[1] =
            TypedEncoder.Primitive({ isDynamic: true, data: abi.encodePacked("extra") });
        invalidCallC.chunks[0].structs = new TypedEncoder.Struct[](1);
        invalidCallC.chunks[0].structs[0] = paramsStruct;

        vm.expectRevert(TypedEncoder.InvalidCallEncodingStructure.selector);
        invalidCallC.encode();

        // Test Case D: Wrong struct count - 0 structs (should be 1)
        TypedEncoder.Struct memory invalidCallD = TypedEncoder.Struct({
            typeHash: keccak256("InvalidCall(string signature)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.CallWithSignature
        });
        invalidCallD.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        invalidCallD.chunks[0].primitives[0] =
            TypedEncoder.Primitive({ isDynamic: true, data: abi.encodePacked("transfer(address,uint256)") });

        vm.expectRevert(TypedEncoder.InvalidCallEncodingStructure.selector);
        invalidCallD.encode();

        // Test Case E: Wrong struct count - 2 structs (should be 1)
        TypedEncoder.Struct memory paramsStruct2 = TypedEncoder.Struct({
            typeHash: keccak256("Params2(address addr)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Struct
        });
        paramsStruct2.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        paramsStruct2.chunks[0].primitives[0] =
            TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(address(0x5678)) });

        TypedEncoder.Struct memory invalidCallE = TypedEncoder.Struct({
            typeHash: keccak256("InvalidCall(string signature,Params params,Params2 params2)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.CallWithSignature
        });
        invalidCallE.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        invalidCallE.chunks[0].primitives[0] =
            TypedEncoder.Primitive({ isDynamic: true, data: abi.encodePacked("transfer(address,uint256)") });
        invalidCallE.chunks[0].structs = new TypedEncoder.Struct[](2);
        invalidCallE.chunks[0].structs[0] = paramsStruct;
        invalidCallE.chunks[0].structs[1] = paramsStruct2;

        vm.expectRevert(TypedEncoder.InvalidCallEncodingStructure.selector);
        invalidCallE.encode();
    }
}
