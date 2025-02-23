// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "forge-std/Test.sol";

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import "../src/Permit3.sol";
import "../src/interfaces/INonceManager.sol";

contract MockToken is ERC20 {
    constructor() ERC20("Mock", "MOCK") {
        _mint(msg.sender, 1_000_000 * 10 ** decimals());
    }
}

contract Permit3Test is Test {
    using ECDSA for bytes32;

    Permit3 permit3;
    MockToken token;

    uint256 ownerPrivateKey;
    address owner;
    address spender;
    address recipient;

    uint160 constant AMOUNT = 1000;
    uint48 constant EXPIRATION = 1000;

    function setUp() public {
        permit3 = new Permit3();
        token = new MockToken();

        ownerPrivateKey = 0x1234;
        owner = vm.addr(ownerPrivateKey);
        spender = address(0x2);
        recipient = address(0x3);

        deal(address(token), owner, 10_000);
        vm.prank(owner);
        token.approve(address(permit3), type(uint256).max);
    }

    function test_singleChainPermit() public {
        IPermit3.SpendTransferPermit[] memory permits = new IPermit3.SpendTransferPermit[](1);
        permits[0] = IPermit3.SpendTransferPermit({
            transferOrExpiration: EXPIRATION,
            token: address(token),
            spender: spender,
            amount: AMOUNT
        });

        IPermit3.ChainPermits memory chainPermits = IPermit3.ChainPermits({ chainId: 1, nonce: 1, permits: permits });

        uint256 deadline = block.timestamp + 1 hours;
        bytes32 structHash = _getPermitStructHash(owner, deadline, chainPermits);
        bytes32 digest = _getDigest(structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        permit3.permit(owner, deadline, chainPermits, signature);

        (uint160 allowance,,) = permit3.allowance(owner, address(token), spender);
        assertEq(allowance, AMOUNT);
    }

    function test_multiChainPermit() public {
        IPermit3.SpendTransferPermit[] memory permits = new IPermit3.SpendTransferPermit[](1);
        permits[0] = IPermit3.SpendTransferPermit({
            transferOrExpiration: EXPIRATION,
            token: address(token),
            spender: spender,
            amount: AMOUNT
        });

        IPermit3.ChainPermits memory chainPermits = IPermit3.ChainPermits({ chainId: 1, nonce: 1, permits: permits });

        bytes32[] memory followingHashes = new bytes32[](1);
        followingHashes[0] = bytes32(uint256(1)); // Simulated hash from another chain

        IPermit3.Permit3Proof memory proof =
            IPermit3.Permit3Proof({ preHash: bytes32(0), permits: chainPermits, followingHashes: followingHashes });

        uint256 deadline = block.timestamp + 1 hours;
        bytes32 structHash = _getMultiChainPermitStructHash(owner, deadline, proof);
        bytes32 digest = _getDigest(structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        permit3.permit(owner, deadline, proof, signature);

        (uint160 allowance,,) = permit3.allowance(owner, address(token), spender);
        assertEq(allowance, AMOUNT);
    }

    function test_immediateTransfer() public {
        IPermit3.SpendTransferPermit[] memory permits = new IPermit3.SpendTransferPermit[](1);
        permits[0] = IPermit3.SpendTransferPermit({
            transferOrExpiration: 1, // Immediate transfer
            token: address(token),
            spender: recipient,
            amount: AMOUNT
        });

        IPermit3.ChainPermits memory chainPermits = IPermit3.ChainPermits({ chainId: 1, nonce: 1, permits: permits });

        uint256 deadline = block.timestamp + 1 hours;
        bytes32 structHash = _getPermitStructHash(owner, deadline, chainPermits);
        bytes32 digest = _getDigest(structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        permit3.permit(owner, deadline, chainPermits, signature);

        assertEq(token.balanceOf(recipient), AMOUNT);
    }

    function test_permitExpired() public {
        IPermit3.SpendTransferPermit[] memory permits = new IPermit3.SpendTransferPermit[](1);
        permits[0] = IPermit3.SpendTransferPermit({
            transferOrExpiration: EXPIRATION,
            token: address(token),
            spender: spender,
            amount: AMOUNT
        });

        IPermit3.ChainPermits memory chainPermits = IPermit3.ChainPermits({ chainId: 1, nonce: 1, permits: permits });

        uint256 deadline = block.timestamp - 1;
        bytes32 structHash = _getPermitStructHash(owner, deadline, chainPermits);
        bytes32 digest = _getDigest(structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert(INonceManager.SignatureExpired.selector);
        permit3.permit(owner, deadline, chainPermits, signature);
    }

    function test_invalidSignature() public {
        IPermit3.SpendTransferPermit[] memory permits = new IPermit3.SpendTransferPermit[](1);
        permits[0] = IPermit3.SpendTransferPermit({
            transferOrExpiration: EXPIRATION,
            token: address(token),
            spender: spender,
            amount: AMOUNT
        });

        IPermit3.ChainPermits memory chainPermits = IPermit3.ChainPermits({ chainId: 1, nonce: 1, permits: permits });

        uint256 deadline = block.timestamp + 1 hours;
        bytes32 structHash = _getPermitStructHash(owner, deadline, chainPermits);
        bytes32 digest = _getDigest(structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(0x5678, digest); // Wrong private key
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert(INonceManager.InvalidSignature.selector);
        permit3.permit(owner, deadline, chainPermits, signature);
    }

    function _getPermitStructHash(
        address ownerAddress,
        uint256 deadline,
        IPermit3.ChainPermits memory permits
    ) internal view returns (bytes32) {
        return keccak256(abi.encode(permit3.SIGNED_PERMIT3_TYPEHASH(), ownerAddress, deadline, _hashChainPermits(permits)));
    }

    function _getMultiChainPermitStructHash(
        address ownerAddress,
        uint256 deadline,
        IPermit3.Permit3Proof memory proof
    ) internal view returns (bytes32) {
        bytes32 chainedHashes = proof.preHash;
        chainedHashes = keccak256(abi.encodePacked(chainedHashes, _hashChainPermits(proof.permits)));

        for (uint256 i = 0; i < proof.followingHashes.length; i++) {
            chainedHashes = keccak256(abi.encodePacked(chainedHashes, proof.followingHashes[i]));
        }

        return keccak256(abi.encode(permit3.SIGNED_PERMIT3_TYPEHASH(), ownerAddress, deadline, chainedHashes));
    }

    function _hashChainPermits(
        IPermit3.ChainPermits memory permits
    ) internal view returns (bytes32) {
        bytes32[] memory permitHashes = new bytes32[](permits.permits.length);

        for (uint256 i = 0; i < permits.permits.length; i++) {
            permitHashes[i] = keccak256(
                abi.encode(
                    permits.permits[i].transferOrExpiration,
                    permits.permits[i].token,
                    permits.permits[i].spender,
                    permits.permits[i].amount
                )
            );
        }

        return keccak256(
            abi.encode(
                permit3.CHAIN_PERMITS_TYPEHASH(),
                permits.chainId,
                permits.nonce,
                keccak256(abi.encodePacked(permitHashes))
            )
        );
    }

    function _getDigest(
        bytes32 structHash
    ) internal view returns (bytes32) {
        return _hashTypedDataV4(structHash);
    }

    function _hashTypedDataV4(
        bytes32 structHash
    ) internal view returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", _domainSeparatorV4(), structHash));
    }

    function _domainSeparatorV4() internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("Permit3")),
                keccak256(bytes("1")),
                0, // CROSS_CHAIN_ID
                address(permit3)
            )
        );
    }
}
