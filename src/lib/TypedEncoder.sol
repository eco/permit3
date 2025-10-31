// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title TypedEncoder
 * @notice A library for dynamic struct encoding supporting both EIP-712 structHash and ABI encoding
 * @dev Enables encoding arbitrary struct types at runtime without compile-time type knowledge.
 *      This library bridges the gap between EIP-712 typed data (for signatures) and standard
 *      Solidity ABI encoding (for contract calls), providing a unified interface for dynamic
 *      struct construction and encoding.
 * @author Permit3.14 Team
 */
library TypedEncoder {
    /**
     * @notice Thrown when Array encoding type is used with non-struct fields (primitives or arrays)
     * @dev Array encoding type requires chunks to contain only struct fields, not primitives or arrays
     */
    error UnsupportedArrayType();

    /**
     * @notice Thrown when an array element chunk doesn't contain exactly one field
     * @dev Each array element must be represented by a chunk containing exactly one primitive, struct, or array
     */
    error InvalidArrayElementType();

    /**
     * @notice Thrown when CallWithSelector or CallWithSignature encoding has invalid structure
     * @dev Call encoding types require exactly 1 chunk with 1 primitive (selector/signature) and 1 struct (params)
     */
    error InvalidCallEncodingStructure();

    /**
     * @notice Thrown when an encoding type is not yet implemented
     */
    error EncodingTypeNotImplemented();

    /**
     * @notice Thrown when Create encoding has invalid structure
     * @dev Create requires exactly 1 chunk with 2 primitives: address deployer, uint256 nonce
     */
    error InvalidCreateEncodingStructure();

    /**
     * @notice Thrown when Create2 encoding has invalid structure
     * @dev Create2 requires exactly 1 chunk with 3 primitives: address deployer, bytes32 salt, bytes32 initCodeHash
     */
    error InvalidCreate2EncodingStructure();

    /**
     * @notice Thrown when Create3 encoding has invalid structure
     * @dev Create3 requires exactly 1 chunk with 3 primitives: address deployer, bytes32 salt, bytes32
     * createDeployCodeHash
     */
    error InvalidCreate3EncodingStructure();

    /**
     * @notice Defines how a struct should be encoded in ABI format (does not affect EIP-712 hashing)
     * @dev The encoding type determines the output format of the `encode()` function
     * @param Struct Standard struct encoding - produces abi.encode() compatible output with proper head/tail layout
     * @param Array Array encoding where nested structs become array elements encoded as bytes for polymorphic types
     * @param ABI Pure ABI encoding without offset wrapper - used when embedding structs as bytes in parent structures
     * @param Packed computes abi.encodePacked(all_fields) for compact byte encoding without hashing
     * @param CallWithSelector combines bytes4 selector with ABI-encoded params for contract calls
     * @param CallWithSignature computes selector from signature string and combines with params
     * @param Hash computes keccak256(abi.encodePacked(all_fields)) for compact hash commitments with expandable data
     * @param Create computes contract address from CREATE opcode: keccak256(rlp([deployer, nonce]))[12:]
     * @param Create2 computes contract address from CREATE2 opcode: keccak256(0xff ++ deployer ++ salt ++
     * initCodeHash)[12:]
     * @param Create3 computes contract address from CREATE3 pattern: two-stage CREATE2 + CREATE for
     * bytecode-independent addresses
     */
    enum EncodingType {
        Struct,
        Array,
        ABI,
        Packed,
        CallWithSelector,
        CallWithSignature,
        Hash,
        Create,
        Create2,
        Create3
    }

    /**
     * @notice Represents a complete struct with its EIP-712 type hash and ordered field chunks
     * @dev Chunks define field order and enable flexible field arrangement. Use multiple chunks when
     *      different field types need to be interspersed (e.g., uint256, string, uint256 would use 3 chunks).
     *      Within a single chunk, fields are processed in order: primitives → structs → arrays.
     * @param typeHash The EIP-712 type hash computed as keccak256("TypeName(type1 field1,type2 field2,...)")
     * @param encodingType Determines how this struct is encoded for ABI
     * (Struct/Array/ABI/CallWithSelector/CallWithSignature)
     * @param chunks Ordered array of field chunks that define the struct's fields and their layout
     */
    struct Struct {
        bytes32 typeHash;
        EncodingType encodingType;
        Chunk[] chunks;
    }

    /**
     * @notice Represents a primitive field (non-struct, non-array value)
     * @dev Primitives are basic types like integers, addresses, booleans, fixed-size bytes, strings, and bytes
     * @param isDynamic True for dynamic string, bytes, dynamic arrays; false for uint256, address, bytes32, bool, etc.
     * @param data The encoded field value - use abi.encode() for static types to get 32-byte aligned data,
     *             use abi.encodePacked() for dynamic types to get the raw bytes without length prefix
     */
    struct Primitive {
        bool isDynamic;
        bytes data;
    }

    /**
     * @notice Represents an array field containing elements of any type
     * @dev Each array element must be represented by a Chunk containing exactly one field (primitive, struct, or
     * nested array).
     *      This allows arrays of mixed complexity while maintaining type safety.
     * @param isDynamic True for dynamic-length arrays (T[]), false for fixed-size arrays (T[N])
     * @param data Array of chunks where each chunk contains exactly one element (one primitive, one struct, or one
     * array)
     */
    struct Array {
        bool isDynamic;
        Chunk[] data;
    }

    /**
     * @notice Groups related fields together to control encoding order
     * @dev Chunks enable flexible field ordering when building complex structs. Within a chunk, fields are
     *      always processed in a fixed order: primitives → structs → arrays. Use multiple chunks when
     *      different field types need to be interleaved to preserve struct field order.
     *      Example: struct { uint256 a; string b; address c; } → 1 chunk: {primitives: [a,b,c]}
     *               struct { uint256 a; bytes32[] arr; uint256 b; } → 2 chunks: [{primitives:[a], arrays:[arr]},
     * {primitives:[b]}]
     * @param primitives Array of primitive fields (integers, addresses, strings, bytes, etc.)
     * @param structs Array of nested struct fields
     * @param arrays Array of array fields (can be arrays of any type including nested arrays)
     */
    struct Chunk {
        Primitive[] primitives;
        Struct[] structs;
        Array[] arrays;
    }

    /**
     * @notice Computes the EIP-712 struct hash for signature validation
     * @dev Implements EIP-712 encoding: keccak(encodePacked(typeHash, encodeData(field1), encodeData(field2)))
     *      - Static primitives are encoded directly (32 bytes each)
     *      - Dynamic primitives (string, bytes) are encoded as keccak256(data)
     *      - Nested structs are encoded recursively as their struct hash
     *      - Arrays are encoded as keccak256(concatenation of element hashes)
     *      The encodingType parameter does NOT affect EIP-712 hashing - only ABI encoding via encode()
     * @param s The struct to hash following EIP-712 rules
     * @return The 32-byte EIP-712 compliant struct hash (structHash)
     */
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

    /**
     * @notice Encodes a struct according to its encodingType, producing various output formats
     * @dev Behavior depends on encodingType:
     *      - Struct: Standard abi.encode() output with head/tail layout, dynamic structs include offset wrapper
     *      - Array: Encodes struct fields as array elements where nested structs become bytes
     *      - ABI: Pure ABI encoding without offset wrapper (for embedding in parent structs as bytes)
     *      - CallWithSelector: Produces calldata with bytes4 selector + ABI params (like abi.encodeWithSelector)
     *      - CallWithSignature: Computes selector from signature string + ABI params (like abi.encodeWithSignature)
     *      - Hash: Computes keccak256(abi.encodePacked(all_fields)) for compact hash commitment (returns 32 bytes)
     *      - Packed: Computes abi.encodePacked(all_fields) for compact byte encoding (returns dynamic bytes)
     * @param s The struct to encode with its configured encodingType
     * @return Encoded bytes in the format specified by s.encodingType:
     *         Struct/Array: ABI-encoded struct data (with offset wrapper if dynamic)
     *         ABI: Raw ABI encoding (no wrapper)
     *         CallWithSelector/Signature: 4-byte selector + ABI-encoded parameters (calldata)
     *         Hash: 32-byte hash of packed struct data
     *         Packed: Packed bytes without hashing (dynamic length)
     */
    function encode(
        Struct memory s
    ) internal pure returns (bytes memory) {
        // Packed encoding returns abi.encodePacked(all_fields) without hashing
        if (s.encodingType == EncodingType.Packed) {
            return _encodePacked(s);
        }
        // ABI encoding type returns raw struct encoding without offset wrapper
        if (s.encodingType == EncodingType.ABI) {
            return _encodeAbi(s);
        }
        // Encoding types implemented in later commits
        if (
            s.encodingType == EncodingType.CallWithSelector || s.encodingType == EncodingType.CallWithSignature
                || s.encodingType == EncodingType.Hash || s.encodingType == EncodingType.Create
                || s.encodingType == EncodingType.Create2 || s.encodingType == EncodingType.Create3
        ) {
            revert EncodingTypeNotImplemented();
        }

        // For Array and Struct types, encode and add offset wrapper if dynamic
        bytes memory encoded;
        if (s.encodingType == EncodingType.Array) {
            // Validate array encoding structure before forwarding
            if (s.chunks.length != 1) {
                revert UnsupportedArrayType();
            }
            Chunk memory chunk = s.chunks[0];
            if (chunk.primitives.length > 0 || chunk.arrays.length > 0) {
                revert UnsupportedArrayType();
            }
            encoded = _encodeAsArray(s);
        } else {
            // Default Struct type uses _encodeAbi
            encoded = _encodeAbi(s);
        }

        return _isDynamic(s) ? abi.encodePacked(abi.encode(uint256(32)), encoded) : encoded;
    }

    /**
     * @notice Encodes a struct as a normal struct array
     * @dev Used for polymorphic arrays where elements have different struct types for EIP-712 hashing,
     *      but produce a normal struct array for encode(). Single chunk must contain only structs -
     *      primitives and arrays are not supported. The output format is standard struct array encoding:
     *      [array length] [offset1/data1] [offset2/data2] ... [dynamic_data...]
     * @param s The struct with EncodingType.Array - must have only struct fields in the chunk
     * @return ABI-encoded struct array with length prefix and standard offset/data layout
     */
    function _encodeAsArray(
        Struct memory s
    ) private pure returns (bytes memory) {
        // Validation is performed in encode() function before calling this private function
        Chunk memory chunk = s.chunks[0];

        uint256 totalStructs = chunk.structs.length;

        bytes[] memory structEncodings = new bytes[](totalStructs);
        uint256[] memory offsets = new uint256[](totalStructs);
        uint256 currentOffset = totalStructs * 32;

        for (uint256 i = 0; i < totalStructs; i++) {
            Struct memory childStruct = chunk.structs[i];

            // Encode child struct normally (not wrapped as bytes)
            bytes memory childEncoded = _encodeAbi(childStruct);
            structEncodings[i] = childEncoded;
            offsets[i] = currentOffset;
            currentOffset += childEncoded.length;
        }

        bytes memory arrayHeader;
        bytes memory arrayData;

        for (uint256 i = 0; i < totalStructs; i++) {
            arrayHeader = abi.encodePacked(arrayHeader, abi.encode(offsets[i]));
            arrayData = abi.encodePacked(arrayData, structEncodings[i]);
        }

        return abi.encodePacked(abi.encode(totalStructs), arrayHeader, arrayData);
    }

    /**
     * @notice Encodes a function call with a bytes4 selector, producing abi.encodeWithSelector() compatible output
     * @dev Requires exactly 1 chunk containing:
     *      - 1 primitive: bytes4 selector (4 bytes, use abi.encodePacked(bytes4))
     *      - 1 struct: function parameters
     *      The params struct fields are encoded as individual function arguments (flattened), not as a wrapped struct.
     *      Output format: [4-byte selector][ABI-encoded params]
     * @param s The struct with EncodingType.CallWithSelector and valid structure
     * @return Calldata bytes compatible with abi.encodeWithSelector(selector, ...params) - ready for low-level calls
     */
    function _encodeCallWithSelector(
        Struct memory s
    ) private pure returns (bytes memory) {
        // Validation is performed in encode() function before calling this private function
        Chunk memory chunk = s.chunks[0];
        Primitive memory selectorPrimitive = chunk.primitives[0];

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

    /**
     * @notice Encodes a function call with a signature string, computing the selector and producing calldata
     * @dev Requires exactly 1 chunk containing:
     *      - 1 dynamic primitive: function signature string (e.g., "transfer(address,uint256)")
     *      - 1 struct: function parameters
     *      Computes selector as bytes4(keccak256(signature)), then encodes like CallWithSelector.
     *      The params struct fields are encoded as individual function arguments (flattened).
     *      Output format: [4-byte selector][ABI-encoded params]
     * @param s The struct with EncodingType.CallWithSignature and valid structure
     * @return Calldata bytes compatible with abi.encodeWithSignature(sig, ...params) - ready for low-level calls
     */
    function _encodeCallWithSignature(
        Struct memory s
    ) private pure returns (bytes memory) {
        // Validation is performed in encode() function before calling this private function
        Chunk memory chunk = s.chunks[0];
        Primitive memory signaturePrimitive = chunk.primitives[0];

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

    /**
     * @notice Encodes struct fields using abi.encodePacked and computes keccak256 hash
     * @dev Hash encoding produces compact commitments to struct data that can be expanded later.
     *      Process: abi.encodePacked(all_fields_recursively) → keccak256() → bytes32
     *      Nested Hash-type structs are hashed first, then their bytes32 is packed into parent.
     *      Arrays pack elements without length prefix for maximum compactness.
     * @param s The struct to hash with EncodingType.Hash
     * @return The 32-byte hash commitment to the struct's data
     */
    function _encodeHash(
        Struct memory s
    ) private pure returns (bytes32) {
        bytes memory packed;
        uint256 chunksLen = s.chunks.length;

        for (uint256 i = 0; i < chunksLen; i++) {
            packed = abi.encodePacked(packed, _encodePackedChunk(s.chunks[i]));
        }

        return keccak256(packed);
    }

    /**
     * @notice Encodes a chunk's fields using abi.encodePacked for compact hash computation
     * @dev Processes fields in standard order: primitives → structs → arrays
     *      - Primitives: packed directly (no padding)
     *      - Structs: Hash-type structs are hashed recursively, others are ABI-encoded then packed
     *      - Arrays: packed without length prefix using _encodePackedArray
     * @param chunk The chunk containing fields to pack
     * @return Packed bytes ready for hashing (no padding, minimal overhead)
     */
    function _encodePackedChunk(
        Chunk memory chunk
    ) private pure returns (bytes memory) {
        bytes memory packed;

        // Process primitives - pack data directly
        uint256 primLen = chunk.primitives.length;
        for (uint256 i = 0; i < primLen; i++) {
            packed = abi.encodePacked(packed, chunk.primitives[i].data);
        }

        // Process nested structs
        uint256 structLen = chunk.structs.length;
        for (uint256 i = 0; i < structLen; i++) {
            Struct memory nestedStruct = chunk.structs[i];

            // If nested struct is Hash type, hash it first then pack the bytes32
            if (nestedStruct.encodingType == EncodingType.Hash) {
                packed = abi.encodePacked(packed, _encodeHash(nestedStruct));
            } else if (nestedStruct.encodingType == EncodingType.Packed) {
                // If nested struct is Packed type, pack it recursively without hashing
                packed = abi.encodePacked(packed, _encodePacked(nestedStruct));
            } else {
                // For other encoding types, pack their ABI encoding
                packed = abi.encodePacked(packed, _encodeAbi(nestedStruct));
            }
        }

        // Process arrays - pack without length prefix
        uint256 arrLen = chunk.arrays.length;
        for (uint256 i = 0; i < arrLen; i++) {
            packed = abi.encodePacked(packed, _encodePackedArray(chunk.arrays[i]));
        }

        return packed;
    }

    /**
     * @notice Encodes an array using abi.encodePacked for compact hash computation
     * @dev Packs array elements without length prefix for maximum compactness.
     *      Each element (represented as a Chunk) is packed recursively.
     *      Used within Hash encoding to create compact hash commitments.
     * @param array The array to pack (can contain primitives, structs, or nested arrays)
     * @return Packed bytes of all array elements concatenated (no length, no padding)
     */
    function _encodePackedArray(
        Array memory array
    ) private pure returns (bytes memory) {
        bytes memory packed;
        uint256 arrayLen = array.data.length;

        for (uint256 i = 0; i < arrayLen; i++) {
            packed = abi.encodePacked(packed, _encodePackedChunk(array.data[i]));
        }

        return packed;
    }

    /**
     * @notice Encodes struct fields using abi.encodePacked for compact byte encoding
     * @dev Packed encoding produces compact byte sequences without hashing.
     *      Process: abi.encodePacked(all_fields_recursively) → bytes
     *      Nested Packed-type structs are packed recursively (no intermediate hashing).
     *      Arrays pack elements without length prefix for maximum compactness.
     *      Unlike Hash encoding, this returns the raw packed bytes, not a hash.
     * @param s The struct to pack with EncodingType.Packed
     * @return The packed bytes (variable length, dynamic)
     */
    function _encodePacked(
        Struct memory s
    ) private pure returns (bytes memory) {
        bytes memory packed;
        uint256 chunksLen = s.chunks.length;

        for (uint256 i = 0; i < chunksLen; i++) {
            packed = abi.encodePacked(packed, _encodePackedChunk(s.chunks[i]));
        }

        return packed;
    }

    /**
     * @notice Computes contract address from CREATE opcode using RLP encoding
     * @dev Formula: keccak256(rlp([sender, nonce]))[12:]
     *      RLP encoding varies by nonce value:
     *      - Nonce 0: 0xd6, 0x94, address(20 bytes), 0x80
     *      - Nonce 1-127: 0xd6, 0x94, address(20 bytes), nonce(1 byte)
     *      - Nonce 128-255: 0xd7, 0x94, address(20 bytes), 0x81, nonce(1 byte)
     *      - Nonce 256-65535: 0xd8, 0x94, address(20 bytes), 0x82, nonce_high, nonce_low
     *      - Higher nonces: more complex RLP encoding (up to uint64)
     *      Requires exactly 1 chunk with 2 static primitives (address, uint256).
     * @param s The struct with EncodingType.Create
     * @return The computed contract address (20 bytes)
     */
    function _encodeCreate(
        Struct memory s
    ) private pure returns (address) {
        // Validation is performed in encode() function before calling this private function
        Chunk memory chunk = s.chunks[0];
        Primitive memory deployerPrimitive = chunk.primitives[0];
        Primitive memory noncePrimitive = chunk.primitives[1];

        bytes memory deployerData = deployerPrimitive.data;
        address deployer;
        assembly {
            deployer := mload(add(deployerData, 32))
        }

        bytes memory nonceData = noncePrimitive.data;
        uint256 nonce;
        assembly {
            nonce := mload(add(nonceData, 32))
        }

        // Compute RLP encoding based on nonce value
        bytes memory rlpEncoded;

        if (nonce == 0) {
            // RLP: 0xd6, 0x94, address(20), 0x80
            rlpEncoded = abi.encodePacked(hex"d694", deployer, hex"80");
        } else if (nonce <= 0x7f) {
            // RLP: 0xd6, 0x94, address(20), nonce(1 byte)
            rlpEncoded = abi.encodePacked(hex"d694", deployer, uint8(nonce));
        } else if (nonce <= 0xff) {
            // RLP: 0xd7, 0x94, address(20), 0x81, nonce(1 byte)
            rlpEncoded = abi.encodePacked(hex"d794", deployer, hex"81", uint8(nonce));
        } else if (nonce <= 0xffff) {
            // RLP: 0xd8, 0x94, address(20), 0x82, nonce(2 bytes big-endian)
            rlpEncoded = abi.encodePacked(hex"d894", deployer, hex"82", uint16(nonce));
        } else if (nonce <= 0xffffff) {
            // RLP: 0xd9, 0x94, address(20), 0x83, nonce(3 bytes big-endian)
            rlpEncoded = abi.encodePacked(hex"d994", deployer, hex"83", uint24(nonce));
        } else if (nonce <= 0xffffffff) {
            // RLP: 0xda, 0x94, address(20), 0x84, nonce(4 bytes big-endian)
            rlpEncoded = abi.encodePacked(hex"da94", deployer, hex"84", uint32(nonce));
        } else if (nonce <= 0xffffffffff) {
            // RLP: 0xdb, 0x94, address(20), 0x85, nonce(5 bytes big-endian)
            rlpEncoded = abi.encodePacked(hex"db94", deployer, hex"85", uint40(nonce));
        } else if (nonce <= 0xffffffffffff) {
            // RLP: 0xdc, 0x94, address(20), 0x86, nonce(6 bytes big-endian)
            rlpEncoded = abi.encodePacked(hex"dc94", deployer, hex"86", uint48(nonce));
        } else if (nonce <= 0xffffffffffffff) {
            // RLP: 0xdd, 0x94, address(20), 0x87, nonce(7 bytes big-endian)
            rlpEncoded = abi.encodePacked(hex"dd94", deployer, hex"87", uint56(nonce));
        } else {
            // RLP: 0xde, 0x94, address(20), 0x88, nonce(8 bytes big-endian)
            rlpEncoded = abi.encodePacked(hex"de94", deployer, hex"88", uint64(nonce));
        }

        // Hash and extract last 20 bytes as address
        bytes32 computedHash = keccak256(rlpEncoded);
        return address(uint160(uint256(computedHash)));
    }

    /**
     * @notice Computes contract address from CREATE2 opcode
     * @dev Formula: keccak256(0xff ++ deployer ++ salt ++ initCodeHash)[12:]
     *      Standard CREATE2 address computation for deterministic deployments.
     *      Requires exactly 1 chunk with 3 static primitives (address, bytes32, bytes32).
     * @param s The struct with EncodingType.Create2
     * @return The computed contract address (20 bytes)
     */
    function _encodeCreate2(
        Struct memory s
    ) private pure returns (address) {
        // Validation is performed in encode() function before calling this private function
        Chunk memory chunk = s.chunks[0];
        Primitive memory deployerPrimitive = chunk.primitives[0];
        Primitive memory saltPrimitive = chunk.primitives[1];
        Primitive memory initCodeHashPrimitive = chunk.primitives[2];

        bytes memory deployerData = deployerPrimitive.data;
        address deployer;
        assembly {
            deployer := mload(add(deployerData, 32))
        }

        bytes memory saltData = saltPrimitive.data;
        bytes32 salt;
        assembly {
            salt := mload(add(saltData, 32))
        }

        bytes memory initCodeHashData = initCodeHashPrimitive.data;
        bytes32 initCodeHash;
        assembly {
            initCodeHash := mload(add(initCodeHashData, 32))
        }

        // Compute CREATE2 address: keccak256(0xff ++ deployer ++ salt ++ initCodeHash)[12:]
        bytes32 computedHash = keccak256(abi.encodePacked(hex"ff", deployer, salt, initCodeHash));
        return address(uint160(uint256(computedHash)));
    }

    /**
     * @notice Computes contract address from CREATE3 pattern (CREATE2 + CREATE)
     * @dev CREATE3 provides bytecode-independent deterministic addresses through two stages:
     *      Stage 1: Deploy intermediary contract via CREATE2
     *        intermediary = keccak256(0xff ++ deployer ++ salt ++ createDeployCodeHash)[12:]
     *      Stage 2: Intermediary deploys target via CREATE with nonce=1
     *        target = keccak256(rlp([intermediary, 1]))[12:]
     *      Where rlp([intermediary, 1]) = 0xd6, 0x94, intermediary(20), 0x01
     *      Requires exactly 1 chunk with 3 static primitives (address, bytes32, bytes32).
     *      Reference: Axelar CREATE3 implementation
     * @param s The struct with EncodingType.Create3
     * @return The computed contract address (20 bytes)
     */
    function _encodeCreate3(
        Struct memory s
    ) private pure returns (address) {
        // Validation is performed in encode() function before calling this private function
        Chunk memory chunk = s.chunks[0];
        Primitive memory deployerPrimitive = chunk.primitives[0];
        Primitive memory saltPrimitive = chunk.primitives[1];
        Primitive memory createDeployCodeHashPrimitive = chunk.primitives[2];

        bytes memory deployerData = deployerPrimitive.data;
        address deployer;
        assembly {
            deployer := mload(add(deployerData, 32))
        }

        bytes memory saltData = saltPrimitive.data;
        bytes32 salt;
        assembly {
            salt := mload(add(saltData, 32))
        }

        bytes memory createDeployCodeHashData = createDeployCodeHashPrimitive.data;
        bytes32 createDeployCodeHash;
        assembly {
            createDeployCodeHash := mload(add(createDeployCodeHashData, 32))
        }

        // Stage 1: Compute intermediary deployer address via CREATE2
        bytes32 intermediaryHash = keccak256(abi.encodePacked(hex"ff", deployer, salt, createDeployCodeHash));
        address intermediary = address(uint160(uint256(intermediaryHash)));

        // Stage 2: Compute final address via CREATE with nonce=1
        // RLP encoding for nonce=1: 0xd6, 0x94, address(20), 0x01
        bytes32 computedHash = keccak256(abi.encodePacked(hex"d694", intermediary, hex"01"));
        return address(uint160(uint256(computedHash)));
    }

    /**
     * @notice Encodes a chunk's fields according to EIP-712 rules for struct hash computation
     * @dev Processing order: primitives → structs → arrays
     *      - Static primitives: encoded value (32 bytes)
     *      - Dynamic primitives: keccak256(value)
     *      - Structs: recursively computed struct hash
     *      - Arrays: keccak256 of concatenated element encodings
     *      All encodings are concatenated using abi.encodePacked()
     * @param chunk The chunk containing primitives, structs, and/or arrays to encode
     * @return Concatenated EIP-712 encoded data for all fields in the chunk (used in struct hash computation)
     */
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

    /**
     * @notice Encodes an array according to EIP-712 rules: keccak256 of concatenated element encodings
     * @dev Each array element (represented as a Chunk) is EIP-712 encoded, then all encodings are
     *      concatenated and hashed. This applies to both fixed-size and dynamic arrays.
     *      Array encoding: keccak256(abi.encodePacked(encodeData(element1), encodeData(element2), ...))
     * @param array The array with elements stored as chunks (each chunk contains one element)
     * @return The 32-byte hash representing the array in EIP-712 struct hash computation
     */
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

    /**
     * @notice Encodes a struct using standard Solidity ABI encoding rules with head/tail layout
     * @dev Implements ABI encoding where:
     *      - Static fields go in the head (encoded in place)
     *      - Dynamic fields go in the tail (head contains offset pointer)
     *      - Nested structs with EncodingType.ABI/CallWith* are wrapped as bytes
     * @param s The struct to ABI encode
     * @return ABI-encoded struct data with proper head/tail layout matching Solidity's abi.encode() output
     */
    function _encodeAbi(
        Struct memory s
    ) private pure returns (bytes memory) {
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
            fieldIndex = _encodeChunkFields(s.chunks[i], headParts, tailParts, hasTail, fieldIndex);
        }

        return _abiEncodeHeadTail(headParts, tailParts, hasTail, fieldCount);
    }

    /**
     * @notice Encodes an array using standard Solidity ABI encoding rules
     * @dev Array encoding format:
     *      - Dynamic arrays: [length (32 bytes)][elements...]
     *      - Fixed arrays: [elements...] (no length prefix)
     *      - Static elements: encoded inline
     *      - Dynamic elements: head contains offsets, tail contains data
     *      Each array element must be represented by a chunk containing exactly one field
     * @param array The array to encode with elements stored as chunks
     * @return ABI-encoded array data matching Solidity's encoding for T[] or T[N]
     */
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
                elements[i] = _encodeAbi(chunk.structs[0]);
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

    /**
     * @notice Encodes a single chunk's fields using ABI encoding with head/tail layout
     * @dev Processes fields in order (primitives → structs → arrays) and applies standard ABI encoding.
     *      Static fields are encoded in the head, dynamic fields are encoded in the tail with offsets in the head.
     *      This is used when encoding chunks directly for CallWithSelector/CallWithSignature parameter flattening.
     * @param chunk The chunk containing fields to encode
     * @return ABI-encoded data for all fields in the chunk with proper head/tail layout
     */
    function _encodeAbi(
        Chunk memory chunk
    ) private pure returns (bytes memory) {
        uint256 totalFields = chunk.primitives.length + chunk.structs.length + chunk.arrays.length;

        bytes[] memory headParts = new bytes[](totalFields);
        bytes[] memory tailParts = new bytes[](totalFields);
        bool[] memory hasTail = new bool[](totalFields);

        _encodeChunkFields(chunk, headParts, tailParts, hasTail, 0);

        return _abiEncodeHeadTail(headParts, tailParts, hasTail, totalFields);
    }

    /**
     * @notice Encodes all fields in a chunk, populating head/tail arrays for ABI encoding
     * @dev Processes fields in order: primitives → structs → arrays
     *      - Static fields: populated in headParts
     *      - Dynamic fields: offset in headParts, data in tailParts, hasTail flag set
     *      - ABI/CallWith* encodings are wrapped as bytes (length + data + padding)
     * @param chunk The chunk containing fields to encode
     * @param headParts Array to store head data (static values or offsets for dynamic values)
     * @param tailParts Array to store tail data (dynamic field contents)
     * @param hasTail Boolean array indicating which fields have tail data
     * @param startIndex The index in head/tail arrays where this chunk's fields start
     * @return The next available index in head/tail arrays after encoding this chunk's fields
     */
    function _encodeChunkFields(
        Chunk memory chunk,
        bytes[] memory headParts,
        bytes[] memory tailParts,
        bool[] memory hasTail,
        uint256 startIndex
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

            bytes memory structEncoded;
            if (childStruct.encodingType == EncodingType.Array) {
                structEncoded = _encodeAsArray(childStruct);
            } else if (childStruct.encodingType == EncodingType.CallWithSelector) {
                structEncoded = _encodeCallWithSelector(childStruct);
            } else if (childStruct.encodingType == EncodingType.CallWithSignature) {
                structEncoded = _encodeCallWithSignature(childStruct);
            } else if (childStruct.encodingType == EncodingType.Hash) {
                // Hash encoding returns bytes32 (32 bytes)
                structEncoded = abi.encodePacked(_encodeHash(childStruct));
            } else if (childStruct.encodingType == EncodingType.Packed) {
                // Packed encoding returns dynamic bytes
                structEncoded = _encodePacked(childStruct);
            } else if (childStruct.encodingType == EncodingType.Create) {
                // Create encoding returns address (20 bytes)
                structEncoded = abi.encodePacked(_encodeCreate(childStruct));
            } else if (childStruct.encodingType == EncodingType.Create2) {
                // Create2 encoding returns address (20 bytes)
                structEncoded = abi.encodePacked(_encodeCreate2(childStruct));
            } else if (childStruct.encodingType == EncodingType.Create3) {
                // Create3 encoding returns address (20 bytes)
                structEncoded = abi.encodePacked(_encodeCreate3(childStruct));
            } else if (childStruct.encodingType == EncodingType.ABI) {
                bytes memory innerEncoded = _encodeAbi(childStruct);
                // Check if struct has dynamic field contents (not encoding type)
                bool hasDynamicFields = _hasDynamicFields(childStruct);
                structEncoded =
                    hasDynamicFields ? abi.encodePacked(abi.encode(uint256(32)), innerEncoded) : innerEncoded;
            } else {
                // EncodingType.Struct uses standard ABI encoding
                structEncoded = _encodeAbi(childStruct);
            }

            // ABI, CallWithSelector, CallWithSignature, and Packed are represented as bytes
            // Wrap with length prefix and padding (always dynamic)
            if (
                childStruct.encodingType == EncodingType.ABI
                    || childStruct.encodingType == EncodingType.CallWithSelector
                    || childStruct.encodingType == EncodingType.CallWithSignature
                    || childStruct.encodingType == EncodingType.Packed
            ) {
                tailParts[fieldIndex] = abi.encodePacked(abi.encode(structEncoded.length), _padTo32(structEncoded));
                hasTail[fieldIndex] = true;
                fieldIndex++;
            } else if (_isDynamic(childStruct)) {
                // For Array and Struct types, use standard dynamic/static handling
                tailParts[fieldIndex] = structEncoded;
                hasTail[fieldIndex] = true;
                fieldIndex++;
            } else {
                // Static struct (Hash, Create, Create2, Create3, and Struct with all static fields)
                headParts[fieldIndex] = structEncoded;
                fieldIndex++;
            }
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

    /**
     * @notice Combines head and tail parts into final ABI-encoded output
     * @dev Implements standard ABI head/tail encoding:
     *      1. Calculate initial tail offset (sum of head sizes: static fields are 32 bytes, dynamic fields are 32-byte
     * offsets)
     *      2. Build head: static values in place, offsets for dynamic values
     *      3. Build tail: concatenate all dynamic field data
     *      4. Result: [head][tail]
     * @param headParts Array of head data - contains actual data for static fields, unused for dynamic fields
     * @param tailParts Array of tail data - contains actual data for dynamic fields
     * @param hasTail Boolean array indicating which fields are dynamic (true = field has tail data)
     * @param fieldCount Total number of fields being encoded
     * @return Complete ABI-encoded bytes with proper head/tail layout
     */
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

    /**
     * @notice Pads bytes data to the next 32-byte boundary by appending zero bytes
     * @dev ABI encoding requires dynamic data (strings, bytes) to be padded to 32-byte multiples.
     *      Calculates padded length as ceiling(length / 32) * 32 and appends zero bytes if needed.
     *      Example: 35 bytes → 64 bytes (adds 29 zero bytes)
     * @param data The bytes to pad (can be any length)
     * @return Padded bytes with length as a multiple of 32 (original data + zero bytes)
     */
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

    /**
     * @notice Determines if an array element is dynamic by examining its chunk
     * @dev Array elements must be represented by chunks containing exactly one field.
     *      Returns true if that single field is dynamic (dynamic primitive, dynamic struct, or dynamic/nested array).
     *      Reverts if the chunk doesn't contain exactly one field.
     * @param chunk The chunk representing one array element (must contain exactly 1 primitive, struct, or array)
     * @return True if the element is dynamic and requires offset-based encoding, false if static
     */
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

    /**
     * @notice Determines if a chunk contains any dynamic fields
     * @dev A chunk is dynamic if any of its fields are dynamic:
     *      - Any primitive marked as dynamic (string, bytes, etc.)
     *      - Any nested struct that is dynamic
     *      - Any array that is dynamic (checked recursively)
     *      Checks all primitives, structs, and arrays in the chunk.
     * @param chunk The chunk to check for dynamic fields
     * @return True if the chunk contains at least one dynamic field, false if all fields are static
     */
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

    /**
     * @notice Determines if an array is dynamic for ABI encoding purposes
     * @dev An array is dynamic if:
     *      1. It's a dynamic-length array (T[] vs T[N]), OR
     *      2. It's a fixed-size array containing dynamic elements (e.g., string[3])
     *      Recursively checks element chunks to determine if elements are dynamic.
     * @param array The array to check
     * @return True if the array requires offset-based encoding (dynamic), false if it can be encoded inline (static)
     */
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

    /**
     * @notice Checks if a struct has dynamic field contents (ignoring encoding type)
     * @dev Used to determine if offset wrapper is needed when wrapping struct as bytes.
     *      Unlike _isDynamic which considers encoding type, this only checks field contents.
     * @param s The struct to check
     * @return True if the struct contains any dynamic fields, false otherwise
     */
    function _hasDynamicFields(
        Struct memory s
    ) private pure returns (bool) {
        uint256 chunksLen = s.chunks.length;
        for (uint256 i = 0; i < chunksLen; i++) {
            if (_isDynamic(s.chunks[i])) {
                return true;
            }
        }
        return false;
    }

    /**
     * @notice Determines if a struct is dynamic based on its encoding type and field contents
     * @dev A struct is dynamic if:
     *      - encodingType is Array (polymorphic array encoding is always dynamic)
     *      - encodingType is ABI (wrapped as bytes, always dynamic)
     *      - encodingType is CallWithSelector or CallWithSignature (calldata is always dynamic bytes)
     *      - encodingType is Packed (produces variable-length bytes, always dynamic)
     *      - encodingType is Hash (produces 32-byte hash, static when nested)
     *      - encodingType is Struct and any of its chunks contain dynamic fields
     *      This affects how the struct is encoded when nested in a parent struct (offset vs inline).
     * @param s The struct to check
     * @return True if the struct requires offset-based encoding when nested, false if it can be encoded inline
     */
    function _isDynamic(
        Struct memory s
    ) private pure returns (bool) {
        if (
            s.encodingType == EncodingType.Array || s.encodingType == EncodingType.ABI
                || s.encodingType == EncodingType.CallWithSelector || s.encodingType == EncodingType.CallWithSignature
                || s.encodingType == EncodingType.Packed
        ) {
            return true;
        }

        // Hash, Create, Create2, Create3 produce fixed-size output (static)
        // Hash: 32 bytes, Create/Create2/Create3: 20 bytes
        if (
            s.encodingType == EncodingType.Hash || s.encodingType == EncodingType.Create
                || s.encodingType == EncodingType.Create2 || s.encodingType == EncodingType.Create3
        ) {
            return false;
        }

        return _hasDynamicFields(s);
    }
}
