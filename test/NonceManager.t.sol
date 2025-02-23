// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "forge-std/Test.sol";

import "../src/NonceManager.sol";

contract MockNonceManager is NonceManager {
    constructor() NonceManager("MockNonceManager", "1.0.0") { }

    function exposed_useNonce(address owner, uint48 nonce) public {
        _useNonce(owner, nonce);
    }

    function exposed_hashTypedDataV4(
        bytes32 structHash
    ) public view returns (bytes32) {
        return _hashTypedDataV4(structHash);
    }
}

contract NonceManagerTest is Test {
    using ECDSA for bytes32;

    MockNonceManager nonceManager;
    uint256 ownerPrivateKey;
    address owner;

    event NonceUsed(address indexed owner, uint48 nonce);

    function setUp() public {
        ownerPrivateKey = 0x1234;
        owner = vm.addr(ownerPrivateKey);
        nonceManager = new MockNonceManager();
    }

    function test_nonceInitiallyUnused() public view {
        assertFalse(nonceManager.isNonceUsed(owner, 1));
    }

    function test_useNonce() public {
        nonceManager.exposed_useNonce(owner, 1);
        assertTrue(nonceManager.isNonceUsed(owner, 1));
    }

    function test_cannotReuseNonce() public {
        nonceManager.exposed_useNonce(owner, 1);
        vm.expectRevert(INonceManager.NonceAlreadyUsed.selector);
        nonceManager.exposed_useNonce(owner, 1);
    }

    function test_directNonceInvalidation() public {
        uint48[] memory nonces = new uint48[](2);
        nonces[0] = 1;
        nonces[1] = 2;

        vm.prank(owner);
        nonceManager.invalidateNonces(nonces);

        assertTrue(nonceManager.isNonceUsed(owner, 1));
        assertTrue(nonceManager.isNonceUsed(owner, 2));
    }

    function test_signedNonceInvalidation() public {
        uint48[] memory noncesToInvalidate = new uint48[](2);
        noncesToInvalidate[0] = 1;
        noncesToInvalidate[1] = 2;

        INonceManager.NoncesToInvalidate memory invalidations =
            INonceManager.NoncesToInvalidate({ chainId: 1, noncesToInvalidate: noncesToInvalidate });

        uint256 deadline = block.timestamp + 1 hours;
        bytes32 structHash = _getInvalidationStructHash(owner, deadline, invalidations);
        bytes32 digest = nonceManager.exposed_hashTypedDataV4(structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        nonceManager.invalidateNonces(owner, deadline, invalidations, signature);

        assertTrue(nonceManager.isNonceUsed(owner, 1));
        assertTrue(nonceManager.isNonceUsed(owner, 2));
    }

    function test_signedNonceInvalidationExpired() public {
        uint48[] memory noncesToInvalidate = new uint48[](1);
        noncesToInvalidate[0] = 1;

        INonceManager.NoncesToInvalidate memory invalidations =
            INonceManager.NoncesToInvalidate({ chainId: 1, noncesToInvalidate: noncesToInvalidate });

        uint256 deadline = block.timestamp - 1;
        bytes32 structHash = _getInvalidationStructHash(owner, deadline, invalidations);
        bytes32 digest = nonceManager.exposed_hashTypedDataV4(structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert(INonceManager.SignatureExpired.selector);
        nonceManager.invalidateNonces(owner, deadline, invalidations, signature);
    }

    function test_signedNonceInvalidationWrongSigner() public {
        uint48[] memory noncesToInvalidate = new uint48[](1);
        noncesToInvalidate[0] = 1;

        INonceManager.NoncesToInvalidate memory invalidations =
            INonceManager.NoncesToInvalidate({ chainId: 1, noncesToInvalidate: noncesToInvalidate });

        uint256 deadline = block.timestamp + 1 hours;
        bytes32 structHash = _getInvalidationStructHash(owner, deadline, invalidations);
        bytes32 digest = nonceManager.exposed_hashTypedDataV4(structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(0x5678, digest); // Different private key
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert(INonceManager.InvalidSignature.selector);
        nonceManager.invalidateNonces(owner, deadline, invalidations, signature);
    }

    function test_crossChainNonceInvalidation() public {
        uint48[] memory noncesToInvalidate = new uint48[](2);
        noncesToInvalidate[0] = 1;
        noncesToInvalidate[1] = 2;

        bytes32[] memory followingHashes = new bytes32[](1);
        followingHashes[0] = keccak256("next chain hash");

        INonceManager.NoncesToInvalidate memory invalidations =
                            INonceManager.NoncesToInvalidate({
                chainId: 1,
                noncesToInvalidate: noncesToInvalidate
            });

        INonceManager.CancelPermit3Proof memory proof = INonceManager.CancelPermit3Proof({
            preHash: keccak256("previous chain hash"),
            invalidations: invalidations,
            followingHashes: followingHashes
        });

        uint256 deadline = block.timestamp + 1 hours;
        bytes32 structHash = _getCrossChainInvalidationStructHash(owner, deadline, proof);
        bytes32 digest = nonceManager.exposed_hashTypedDataV4(structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        nonceManager.invalidateNonces(owner, deadline, proof, signature);

        assertTrue(nonceManager.isNonceUsed(owner, 1));
        assertTrue(nonceManager.isNonceUsed(owner, 2));
    }

    function test_crossChainNonceInvalidationExpired() public {
        uint48[] memory noncesToInvalidate = new uint48[](1);
        noncesToInvalidate[0] = 1;

        INonceManager.NoncesToInvalidate memory invalidations =
                            INonceManager.NoncesToInvalidate({
                chainId: 1,
                noncesToInvalidate: noncesToInvalidate
            });

        INonceManager.CancelPermit3Proof memory proof = INonceManager.CancelPermit3Proof({
            preHash: keccak256("previous chain hash"),
            invalidations: invalidations,
            followingHashes: new bytes32[](0)
        });

        uint256 deadline = block.timestamp - 1;
        bytes32 structHash = _getCrossChainInvalidationStructHash(owner, deadline, proof);
        bytes32 digest = nonceManager.exposed_hashTypedDataV4(structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert(INonceManager.SignatureExpired.selector);
        nonceManager.invalidateNonces(owner, deadline, proof, signature);
    }

    function test_crossChainNonceInvalidationWrongSigner() public {
        uint48[] memory noncesToInvalidate = new uint48[](1);
        noncesToInvalidate[0] = 1;

        INonceManager.NoncesToInvalidate memory invalidations =
                            INonceManager.NoncesToInvalidate({
                chainId: 1,
                noncesToInvalidate: noncesToInvalidate
            });

        INonceManager.CancelPermit3Proof memory proof = INonceManager.CancelPermit3Proof({
            preHash: keccak256("previous chain hash"),
            invalidations: invalidations,
            followingHashes: new bytes32[](0)
        });

        uint256 deadline = block.timestamp + 1 hours;
        bytes32 structHash = _getCrossChainInvalidationStructHash(owner, deadline, proof);
        bytes32 digest = nonceManager.exposed_hashTypedDataV4(structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(0x5678, digest); // Different private key
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert(INonceManager.InvalidSignature.selector);
        nonceManager.invalidateNonces(owner, deadline, proof, signature);
    }

    function _getCrossChainInvalidationStructHash(
        address owner,
        uint256 deadline,
        INonceManager.CancelPermit3Proof memory proof
    ) internal view returns (bytes32) {
        bytes32 chainedInvalidationHashes = proof.preHash;
        chainedInvalidationHashes = keccak256(
            abi.encodePacked(
                chainedInvalidationHashes,
                nonceManager.hashNoncesToInvalidate(proof.invalidations)
            )
        );

        for (uint256 i = 0; i < proof.followingHashes.length; i++) {
            chainedInvalidationHashes = keccak256(
                abi.encodePacked(chainedInvalidationHashes, proof.followingHashes[i])
            );
        }

        return keccak256(
            abi.encode(
                nonceManager.SIGNED_CANCEL_PERMIT3_TYPEHASH(),
                owner,
                deadline,
                chainedInvalidationHashes
            )
        );
    }

    function test_hashNoncesToInvalidate() public view {
        uint48[] memory noncesToInvalidate = new uint48[](2);
        noncesToInvalidate[0] = 1;
        noncesToInvalidate[1] = 2;

        INonceManager.NoncesToInvalidate memory invalidations =
            INonceManager.NoncesToInvalidate({ chainId: 1, noncesToInvalidate: noncesToInvalidate });

        bytes32 hash = nonceManager.hashNoncesToInvalidate(invalidations);
        assertTrue(hash != bytes32(0));
    }

    function test_eIP712DomainSeparator() public view {
        (
             ,
            string memory name,
            string memory version,
            uint256 chainId,
            address verifyingContract,
             ,

        ) = nonceManager.eip712Domain();

        assertEq(name, "MockNonceManager");
        assertEq(version, "1.0.0");
        assertEq(verifyingContract, address(nonceManager));
        assertEq(chainId, 0); // Cross-chain ID
    }

    function _getInvalidationStructHash(
        address owner,
        uint256 deadline,
        INonceManager.NoncesToInvalidate memory invalidations
    ) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                nonceManager.SIGNED_CANCEL_PERMIT3_TYPEHASH(),
                owner,
                deadline,
                nonceManager.hashNoncesToInvalidate(invalidations)
            )
        );
    }
}
