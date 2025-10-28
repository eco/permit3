// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { TypedEncoder } from "../../src/lib/TypedEncoder.sol";
import "forge-std/Test.sol";

contract TypedEncoderPolymorphicTest is Test {
    struct Call {
        address target;
        bytes callData;
    }

    struct Batch {
        Call[] calls;
    }

    struct TransferParams {
        address recipient;
        uint256 amount;
    }

    struct ApproveParams {
        address recipient;
        uint256 amount;
    }

    struct ExecuteParams {
        bytes data;
    }

    function testPolymorphicCalls() public pure {
        // Create params struct for transfer call
        TypedEncoder.Struct memory transferParams = TypedEncoder.Struct({
            typeHash: keccak256("TransferParams(address recipient,uint256 amount)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Struct
        });
        transferParams.chunks[0].primitives = new TypedEncoder.Primitive[](2);
        transferParams.chunks[0].primitives[0] = TypedEncoder.Primitive({
            isDynamic: false,
            data: abi.encode(address(0x5555555555555555555555555555555555555555))
        });
        transferParams.chunks[0].primitives[1] =
            TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(1000)) });

        // Create CallWithSignature for transfer
        TypedEncoder.Struct memory callData1 = TypedEncoder.Struct({
            typeHash: keccak256(
                "CallData(string signature,TransferParams params)TransferParams(address recipient,uint256 amount)"
            ),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.CallWithSignature
        });
        callData1.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        callData1.chunks[0].structs = new TypedEncoder.Struct[](1);
        callData1.chunks[0].primitives[0] =
            TypedEncoder.Primitive({ isDynamic: true, data: bytes("transfer(address,uint256)") });
        callData1.chunks[0].structs[0] = transferParams;

        // Create Call_1 struct with target and callData
        TypedEncoder.Struct memory call1 = TypedEncoder.Struct({
            typeHash: keccak256("Call_1(address target,bytes callData)"),
            chunks: new TypedEncoder.Chunk[](2),
            encodingType: TypedEncoder.EncodingType.Struct
        });
        call1.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        call1.chunks[0].primitives[0] = TypedEncoder.Primitive({
            isDynamic: false,
            data: abi.encode(address(0x1111111111111111111111111111111111111111))
        });
        call1.chunks[1].structs = new TypedEncoder.Struct[](1);
        call1.chunks[1].structs[0] = callData1;

        // Create params struct for approve call
        TypedEncoder.Struct memory approveParams = TypedEncoder.Struct({
            typeHash: keccak256("ApproveParams(address recipient,uint256 amount)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Struct
        });
        approveParams.chunks[0].primitives = new TypedEncoder.Primitive[](2);
        approveParams.chunks[0].primitives[0] = TypedEncoder.Primitive({
            isDynamic: false,
            data: abi.encode(address(0x2222222222222222222222222222222222222222))
        });
        approveParams.chunks[0].primitives[1] =
            TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(2000)) });

        // Create CallWithSignature for approve
        TypedEncoder.Struct memory callData2 = TypedEncoder.Struct({
            typeHash: keccak256(
                "CallData(string signature,ApproveParams params)ApproveParams(address recipient,uint256 amount)"
            ),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.CallWithSignature
        });
        callData2.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        callData2.chunks[0].structs = new TypedEncoder.Struct[](1);
        callData2.chunks[0].primitives[0] =
            TypedEncoder.Primitive({ isDynamic: true, data: bytes("approve(address,uint256)") });
        callData2.chunks[0].structs[0] = approveParams;

        // Create Call_2 struct with target and callData
        TypedEncoder.Struct memory call2 = TypedEncoder.Struct({
            typeHash: keccak256("Call_2(address target,bytes callData)"),
            chunks: new TypedEncoder.Chunk[](2),
            encodingType: TypedEncoder.EncodingType.Struct
        });
        call2.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        call2.chunks[0].primitives[0] = TypedEncoder.Primitive({
            isDynamic: false,
            data: abi.encode(address(0x3333333333333333333333333333333333333333))
        });
        call2.chunks[1].structs = new TypedEncoder.Struct[](1);
        call2.chunks[1].structs[0] = callData2;

        // Create params struct for execute call
        TypedEncoder.Struct memory executeParams = TypedEncoder.Struct({
            typeHash: keccak256("ExecuteParams(bytes data)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Struct
        });
        executeParams.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        executeParams.chunks[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: true, data: hex"deadbeef" });

        // Create CallWithSignature for execute
        TypedEncoder.Struct memory callData3 = TypedEncoder.Struct({
            typeHash: keccak256("CallData(string signature,ExecuteParams params)ExecuteParams(bytes data)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.CallWithSignature
        });
        callData3.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        callData3.chunks[0].structs = new TypedEncoder.Struct[](1);
        callData3.chunks[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: true, data: bytes("execute(bytes)") });
        callData3.chunks[0].structs[0] = executeParams;

        // Create Call_3 struct with target and callData
        TypedEncoder.Struct memory call3 = TypedEncoder.Struct({
            typeHash: keccak256("Call_3(address target,bytes callData)"),
            chunks: new TypedEncoder.Chunk[](2),
            encodingType: TypedEncoder.EncodingType.Struct
        });
        call3.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        call3.chunks[0].primitives[0] = TypedEncoder.Primitive({
            isDynamic: false,
            data: abi.encode(address(0x4444444444444444444444444444444444444444))
        });
        call3.chunks[1].structs = new TypedEncoder.Struct[](1);
        call3.chunks[1].structs[0] = callData3;

        // Create polymorphic array of calls
        TypedEncoder.Struct memory callsStruct = TypedEncoder.Struct({
            typeHash: keccak256(
                "Calls(Call_1 call_1,Call_2 call_2,Call_3 call_3)" "Call_1(address target,bytes callData)"
                "Call_2(address target,bytes callData)" "Call_3(address target,bytes callData)"
            ),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Array
        });
        callsStruct.chunks[0].structs = new TypedEncoder.Struct[](3);
        callsStruct.chunks[0].structs[0] = call1;
        callsStruct.chunks[0].structs[1] = call2;
        callsStruct.chunks[0].structs[2] = call3;

        // Wrap in batch struct
        TypedEncoder.Struct memory batchStruct = TypedEncoder.Struct({
            typeHash: keccak256(
                "Batch(Calls calls)" "Call_1(address target,bytes callData)" "Call_2(address target,bytes callData)"
                "Call_3(address target,bytes callData)" "Calls(Call_1 call_1,Call_2 call_2,Call_3 call_3)"
            ),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Struct
        });
        batchStruct.chunks[0].structs = new TypedEncoder.Struct[](1);
        batchStruct.chunks[0].structs[0] = callsStruct;

        bytes memory encoded = TypedEncoder.encode(batchStruct);

        Batch memory batched = abi.decode(encoded, (Batch));
        assertEq(batched.calls.length, 3);

        // Verify Call 1 (transfer)
        assertEq(batched.calls[0].target, address(0x1111111111111111111111111111111111111111));

        // Extract selector from callData (first 4 bytes)
        bytes memory cd1 = batched.calls[0].callData;
        bytes4 selector1;
        assembly {
            selector1 := mload(add(cd1, 32))
        }
        assertEq(selector1, bytes4(keccak256("transfer(address,uint256)")));

        // Decode params from callData (skip first 4 bytes)
        bytes memory paramsBytes1 = new bytes(cd1.length - 4);
        for (uint256 i = 0; i < paramsBytes1.length; i++) {
            paramsBytes1[i] = cd1[i + 4];
        }
        (address recipient1, uint256 amount1) = abi.decode(paramsBytes1, (address, uint256));
        assertEq(recipient1, address(0x5555555555555555555555555555555555555555));
        assertEq(amount1, 1000);

        // Verify Call 2 (approve)
        assertEq(batched.calls[1].target, address(0x3333333333333333333333333333333333333333));

        bytes memory cd2 = batched.calls[1].callData;
        bytes4 selector2;
        assembly {
            selector2 := mload(add(cd2, 32))
        }
        assertEq(selector2, bytes4(keccak256("approve(address,uint256)")));

        bytes memory paramsBytes2 = new bytes(cd2.length - 4);
        for (uint256 i = 0; i < paramsBytes2.length; i++) {
            paramsBytes2[i] = cd2[i + 4];
        }
        (address recipient2, uint256 amount2) = abi.decode(paramsBytes2, (address, uint256));
        assertEq(recipient2, address(0x2222222222222222222222222222222222222222));
        assertEq(amount2, 2000);

        // Verify Call 3 (execute)
        assertEq(batched.calls[2].target, address(0x4444444444444444444444444444444444444444));

        bytes memory cd3 = batched.calls[2].callData;
        bytes4 selector3;
        assembly {
            selector3 := mload(add(cd3, 32))
        }
        assertEq(selector3, bytes4(keccak256("execute(bytes)")));

        bytes memory paramsBytes3 = new bytes(cd3.length - 4);
        for (uint256 i = 0; i < paramsBytes3.length; i++) {
            paramsBytes3[i] = cd3[i + 4];
        }
        bytes memory data3 = abi.decode(paramsBytes3, (bytes));
        assertEq(data3, hex"deadbeef");
    }

    /// @notice Tests CallWithSignature encoding containing an array parameter with nested CallWithSignature elements
    /// @dev Verifies complex nesting: CallWithSignature → Array → Call structs → CallWithSignature calldata
    ///      This demonstrates triple-level encoding where:
    ///      - Outer: CallWithSignature for batch(Call[])
    ///      - Middle: Array encoding for polymorphic Call[] array
    ///      - Inner: Each Call contains CallWithSignature-encoded calldata
    function testCallWithSignatureContainingArray() public pure {
        // STEP 1: Create Inner CallWithSignature #1 - transfer(address,uint256)
        TypedEncoder.Struct memory innerParams1 = TypedEncoder.Struct({
            typeHash: keccak256("TransferParams(address recipient,uint256 amount)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Struct
        });
        innerParams1.chunks[0].primitives = new TypedEncoder.Primitive[](2);
        innerParams1.chunks[0].primitives[0] = TypedEncoder.Primitive({
            isDynamic: false,
            data: abi.encode(address(0x1111111111111111111111111111111111111000))
        });
        innerParams1.chunks[0].primitives[1] =
            TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(1000)) });

        TypedEncoder.Struct memory innerCallWithSig1 = TypedEncoder.Struct({
            typeHash: keccak256("InnerCall1(string signature,TransferParams params)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.CallWithSignature
        });
        innerCallWithSig1.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        innerCallWithSig1.chunks[0].structs = new TypedEncoder.Struct[](1);
        innerCallWithSig1.chunks[0].primitives[0] =
            TypedEncoder.Primitive({ isDynamic: true, data: bytes("transfer(address,uint256)") });
        innerCallWithSig1.chunks[0].structs[0] = innerParams1;

        // STEP 2: Create Inner CallWithSignature #2 - approve(address,uint256)
        TypedEncoder.Struct memory innerParams2 = TypedEncoder.Struct({
            typeHash: keccak256("ApproveParams(address spender,uint256 amount)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Struct
        });
        innerParams2.chunks[0].primitives = new TypedEncoder.Primitive[](2);
        innerParams2.chunks[0].primitives[0] = TypedEncoder.Primitive({
            isDynamic: false,
            data: abi.encode(address(0x2222222222222222222222222222222222222000))
        });
        innerParams2.chunks[0].primitives[1] =
            TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(2000)) });

        TypedEncoder.Struct memory innerCallWithSig2 = TypedEncoder.Struct({
            typeHash: keccak256("InnerCall2(string signature,ApproveParams params)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.CallWithSignature
        });
        innerCallWithSig2.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        innerCallWithSig2.chunks[0].structs = new TypedEncoder.Struct[](1);
        innerCallWithSig2.chunks[0].primitives[0] =
            TypedEncoder.Primitive({ isDynamic: true, data: bytes("approve(address,uint256)") });
        innerCallWithSig2.chunks[0].structs[0] = innerParams2;

        // STEP 3: Create Inner CallWithSignature #3 - execute(bytes)
        TypedEncoder.Struct memory innerParams3 = TypedEncoder.Struct({
            typeHash: keccak256("ExecuteParams(bytes data)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Struct
        });
        innerParams3.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        innerParams3.chunks[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: true, data: hex"cafebabe" });

        TypedEncoder.Struct memory innerCallWithSig3 = TypedEncoder.Struct({
            typeHash: keccak256("InnerCall3(string signature,ExecuteParams params)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.CallWithSignature
        });
        innerCallWithSig3.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        innerCallWithSig3.chunks[0].structs = new TypedEncoder.Struct[](1);
        innerCallWithSig3.chunks[0].primitives[0] =
            TypedEncoder.Primitive({ isDynamic: true, data: bytes("execute(bytes)") });
        innerCallWithSig3.chunks[0].structs[0] = innerParams3;

        // STEP 4: Create Call structs with target + CallWithSignature (produces callData bytes)
        TypedEncoder.Struct memory outerCall1 = TypedEncoder.Struct({
            typeHash: keccak256("Call_1(address target,bytes callData)"),
            chunks: new TypedEncoder.Chunk[](2),
            encodingType: TypedEncoder.EncodingType.Struct
        });
        outerCall1.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        outerCall1.chunks[0].primitives[0] = TypedEncoder.Primitive({
            isDynamic: false,
            data: abi.encode(address(0x1111111111111111111111111111111111111111))
        });
        outerCall1.chunks[1].structs = new TypedEncoder.Struct[](1);
        outerCall1.chunks[1].structs[0] = innerCallWithSig1;

        TypedEncoder.Struct memory outerCall2 = TypedEncoder.Struct({
            typeHash: keccak256("Call_2(address target,bytes callData)"),
            chunks: new TypedEncoder.Chunk[](2),
            encodingType: TypedEncoder.EncodingType.Struct
        });
        outerCall2.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        outerCall2.chunks[0].primitives[0] = TypedEncoder.Primitive({
            isDynamic: false,
            data: abi.encode(address(0x2222222222222222222222222222222222222222))
        });
        outerCall2.chunks[1].structs = new TypedEncoder.Struct[](1);
        outerCall2.chunks[1].structs[0] = innerCallWithSig2;

        TypedEncoder.Struct memory outerCall3 = TypedEncoder.Struct({
            typeHash: keccak256("Call_3(address target,bytes callData)"),
            chunks: new TypedEncoder.Chunk[](2),
            encodingType: TypedEncoder.EncodingType.Struct
        });
        outerCall3.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        outerCall3.chunks[0].primitives[0] = TypedEncoder.Primitive({
            isDynamic: false,
            data: abi.encode(address(0x3333333333333333333333333333333333333333))
        });
        outerCall3.chunks[1].structs = new TypedEncoder.Struct[](1);
        outerCall3.chunks[1].structs[0] = innerCallWithSig3;

        // STEP 5: Create Array-encoded struct with 3 Call structs
        TypedEncoder.Struct memory callsArray = TypedEncoder.Struct({
            typeHash: keccak256(
                "Calls(Call_1 call_1,Call_2 call_2,Call_3 call_3)" "Call_1(address target,bytes callData)"
                "Call_2(address target,bytes callData)" "Call_3(address target,bytes callData)"
            ),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Array
        });
        callsArray.chunks[0].structs = new TypedEncoder.Struct[](3);
        callsArray.chunks[0].structs[0] = outerCall1;
        callsArray.chunks[0].structs[1] = outerCall2;
        callsArray.chunks[0].structs[2] = outerCall3;

        // STEP 6: Create Outer Params struct containing the array
        TypedEncoder.Struct memory outerParams = TypedEncoder.Struct({
            typeHash: keccak256("BatchParams(Call[] calls)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Struct
        });
        outerParams.chunks[0].structs = new TypedEncoder.Struct[](1);
        outerParams.chunks[0].structs[0] = callsArray;

        // STEP 7: Create Outer CallWithSignature - batch(Call[])
        TypedEncoder.Struct memory outerCallWithSig = TypedEncoder.Struct({
            typeHash: keccak256("OuterCall(string signature,BatchParams params)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.CallWithSignature
        });
        outerCallWithSig.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        outerCallWithSig.chunks[0].structs = new TypedEncoder.Struct[](1);
        outerCallWithSig.chunks[0].primitives[0] =
            TypedEncoder.Primitive({ isDynamic: true, data: bytes("batch(Call[])") });
        outerCallWithSig.chunks[0].structs[0] = outerParams;

        // STEP 8: Encode the outer CallWithSignature
        bytes memory encoded = TypedEncoder.encode(outerCallWithSig);

        // STEP 9: Compute expected output using Call struct with callData
        Call[] memory expectedCalls = new Call[](3);
        expectedCalls[0] = Call({
            target: address(0x1111111111111111111111111111111111111111),
            callData: abi.encodeWithSignature(
                "transfer(address,uint256)", address(0x1111111111111111111111111111111111111000), uint256(1000)
            )
        });
        expectedCalls[1] = Call({
            target: address(0x2222222222222222222222222222222222222222),
            callData: abi.encodeWithSignature(
                "approve(address,uint256)", address(0x2222222222222222222222222222222222222000), uint256(2000)
            )
        });
        expectedCalls[2] = Call({
            target: address(0x3333333333333333333333333333333333333333),
            callData: abi.encodeWithSignature("execute(bytes)", hex"cafebabe")
        });

        bytes memory expected = abi.encodeWithSignature("batch(Call[])", expectedCalls);

        // STEP 10: Verify the encoding matches
        assertEq(encoded, expected);

        // STEP 11: Decode and verify structure
        bytes4 decodedSelector;
        assembly {
            decodedSelector := mload(add(encoded, 32))
        }
        assertEq(decodedSelector, bytes4(keccak256(bytes("batch(Call[])"))));

        bytes memory calldataParams = new bytes(encoded.length - 4);
        for (uint256 i = 0; i < calldataParams.length; i++) {
            calldataParams[i] = encoded[i + 4];
        }
        Call[] memory decodedCalls = abi.decode(calldataParams, (Call[]));

        assertEq(decodedCalls.length, 3);

        // Verify Call 1 and decode inner calldata
        assertEq(decodedCalls[0].target, address(0x1111111111111111111111111111111111111111));

        bytes memory innerCalldata1Decoded = decodedCalls[0].callData;
        bytes4 innerSelector1;
        assembly {
            innerSelector1 := mload(add(innerCalldata1Decoded, 32))
        }
        assertEq(innerSelector1, bytes4(keccak256(bytes("transfer(address,uint256)"))));

        bytes memory innerParams1Bytes = new bytes(innerCalldata1Decoded.length - 4);
        for (uint256 i = 0; i < innerParams1Bytes.length; i++) {
            innerParams1Bytes[i] = innerCalldata1Decoded[i + 4];
        }
        (address recipient1, uint256 amount1) = abi.decode(innerParams1Bytes, (address, uint256));
        assertEq(recipient1, address(0x1111111111111111111111111111111111111000));
        assertEq(amount1, 1000);

        // Verify Call 2 and decode inner calldata
        assertEq(decodedCalls[1].target, address(0x2222222222222222222222222222222222222222));

        bytes memory innerCalldata2Decoded = decodedCalls[1].callData;
        bytes4 innerSelector2;
        assembly {
            innerSelector2 := mload(add(innerCalldata2Decoded, 32))
        }
        assertEq(innerSelector2, bytes4(keccak256(bytes("approve(address,uint256)"))));

        bytes memory innerParams2Bytes = new bytes(innerCalldata2Decoded.length - 4);
        for (uint256 i = 0; i < innerParams2Bytes.length; i++) {
            innerParams2Bytes[i] = innerCalldata2Decoded[i + 4];
        }
        (address spender2, uint256 amount2) = abi.decode(innerParams2Bytes, (address, uint256));
        assertEq(spender2, address(0x2222222222222222222222222222222222222000));
        assertEq(amount2, 2000);

        // Verify Call 3 and decode inner calldata
        assertEq(decodedCalls[2].target, address(0x3333333333333333333333333333333333333333));

        bytes memory innerCalldata3Decoded = decodedCalls[2].callData;
        bytes4 innerSelector3;
        assembly {
            innerSelector3 := mload(add(innerCalldata3Decoded, 32))
        }
        assertEq(innerSelector3, bytes4(keccak256(bytes("execute(bytes)"))));

        bytes memory innerParams3Bytes = new bytes(innerCalldata3Decoded.length - 4);
        for (uint256 i = 0; i < innerParams3Bytes.length; i++) {
            innerParams3Bytes[i] = innerCalldata3Decoded[i + 4];
        }
        bytes memory data3 = abi.decode(innerParams3Bytes, (bytes));
        assertEq(data3, hex"cafebabe");
    }
}
