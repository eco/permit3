# Permit3 Test Suite

This directory contains the test suite for the Permit3 contract system. The test files have been organized to reduce duplication and improve maintainability.

## Test Organization

### Core Component Tests

- **NonceManagerTest.sol**: Tests for nonce management functionality
- **PermitBaseTest.sol**: Tests for basic permit functionality (allowances, transfers)
- **Permit3Test.sol**: Tests for the main Permit3 functionality

### Specialized Tests

- **UnhingedMerkleTreeTest.sol**: Tests for the Unhinged Merkle Tree functionality
- **EIP712.t.sol**: Tests for EIP712 signature verification

### Test Infrastructure

- **utils/ConsolidatedTestBase.sol**: Base test contract with common setup and helper methods
- **utils/TestUtils.sol**: Shared utility functions for testing

## Running Tests

```bash
# Run all tests
forge test

# Run a specific test file
forge test --match-contract NonceManagerTest

# Run a specific test
forge test --match-test test_permitTransferFrom

# Run tests with gas reporting
forge test --gas-report
```

## Test Design

1. **Base Test Contract**: Almost all tests inherit from `ConsolidatedTestBase`, which provides common:
   - Setup for the Permit3 contract
   - Test accounts
   - Helper functions for signing
   - Utility functions for specific test scenarios

2. **Test Structure**: Each test file focuses on a specific component:
   - Simple tests that verify basic functionality
   - More complex tests that cover edge cases
   - Tests for specific failure modes

3. **Helper Functions**: Common operations are abstracted into helper functions to avoid duplication.

## Consolidation Strategy

The test suite was consolidated using the following principles:

1. **Avoid Duplication**: Tests that covered the same functionality were merged
2. **Consistent Base**: A standardized test base class provides common functionality
3. **Feature-Based Organization**: Tests are organized around features, not contract structure
4. **Clear Naming**: Test names clearly indicate the functionality being tested

This consolidation has resulted in a more maintainable test suite with improved organization.