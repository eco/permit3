// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "forge-std/Test.sol";

import { EIP712 } from "../src/lib/EIP712.sol";

// Test contract for EIP712 functionality
contract EIP712TestContract is EIP712 {
    constructor(
        string memory name,
        string memory version
    ) EIP712(name, version) { }

    // Expose internal methods for testing
    function domainSeparatorV4() external view returns (bytes32) {
        return _domainSeparatorV4();
    }

    function hashTypedDataV4(
        bytes32 structHash
    ) external view returns (bytes32) {
        return _hashTypedDataV4(structHash);
    }

    function eip712Name() external view returns (string memory) {
        return _EIP712Name();
    }

    function eip712Version() external view returns (string memory) {
        return _EIP712Version();
    }
}

// Proxy that runs the implementation's code in its own context (delegatecall), so address(this) != _cachedThis
// inside _domainSeparatorV4 and the separator is rebuilt for the proxy's address
contract EIP712Proxy {
    EIP712TestContract private immutable _implementation;

    constructor(
        EIP712TestContract implementation
    ) {
        _implementation = implementation;
    }

    fallback() external {
        address impl = address(_implementation);
        assembly {
            // Copy calldata to memory
            calldatacopy(0, 0, calldatasize())
            // Run the implementation's code in this contract's context
            let success := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            // Copy returndata to memory
            returndatacopy(0, 0, returndatasize())
            // Revert or return
            switch success
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
}

/**
 * @title EIP712Test
 * @notice Comprehensive test suite for the EIP712 library
 */
contract EIP712Test is Test {
    EIP712TestContract eip712;
    EIP712TestContract eip712LongName;

    function setUp() public {
        // Create an instance with short name/version (fits in ShortString)
        eip712 = new EIP712TestContract("Test", "1");

        // Create an instance with long name/version (requires fallback storage)
        string memory longName =
            "This is a very long name that exceeds the ShortString limit and will require fallback storage in the contract implementation";
        string memory longVersion =
            "1.0.0-alpha+ThisIsAVeryLongVersionStringThatExceedsTheShortStringLimitAndWillRequireFallbackStorage";
        eip712LongName = new EIP712TestContract(longName, longVersion);
    }

    function test_domainSeparator() public view {
        bytes32 domainSeparator = eip712.domainSeparatorV4();

        // Calculate the expected domain separator
        bytes32 expectedDomainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("Test")), // Name
                keccak256(bytes("1")), // Version
                uint256(1), // CROSS_CHAIN_ID constant (1) used in EIP712.sol
                address(eip712)
            )
        );

        assertEq(domainSeparator, expectedDomainSeparator);
    }

    function test_hashTypedDataV4() public view {
        bytes32 structHash = keccak256(abi.encode(keccak256("Test(uint256 value)"), uint256(123)));
        bytes32 digest = eip712.hashTypedDataV4(structHash);

        bytes32 expectedDigest = keccak256(abi.encodePacked("\x19\x01", eip712.domainSeparatorV4(), structHash));

        assertEq(digest, expectedDigest);
    }

    function test_eip712Domain() public view {
        // Call the eip712Domain function to test it
        (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt,
            uint256[] memory extensions
        ) = eip712.eip712Domain();

        // Verify the results
        assertEq(fields, hex"0f"); // 01111 - indicates which fields are set
        assertEq(name, "Test");
        assertEq(version, "1");
        assertEq(chainId, 1); // CROSS_CHAIN_ID
        assertEq(verifyingContract, address(eip712));
        assertEq(salt, bytes32(0));
        assertEq(extensions.length, 0);
    }

    function test_longNameFallback() public view {
        string memory longName =
            "This is a very long name that exceeds the ShortString limit and will require fallback storage in the contract implementation";

        // Call the eip712Domain function
        (, string memory returnedName, string memory returnedVersion,,,,) = eip712LongName.eip712Domain();

        // Verify returned name and version use fallback
        assertEq(returnedName, longName);
        assertEq(
            returnedVersion,
            "1.0.0-alpha+ThisIsAVeryLongVersionStringThatExceedsTheShortStringLimitAndWillRequireFallbackStorage"
        );
    }

    function test_directEIP712Name() public view {
        string memory name = eip712.eip712Name();
        assertEq(name, "Test");

        string memory longName = eip712LongName.eip712Name();
        assertEq(
            longName,
            "This is a very long name that exceeds the ShortString limit and will require fallback storage in the contract implementation"
        );
    }

    function test_directEIP712Version() public view {
        string memory version = eip712.eip712Version();
        assertEq(version, "1");

        string memory longVersion = eip712LongName.eip712Version();
        assertEq(
            longVersion,
            "1.0.0-alpha+ThisIsAVeryLongVersionStringThatExceedsTheShortStringLimitAndWillRequireFallbackStorage"
        );
    }

    function test_buildDomainSeparatorWithDifferentAddress() public {
        // Create a test contract with a different address to trigger the "else" branch
        // in _domainSeparatorV4
        vm.startPrank(address(0x1234));
        EIP712TestContract differentAddress = new EIP712TestContract("Test", "1");
        vm.stopPrank();

        bytes32 domainSeparator = differentAddress.domainSeparatorV4();

        // Calculate the expected domain separator for the different address
        bytes32 expectedDomainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("Test")), // Name
                keccak256(bytes("1")), // Version
                uint256(1), // CROSS_CHAIN_ID constant (1) used in EIP712.sol
                address(differentAddress)
            )
        );

        assertEq(domainSeparator, expectedDomainSeparator);
    }

    function test_domainSeparatorThroughProxy() public {
        // Exercises the branch in _domainSeparatorV4() where address(this) != _cachedThis

        // Create original EIP712 instance
        EIP712TestContract impl = new EIP712TestContract("TestDomain", "1");

        // Get domain separator directly from implementation (uses cached separator)
        bytes32 implSeparator = impl.domainSeparatorV4();

        // The proxy delegatecalls the implementation, so its code runs with address(this) == proxy
        EIP712Proxy proxy = new EIP712Proxy(impl);

        (bool success, bytes memory data) = address(proxy).staticcall(abi.encodeWithSignature("domainSeparatorV4()"));
        require(success, "Call failed");
        bytes32 proxySeparator = abi.decode(data, (bytes32));

        // The separator is rebuilt for the proxy's address, so it differs from the cached one
        bytes32 expectedProxySeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("TestDomain")),
                keccak256(bytes("1")),
                uint256(1), // CROSS_CHAIN_ID constant (1)
                address(proxy)
            )
        );
        assertEq(proxySeparator, expectedProxySeparator, "Rebuilt for the calling address");
        assertTrue(proxySeparator != implSeparator, "Differs from the cached separator");

        // hashTypedDataV4 through the proxy uses the rebuilt separator
        bytes32 testStruct = keccak256("test");
        (success, data) = address(proxy).staticcall(abi.encodeWithSignature("hashTypedDataV4(bytes32)", testStruct));
        require(success, "Call failed");
        bytes32 proxyHash = abi.decode(data, (bytes32));
        assertEq(proxyHash, keccak256(abi.encodePacked("\x19\x01", expectedProxySeparator, testStruct)));
    }

    function test_domainSeparatorIgnoresBlockChainId() public {
        bytes32 separator = eip712.domainSeparatorV4();

        // A different chain id (for example after a fork) does not change the separator
        vm.chainId(424_242);
        assertEq(eip712.domainSeparatorV4(), separator, "Separator does not depend on block.chainid");

        (,,, uint256 chainId,,,) = eip712.eip712Domain();
        assertEq(chainId, 1, "Domain chainId is CROSS_CHAIN_ID");
    }

    function test_cached_and_actual_domain_separators() public {
        // Create EIP712 test contract
        EIP712TestContract impl = new EIP712TestContract("TestDomain", "1");

        // This is a direct call where address(this) == _cachedThis
        bytes32 directSeparator = impl.domainSeparatorV4();

        // To verify that we're actually getting different values in different branches,
        // manually compute what we would expect in the non-cached branch
        bytes32 expectedDomainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("TestDomain")),
                keccak256(bytes("1")),
                uint256(1), // CROSS_CHAIN_ID constant (1)
                address(impl)
            )
        );

        // Both should be equal since the cached value should be correctly initialized
        assertEq(directSeparator, expectedDomainSeparator, "Computed domain separator should match expected");
    }
}
