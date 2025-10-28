// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { TypedEncoder } from "../../src/lib/TypedEncoder.sol";
import "forge-std/Test.sol";

contract TypedEncoderPolymorphicTest is Test {
    struct Call {
        address target;
        string functionSelector;
        bytes params;
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
        TypedEncoder.Struct memory params1 = TypedEncoder.Struct({
            typeHash: keccak256("TransferParams(address recipient,uint256 amount)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Struct
        });
        params1.chunks[0].primitives = new TypedEncoder.Primitive[](2);
        params1.chunks[0].structs = new TypedEncoder.Struct[](0);
        params1.chunks[0].arrays = new TypedEncoder.Array[](0);
        params1.chunks[0].primitives[0] = TypedEncoder.Primitive({
            isDynamic: false,
            data: abi.encode(address(0x5555555555555555555555555555555555555555))
        });
        params1.chunks[0].primitives[1] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(1000)) });

        TypedEncoder.Struct memory call1 = TypedEncoder.Struct({
            typeHash: keccak256(
                "Call_1(address target,string functionSelector,TransferParams params)"
                "TransferParams(address recipient,uint256 amount)"
            ),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Struct
        });
        call1.chunks[0].primitives = new TypedEncoder.Primitive[](2);
        call1.chunks[0].structs = new TypedEncoder.Struct[](1);
        call1.chunks[0].arrays = new TypedEncoder.Array[](0);
        call1.chunks[0].primitives[0] = TypedEncoder.Primitive({
            isDynamic: false,
            data: abi.encode(address(0x1111111111111111111111111111111111111111))
        });
        call1.chunks[0].primitives[1] =
            TypedEncoder.Primitive({ isDynamic: true, data: bytes("transfer(address,uint256)") });
        call1.chunks[0].structs[0] = params1;

        TypedEncoder.Struct memory params2 = TypedEncoder.Struct({
            typeHash: keccak256("ApproveParams(address recipient,uint256 amount)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Struct
        });
        params2.chunks[0].primitives = new TypedEncoder.Primitive[](2);
        params2.chunks[0].structs = new TypedEncoder.Struct[](0);
        params2.chunks[0].arrays = new TypedEncoder.Array[](0);
        params2.chunks[0].primitives[0] = TypedEncoder.Primitive({
            isDynamic: false,
            data: abi.encode(address(0x2222222222222222222222222222222222222222))
        });
        params2.chunks[0].primitives[1] = TypedEncoder.Primitive({ isDynamic: false, data: abi.encode(uint256(2000)) });

        TypedEncoder.Struct memory call2 = TypedEncoder.Struct({
            typeHash: keccak256(
                "Call_2(address target,string functionSelector,ApproveParams params)"
                "ApproveParams(address recipient,uint256 amount)"
            ),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Struct
        });
        call2.chunks[0].primitives = new TypedEncoder.Primitive[](2);
        call2.chunks[0].structs = new TypedEncoder.Struct[](1);
        call2.chunks[0].arrays = new TypedEncoder.Array[](0);
        call2.chunks[0].primitives[0] = TypedEncoder.Primitive({
            isDynamic: false,
            data: abi.encode(address(0x3333333333333333333333333333333333333333))
        });
        call2.chunks[0].primitives[1] =
            TypedEncoder.Primitive({ isDynamic: true, data: bytes("approve(address,uint256)") });
        call2.chunks[0].structs[0] = params2;

        TypedEncoder.Struct memory params3 = TypedEncoder.Struct({
            typeHash: keccak256("ExecuteParams(bytes data)"),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Struct
        });
        params3.chunks[0].primitives = new TypedEncoder.Primitive[](1);
        params3.chunks[0].structs = new TypedEncoder.Struct[](0);
        params3.chunks[0].arrays = new TypedEncoder.Array[](0);
        params3.chunks[0].primitives[0] = TypedEncoder.Primitive({ isDynamic: true, data: hex"deadbeef" });

        TypedEncoder.Struct memory call3 = TypedEncoder.Struct({
            typeHash: keccak256(
                "Call_3(address target,string functionSelector,ExecuteParams params)" "ExecuteParams(bytes data)"
            ),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Struct
        });
        call3.chunks[0].primitives = new TypedEncoder.Primitive[](2);
        call3.chunks[0].structs = new TypedEncoder.Struct[](1);
        call3.chunks[0].arrays = new TypedEncoder.Array[](0);
        call3.chunks[0].primitives[0] = TypedEncoder.Primitive({
            isDynamic: false,
            data: abi.encode(address(0x4444444444444444444444444444444444444444))
        });
        call3.chunks[0].primitives[1] = TypedEncoder.Primitive({ isDynamic: true, data: bytes("execute(bytes)") });
        call3.chunks[0].structs[0] = params3;

        TypedEncoder.Struct memory callsStruct = TypedEncoder.Struct({
            typeHash: keccak256(
                "Calls(Call_1 call_1,Call_2 call_2,Call_3 call_3)"
                "Call_1(address target,string functionSelector,TransferParams params)"
                "Call_2(address target,string functionSelector,ApproveParams params)"
                "Call_3(address target,string functionSelector,ExecuteParams params)"
                "TransferParams(address recipient,uint256 amount)" "ApproveParams(address recipient,uint256 amount)"
                "ExecuteParams(bytes data)"
            ),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Array
        });
        callsStruct.chunks[0].primitives = new TypedEncoder.Primitive[](0);
        callsStruct.chunks[0].structs = new TypedEncoder.Struct[](3);
        callsStruct.chunks[0].arrays = new TypedEncoder.Array[](0);
        callsStruct.chunks[0].structs[0] = call1;
        callsStruct.chunks[0].structs[1] = call2;
        callsStruct.chunks[0].structs[2] = call3;

        TypedEncoder.Struct memory batchStruct = TypedEncoder.Struct({
            typeHash: keccak256(
                "Batch(Calls calls)" "Calls(Call_1 call_1,Call_2 call_2,Call_3 call_3)"
                "Call_1(address target,string functionSelector,TransferParams params)"
                "Call_2(address target,string functionSelector,ApproveParams params)"
                "Call_3(address target,string functionSelector,ExecuteParams params)"
                "TransferParams(address recipient,uint256 amount)" "ApproveParams(address recipient,uint256 amount)"
                "ExecuteParams(bytes data)"
            ),
            chunks: new TypedEncoder.Chunk[](1),
            encodingType: TypedEncoder.EncodingType.Struct
        });
        batchStruct.chunks[0].primitives = new TypedEncoder.Primitive[](0);
        batchStruct.chunks[0].structs = new TypedEncoder.Struct[](1);
        batchStruct.chunks[0].arrays = new TypedEncoder.Array[](0);
        batchStruct.chunks[0].structs[0] = callsStruct;

        bytes memory encoded = TypedEncoder.encode(batchStruct);

        Batch memory batched = abi.decode(encoded, (Batch));
        assertEq(batched.calls.length, 3);

        assertEq(batched.calls[0].target, address(0x1111111111111111111111111111111111111111));
        assertEq(batched.calls[0].functionSelector, "transfer(address,uint256)");
        TransferParams memory transferParams = abi.decode(batched.calls[0].params, (TransferParams));
        assertEq(transferParams.recipient, address(0x5555555555555555555555555555555555555555));
        assertEq(transferParams.amount, 1000);

        assertEq(batched.calls[1].target, address(0x3333333333333333333333333333333333333333));
        assertEq(batched.calls[1].functionSelector, "approve(address,uint256)");
        ApproveParams memory approveParams = abi.decode(batched.calls[1].params, (ApproveParams));
        assertEq(approveParams.recipient, address(0x2222222222222222222222222222222222222222));
        assertEq(approveParams.amount, 2000);

        assertEq(batched.calls[2].target, address(0x4444444444444444444444444444444444444444));
        assertEq(batched.calls[2].functionSelector, "execute(bytes)");
        ExecuteParams memory executeParams = abi.decode(batched.calls[2].params, (ExecuteParams));
        assertEq(executeParams.data, hex"deadbeef");
    }
}
