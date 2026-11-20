// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../src/interfaces/INonceManager.sol";
import "./utils/TestBase.sol";

/**
 * @title NonceManagerTest
 * @notice Consolidated tests for NonceManager functionality
 */
contract NonceManagerTest is TestBase {
    function test_nonceInitiallyUnused() public view {
        assertFalse(permit3.isNonceUsed(owner, SALT));
    }

    function test_directNonceInvalidation() public {
        bytes32[] memory salts = new bytes32[](2);
        salts[0] = bytes32(uint256(1));
        salts[1] = bytes32(uint256(2));

        vm.prank(owner);
        permit3.invalidateNonces(salts);

        assertTrue(permit3.isNonceUsed(owner, bytes32(uint256(1))));
        assertTrue(permit3.isNonceUsed(owner, bytes32(uint256(2))));
    }

    function test_signedNonceInvalidation() public {
        bytes32[] memory salts = new bytes32[](2);
        salts[0] = bytes32(uint256(1));
        salts[1] = bytes32(uint256(2));

        INonceManager.NoncesToInvalidate memory invalidations =
            INonceManager.NoncesToInvalidate({ chainId: uint64(block.chainid), salts: salts });

        uint48 deadline = uint48(block.timestamp + 1 hours);
        bytes32 structHash = _getInvalidationStructHash(owner, deadline, invalidations);
        bytes32 digest = exposed_hashTypedDataV4(structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        permit3.invalidateNonces(owner, deadline, salts, signature);

        assertTrue(permit3.isNonceUsed(owner, bytes32(uint256(1))));
        assertTrue(permit3.isNonceUsed(owner, bytes32(uint256(2))));
    }

    function test_signedNonceInvalidationExpired() public {
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = bytes32(uint256(1));

        INonceManager.NoncesToInvalidate memory invalidations =
            INonceManager.NoncesToInvalidate({ chainId: uint64(block.chainid), salts: salts });

        uint48 deadline = uint48(block.timestamp - 1);
        bytes32 structHash = _getInvalidationStructHash(owner, deadline, invalidations);
        bytes32 digest = exposed_hashTypedDataV4(structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert(
            abi.encodeWithSelector(INonceManager.SignatureExpired.selector, deadline, uint48(block.timestamp))
        );
        permit3.invalidateNonces(owner, deadline, salts, signature);
    }

    function test_signedNonceInvalidationWrongSigner() public {
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = bytes32(uint256(1));

        INonceManager.NoncesToInvalidate memory invalidations =
            INonceManager.NoncesToInvalidate({ chainId: uint64(block.chainid), salts: salts });

        uint48 deadline = uint48(block.timestamp + 1 hours);
        bytes32 structHash = _getInvalidationStructHash(owner, deadline, invalidations);
        bytes32 digest = exposed_hashTypedDataV4(structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(0x5678, digest); // Different private key
        bytes memory signature = abi.encodePacked(r, s, v);

        // When signature is from wrong private key, the recovered signer will be different
        vm.expectRevert();
        permit3.invalidateNonces(owner, deadline, salts, signature);
    }

    function test_crossChainNonceInvalidation() public {
        bytes32[] memory salts = new bytes32[](2);
        salts[0] = bytes32(uint256(1));
        salts[1] = bytes32(uint256(2));

        bytes32[] memory followingHashes = new bytes32[](1);
        followingHashes[0] = keccak256("next chain hash");

        INonceManager.NoncesToInvalidate memory invalidations =
            INonceManager.NoncesToInvalidate({ chainId: uint64(block.chainid), salts: salts });

        // Create a minimal proof structure for testing
        bytes32[] memory nodes = new bytes32[](0);

        uint48 deadline = uint48(block.timestamp + 1 hours);
        bytes32 structHash = _getUnbalancedInvalidationStructHash(owner, deadline, invalidations, nodes);
        bytes32 digest = exposed_hashTypedDataV4(structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        permit3.invalidateNonces(owner, deadline, invalidations, nodes, signature);

        assertTrue(permit3.isNonceUsed(owner, bytes32(uint256(1))));
        assertTrue(permit3.isNonceUsed(owner, bytes32(uint256(2))));
    }

    function test_wrongChainIdSignedInvalidation() public {
        // Skip this test if we're on a chain with ID 1 (unlikely in tests)
        if (block.chainid == 1) {
            return;
        }

        bytes32[] memory salts = new bytes32[](1);
        salts[0] = bytes32(uint256(1));

        INonceManager.NoncesToInvalidate memory invalidations = INonceManager.NoncesToInvalidate({
            chainId: 1, // Wrong chain ID
            salts: salts
        });

        uint48 deadline = uint48(block.timestamp + 1 hours);
        bytes32 structHash = _getInvalidationStructHash(owner, deadline, invalidations);
        bytes32 digest = exposed_hashTypedDataV4(structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Should revert with InvalidSignature (signature was created for wrong chain ID)
        vm.expectRevert();
        permit3.invalidateNonces(owner, deadline, salts, signature);
    }

    function test_wrongChainIdCrossChainInvalidation() public {
        // Skip this test if we're on a chain with ID 1 (unlikely in tests)
        if (block.chainid == 1) {
            return;
        }

        bytes32[] memory salts = new bytes32[](1);
        salts[0] = bytes32(uint256(1));

        INonceManager.NoncesToInvalidate memory invalidations = INonceManager.NoncesToInvalidate({
            chainId: 1, // Wrong chain ID
            salts: salts
        });

        // Create a minimal proof structure for testing
        bytes32[] memory nodes = new bytes32[](0);
        uint48 deadline = uint48(block.timestamp + 1 hours);
        bytes32 structHash = _getUnbalancedInvalidationStructHash(owner, deadline, invalidations, nodes);
        bytes32 digest = exposed_hashTypedDataV4(structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert(abi.encodeWithSelector(INonceManager.WrongChainId.selector, uint64(block.chainid), 1));
        permit3.invalidateNonces(owner, deadline, invalidations, nodes, signature);
    }

    function test_crossChainNonceInvalidationExpired() public {
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = bytes32(uint256(1));

        INonceManager.NoncesToInvalidate memory invalidations =
            INonceManager.NoncesToInvalidate({ chainId: uint64(block.chainid), salts: salts });

        // Create a minimal proof structure for testing
        bytes32[] memory nodes = new bytes32[](0);
        uint48 deadline = uint48(block.timestamp - 1);
        bytes32 structHash = _getUnbalancedInvalidationStructHash(owner, deadline, invalidations, nodes);
        bytes32 digest = exposed_hashTypedDataV4(structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert(
            abi.encodeWithSelector(INonceManager.SignatureExpired.selector, deadline, uint48(block.timestamp))
        );
        permit3.invalidateNonces(owner, deadline, invalidations, nodes, signature);
    }

    function test_crossChainNonceInvalidationWrongSigner() public {
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = bytes32(uint256(1));

        INonceManager.NoncesToInvalidate memory invalidations =
            INonceManager.NoncesToInvalidate({ chainId: uint64(block.chainid), salts: salts });

        // Create a minimal proof structure for testing
        bytes32[] memory nodes = new bytes32[](0);
        uint48 deadline = uint48(block.timestamp + 1 hours);
        bytes32 structHash = _getUnbalancedInvalidationStructHash(owner, deadline, invalidations, nodes);
        bytes32 digest = exposed_hashTypedDataV4(structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(0x5678, digest); // Different private key
        bytes memory signature = abi.encodePacked(r, s, v);

        // When signature is from wrong private key, the recovered signer will be different
        vm.expectRevert();
        permit3.invalidateNonces(owner, deadline, invalidations, nodes, signature);
    }

    function test_eIP712Domain() public view {
        // Call the eip712Domain function to test it
        (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt,
            uint256[] memory extensions
        ) = permit3.eip712Domain();

        // Verify the results
        assertEq(fields, hex"0f"); // 01111 - indicates which fields are set
        assertEq(name, "Permit3");
        assertEq(version, "1");
        assertEq(chainId, 1); // CROSS_CHAIN_ID
        assertEq(verifyingContract, address(permit3));
        assertEq(salt, bytes32(0));
        assertEq(extensions.length, 0);
    }

    function test_invalidateNoncesWithProof() public {
        WithProofParams memory p;
        p.testSalt = bytes32(uint256(5555));

        // Set up invalidation parameters
        p.salts = new bytes32[](1);
        p.salts[0] = p.testSalt;

        p.invalidations = INonceManager.NoncesToInvalidate({ chainId: uint64(block.chainid), salts: p.salts });

        // Set up unbalanced proof - create a simple proof that will produce a calculable root
        p.invalidationsHash = permit3.hashNoncesToInvalidate(p.invalidations);

        // Create a simple proof structure where the leaf is the root (no proof needed)
        bytes32[] memory proofNodes = new bytes32[](0);
        p.proof = proofNodes;

        // Set up deadline
        p.deadline = uint48(block.timestamp + 1 hours);

        // The root will be calculated by the library from the proof and invalidations hash
        p.merkleRoot = p.invalidationsHash; // For simple proof, root equals leaf

        // Create the signature
        p.signedHash = keccak256(abi.encode(permit3.CANCEL_PERMIT3_TYPEHASH(), owner, p.deadline, p.merkleRoot));
        p.digest = _getDigest(p.signedHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, p.digest);
        p.signature = abi.encodePacked(r, s, v);

        // Ensure salt isn't used already
        assertFalse(permit3.isNonceUsed(owner, p.testSalt));

        // Call the invalidateNonces function with proof
        permit3.invalidateNonces(owner, p.deadline, p.invalidations, p.proof, p.signature);

        // Verify salt is now used
        assertTrue(permit3.isNonceUsed(owner, p.testSalt));
    }

    /**
     * @notice Regression test pinning hashNoncesToInvalidate to EIP-712 hashStruct(NoncesToInvalidate).
     * @dev The expected hashes are known-answer vectors for chainId 1, computed outside this repository: forge's
     *      EIP-712 encoder (vm.eip712HashStruct) and `cast keccak` over `cast abi-encode` give the same values.
     *      The type hash is checked against the literal type string. The old encoding, which inlined the
     *      bytes32[] member with abi.encode, gives a different hash, so this test fails on the pre-fix contract.
     */
    function test_hashNoncesToInvalidate_matchesEip712AndRejectsBuggyForm() public view {
        bytes32 typeHash = keccak256("NoncesToInvalidate(uint64 chainId,bytes32[] salts)");
        assertEq(permit3.NONCES_TO_INVALIDATE_TYPEHASH(), typeHash, "type string");

        bytes32[] memory salts = new bytes32[](3);
        salts[0] = bytes32(uint256(0xAA));
        salts[1] = bytes32(uint256(0xBB));
        salts[2] = bytes32(uint256(0xCC));
        INonceManager.NoncesToInvalidate memory invalidations =
            INonceManager.NoncesToInvalidate({ chainId: 1, salts: salts });

        bytes32 expected = 0x5d1b584c7dc3a38b2f15cf3e0a0730f31d107fa6fbc8c1d3fbf40895dcb64a29;
        assertEq(permit3.hashNoncesToInvalidate(invalidations), expected, "hashStruct(NoncesToInvalidate)");

        // The old encoding: the dynamic array inlined with abi.encode
        bytes32 buggy = keccak256(abi.encode(typeHash, uint64(1), salts));
        assertTrue(buggy != expected, "the old inline-array encoding differs from hashStruct");

        // An empty array is encoded as keccak256 of no bytes
        invalidations.salts = new bytes32[](0);
        assertEq(
            permit3.hashNoncesToInvalidate(invalidations),
            0x42a2844a4bdc1802e4245dd40d3ebddccc614d1305c4ec20f6bfb6b91172b9cc,
            "hashStruct(NoncesToInvalidate) with no salts"
        );
    }

    /**
     * @notice A signature over a digest built only from literal EIP-712 type strings and the domain fields is
     *         accepted by the signed invalidateNonces overload.
     * @dev The owner signs CancelPermit3(owner, deadline, merkleRoot). For a single-chain invalidation the
     *      merkleRoot is hashStruct(NoncesToInvalidate), computed here without the contract's hashing helpers
     *      or type hash constants.
     */
    function test_signedInvalidation_acceptsStandardEip712Signature() public {
        bytes32[] memory salts = new bytes32[](3);
        salts[0] = bytes32(uint256(0x111));
        salts[1] = bytes32(uint256(0x222));
        salts[2] = bytes32(uint256(0x333));

        uint48 deadline = uint48(block.timestamp + 1 hours);

        // hashStruct(NoncesToInvalidate) from the literal type string
        bytes32 noncesStructHash = keccak256(
            abi.encode(
                keccak256("NoncesToInvalidate(uint64 chainId,bytes32[] salts)"),
                uint64(block.chainid),
                keccak256(abi.encodePacked(salts))
            )
        );

        // hashStruct(CancelPermit3) with merkleRoot = the single leaf
        bytes32 cancelStructHash = keccak256(
            abi.encode(
                keccak256("CancelPermit3(address owner,uint48 deadline,bytes32 merkleRoot)"),
                owner,
                deadline,
                noncesStructHash
            )
        );

        // Domain: name "Permit3", version "1", chainId 1 (CROSS_CHAIN_ID), this contract
        bytes32 domainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("Permit3"),
                keccak256("1"),
                uint256(1),
                address(permit3)
            )
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, cancelStructHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Sanity: nonces start unused.
        for (uint256 i = 0; i < salts.length; i++) {
            assertFalse(permit3.isNonceUsed(owner, salts[i]));
        }

        // Expect a NonceInvalidated event for each salt.
        for (uint256 i = 0; i < salts.length; i++) {
            vm.expectEmit(true, true, false, false, address(permit3));
            emit INonceManager.NonceInvalidated(owner, salts[i]);
        }

        // A standard-EIP-712-derived signature must be accepted.
        permit3.invalidateNonces(owner, deadline, salts, signature);

        // Every salt is now invalidated.
        for (uint256 i = 0; i < salts.length; i++) {
            assertTrue(permit3.isNonceUsed(owner, salts[i]), "salt should be invalidated");
        }
    }
}
