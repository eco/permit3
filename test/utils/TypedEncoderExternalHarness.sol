// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "../../src/lib/TypedEncoder.sol";

/**
 * @title TypedEncoderExternalHarness
 * @notice Test harness to verify if bytes encoding workaround works for TypedEncoder.Struct
 * @dev Tests whether we can pass TypedEncoder.Struct as bytes to external functions
 */
contract TypedEncoderExternalHarness {
    using TypedEncoder for TypedEncoder.Struct;

    // ============================================
    // APPROACH 1: Direct abi.decode
    // Result: ❌ FAILED - Error 9611: "Decoding type not supported"
    // Conclusion: Cannot use abi.decode with recursive types
    // ============================================

    // function encodeFromBytes(bytes memory encodedStruct) external pure returns (bytes memory) {
    //     TypedEncoder.Struct memory s = abi.decode(encodedStruct, (TypedEncoder.Struct));
    //     return s.encode();
    // }

    // ============================================
    // APPROACH 2: Accept bytes, return hash
    // Result: ❌ FAILED - Error 9611: "Decoding type not supported"
    // Conclusion: Cannot use abi.decode with recursive types
    // ============================================

    // function hashFromBytes(bytes memory encodedStruct) external pure returns (bytes32) {
    //     TypedEncoder.Struct memory s = abi.decode(encodedStruct, (TypedEncoder.Struct));
    //     return s.hash();
    // }

    // ============================================
    // APPROACH 3: Build struct internally from primitives
    // ============================================

    /**
     * @notice Accept primitive data, build TypedEncoder.Struct internally
     * @param typeHash The typeHash for the struct
     * @param primitiveData Array of encoded primitives
     * @return Encoded result
     */
    function encodeFromPrimitives(
        bytes32 typeHash,
        bytes[] memory primitiveData
    ) external pure returns (bytes memory) {
        // Build TypedEncoder.Struct internally (no external parameter)
        TypedEncoder.Struct memory s = TypedEncoder.Struct({
            typeHash: typeHash,
            encodingType: TypedEncoder.EncodingType.Struct,
            chunks: new TypedEncoder.Chunk[](1)
        });

        s.chunks[0].primitives = new TypedEncoder.Primitive[](primitiveData.length);
        for (uint256 i = 0; i < primitiveData.length; i++) {
            s.chunks[0].primitives[i] = TypedEncoder.Primitive({
                isDynamic: false,
                data: primitiveData[i]
            });
        }

        return s.encode();
    }
}
