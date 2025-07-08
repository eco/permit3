// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Permit3ApproverModule } from "../../src/modules/Permit3ApproverModule.sol";
import { IERC7579Module } from "../../src/modules/interfaces/IERC7579Module.sol";
import { IExecutorModule } from "../../src/modules/interfaces/IExecutorModule.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { Test } from "forge-std/Test.sol";

contract MockERC20 is IERC20 {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    uint256 public totalSupply;

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }
}

contract MockSmartAccount {
    mapping(address => bool) public installedModules;

    function installModule(uint256 moduleType, address module, bytes calldata data) external {
        installedModules[module] = true;
        IERC7579Module(module).onInstall(data);
    }

    function uninstallModule(uint256 moduleType, address module, bytes calldata data) external {
        installedModules[module] = false;
        IERC7579Module(module).onUninstall(data);
    }

    function executeFromExecutor(address executor, bytes calldata data) external {
        require(installedModules[executor], "Module not installed");
        // Get executions from the module
        IExecutorModule.Execution[] memory executions = IExecutorModule(executor).execute(address(this), data);

        // Execute each call
        for (uint256 i = 0; i < executions.length; i++) {
            (bool success,) = executions[i].target.call{ value: executions[i].value }(executions[i].data);
            require(success, "Execution failed");
        }
    }
}

contract Permit3ApproverModuleTest is Test {
    Permit3ApproverModule public module;
    MockSmartAccount public smartAccount;
    MockERC20 public token1;
    MockERC20 public token2;
    address public constant PERMIT3 = address(0x000000000022D473030F116dDEE9F6B43aC78BA3);

    function setUp() public {
        module = new Permit3ApproverModule(PERMIT3);
        smartAccount = new MockSmartAccount();
        token1 = new MockERC20();
        token2 = new MockERC20();
    }

    function testModuleConstants() public {
        assertEq(module.MODULE_TYPE(), 2);
        assertEq(module.NAME(), "Permit3ApproverModule");
        assertEq(module.VERSION(), "1.0.0");
        assertEq(module.PERMIT3(), PERMIT3);
    }

    function testModuleType() public {
        assertTrue(module.isModuleType(2)); // Executor type
        assertFalse(module.isModuleType(1)); // Not validator
        assertFalse(module.isModuleType(3)); // Not hook
        assertFalse(module.isModuleType(4)); // Not fallback
    }

    function testSupportsInterface() public {
        assertTrue(module.supportsInterface(type(IERC7579Module).interfaceId));
        assertTrue(module.supportsInterface(type(IExecutorModule).interfaceId));
    }

    function testInstallModule() public {
        smartAccount.installModule(2, address(module), "");
        assertTrue(smartAccount.installedModules(address(module)));
        assertTrue(module.isInitialized(address(smartAccount)));
    }

    function testUninstallModule() public {
        smartAccount.installModule(2, address(module), "");
        smartAccount.uninstallModule(2, address(module), "");
        assertFalse(smartAccount.installedModules(address(module)));
    }

    function testExecuteApprovals() public {
        // Install module
        smartAccount.installModule(2, address(module), "");

        // Prepare tokens to approve
        address[] memory tokens = new address[](2);
        tokens[0] = address(token1);
        tokens[1] = address(token2);

        // Get execution data
        bytes memory execData = module.getExecutionData(tokens);

        // Execute through smart account
        smartAccount.executeFromExecutor(address(module), execData);

        // Check approvals
        assertEq(token1.allowance(address(smartAccount), PERMIT3), type(uint256).max);
        assertEq(token2.allowance(address(smartAccount), PERMIT3), type(uint256).max);
    }

    function testExecuteView() public {
        address[] memory tokens = new address[](2);
        tokens[0] = address(token1);
        tokens[1] = address(token2);
        bytes memory execData = abi.encode(tokens);

        // Call execute to get the executions
        IExecutorModule.Execution[] memory executions = module.execute(address(smartAccount), execData);

        // Verify executions
        assertEq(executions.length, 2);
        assertEq(executions[0].target, address(token1));
        assertEq(executions[0].value, 0);
        assertEq(executions[1].target, address(token2));
        assertEq(executions[1].value, 0);
    }

    function testExecuteNoTokens() public {
        smartAccount.installModule(2, address(module), "");

        address[] memory tokens = new address[](0);
        bytes memory execData = abi.encode(tokens);

        vm.expectRevert(Permit3ApproverModule.NoTokensProvided.selector);
        smartAccount.executeFromExecutor(address(module), execData);
    }

    function testExecuteZeroAddressToken() public {
        smartAccount.installModule(2, address(module), "");

        address[] memory tokens = new address[](2);
        tokens[0] = address(token1);
        tokens[1] = address(0);
        bytes memory execData = abi.encode(tokens);

        vm.expectRevert(abi.encodeWithSelector(Permit3ApproverModule.ZeroAddress.selector, "token"));
        smartAccount.executeFromExecutor(address(module), execData);
    }

    function testConstructorZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(Permit3ApproverModule.ZeroAddress.selector, "permit3"));
        new Permit3ApproverModule(address(0));
    }

    function testGetExecutionData() public {
        address[] memory tokens = new address[](3);
        tokens[0] = address(0x1);
        tokens[1] = address(0x2);
        tokens[2] = address(0x3);

        bytes memory data = module.getExecutionData(tokens);
        address[] memory decoded = abi.decode(data, (address[]));

        assertEq(decoded.length, 3);
        assertEq(decoded[0], address(0x1));
        assertEq(decoded[1], address(0x2));
        assertEq(decoded[2], address(0x3));
    }
}
