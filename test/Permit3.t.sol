// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../src/interfaces/IPermit3.sol";
import "./utils/TestBase.sol";

/**
 * @title Permit3Test
 * @notice Consolidated tests for core Permit3 functionality
 */
contract Permit3Test is TestBase {
    bytes32 public constant SIGNED_PERMIT3_WITNESS_TYPEHASH = keccak256(
        "SignedPermit3Witness(address owner,bytes32 salt,uint48 deadline,uint48 timestamp,bytes32 permitHash,bytes32 witnessTypeHash,bytes32 witness)"
    );

    function test_permitTransferFrom() public {
        // Create the permit
        IPermit3.ChainPermits memory chainPermits = _createBasicTransferPermit();

        // Reset recipient balance
        deal(address(token), recipient, 0);

        uint48 deadline = uint48(block.timestamp + 1 hours);
        uint48 timestamp = uint48(block.timestamp);
        bytes memory signature = _signPermit(chainPermits, deadline, timestamp, SALT);

        // Execute permit
        permit3.permit(owner, SALT, deadline, timestamp, chainPermits.permits, signature);

        // Verify transfer happened
        assertEq(token.balanceOf(recipient), AMOUNT);

        // Verify nonce is used
        assertTrue(permit3.isNonceUsed(owner, SALT));
    }

    function test_permitTransferFromExpired() public {
        // Create the permit
        IPermit3.ChainPermits memory chainPermits = _createBasicTransferPermit();

        uint48 deadline = uint48(block.timestamp - 1); // Expired
        uint48 timestamp = uint48(block.timestamp);
        bytes memory signature = _signPermit(chainPermits, deadline, timestamp, SALT);

        // Should revert with SignatureExpired
        vm.expectRevert(
            abi.encodeWithSelector(INonceManager.SignatureExpired.selector, deadline, uint48(block.timestamp))
        );
        permit3.permit(owner, SALT, deadline, timestamp, chainPermits.permits, signature);
    }

    function test_permitTransferFromInvalidSignature() public {
        // Create the permit
        IPermit3.ChainPermits memory chainPermits = _createBasicTransferPermit();

        uint48 deadline = uint48(block.timestamp + 1 hours);
        uint48 timestamp = uint48(block.timestamp);
        bytes memory signature = _signPermit(chainPermits, deadline, timestamp, SALT);

        // Modify signature to make it invalid
        signature[0] = signature[0] ^ bytes1(uint8(1));

        // Should revert with InvalidSignature
        // When signature is invalid, the recovered signer will be different from owner
        // We can't predict the exact recovered address, so we use expectRevert without parameters
        vm.expectRevert();
        permit3.permit(owner, SALT, deadline, timestamp, chainPermits.permits, signature);
    }

    function test_permitTransferFromReusedNonce() public {
        // Create the permit
        IPermit3.ChainPermits memory chainPermits = _createBasicTransferPermit();

        uint48 deadline = uint48(block.timestamp + 1 hours);
        uint48 timestamp = uint48(block.timestamp);
        bytes memory signature = _signPermit(chainPermits, deadline, timestamp, SALT);

        // First permit should succeed
        permit3.permit(owner, SALT, deadline, timestamp, chainPermits.permits, signature);

        // Second attempt with same nonce should fail
        vm.expectRevert(abi.encodeWithSelector(INonceManager.NonceAlreadyUsed.selector, owner, SALT));
        permit3.permit(owner, SALT, deadline, timestamp, chainPermits.permits, signature);
    }

    function test_permitTransferFromWrongChainId() public {
        // Skip this test if we're on chain 999 (unlikely in tests)
        if (block.chainid == 999) {
            return;
        }

        // Create a permit with wrong chain ID
        IPermit3.AllowanceOrTransfer[] memory permits = new IPermit3.AllowanceOrTransfer[](1);
        permits[0] = IPermit3.AllowanceOrTransfer({
            modeOrExpiration: 0, // Transfer mode
            token: address(token),
            account: recipient,
            amountDelta: AMOUNT
        });

        IPermit3.ChainPermits memory chainPermits = IPermit3.ChainPermits({
            chainId: 999, // Wrong chain ID
            permits: permits
        });

        uint48 deadline = uint48(block.timestamp + 1 hours);
        uint48 timestamp = uint48(block.timestamp);
        bytes memory signature = _signPermit(chainPermits, deadline, timestamp, SALT);

        // Should revert with InvalidSignature (signature was created for wrong chain ID)
        vm.expectRevert();
        permit3.permit(owner, SALT, deadline, timestamp, chainPermits.permits, signature);
    }

    function test_permitAllowance() public {
        // Create a permit for allowance
        IPermit3.AllowanceOrTransfer[] memory permits = new IPermit3.AllowanceOrTransfer[](1);
        permits[0] = IPermit3.AllowanceOrTransfer({
            modeOrExpiration: EXPIRATION, // Setting expiration (allowance mode)
            token: address(token),
            account: spender, // Approve spender
            amountDelta: AMOUNT
        });

        IPermit3.ChainPermits memory chainPermits =
            IPermit3.ChainPermits({ chainId: uint64(block.chainid), permits: permits });

        uint48 deadline = uint48(block.timestamp + 1 hours);
        uint48 timestamp = uint48(block.timestamp);
        bytes memory signature = _signPermit(chainPermits, deadline, timestamp, SALT);

        // Execute permit
        permit3.permit(owner, SALT, deadline, timestamp, chainPermits.permits, signature);

        // Verify allowance is set
        (uint160 amount, uint48 expiration,) = permit3.allowance(owner, address(token), spender);
        assertEq(amount, AMOUNT);
        assertEq(expiration, EXPIRATION);

        // Verify nonce is used
        assertTrue(permit3.isNonceUsed(owner, SALT));
    }

    function test_permitMultipleOperations() public {
        // Create combined permit with both allowance and transfer
        IPermit3.AllowanceOrTransfer[] memory permits = new IPermit3.AllowanceOrTransfer[](2);

        // Approve spender
        permits[0] = IPermit3.AllowanceOrTransfer({
            modeOrExpiration: EXPIRATION, // Setting expiration (allowance mode)
            token: address(token),
            account: spender,
            amountDelta: AMOUNT
        });

        // Transfer tokens
        permits[1] = IPermit3.AllowanceOrTransfer({
            modeOrExpiration: 0, // Transfer mode
            token: address(token),
            account: recipient,
            amountDelta: AMOUNT / 2
        });

        IPermit3.ChainPermits memory chainPermits =
            IPermit3.ChainPermits({ chainId: uint64(block.chainid), permits: permits });

        // Reset balances
        deal(address(token), recipient, 0);

        uint48 deadline = uint48(block.timestamp + 1 hours);
        uint48 timestamp = uint48(block.timestamp);
        bytes memory signature = _signPermit(chainPermits, deadline, timestamp, SALT);

        // Execute permit
        permit3.permit(owner, SALT, deadline, timestamp, chainPermits.permits, signature);

        // Verify allowance is set
        (uint160 amount, uint48 expiration,) = permit3.allowance(owner, address(token), spender);
        assertEq(amount, AMOUNT);
        assertEq(expiration, EXPIRATION);

        // Verify transfer happened
        assertEq(token.balanceOf(recipient), AMOUNT / 2);

        // Verify nonce is used
        assertTrue(permit3.isNonceUsed(owner, SALT));
    }

    // The witness test functionality is covered in Permit3Witness.t.sol
    // No need to duplicate it here

    function test_unhingedPermit() public {
        // Test the unhinged permit functionality

        // Create a chain permit for the current chain
        IPermit3.ChainPermits memory chainPermits = _createBasicTransferPermit();

        // Create a valid unhinged proof (using preHash only, no subtreeProof - mutually exclusive)
        bytes32[] memory nodes = new bytes32[](2);
        nodes[0] = bytes32(uint256(0x1234)); // preHash
        nodes[1] = bytes32(uint256(0x9abc)); // following hash

        // Create packed counts with hasPreHash flag set to true (no subtreeProof)
        bytes32 counts = keccak256(""); // Just to create a variable
        {
            // Pack with updated format: 0 subtree proof nodes, 1 following hash, with preHash flag
            uint256 packedValue = uint256(0) << 136; // 0 subtree proof nodes (shifted 136 bits)
            packedValue |= uint256(1) << 16; // 1 following hash (shifted 16 bits)
            packedValue |= 1; // hasPreHash flag (last bit set to 1)
            counts = bytes32(packedValue);
        }

        IUnhingedMerkleTree.UnhingedProof memory unhingedProof =
            IUnhingedMerkleTree.UnhingedProof({ nodes: nodes, counts: counts });

        IPermit3.UnhingedPermitProof memory permitProof =
            IPermit3.UnhingedPermitProof({ permits: chainPermits, unhingedProof: unhingedProof });

        // Reset recipient balance
        deal(address(token), recipient, 0);

        uint48 deadline = uint48(block.timestamp + 1 hours);
        uint48 timestamp = uint48(block.timestamp);

        // Create signature
        bytes memory signature = _signUnhingedPermit(permitProof, deadline, timestamp, SALT);

        // Execute permit
        permit3.permit(owner, SALT, deadline, timestamp, permitProof, signature);

        // Verify transfer happened
        assertEq(token.balanceOf(recipient), AMOUNT);

        // Verify nonce is used
        assertTrue(permit3.isNonceUsed(owner, SALT));
    }

    function test_invalidUnhingedProof() public {
        // Test the branch where unhinged proof is invalid

        // Create a chain permit for the current chain
        IPermit3.ChainPermits memory chainPermits = _createBasicTransferPermit();

        // Create an invalid unhinged proof with invalid structure
        // Since we're testing the failure path, we'll make a fixed signature
        // instead of using the _signUnhingedPermit helper which is failing for invalid proofs

        bytes32[] memory nodes = new bytes32[](1); // Just 1 node, invalid
        nodes[0] = bytes32(uint256(0x1)); // preHash only

        // This is invalid - subtree proof count should be at least 1
        bytes32 counts = bytes32(uint256(0) << 128 | uint256(0));

        // Create invalid proof
        IUnhingedMerkleTree.UnhingedProof memory invalidProof =
            IUnhingedMerkleTree.UnhingedProof({ nodes: nodes, counts: counts });

        IPermit3.UnhingedPermitProof memory permitProof =
            IPermit3.UnhingedPermitProof({ permits: chainPermits, unhingedProof: invalidProof });

        uint48 deadline = uint48(block.timestamp + 1 hours);
        uint48 timestamp = uint48(block.timestamp);

        // Create a dummy signature
        bytes memory signature = new bytes(65);

        // Test that an invalid proof reverts
        vm.expectRevert();
        vm.prank(owner);
        permit3.permit(owner, SALT, deadline, timestamp, permitProof, signature);
    }

    function test_permitUnhingedProofErrors() public {
        // Test errors in unhinged permit processing

        // Create a chain permit with wrong chain ID
        IPermit3.ChainPermits memory chainPermits = IPermit3.ChainPermits({
            chainId: 999, // Wrong chain ID
            permits: new IPermit3.AllowanceOrTransfer[](0)
        });

        // Create a dummy proof
        bytes32[] memory nodes = new bytes32[](1);
        nodes[0] = bytes32(uint256(0x1));

        IUnhingedMerkleTree.UnhingedProof memory proof =
            IUnhingedMerkleTree.UnhingedProof({ nodes: nodes, counts: bytes32(0) });

        IPermit3.UnhingedPermitProof memory permitProof =
            IPermit3.UnhingedPermitProof({ permits: chainPermits, unhingedProof: proof });

        uint48 deadline = uint48(block.timestamp + 1 hours);
        uint48 timestamp = uint48(block.timestamp);

        // Create a dummy signature
        bytes memory signature = new bytes(65);

        // Test that wrong chain ID reverts with WrongChainId error
        vm.expectRevert(abi.encodeWithSelector(INonceManager.WrongChainId.selector, uint64(block.chainid), 999));
        vm.prank(owner);
        permit3.permit(owner, SALT, deadline, timestamp, permitProof, signature);

        // Test that expired deadline reverts with SignatureExpired error
        uint48 expiredDeadline = uint48(block.timestamp - 1);

        vm.expectRevert(
            abi.encodeWithSelector(INonceManager.SignatureExpired.selector, expiredDeadline, uint48(block.timestamp))
        );
        vm.prank(owner);
        permit3.permit(owner, SALT, expiredDeadline, timestamp, permitProof, signature);
    }
}
