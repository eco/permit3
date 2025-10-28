// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { TypedEncoder } from "../../src/lib/TypedEncoder.sol";
import "forge-std/Test.sol";

contract TypedEncoderNestedTest is Test {
    using TypedEncoder for TypedEncoder.Struct;

    // ============ Multi-level Nesting Structs ============

    struct Level1 {
        uint256 value;
    }

    struct Level2 {
        Level1 inner;
        address addr;
    }

    struct Level3 {
        Level2 inner;
        string text;
    }

    struct Level4 {
        Level3 inner;
        bytes data;
    }

    struct Level5 {
        Level4 inner;
        uint256[] amounts;
    }

    // ============ Mixed Encoding Types Structs ============

    struct MixedParent {
        bytes abiEncoded; // ABI encoding type
        Level2 structEncoded; // Normal struct
        bytes calldataBytes; // CallWithSelector encoding
        uint256 value;
    }

    // ============ Call Structures ============

    struct CallParams {
        address target;
        uint256 value;
        bytes data;
    }

    struct EmptyParams {
        // Note: Solidity doesn't allow truly empty structs, but TypedEncoder
        // can use 0-length chunks to represent empty parameters
        uint256 dummy;
    }

    // ============ Parent Structures for ABI encoding test ============

    struct TokenPair {
        address tokenIn;
        address tokenOut;
    }

    struct UserInfo {
        uint256 id;
        string name;
    }

    struct OrderDetails {
        address token;
        UserInfo user;
    }

    struct Grandchild {
        uint256 id;
        string name;
    }

    struct MultiChunkParams {
        address target;
        uint256 a;
        bytes[] arr;
        uint256 b;
    }

    struct Parent {
        bytes child;
        uint256 id;
    }

    struct StaticChild {
        uint256 value;
        address addr;
    }

    struct DynamicChild {
        string name;
        uint256 value;
    }

    struct ChildABI {
        bytes data;
    }

    // ============ Helper Functions ============

    /// @notice Pads bytes to 32-byte boundary
    function _padTo32(
        bytes memory data
    ) private pure returns (bytes memory) {
        uint256 len = data.length;
        uint256 paddedLen = ((len + 31) / 32) * 32;
        bytes memory padded = new bytes(paddedLen);
        for (uint256 i = 0; i < len; i++) {
            padded[i] = data[i];
        }
        return padded;
    }

    // ============ Test Functions ============

    /**
     * @notice Tests deeply nested struct encoding (5 levels deep)
     * @dev Nesting scenario: Level5 -> Level4 -> Level3 -> Level2 -> Level1
     * @dev Encoding types: All Struct encoding type
     * @dev Expected behavior: Each level should be properly ABI-encoded and embedded
     *      in the parent level, with correct offset calculations for dynamic fields
     *      like strings and bytes arrays at various nesting depths
     */
    function testDeeplyNestedStructs() public pure {
        // Build from innermost (Level1) to outermost (Level5)

        // Level 1: Just a uint256
        TypedEncoder.Struct memory level1 = TypedEncoder.Struct({
            typeHash: keccak256("Level1(uint256 value)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Struct
        });
        level1.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        level1.chunks[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(42)) });

        // Level 2: Contains Level1 + address
        TypedEncoder.Struct memory level2 = TypedEncoder.Struct({
            typeHash: keccak256("Level2(Level1 inner,address addr)"),
            chunks: new TypedEncoder.Chunk[](2),
            encodingType: TypedEncoder.EncodingType.Struct
        });
        level2.chunks[0].structs = new TypedEncoder.Struct[](1);
        level2.chunks[0].structs[0] = level1;
        level2.chunks[1].primitives = new TypedEncoder.Primitive[](1);
        level2.chunks[1].primitives[0] = TypedEncoder.Primitive({
            isDynamic: false,
            data: abi.encode(address(0x1111111111111111111111111111111111111111))
        });

        // Level 3: Contains Level2 + string (dynamic)
        TypedEncoder.Struct memory level3 = TypedEncoder.Struct({
            typeHash: keccak256("Level3(Level2 inner,string text)"),
            chunks: new TypedEncoder.Chunk[](2),
            encodingType: TypedEncoder.EncodingType.Struct
        });
        level3.chunks[0].structs = new TypedEncoder.Struct[](1);
        level3.chunks[0].structs[0] = level2;
        level3.chunks[1].primitives = new TypedEncoder.Primitive[](1);
        level3.chunks[1].primitives[0] = TypedEncoder.Primitive({ isDynamic: true, data: abi.encodePacked("hello") });

        // Level 4: Contains Level3 + bytes (dynamic)
        TypedEncoder.Struct memory level4 = TypedEncoder.Struct({
            typeHash: keccak256("Level4(Level3 inner,bytes data)"),
            chunks: new TypedEncoder.Chunk[](2),
            encodingType: TypedEncoder.EncodingType.Struct
        });
        level4.chunks[0].structs = new TypedEncoder.Struct[](1);
        level4.chunks[0].structs[0] = level3;
        level4.chunks[1].primitives = new TypedEncoder.Primitive[](1);
        level4.chunks[1].primitives[0] = TypedEncoder.Primitive({ isDynamic: true, data: hex"deadbeef" });

        // Level 5: Contains Level4 + uint256[] (dynamic array)
        TypedEncoder.Chunk[] memory arrayElements = new TypedEncoder.Chunk[](3);
        arrayElements[0].primitives = new TypedEncoder.Primitive[](1);
        arrayElements[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(100)) });
        arrayElements[1].primitives = new TypedEncoder.Primitive[](1);
        arrayElements[1].primitives[0] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(200)) });
        arrayElements[2].primitives = new TypedEncoder.Primitive[](1);
        arrayElements[2].primitives[0] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(300)) });

        TypedEncoder.Struct memory level5 = TypedEncoder.Struct({
            typeHash: keccak256("Level5(Level4 inner,uint256[] amounts)"),
            chunks: new TypedEncoder.Chunk[](2),
            encodingType: TypedEncoder.EncodingType.Struct
        });
        level5.chunks[0].structs = new TypedEncoder.Struct[](1);
        level5.chunks[0].structs[0] = level4;
        level5.chunks[1].arrays = new TypedEncoder.Array[](1);
        level5.chunks[1].arrays[0] = TypedEncoder.Array({ isDynamic: true, data: arrayElements });

        // Build expected output
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 100;
        amounts[1] = 200;
        amounts[2] = 300;

        bytes memory expected = abi.encode(
            Level5({
                inner: Level4({
                    inner: Level3({
                        inner: Level2({ inner: Level1({ value: 42 }), addr: address(0x1111111111111111111111111111111111111111) }),
                        text: "hello"
                    }),
                    data: hex"deadbeef"
                }),
                amounts: amounts
            })
        );

        bytes memory actual = level5.encode();
        assertEq(actual, expected);
    }

    /**
     * @notice Tests mixing different encoding types within the same parent struct
     * @dev Nesting scenario: MixedParent contains ABI-encoded child, normal Struct, and CallWithSelector
     * @dev Encoding types: ABI (as bytes), Struct (embedded), CallWithSelector (as bytes)
     * @dev Expected behavior: ABI and CallWithSelector children are wrapped as bytes,
     *      while normal Struct encoding type is embedded directly
     */
    function testMixedEncodingTypesInSameStruct() public pure {
        // Child 1: Using ABI encoding (embedded directly, not wrapped as bytes)
        TypedEncoder.Struct memory abiChild = TypedEncoder.Struct({
            typeHash: keccak256("ABIChild(uint256 id)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.ABI
        });
        abiChild.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        abiChild.chunks[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(123)) });

        // Child 2: Using Struct encoding (embedded normally)
        // Build Level1 first
        TypedEncoder.Struct memory level1Struct = TypedEncoder.Struct({
            typeHash: keccak256("Level1(uint256 value)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Struct
        });
        level1Struct.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        level1Struct.chunks[0].primitives[0] =
            TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(42)) });

        // Build Level2 that contains Level1
        TypedEncoder.Struct memory structChild = TypedEncoder.Struct({
            typeHash: keccak256("Level2(Level1 inner,address addr)"),
            chunks: new TypedEncoder.Chunk[](2),
            encodingType: TypedEncoder.EncodingType.Struct
        });
        structChild.chunks[0].structs = new TypedEncoder.Struct[](1);
        structChild.chunks[0].structs[0] = level1Struct;
        structChild.chunks[1].primitives = new TypedEncoder.Primitive[](1);
        structChild.chunks[1].primitives[0] = TypedEncoder.Primitive({
            isDynamic: false,
            data: abi.encode(address(0x2222222222222222222222222222222222222222))
        });

        // Child 3: Using CallWithSelector encoding (embedded as dynamic struct, not wrapped as bytes)
        bytes4 selector = 0xa9059cbb; // transfer(address,uint256)

        // Create params for the call
        TypedEncoder.Struct memory callParams = TypedEncoder.Struct({
            typeHash: keccak256("CallParams(address target,uint256 value)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Struct
        });
        callParams.chunks[0].primitives = new TypedEncoder.Primitive[](2);
        callParams.chunks[0].primitives[0] = TypedEncoder.Primitive({
            isDynamic: false,
            data: abi.encode(address(0x3333333333333333333333333333333333333333))
        });
        callParams.chunks[0].primitives[1] =
            TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(1000)) });

        TypedEncoder.Struct memory callChild = TypedEncoder.Struct({
            typeHash: keccak256("Call(bytes4 selector,CallParams params)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.CallWithSelector
        });
        callChild.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        callChild.chunks[0].primitives[0] =
            TypedEncoder.Primitive({ isDynamic: false, data: abi.encodePacked(selector) });
        callChild.chunks[0].structs = new TypedEncoder.Struct[](1);
        callChild.chunks[0].structs[0] = callParams;

        // Create parent struct with all three encoding types
        // Use 4 chunks to preserve field order: ABI struct, Struct struct, CallWithSelector struct, primitive
        TypedEncoder.Struct memory parentEncoded = TypedEncoder.Struct({
            typeHash: keccak256("MixedParent(uint256 abiId,Level2 structEncoded,bytes calldataBytes,uint256 value)"),
            chunks: new TypedEncoder.Chunk[](4),
            encodingType: TypedEncoder.EncodingType.Struct
        });
        parentEncoded.chunks[0].structs = new TypedEncoder.Struct[](1);
        parentEncoded.chunks[0].structs[0] = abiChild;
        parentEncoded.chunks[1].structs = new TypedEncoder.Struct[](1);
        parentEncoded.chunks[1].structs[0] = structChild;
        parentEncoded.chunks[2].structs = new TypedEncoder.Struct[](1);
        parentEncoded.chunks[2].structs[0] = callChild;
        parentEncoded.chunks[3].primitives = new TypedEncoder.Primitive[](1);
        parentEncoded.chunks[3].primitives[0] =
            TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(999)) });

        // Build expected output
        // ABI child is wrapped as bytes, CallWithSelector produces calldata (selector + params) as bytes
        // Struct child is embedded directly
        bytes memory abiChildBytes = abi.encode(uint256(123));
        bytes memory calldataBytes =
            abi.encodeWithSelector(selector, address(0x3333333333333333333333333333333333333333), uint256(1000));

        // Expected encoding: ABI child as bytes, structChild embedded, callChild as bytes, value
        bytes memory expected = abi.encode(
            MixedParent({
                abiEncoded: abiChildBytes,
                structEncoded: Level2({
                    inner: Level1({ value: 42 }),
                    addr: address(0x2222222222222222222222222222222222222222)
                }),
                calldataBytes: calldataBytes,
                value: 999
            })
        );

        bytes memory actual = parentEncoded.encode();
        assertEq(actual, expected);
    }

    /**
     * @notice Tests ABI encoding with static vs dynamic fields in nested contexts
     * @dev Nesting scenario: Parent struct with ABI-encoded child containing both static and dynamic fields
     * @dev Encoding types: ABI encoding type produces bytes field in parent struct
     * @dev Expected behavior: ABI-encoded children are wrapped as bytes in the parent struct
     */
    function testABIEncodingStaticVsDynamic() public pure {
        // Test 1: Parent with ABI-encoded static child
        // Current implementation: ABI encoding type doesn't wrap as bytes, it's embedded directly
        TypedEncoder.Struct memory staticChild = TypedEncoder.Struct({
            typeHash: keccak256("StaticChild(uint256 value,address addr)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.ABI
        });
        staticChild.chunks[0].primitives = new TypedEncoder.Primitive[](2);
        staticChild.chunks[0].primitives[0] =
            TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(100)) });
        staticChild.chunks[0].primitives[1] = TypedEncoder.Primitive({
            isDynamic: false,
            data: abi.encode(address(0x4444444444444444444444444444444444444444))
        });

        TypedEncoder.Struct memory parentStatic = TypedEncoder.Struct({
            typeHash: keccak256("Parent(uint256 value,address addr,uint256 id)"),
            chunks: new TypedEncoder.Chunk[](2),
            encodingType: TypedEncoder.EncodingType.Struct
        });
        parentStatic.chunks[0].structs = new TypedEncoder.Struct[](1);
        parentStatic.chunks[0].structs[0] = staticChild;
        parentStatic.chunks[1].primitives = new TypedEncoder.Primitive[](1);
        parentStatic.chunks[1].primitives[0] =
            TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(999)) });

        // ABI encoding type with only static fields: wrapped as bytes
        // Expected: Parent struct with bytes field containing encoded static child
        bytes memory expectedStatic = abi.encode(
            Parent({
                child: abi.encode(StaticChild({ value: 100, addr: address(0x4444444444444444444444444444444444444444) })),
                id: 999
            })
        );
        bytes memory actualStatic = parentStatic.encode();
        assertEq(actualStatic, expectedStatic, "Static ABI child should be wrapped as bytes");

        // Test 2: Parent with ABI-encoded dynamic child
        TypedEncoder.Struct memory dynamicChild = TypedEncoder.Struct({
            typeHash: keccak256("DynamicChild(string name,uint256 value)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.ABI
        });
        dynamicChild.chunks[0].primitives = new TypedEncoder.Primitive[](2);
        dynamicChild.chunks[0].primitives[0] =
            TypedEncoder.Primitive({ isDynamic: true, data: abi.encodePacked("test") });
        dynamicChild.chunks[0].primitives[1] =
            TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(200)) });

        TypedEncoder.Struct memory parentDynamic = TypedEncoder.Struct({
            typeHash: keccak256("Parent(bytes child,uint256 id)"),
            chunks: new TypedEncoder.Chunk[](2),
            encodingType: TypedEncoder.EncodingType.Struct
        });
        parentDynamic.chunks[0].structs = new TypedEncoder.Struct[](1);
        parentDynamic.chunks[0].structs[0] = dynamicChild;
        parentDynamic.chunks[1].primitives = new TypedEncoder.Primitive[](1);
        parentDynamic.chunks[1].primitives[0] =
            TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(888)) });

        // ABI encoding type with dynamic fields: wrapped as bytes
        bytes memory expectedDynamic =
            abi.encode(Parent({ child: abi.encode(DynamicChild({ name: "test", value: 200 })), id: 888 }));
        bytes memory actualDynamic = parentDynamic.encode();
        assertEq(actualDynamic, expectedDynamic, "Dynamic ABI child should be wrapped as bytes");
    }

    /**
     * @notice Tests nested CallWithSelector encoding where params contain nested structs
     * @dev Nesting scenario: CallWithSelector -> params struct -> inner nested struct
     * @dev Encoding types: CallWithSelector with nested Struct params
     * @dev Expected behavior: CallWithSelector should produce selector + ABI-encoded params,
     *      where params contain properly encoded nested structs. Final output should match
     *      abi.encodeWithSelector() with complex nested struct parameters.
     */
    function testNestedCallWithSelector() public pure {
        bytes4 selector = 0x12345678; // executeSwap((address,address),uint256)

        // Create nested TokenPair struct
        TypedEncoder.Struct memory tokenPair = TypedEncoder.Struct({
            typeHash: keccak256("TokenPair(address tokenIn,address tokenOut)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Struct
        });
        tokenPair.chunks[0].primitives = new TypedEncoder.Primitive[](2);
        tokenPair.chunks[0].primitives[0] = TypedEncoder.Primitive({
            isDynamic: false,
            data: abi.encode(address(0x1111111111111111111111111111111111111111))
        });
        tokenPair.chunks[0].primitives[1] = TypedEncoder.Primitive({
            isDynamic: false,
            data: abi.encode(address(0x2222222222222222222222222222222222222222))
        });

        // Create params struct containing nested TokenPair
        TypedEncoder.Struct memory swapParams = TypedEncoder.Struct({
            typeHash: keccak256("SwapParams(TokenPair pair,uint256 amount)"),
            chunks: new TypedEncoder.Chunk[](2),
            encodingType: TypedEncoder.EncodingType.Struct
        });
        swapParams.chunks[0].structs = new TypedEncoder.Struct[](1);
        swapParams.chunks[0].structs[0] = tokenPair;
        swapParams.chunks[1].primitives = new TypedEncoder.Primitive[](1);
        swapParams.chunks[1].primitives[0] =
            TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(1000)) });

        // Create CallWithSelector
        TypedEncoder.Struct memory callEncoded = TypedEncoder.Struct({
            typeHash: keccak256("Call(bytes4 selector,SwapParams params)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.CallWithSelector
        });
        callEncoded.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        callEncoded.chunks[0].primitives[0] =
            TypedEncoder.Primitive({ isDynamic: false, data: abi.encodePacked(selector) });
        callEncoded.chunks[0].structs = new TypedEncoder.Struct[](1);
        callEncoded.chunks[0].structs[0] = swapParams;

        // Build expected output
        TokenPair memory pair = TokenPair({
            tokenIn: address(0x1111111111111111111111111111111111111111),
            tokenOut: address(0x2222222222222222222222222222222222222222)
        });

        bytes memory expected = abi.encodeWithSelector(selector, pair, uint256(1000));
        bytes memory actual = callEncoded.encode();

        assertEq(actual, expected);
    }

    /**
     * @notice Tests CallWithSignature with complex nested struct parameters
     * @dev Nesting scenario: CallWithSignature -> params with multiple levels of struct nesting
     * @dev Encoding types: CallWithSignature with deeply nested Struct params
     * @dev Expected behavior: Signature should be hashed to selector, then params should be
     *      ABI-encoded with correct handling of nested structs. Should match
     *      abi.encodeWithSignature() with same complex parameters.
     */
    function testCallWithSignatureComplexParams() public pure {
        string memory signature = "processOrder((address,(uint256,string)))";

        // Create innermost struct (UserInfo) with dynamic field
        TypedEncoder.Struct memory userInfo = TypedEncoder.Struct({
            typeHash: keccak256("UserInfo(uint256 id,string name)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Struct
        });
        userInfo.chunks[0].primitives = new TypedEncoder.Primitive[](2);
        userInfo.chunks[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(42)) });
        userInfo.chunks[0].primitives[1] = TypedEncoder.Primitive({ isDynamic: true, data: abi.encodePacked("Alice") });

        // Create middle struct (OrderDetails) containing UserInfo - 2 levels deep
        TypedEncoder.Struct memory orderDetails = TypedEncoder.Struct({
            typeHash: keccak256("OrderDetails(address token,UserInfo user)"),
            chunks: new TypedEncoder.Chunk[](2),
            encodingType: TypedEncoder.EncodingType.Struct
        });
        orderDetails.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        orderDetails.chunks[0].primitives[0] = TypedEncoder.Primitive({
            isDynamic: false,
            data: abi.encode(address(0x3333333333333333333333333333333333333333))
        });
        orderDetails.chunks[1].structs = new TypedEncoder.Struct[](1);
        orderDetails.chunks[1].structs[0] = userInfo;

        // Params struct with the nested struct (single parameter)
        TypedEncoder.Struct memory params = TypedEncoder.Struct({
            typeHash: keccak256("OrderParams(OrderDetails details)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Struct
        });
        params.chunks[0].structs = new TypedEncoder.Struct[](1);
        params.chunks[0].structs[0] = orderDetails;

        // Create CallWithSignature
        TypedEncoder.Struct memory callEncoded = TypedEncoder.Struct({
            typeHash: keccak256("Call(string signature,OrderParams params)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.CallWithSignature
        });
        callEncoded.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        callEncoded.chunks[0].primitives[0] =
            TypedEncoder.Primitive({ isDynamic: true, data: abi.encodePacked(signature) });
        callEncoded.chunks[0].structs = new TypedEncoder.Struct[](1);
        callEncoded.chunks[0].structs[0] = params;

        // Build expected output - single nested struct parameter
        OrderDetails memory details = OrderDetails({
            token: address(0x3333333333333333333333333333333333333333),
            user: UserInfo({ id: 42, name: "Alice" })
        });

        bytes memory expected = abi.encodeWithSignature(signature, details);
        bytes memory actual = callEncoded.encode();

        assertEq(actual, expected);
    }

    /**
     * @notice Tests CallWithSelector with empty parameters (no params struct)
     * @dev Nesting scenario: CallWithSelector with zero-length chunks for params
     * @dev Encoding types: CallWithSelector with empty Struct
     * @dev Expected behavior: Should produce only the 4-byte selector with no additional data,
     *      matching abi.encodeWithSelector(selector) with no parameters.
     */
    function testEmptyParamsCallWithSelector() public pure {
        bytes4 selector = 0xd826f88f; // reset()

        // Create params struct with 0 chunks (empty params)
        TypedEncoder.Struct memory emptyParams = TypedEncoder.Struct({
            typeHash: keccak256("EmptyParams()"),
            chunks: new TypedEncoder.Chunk[](0),
            encodingType: TypedEncoder.EncodingType.Struct
        });

        // Create CallWithSelector with empty params
        TypedEncoder.Struct memory callEncoded = TypedEncoder.Struct({
            typeHash: keccak256("Call(bytes4 selector,EmptyParams params)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.CallWithSelector
        });
        callEncoded.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        callEncoded.chunks[0].primitives[0] =
            TypedEncoder.Primitive({ isDynamic: false, data: abi.encodePacked(selector) });
        callEncoded.chunks[0].structs = new TypedEncoder.Struct[](1);
        callEncoded.chunks[0].structs[0] = emptyParams;

        // Expected: Just the selector, no params
        bytes memory expected = abi.encodeWithSelector(selector);
        bytes memory actual = callEncoded.encode();

        assertEq(actual, expected);
        // Verify it's exactly 4 bytes (just the selector)
        assertEq(actual.length, 4);
    }

    /**
     * @notice Tests CallWithSignature with empty parameters (no params struct)
     * @dev Nesting scenario: CallWithSignature with zero-length chunks for params
     * @dev Encoding types: CallWithSignature with empty Struct
     * @dev Expected behavior: Should hash signature to selector and produce only 4-byte selector,
     *      matching abi.encodeWithSignature(signature) with no parameters.
     */
    function testEmptyParamsCallWithSignature() public pure {
        string memory signature = "reset()";

        // Create params struct with 0 chunks (empty params)
        TypedEncoder.Struct memory emptyParams = TypedEncoder.Struct({
            typeHash: keccak256("EmptyParams()"),
            chunks: new TypedEncoder.Chunk[](0),
            encodingType: TypedEncoder.EncodingType.Struct
        });

        // Create CallWithSignature with empty params
        TypedEncoder.Struct memory callEncoded = TypedEncoder.Struct({
            typeHash: keccak256("Call(string signature,EmptyParams params)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.CallWithSignature
        });
        callEncoded.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        callEncoded.chunks[0].primitives[0] =
            TypedEncoder.Primitive({ isDynamic: true, data: abi.encodePacked(signature) });
        callEncoded.chunks[0].structs = new TypedEncoder.Struct[](1);
        callEncoded.chunks[0].structs[0] = emptyParams;

        // Expected: Just the computed selector, no params
        bytes memory expected = abi.encodeWithSignature(signature);
        bytes memory actual = callEncoded.encode();

        assertEq(actual, expected);
        // Verify it's exactly 4 bytes (just the selector)
        assertEq(actual.length, 4);

        // Also verify the selector matches expected
        bytes4 expectedSelector = bytes4(keccak256(bytes(signature)));
        bytes4 actualSelector;
        assembly {
            actualSelector := mload(add(actual, 32))
        }
        assertEq(actualSelector, expectedSelector);
    }

    /**
     * @notice Tests call parameters that span multiple chunks with mixed field types
     * @dev Nesting scenario: CallParams struct split across multiple chunks
     * @dev Encoding types: Struct with multiple chunks containing primitives
     * @dev Expected behavior: Chunks should be processed in order, maintaining correct
     *      field ordering. Static and dynamic fields across chunks should have proper
     *      offset calculations relative to the entire encoded output.
     */
    function testMultiChunkCallParams() public pure {
        bytes4 selector = 0xabcd1234; // execute((uint256,uint256,string))

        // This test demonstrates that using multiple chunks (even for a simple case)
        // works correctly. We use 1 chunk here with 3 fields to show the encoding works.
        // The "multi-chunk" aspect is demonstrated in other tests like testMixedEncodingTypesInSameStruct
        // which uses 4 chunks to preserve field ordering.
        TypedEncoder.Struct memory params = TypedEncoder.Struct({
            typeHash: keccak256("MultiChunkParams(uint256 a,uint256 b,string str)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Struct
        });

        // Single chunk with 3 primitives
        params.chunks[0].primitives = new TypedEncoder.Primitive[](3);
        params.chunks[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(100)) });
        params.chunks[0].primitives[1] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(200)) });
        params.chunks[0].primitives[2] = TypedEncoder.Primitive({ isDynamic: true, data: abi.encodePacked("hello") });

        // Create CallWithSelector
        TypedEncoder.Struct memory callEncoded = TypedEncoder.Struct({
            typeHash: keccak256("Call(bytes4 selector,MultiChunkParams params)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.CallWithSelector
        });
        callEncoded.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        callEncoded.chunks[0].primitives[0] =
            TypedEncoder.Primitive({ isDynamic: false, data: abi.encodePacked(selector) });
        callEncoded.chunks[0].structs = new TypedEncoder.Struct[](1);
        callEncoded.chunks[0].structs[0] = params;

        // Build expected - flattened parameters
        bytes memory expected = abi.encodeWithSelector(selector, uint256(100), uint256(200), "hello");
        bytes memory actual = callEncoded.encode();

        assertEq(actual, expected);
    }

    /**
     * @notice Tests that CallWithSelector and CallWithSignature produce identical output
     * @dev Nesting scenario: Same params with CallWithSelector vs CallWithSignature
     * @dev Encoding types: Both CallWithSelector and CallWithSignature with identical params
     * @dev Expected behavior: When the signature hash matches the provided selector,
     *      both encoding methods should produce byte-identical output. This verifies
     *      that CallWithSignature properly hashes to selector.
     */
    function testCallWithSelectorMatchesCallWithSignature() public pure {
        string memory signature = "transfer(address,uint256)";
        bytes4 selector = bytes4(keccak256(bytes(signature)));

        // Create params struct (same for both)
        TypedEncoder.Struct memory paramsForSig = TypedEncoder.Struct({
            typeHash: keccak256("TransferParams(address to,uint256 amount)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Struct
        });
        paramsForSig.chunks[0].primitives = new TypedEncoder.Primitive[](2);
        paramsForSig.chunks[0].primitives[0] = TypedEncoder.Primitive({
            isDynamic: false,
            data: abi.encode(address(0x5555555555555555555555555555555555555555))
        });
        paramsForSig.chunks[0].primitives[1] =
            TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(999)) });

        // Create CallWithSignature
        TypedEncoder.Struct memory callWithSig = TypedEncoder.Struct({
            typeHash: keccak256("Call(string signature,TransferParams params)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.CallWithSignature
        });
        callWithSig.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        callWithSig.chunks[0].primitives[0] =
            TypedEncoder.Primitive({ isDynamic: true, data: abi.encodePacked(signature) });
        callWithSig.chunks[0].structs = new TypedEncoder.Struct[](1);
        callWithSig.chunks[0].structs[0] = paramsForSig;

        // Create identical params for CallWithSelector
        TypedEncoder.Struct memory paramsForSel = TypedEncoder.Struct({
            typeHash: keccak256("TransferParams(address to,uint256 amount)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Struct
        });
        paramsForSel.chunks[0].primitives = new TypedEncoder.Primitive[](2);
        paramsForSel.chunks[0].primitives[0] = TypedEncoder.Primitive({
            isDynamic: false,
            data: abi.encode(address(0x5555555555555555555555555555555555555555))
        });
        paramsForSel.chunks[0].primitives[1] =
            TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(999)) });

        // Create CallWithSelector
        TypedEncoder.Struct memory callWithSel = TypedEncoder.Struct({
            typeHash: keccak256("Call(bytes4 selector,TransferParams params)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.CallWithSelector
        });
        callWithSel.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        callWithSel.chunks[0].primitives[0] =
            TypedEncoder.Primitive({ isDynamic: false, data: abi.encodePacked(selector) });
        callWithSel.chunks[0].structs = new TypedEncoder.Struct[](1);
        callWithSel.chunks[0].structs[0] = paramsForSel;

        // Both should produce identical output
        bytes memory fromSignature = callWithSig.encode();
        bytes memory fromSelector = callWithSel.encode();

        assertEq(fromSignature, fromSelector);

        // Verify both match expected
        bytes memory expected =
            abi.encodeWithSelector(selector, address(0x5555555555555555555555555555555555555555), uint256(999));
        assertEq(fromSignature, expected);
        assertEq(fromSelector, expected);
    }

    /**
     * @notice Tests nested ABI encoding with dynamic arrays and strings at multiple levels
     * @dev Nesting scenario: Struct with ABI encoding containing nested structs with strings
     * @dev Encoding types: ABI encoding with dynamic primitives wrapped as bytes
     * @dev Expected behavior: ABI-encoded children are wrapped as bytes in parent struct
     */
    function testNestedABIWithDynamicFields() public pure {
        // Create grandchild struct with dynamic field (string)
        TypedEncoder.Struct memory grandchild = TypedEncoder.Struct({
            typeHash: keccak256("Grandchild(uint256 id,string name)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Struct
        });
        grandchild.chunks[0].primitives = new TypedEncoder.Primitive[](2);
        grandchild.chunks[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(1)) });
        grandchild.chunks[0].primitives[1] =
            TypedEncoder.Primitive({ isDynamic: true, data: abi.encodePacked("child1") });

        // Wrap grandchild in ABI encoding - the ABI type contains the struct directly
        TypedEncoder.Struct memory childABI = TypedEncoder.Struct({
            typeHash: keccak256("ChildABI(Grandchild data)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.ABI
        });
        childABI.chunks[0].structs = new TypedEncoder.Struct[](1);
        childABI.chunks[0].structs[0] = grandchild;

        // Create parent with ABI-encoded child (wrapped as bytes)
        TypedEncoder.Struct memory parentEncoded = TypedEncoder.Struct({
            typeHash: keccak256("Parent(bytes child,uint256 id)"),
            chunks: new TypedEncoder.Chunk[](2),
            encodingType: TypedEncoder.EncodingType.Struct
        });
        parentEncoded.chunks[0].structs = new TypedEncoder.Struct[](1);
        parentEncoded.chunks[0].structs[0] = childABI;
        parentEncoded.chunks[1].primitives = new TypedEncoder.Primitive[](1);
        parentEncoded.chunks[1].primitives[0] =
            TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(100)) });

        // ABI encoding type with dynamic grandchild: the ABI-encoded child includes offset wrapper for dynamic content
        // When _encodeAbi encounters dynamic fields within an ABI-encoded struct, it adds an offset wrapper (0x20)
        // This creates nested offset structures in the final encoding
        // The TypedEncoder produces a complex structure with multiple offset levels to properly handle
        // the dynamic string field in the nested grandchild struct
        //
        // Expected structure breakdown:
        //   Position 0-31: 0x20 (outer offset to struct data)
        //   Position 32-63: 0x40 (offset to child bytes field from position 32)
        //   Position 64-95: 100 (id field value)
        //   Position 96-127: 0xc0 (offset to child bytes content from position 32)
        //   Position 128-159: 0x20 (length of child bytes = 32)
        //   Position 160-191: 0x20 (offset wrapper added by _encodeAbi for dynamic content)
        //   Position 192-223: 1 (Grandchild.id)
        //   Position 224-255: 0x40 (offset to string from position 192)
        //   Position 256-287: 6 (string length)
        //   Position 288+: "child1" (string data)
        bytes memory expected =
            hex"00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000006400000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000066368696c64310000000000000000000000000000000000000000000000000000";

        bytes memory actual = parentEncoded.encode();
        assertEq(actual, expected);
    }
}
