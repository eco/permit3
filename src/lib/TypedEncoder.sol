// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title TypedEncoder
/// @notice A library for dynamic struct encoding supporting both EIP-712 structHash and ABI encoding
/// @dev Enables encoding arbitrary struct types at runtime without compile-time type knowledge.
///      This library bridges the gap between EIP-712 typed data (for signatures) and standard
///      Solidity ABI encoding (for contract calls), providing a unified interface for dynamic
///      struct construction and encoding.
/// @author Permit3.14 Team
library TypedEncoder {
    /// @notice Thrown when Array encoding type is used with non-struct fields (primitives or arrays)
    /// @dev Array encoding type requires chunks to contain only struct fields, not primitives or arrays
    error UnsupportedArrayType();

    /// @notice Thrown when an array element chunk doesn't contain exactly one field
    /// @dev Each array element must be represented by a chunk containing exactly one primitive, struct, or array
    error InvalidArrayElementType();

    /// @notice Thrown when CallWithSelector or CallWithSignature encoding has invalid structure
    /// @dev Call encoding types require exactly 1 chunk with 1 primitive (selector/signature) and 1 struct (params)
    error InvalidCallEncodingStructure();

    /// @notice Defines how a struct should be encoded in ABI format (does not affect EIP-712 hashing)
    /// @dev The encoding type determines the output format of the `encode()` function
    /// @param Struct Standard struct encoding - produces abi.encode() compatible output with proper head/tail layout
    /// @param Array Array encoding where nested structs become array elements encoded as bytes - used for polymorphic arrays
    /// @param ABI Pure ABI encoding without offset wrapper - used when embedding structs as bytes in parent structures
    /// @param CallWithSelector Produces abi.encodeWithSelector() output - combines bytes4 selector with ABI-encoded params for contract calls
    /// @param CallWithSignature Produces abi.encodeWithSignature() output - computes selector from signature string and combines with params
    enum EncodingType {
        Struct,
        Array,
        ABI,
        CallWithSelector,
        CallWithSignature
    }

    /// @notice Represents a complete struct with its EIP-712 type hash and ordered field chunks
    /// @dev Chunks define field order and enable flexible field arrangement. Use multiple chunks when
    ///      different field types need to be interspersed (e.g., uint256, string, uint256 would use 3 chunks).
    ///      Within a single chunk, fields are processed in order: primitives → structs → arrays.
    /// @param typeHash The EIP-712 type hash computed as keccak256("TypeName(type1 field1,type2 field2,...)")
    /// @param encodingType Determines how this struct is encoded for ABI (Struct/Array/ABI/CallWithSelector/CallWithSignature)
    /// @param chunks Ordered array of field chunks that define the struct's fields and their layout
    struct Struct {
        bytes32 typeHash;
        EncodingType encodingType;
        Chunk[] chunks;
    }

    /// @notice Represents a primitive field (non-struct, non-array value)
    /// @dev Primitives are basic Solidity types like integers, addresses, booleans, fixed-size bytes, strings, and dynamic bytes
    /// @param isDynamic True for dynamic types (string, bytes, dynamic arrays), false for static types (uint256, address, bytes32, bool, etc.)
    /// @param data The encoded field value - use abi.encode() for static types to get 32-byte aligned data,
    ///             use abi.encodePacked() for dynamic types to get the raw bytes without length prefix
    struct Primitive {
        bool isDynamic;
        bytes data;
    }

    /// @notice Represents an array field containing elements of any type
    /// @dev Each array element must be represented by a Chunk containing exactly one field (primitive, struct, or nested array).
    ///      This allows arrays of mixed complexity while maintaining type safety.
    /// @param isDynamic True for dynamic-length arrays (T[]), false for fixed-size arrays (T[N])
    /// @param data Array of chunks where each chunk contains exactly one element (one primitive, one struct, or one array)
    struct Array {
        bool isDynamic;
        Chunk[] data;
    }

    /// @notice Groups related fields together to control encoding order
    /// @dev Chunks enable flexible field ordering when building complex structs. Within a chunk, fields are
    ///      always processed in a fixed order: primitives → structs → arrays. Use multiple chunks when
    ///      different field types need to be interleaved to preserve struct field order.
    ///      Example: struct { uint256 a; string b; address c; } → 1 chunk: {primitives: [a,b,c]}
    ///               struct { uint256 a; bytes32[] arr; uint256 b; } → 2 chunks: [{primitives:[a], arrays:[arr]}, {primitives:[b]}]
    /// @param primitives Array of primitive fields (integers, addresses, strings, bytes, etc.)
    /// @param structs Array of nested struct fields
    /// @param arrays Array of array fields (can be arrays of any type including nested arrays)
    struct Chunk {
        Primitive[] primitives;
        Struct[] structs;
        Array[] arrays;
    }

    /// @notice Computes the EIP-712 struct hash for signature validation
    /// @dev Implements EIP-712 encoding: keccak256(abi.encodePacked(typeHash, encodeData(field1), encodeData(field2), ...))
    ///      - Static primitives are encoded directly (32 bytes each)
    ///      - Dynamic primitives (string, bytes) are encoded as keccak256(data)
    ///      - Nested structs are encoded recursively as their struct hash
    ///      - Arrays are encoded as keccak256(concatenation of element hashes)
    ///      The encodingType parameter does NOT affect EIP-712 hashing - only ABI encoding via encode()
    /// @param s The struct to hash following EIP-712 rules
    /// @return The 32-byte EIP-712 compliant struct hash (structHash)
    function hash(
        Struct memory s
    ) internal pure returns (bytes32) {
        bytes memory bz = abi.encodePacked(s.typeHash);
        uint256 chunksLen = s.chunks.length;

        for (uint256 i = 0; i < chunksLen; i++) {
            bz = abi.encodePacked(bz, _encodeEip712(s.chunks[i]));
        }

        return keccak256(bz);
    }

    /// @notice Encodes a struct according to its encodingType, producing various output formats
    /// @dev Behavior depends on encodingType:
    ///      - Struct: Standard abi.encode() output with head/tail layout, dynamic structs include offset wrapper
    ///      - Array: Encodes struct fields as array elements where nested structs become bytes
    ///      - ABI: Pure ABI encoding without offset wrapper (for embedding in parent structs as bytes)
    ///      - CallWithSelector: Produces calldata with bytes4 selector + ABI params (like abi.encodeWithSelector)
    ///      - CallWithSignature: Computes selector from signature string + ABI params (like abi.encodeWithSignature)
    /// @param s The struct to encode with its configured encodingType
    /// @return Encoded bytes in the format specified by s.encodingType:
    ///         Struct/Array: ABI-encoded struct data (with offset wrapper if dynamic)
    ///         ABI: Raw ABI encoding (no wrapper)
    ///         CallWithSelector/Signature: 4-byte selector + ABI-encoded parameters (calldata)
    function encode(
        Struct memory s
    ) internal pure returns (bytes memory) {
        // CallWithSelector and CallWithSignature return raw calldata (selector + params)
        if (s.encodingType == EncodingType.CallWithSelector) {
            return _encodeCallWithSelector(s);
        }
        if (s.encodingType == EncodingType.CallWithSignature) {
            return _encodeCallWithSignature(s);
        }
        // ABI encoding type returns raw struct encoding without offset wrapper
        if (s.encodingType == EncodingType.ABI) {
            return _encodeAbi(s, false);
        }

        // For Array and Struct types, encode and add offset wrapper if dynamic
        bytes memory encoded;
        if (s.encodingType == EncodingType.Array) {
            encoded = _encodeAsArray(s);
        } else {
            // Default Struct type uses _encodeAbi
            encoded = _encodeAbi(s, false);
        }

        return _isDynamic(s) ? abi.encodePacked(abi.encode(uint256(32)), encoded) : encoded;
    }

    /// @notice Encodes a struct as an array where each nested struct becomes an array element encoded as bytes
    /// @dev Used for polymorphic arrays where elements have different struct types. All chunks must contain
    ///      only structs - primitives and arrays are not supported. The output format is:
    ///      [array length] [offset1] [offset2] ... [offsetN] [struct1 as bytes] [struct2 as bytes] ...
    /// @param s The struct with EncodingType.Array - must have only struct fields in chunks
    /// @return ABI-encoded array with length prefix, offset table, and struct data encoded as bytes elements
    function _encodeAsArray(
        Struct memory s
    ) private pure returns (bytes memory) {
        uint256 totalStructs = 0;
        uint256 chunksLen = s.chunks.length;

        for (uint256 i = 0; i < chunksLen; i++) {
            if (s.chunks[i].primitives.length > 0 || s.chunks[i].arrays.length > 0) {
                revert UnsupportedArrayType();
            }

            totalStructs += s.chunks[i].structs.length;
        }

        bytes[] memory structEncodings = new bytes[](totalStructs);
        uint256[] memory offsets = new uint256[](totalStructs);
        uint256 elementIndex = 0;
        uint256 currentOffset = totalStructs * 32;

        for (uint256 i = 0; i < chunksLen; i++) {
            uint256 structsLen = s.chunks[i].structs.length;

            for (uint256 j = 0; j < structsLen; j++) {
                structEncodings[elementIndex] = _encodeAbi(s.chunks[i].structs[j], true);
                offsets[elementIndex] = currentOffset;
                currentOffset += structEncodings[elementIndex].length;
                elementIndex++;
            }
        }

        bytes memory arrayHeader;
        bytes memory arrayData;

        for (uint256 i = 0; i < totalStructs; i++) {
            arrayHeader = abi.encodePacked(arrayHeader, abi.encode(offsets[i]));
            arrayData = abi.encodePacked(arrayData, structEncodings[i]);
        }

        return abi.encodePacked(abi.encode(totalStructs), arrayHeader, arrayData);
    }

    /// @notice Encodes a function call with a bytes4 selector, producing abi.encodeWithSelector() compatible output
    /// @dev Requires exactly 1 chunk containing:
    ///      - 1 primitive: bytes4 selector (4 bytes, use abi.encodePacked(bytes4))
    ///      - 1 struct: function parameters
    ///      The params struct fields are encoded as individual function arguments (flattened), not as a wrapped struct.
    ///      Output format: [4-byte selector][ABI-encoded params]
    /// @param s The struct with EncodingType.CallWithSelector and valid structure
    /// @return Calldata bytes compatible with abi.encodeWithSelector(selector, ...params) - ready for low-level calls
    function _encodeCallWithSelector(
        Struct memory s
    ) private pure returns (bytes memory) {
        // Validate structure: exactly 1 chunk with 1 primitive (selector) and 1 struct (params)
        if (s.chunks.length != 1) {
            revert InvalidCallEncodingStructure();
        }

        Chunk memory chunk = s.chunks[0];
        if (chunk.primitives.length != 1 || chunk.structs.length != 1 || chunk.arrays.length != 0) {
            revert InvalidCallEncodingStructure();
        }

        Primitive memory selectorPrimitive = chunk.primitives[0];

        // Selector must be static (not dynamic) and exactly 4 bytes
        if (selectorPrimitive.isDynamic || selectorPrimitive.data.length != 4) {
            revert InvalidCallEncodingStructure();
        }

        // Extract the 4-byte selector directly from the 4-byte data
        bytes memory selectorData = selectorPrimitive.data;
        bytes4 selector;
        assembly {
            // Load from data + 32 (skip length prefix) to get the actual bytes
            selector := mload(add(selectorData, 32))
        }

        // Encode the params struct
        Struct memory paramsStruct = chunk.structs[0];

        // For CallWithSelector, we need to encode the struct fields as if they were passed
        // individually to abi.encodeWithSelector, not as a wrapped struct
        // This means we encode the chunk directly without struct wrapper
        bytes memory params;

        if (paramsStruct.chunks.length == 0) {
            // Empty params case (e.g., reset() with no arguments)
            params = "";
        } else if (paramsStruct.chunks.length == 1) {
            // Single chunk - encode it directly
            params = _encodeAbi(paramsStruct.chunks[0]);
        } else {
            // Multiple chunks - encode each and concatenate
            for (uint256 i = 0; i < paramsStruct.chunks.length; i++) {
                params = abi.encodePacked(params, _encodeAbi(paramsStruct.chunks[i]));
            }
        }

        // Combine selector (4 bytes) + params
        return abi.encodePacked(selector, params);
    }

    /// @notice Encodes a function call with a signature string, computing the selector and producing calldata
    /// @dev Requires exactly 1 chunk containing:
    ///      - 1 dynamic primitive: function signature string (e.g., "transfer(address,uint256)")
    ///      - 1 struct: function parameters
    ///      Computes selector as bytes4(keccak256(signature)), then encodes like CallWithSelector.
    ///      The params struct fields are encoded as individual function arguments (flattened).
    ///      Output format: [4-byte selector][ABI-encoded params]
    /// @param s The struct with EncodingType.CallWithSignature and valid structure
    /// @return Calldata bytes compatible with abi.encodeWithSignature(sig, ...params) - ready for low-level calls
    function _encodeCallWithSignature(
        Struct memory s
    ) private pure returns (bytes memory) {
        // Validate structure: exactly 1 chunk with 1 primitive (signature) and 1 struct (params)
        if (s.chunks.length != 1) {
            revert InvalidCallEncodingStructure();
        }

        Chunk memory chunk = s.chunks[0];
        if (chunk.primitives.length != 1 || chunk.structs.length != 1 || chunk.arrays.length != 0) {
            revert InvalidCallEncodingStructure();
        }

        Primitive memory signaturePrimitive = chunk.primitives[0];

        // Signature must be dynamic (string/bytes)
        if (!signaturePrimitive.isDynamic) {
            revert InvalidCallEncodingStructure();
        }

        // Compute selector from signature: bytes4(keccak256(signature))
        bytes4 selector = bytes4(keccak256(signaturePrimitive.data));

        // Encode the params struct
        Struct memory paramsStruct = chunk.structs[0];

        // For CallWithSignature, we need to encode the struct fields as if they were passed
        // individually to abi.encodeWithSignature, not as a wrapped struct
        // This means we encode the chunk directly without struct wrapper
        bytes memory params;

        if (paramsStruct.chunks.length == 0) {
            // Empty params case (e.g., reset() with no arguments)
            params = "";
        } else if (paramsStruct.chunks.length == 1) {
            // Single chunk - encode it directly
            params = _encodeAbi(paramsStruct.chunks[0]);
        } else {
            // Multiple chunks - encode each and concatenate
            for (uint256 i = 0; i < paramsStruct.chunks.length; i++) {
                params = abi.encodePacked(params, _encodeAbi(paramsStruct.chunks[i]));
            }
        }

        // Combine selector (4 bytes) + params
        return abi.encodePacked(selector, params);
    }

    /// @notice Encodes a chunk's fields according to EIP-712 rules for struct hash computation
    /// @dev Processing order: primitives → structs → arrays
    ///      - Static primitives: encoded value (32 bytes)
    ///      - Dynamic primitives: keccak256(value)
    ///      - Structs: recursively computed struct hash
    ///      - Arrays: keccak256 of concatenated element encodings
    ///      All encodings are concatenated using abi.encodePacked()
    /// @param chunk The chunk containing primitives, structs, and/or arrays to encode
    /// @return Concatenated EIP-712 encoded data for all fields in the chunk (used in struct hash computation)
    function _encodeEip712(
        Chunk memory chunk
    ) private pure returns (bytes memory) {
        bytes memory bz;

        uint256 primitiveLen = chunk.primitives.length;
        for (uint256 i = 0; i < primitiveLen; i++) {
            Primitive memory p = chunk.primitives[i];

            bz = p.isDynamic ? abi.encodePacked(bz, keccak256(p.data)) : abi.encodePacked(bz, p.data);
        }

        uint256 structLen = chunk.structs.length;
        for (uint256 i = 0; i < structLen; i++) {
            bz = abi.encodePacked(bz, hash(chunk.structs[i]));
        }

        uint256 arraysLen = chunk.arrays.length;
        for (uint256 i = 0; i < arraysLen; i++) {
            bz = abi.encodePacked(bz, _encodeEip712(chunk.arrays[i]));
        }

        return bz;
    }

    /// @notice Encodes an array according to EIP-712 rules: keccak256 of concatenated element encodings
    /// @dev Each array element (represented as a Chunk) is EIP-712 encoded, then all encodings are
    ///      concatenated and hashed. This applies to both fixed-size and dynamic arrays.
    ///      Array encoding: keccak256(abi.encodePacked(encodeData(element1), encodeData(element2), ...))
    /// @param array The array with elements stored as chunks (each chunk contains one element)
    /// @return The 32-byte hash representing the array in EIP-712 struct hash computation
    function _encodeEip712(
        Array memory array
    ) private pure returns (bytes32) {
        bytes memory bz;
        uint256 arrayLen = array.data.length;

        for (uint256 i = 0; i < arrayLen; i++) {
            bz = abi.encodePacked(bz, _encodeEip712(array.data[i]));
        }

        return keccak256(bz);
    }

    /// @notice Encodes a struct using standard Solidity ABI encoding rules with head/tail layout
    /// @dev Implements ABI encoding where:
    ///      - Static fields go in the head (encoded in place)
    ///      - Dynamic fields go in the tail (head contains offset pointer)
    ///      The asBytes parameter controls whether nested structs should be encoded as bytes (for polymorphic arrays)
    /// @param s The struct to ABI encode
    /// @param asBytes If true, encode nested structs as bytes elements (for polymorphic array encoding)
    /// @return ABI-encoded struct data with proper head/tail layout matching Solidity's abi.encode() output
    function _encodeAbi(Struct memory s, bool asBytes) private pure returns (bytes memory) {
        uint256 fieldCount = 0;
        uint256 chunksLen = s.chunks.length;

        for (uint256 i = 0; i < chunksLen; i++) {
            fieldCount += s.chunks[i].primitives.length;
            fieldCount += s.chunks[i].structs.length;
            fieldCount += s.chunks[i].arrays.length;
        }

        bytes[] memory headParts = new bytes[](fieldCount);
        bytes[] memory tailParts = new bytes[](fieldCount);
        bool[] memory hasTail = new bool[](fieldCount);

        uint256 fieldIndex = 0;

        for (uint256 i = 0; i < chunksLen; i++) {
            fieldIndex = _encodeChunkFields(s.chunks[i], headParts, tailParts, hasTail, fieldIndex, asBytes);
        }

        return _abiEncodeHeadTail(headParts, tailParts, hasTail, fieldCount);
    }

    /// @notice Encodes an array using standard Solidity ABI encoding rules
    /// @dev Array encoding format:
    ///      - Dynamic arrays: [length (32 bytes)][elements...]
    ///      - Fixed arrays: [elements...] (no length prefix)
    ///      - Static elements: encoded inline
    ///      - Dynamic elements: head contains offsets, tail contains data
    ///      Each array element must be represented by a chunk containing exactly one field
    /// @param array The array to encode with elements stored as chunks
    /// @return ABI-encoded array data matching Solidity's encoding for T[] or T[N]
    function _encodeAbi(
        Array memory array
    ) private pure returns (bytes memory) {
        uint256 arrayLen = array.data.length;
        bytes memory lengthPrefix = array.isDynamic ? abi.encode(arrayLen) : bytes("");

        if (arrayLen == 0) {
            return lengthPrefix;
        }

        bool hasDynamicElement = _isElementDynamic(array.data[0]);
        bytes[] memory elements = new bytes[](arrayLen);

        for (uint256 i = 0; i < arrayLen; i++) {
            Chunk memory chunk = array.data[i];

            if (chunk.primitives.length + chunk.structs.length + chunk.arrays.length != 1) {
                revert InvalidArrayElementType();
            }

            if (chunk.primitives.length == 1) {
                Primitive memory p = chunk.primitives[0];

                elements[i] = hasDynamicElement ? abi.encodePacked(abi.encode(p.data.length), _padTo32(p.data)) : p.data;
            } else if (chunk.structs.length == 1) {
                elements[i] = _encodeAbi(chunk.structs[0], false);
            } else {
                elements[i] = _encodeAbi(chunk.arrays[0]);
            }
        }

        if (!hasDynamicElement) {
            bytes memory result = lengthPrefix;
            for (uint256 i = 0; i < arrayLen; i++) {
                result = abi.encodePacked(result, elements[i]);
            }
            return result;
        }

        uint256 headSize = arrayLen * 32;
        bytes memory head;
        bytes memory tail;
        uint256 tailOffset = headSize;

        for (uint256 i = 0; i < arrayLen; i++) {
            head = abi.encodePacked(head, abi.encode(tailOffset));
            tail = abi.encodePacked(tail, elements[i]);
            tailOffset += elements[i].length;
        }

        return abi.encodePacked(lengthPrefix, head, tail);
    }

    /// @notice Encodes a single chunk's fields using ABI encoding with head/tail layout
    /// @dev Processes fields in order (primitives → structs → arrays) and applies standard ABI encoding.
    ///      Static fields are encoded in the head, dynamic fields are encoded in the tail with offsets in the head.
    ///      This is used when encoding chunks directly for CallWithSelector/CallWithSignature parameter flattening.
    /// @param chunk The chunk containing fields to encode
    /// @return ABI-encoded data for all fields in the chunk with proper head/tail layout
    function _encodeAbi(
        Chunk memory chunk
    ) private pure returns (bytes memory) {
        uint256 totalFields = chunk.primitives.length + chunk.structs.length + chunk.arrays.length;

        bytes[] memory headParts = new bytes[](totalFields);
        bytes[] memory tailParts = new bytes[](totalFields);
        bool[] memory hasTail = new bool[](totalFields);

        _encodeChunkFields(chunk, headParts, tailParts, hasTail, 0, false);

        return _abiEncodeHeadTail(headParts, tailParts, hasTail, totalFields);
    }

    /// @notice Encodes all fields in a chunk, populating head/tail arrays for ABI encoding
    /// @dev Processes fields in order: primitives → structs → arrays
    ///      - Static fields: populated in headParts
    ///      - Dynamic fields: offset in headParts, data in tailParts, hasTail flag set
    ///      The asBytes parameter forces nested structs to be encoded as bytes (for polymorphic arrays)
    /// @param chunk The chunk containing fields to encode
    /// @param headParts Array to store head data (static values or offsets for dynamic values)
    /// @param tailParts Array to store tail data (dynamic field contents)
    /// @param hasTail Boolean array indicating which fields have tail data
    /// @param startIndex The index in head/tail arrays where this chunk's fields start
    /// @param asBytes If true, encode child structs as bytes regardless of their encodingType
    /// @return The next available index in head/tail arrays after encoding this chunk's fields
    function _encodeChunkFields(
        Chunk memory chunk,
        bytes[] memory headParts,
        bytes[] memory tailParts,
        bool[] memory hasTail,
        uint256 startIndex,
        bool asBytes
    ) private pure returns (uint256) {
        uint256 fieldIndex = startIndex;

        uint256 primitivesLen = chunk.primitives.length;
        for (uint256 i = 0; i < primitivesLen; i++) {
            if (chunk.primitives[i].isDynamic) {
                tailParts[fieldIndex] =
                    abi.encodePacked(abi.encode(chunk.primitives[i].data.length), _padTo32(chunk.primitives[i].data));
                hasTail[fieldIndex] = true;
            } else {
                headParts[fieldIndex] = chunk.primitives[i].data;
            }

            fieldIndex++;
        }

        uint256 structsLen = chunk.structs.length;
        for (uint256 i = 0; i < structsLen; i++) {
            Struct memory childStruct = chunk.structs[i];

            if (asBytes) {
                bytes memory innerEncoded = _isDynamic(childStruct)
                    ? abi.encodePacked(abi.encode(uint256(32)), _encodeAbi(childStruct, true))
                    : _encodeAbi(childStruct, true);
                tailParts[fieldIndex] = abi.encodePacked(abi.encode(innerEncoded.length), _padTo32(innerEncoded));
                hasTail[fieldIndex] = true;
                fieldIndex++;
                continue;
            }

            bytes memory structEncoded;
            if (childStruct.encodingType == EncodingType.Array) {
                structEncoded = _encodeAsArray(childStruct);
            } else if (childStruct.encodingType == EncodingType.CallWithSelector) {
                structEncoded = _encodeCallWithSelector(childStruct);
            } else if (childStruct.encodingType == EncodingType.CallWithSignature) {
                structEncoded = _encodeCallWithSignature(childStruct);
            } else {
                // EncodingType.Struct or EncodingType.ABI - both use standard ABI encoding
                structEncoded = _encodeAbi(childStruct, false);
            }

            if (_isDynamic(childStruct)) {
                tailParts[fieldIndex] = structEncoded;
                hasTail[fieldIndex] = true;
                fieldIndex++;
                continue;
            }

            headParts[fieldIndex] = structEncoded;
            fieldIndex++;
        }

        uint256 arraysLen = chunk.arrays.length;
        for (uint256 i = 0; i < arraysLen; i++) {
            bytes memory arrayEncoded = _encodeAbi(chunk.arrays[i]);

            if (_isDynamic(chunk.arrays[i])) {
                tailParts[fieldIndex] = arrayEncoded;
                hasTail[fieldIndex] = true;
                fieldIndex++;
                continue;
            }

            headParts[fieldIndex] = arrayEncoded;
            fieldIndex++;
        }

        return fieldIndex;
    }

    /// @notice Combines head and tail parts into final ABI-encoded output
    /// @dev Implements standard ABI head/tail encoding:
    ///      1. Calculate initial tail offset (sum of head sizes: static fields are 32 bytes, dynamic fields are 32-byte offsets)
    ///      2. Build head: static values in place, offsets for dynamic values
    ///      3. Build tail: concatenate all dynamic field data
    ///      4. Result: [head][tail]
    /// @param headParts Array of head data - contains actual data for static fields, unused for dynamic fields
    /// @param tailParts Array of tail data - contains actual data for dynamic fields
    /// @param hasTail Boolean array indicating which fields are dynamic (true = field has tail data)
    /// @param fieldCount Total number of fields being encoded
    /// @return Complete ABI-encoded bytes with proper head/tail layout
    function _abiEncodeHeadTail(
        bytes[] memory headParts,
        bytes[] memory tailParts,
        bool[] memory hasTail,
        uint256 fieldCount
    ) private pure returns (bytes memory) {
        uint256 tailOffset = 0;
        for (uint256 i = 0; i < fieldCount; i++) {
            tailOffset += hasTail[i] ? 32 : headParts[i].length;
        }

        bytes memory head;
        bytes memory tail;

        for (uint256 i = 0; i < fieldCount; i++) {
            if (!hasTail[i]) {
                head = abi.encodePacked(head, headParts[i]);
                continue;
            }

            bytes memory tailPart = tailParts[i];
            head = abi.encodePacked(head, abi.encode(tailOffset));
            tail = abi.encodePacked(tail, tailPart);
            tailOffset += tailPart.length;
        }

        return abi.encodePacked(head, tail);
    }

    /// @notice Pads bytes data to the next 32-byte boundary by appending zero bytes
    /// @dev ABI encoding requires dynamic data (strings, bytes) to be padded to 32-byte multiples.
    ///      Calculates padded length as ceiling(length / 32) * 32 and appends zero bytes if needed.
    ///      Example: 35 bytes → 64 bytes (adds 29 zero bytes)
    /// @param data The bytes to pad (can be any length)
    /// @return Padded bytes with length as a multiple of 32 (original data + zero bytes)
    function _padTo32(
        bytes memory data
    ) private pure returns (bytes memory) {
        uint256 len = data.length;
        uint256 paddedLen = ((len + 31) / 32) * 32;

        if (len == paddedLen) {
            return data;
        }

        return abi.encodePacked(data, new bytes(paddedLen - len));
    }

    /// @notice Determines if an array element is dynamic by examining its chunk
    /// @dev Array elements must be represented by chunks containing exactly one field.
    ///      Returns true if that single field is dynamic (dynamic primitive, dynamic struct, or dynamic/nested array).
    ///      Reverts if the chunk doesn't contain exactly one field.
    /// @param chunk The chunk representing one array element (must contain exactly 1 primitive, struct, or array)
    /// @return True if the element is dynamic and requires offset-based encoding, false if static
    function _isElementDynamic(
        Chunk memory chunk
    ) private pure returns (bool) {
        if (chunk.primitives.length == 1) {
            return chunk.primitives[0].isDynamic;
        } else if (chunk.structs.length == 1) {
            return _isDynamic(chunk.structs[0]);
        } else if (chunk.arrays.length == 1) {
            return _isDynamic(chunk.arrays[0]);
        }

        revert InvalidArrayElementType();
    }

    /// @notice Determines if a chunk contains any dynamic fields
    /// @dev A chunk is dynamic if any of its fields are dynamic:
    ///      - Any primitive marked as dynamic (string, bytes, etc.)
    ///      - Any nested struct that is dynamic
    ///      - Any array that is dynamic (checked recursively)
    ///      Checks all primitives, structs, and arrays in the chunk.
    /// @param chunk The chunk to check for dynamic fields
    /// @return True if the chunk contains at least one dynamic field, false if all fields are static
    function _isDynamic(
        Chunk memory chunk
    ) private pure returns (bool) {
        uint256 primitivesLen = chunk.primitives.length;
        for (uint256 i = 0; i < primitivesLen; i++) {
            if (chunk.primitives[i].isDynamic) {
                return true;
            }
        }

        uint256 structsLen = chunk.structs.length;
        for (uint256 i = 0; i < structsLen; i++) {
            if (_isDynamic(chunk.structs[i])) {
                return true;
            }
        }

        uint256 arraysLen = chunk.arrays.length;
        for (uint256 i = 0; i < arraysLen; i++) {
            if (_isDynamic(chunk.arrays[i])) {
                return true;
            }
        }

        return false;
    }

    /// @notice Determines if an array is dynamic for ABI encoding purposes
    /// @dev An array is dynamic if:
    ///      1. It's a dynamic-length array (T[] vs T[N]), OR
    ///      2. It's a fixed-size array containing dynamic elements (e.g., string[3])
    ///      Recursively checks element chunks to determine if elements are dynamic.
    /// @param array The array to check
    /// @return True if the array requires offset-based encoding (dynamic), false if it can be encoded inline (static)
    function _isDynamic(
        Array memory array
    ) private pure returns (bool) {
        if (array.isDynamic) {
            return true;
        }

        uint256 dataLen = array.data.length;
        for (uint256 i = 0; i < dataLen; i++) {
            if (_isDynamic(array.data[i])) {
                return true;
            }
        }

        return false;
    }

    /// @notice Determines if a struct is dynamic based on its encoding type and field contents
    /// @dev A struct is dynamic if:
    ///      - encodingType is Array (polymorphic array encoding is always dynamic)
    ///      - encodingType is CallWithSelector or CallWithSignature (calldata is always dynamic bytes)
    ///      - encodingType is Struct or ABI and any of its chunks contain dynamic fields
    ///      This affects how the struct is encoded when nested in a parent struct (offset vs inline).
    /// @param s The struct to check
    /// @return True if the struct requires offset-based encoding when nested, false if it can be encoded inline
    function _isDynamic(
        Struct memory s
    ) private pure returns (bool) {
        if (s.encodingType == EncodingType.Array) {
            return true;
        }

        if (s.encodingType == EncodingType.CallWithSelector || s.encodingType == EncodingType.CallWithSignature) {
            return true;  // Call encodings are always dynamic (represented as bytes)
        }

        // For EncodingType.Struct and EncodingType.ABI, check if any chunks are dynamic
        uint256 chunksLen = s.chunks.length;
        for (uint256 i = 0; i < chunksLen; i++) {
            if (_isDynamic(s.chunks[i])) {
                return true;
            }
        }

        return false;
    }
}
