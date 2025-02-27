// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "forge-std/Test.sol";

import "../src/NonceManager.sol";

contract MockNonceManager is NonceManager {
    constructor() NonceManager("MockNonceManager", "1.0.0") { }

    function exposed_useNonce(address owner, bytes32 salt) public {
        _useNonce(owner, salt);
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
        assertFalse(nonceManager.isNonceUsed(owner, bytes32(uint256(1))));
    }

    function test_useNonce() public {
        nonceManager.exposed_useNonce(owner, bytes32(uint256(1)));
        assertTrue(nonceManager.isNonceUsed(owner, bytes32(uint256(1))));
    }

    function test_cannotReuseNonce() public {
        nonceManager.exposed_useNonce(owner, bytes32(uint256(1)));
        vm.expectRevert(INonceManager.NonceAlreadyUsed.selector);
        nonceManager.exposed_useNonce(owner, bytes32(uint256(1)));
    }

    function test_directNonceInvalidation() public {
        bytes32[] memory salts = new bytes32[](2);
        salts[0] = bytes32(uint256(1));
        salts[1] = bytes32(uint256(2));

        vm.prank(owner);
        nonceManager.invalidateNonces(salts);

        assertTrue(nonceManager.isNonceUsed(owner, bytes32(uint256(1))));
        assertTrue(nonceManager.isNonceUsed(owner, bytes32(uint256(2))));
    }

    function test_signedNonceInvalidation() public {
        bytes32[] memory salts = new bytes32[](2);
        salts[0] = bytes32(uint256(1));
        salts[1] = bytes32(uint256(2));

        INonceManager.NoncesToInvalidate memory invalidations =
            INonceManager.NoncesToInvalidate({ chainId: 31_337, salts: salts });

        uint256 deadline = block.timestamp + 1 hours;
        bytes32 structHash = _getInvalidationStructHash(owner, deadline, invalidations);
        bytes32 digest = nonceManager.exposed_hashTypedDataV4(structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        nonceManager.invalidateNonces(owner, deadline, invalidations, signature);

        assertTrue(nonceManager.isNonceUsed(owner, bytes32(uint256(1))));
        assertTrue(nonceManager.isNonceUsed(owner, bytes32(uint256(2))));
    }

    function test_signedNonceInvalidationExpired() public {
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = bytes32(uint256(1));

        INonceManager.NoncesToInvalidate memory invalidations =
            INonceManager.NoncesToInvalidate({ chainId: 31_337, salts: salts });

        uint256 deadline = block.timestamp - 1;
        bytes32 structHash = _getInvalidationStructHash(owner, deadline, invalidations);
        bytes32 digest = nonceManager.exposed_hashTypedDataV4(structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert(INonceManager.SignatureExpired.selector);
        nonceManager.invalidateNonces(owner, deadline, invalidations, signature);
    }

    function test_signedNonceInvalidationWrongSigner() public {
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = bytes32(uint256(1));

        INonceManager.NoncesToInvalidate memory invalidations =
            INonceManager.NoncesToInvalidate({ chainId: 31_337, salts: salts });

        uint256 deadline = block.timestamp + 1 hours;
        bytes32 structHash = _getInvalidationStructHash(owner, deadline, invalidations);
        bytes32 digest = nonceManager.exposed_hashTypedDataV4(structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(0x5678, digest); // Different private key
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert(INonceManager.InvalidSignature.selector);
        nonceManager.invalidateNonces(owner, deadline, invalidations, signature);
    }

    function test_crossChainNonceInvalidation() public {
        bytes32[] memory salts = new bytes32[](2);
        salts[0] = bytes32(uint256(1));
        salts[1] = bytes32(uint256(2));

        bytes32[] memory followingHashes = new bytes32[](1);
        followingHashes[0] = keccak256("next chain hash");

        INonceManager.NoncesToInvalidate memory invalidations =
            INonceManager.NoncesToInvalidate({ chainId: 31_337, salts: salts });

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

        assertTrue(nonceManager.isNonceUsed(owner, bytes32(uint256(1))));
        assertTrue(nonceManager.isNonceUsed(owner, bytes32(uint256(2))));
    }

    function test_wrongChainIdSignedInvalidation() public {
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = bytes32(uint256(1));

        INonceManager.NoncesToInvalidate memory invalidations = INonceManager.NoncesToInvalidate({
            chainId: 1, // Wrong chain ID
            salts: salts
        });

        uint256 deadline = block.timestamp + 1 hours;
        bytes32 structHash = _getInvalidationStructHash(owner, deadline, invalidations);
        bytes32 digest = nonceManager.exposed_hashTypedDataV4(structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert(abi.encodeWithSelector(INonceManager.WrongChainId.selector, 31_337, 1));
        nonceManager.invalidateNonces(owner, deadline, invalidations, signature);
    }

    function test_wrongChainIdCrossChainInvalidation() public {
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = bytes32(uint256(1));

        INonceManager.NoncesToInvalidate memory invalidations = INonceManager.NoncesToInvalidate({
            chainId: 1, // Wrong chain ID
            salts: salts
        });

        INonceManager.CancelPermit3Proof memory proof = INonceManager.CancelPermit3Proof({
            preHash: keccak256("previous chain hash"),
            invalidations: invalidations,
            followingHashes: new bytes32[](0)
        });

        uint256 deadline = block.timestamp + 1 hours;
        bytes32 structHash = _getCrossChainInvalidationStructHash(owner, deadline, proof);
        bytes32 digest = nonceManager.exposed_hashTypedDataV4(structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert(abi.encodeWithSelector(INonceManager.WrongChainId.selector, 31_337, 1));
        nonceManager.invalidateNonces(owner, deadline, proof, signature);
    }

    function test_crossChainNonceInvalidationExpired() public {
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = bytes32(uint256(1));

        INonceManager.NoncesToInvalidate memory invalidations =
            INonceManager.NoncesToInvalidate({ chainId: 31_337, salts: salts });

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
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = bytes32(uint256(1));

        INonceManager.NoncesToInvalidate memory invalidations =
            INonceManager.NoncesToInvalidate({ chainId: 31_337, salts: salts });

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
        address ownerAddress,
        uint256 deadline,
        INonceManager.CancelPermit3Proof memory proof
    ) internal view returns (bytes32) {
        bytes32 chainedInvalidationHashes = proof.preHash;
        chainedInvalidationHashes = keccak256(
            abi.encodePacked(chainedInvalidationHashes, nonceManager.hashNoncesToInvalidate(proof.invalidations))
        );

        for (uint256 i = 0; i < proof.followingHashes.length; i++) {
            chainedInvalidationHashes = keccak256(abi.encodePacked(chainedInvalidationHashes, proof.followingHashes[i]));
        }

        return keccak256(
            abi.encode(nonceManager.SIGNED_CANCEL_PERMIT3_TYPEHASH(), ownerAddress, deadline, chainedInvalidationHashes)
        );
    }

    function test_hashNoncesToInvalidate() public view {
        bytes32[] memory salts = new bytes32[](2);
        salts[0] = bytes32(uint256(1));
        salts[1] = bytes32(uint256(2));

        INonceManager.NoncesToInvalidate memory invalidations =
            INonceManager.NoncesToInvalidate({ chainId: 31_337, salts: salts });

        bytes32 hash = nonceManager.hashNoncesToInvalidate(invalidations);
        assertTrue(hash != bytes32(0));
    }

    function test_eIP712DomainSeparator() public view {
        (, string memory name, string memory version, uint256 chainId, address verifyingContract,,) =
            nonceManager.eip712Domain();

        assertEq(name, "MockNonceManager");
        assertEq(version, "1.0.0");
        assertEq(verifyingContract, address(nonceManager));
        assertEq(chainId, 0); // Cross-chain ID
    }

    function _getInvalidationStructHash(
        address ownerAddress,
        uint256 deadline,
        INonceManager.NoncesToInvalidate memory invalidations
    ) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                nonceManager.SIGNED_CANCEL_PERMIT3_TYPEHASH(),
                ownerAddress,
                deadline,
                nonceManager.hashNoncesToInvalidate(invalidations)
            )
        );
    }
}
