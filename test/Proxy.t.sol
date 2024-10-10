// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

import "forge-std/Test.sol";
import "core/Proxy.sol";
import "core/Singleton.sol";

contract MockContract is Singleton {
    uint256 private value;

    function setValue(uint256 _value) public {
        value = _value;
    }

    function getValue() public view returns (uint256) {
        return value;
    }
}

contract MockCallback is IProxyCreationCallback {
    Proxy public lastCreatedProxy;
    address public lastSingleton;
    bytes public lastInitializer;
    uint256 public lastSaltNonce;

    function proxyCreated(Proxy proxy, address _singleton, bytes calldata initializer, uint256 saltNonce) external override {
        lastCreatedProxy = proxy;
        lastSingleton = _singleton;
        lastInitializer = initializer;
        lastSaltNonce = saltNonce;
    }
}

contract ProxyTest is Test {
    ProxyFactory factory;
    MockContract mockContract;
    MockCallback mockCallback;

    event ProxyCreation(Proxy proxy, address singleton);

    function setUp() public {
        mockContract = new MockContract();
        factory = new ProxyFactory();
        mockCallback = new MockCallback();
    }

    function testProxyConstructor() public {
        Proxy proxy = new Proxy(address(mockContract));
        assertEq(IProxy(address(proxy)).masterCopy(), address(mockContract));
    }

    function testProxyFallback() public {
        Proxy proxy = factory.createProxy(address(mockContract), "");
        assertEq(IProxy(address(proxy)).masterCopy(), address(mockContract));
        MockContract(address(proxy)).setValue(42);
        MockContract singltone = MockContract(address(proxy));
        assertEq(singltone.getValue(), 42);
    }

    function testCreateProxy() public {
        Proxy newProxy = factory.createProxy(address(mockContract), "");
        assertEq(IProxy(address(newProxy)).masterCopy(), address(mockContract));
    }

    function testCreateProxyWithInitializer() public {
        bytes memory initializerData = abi.encodeWithSignature("setValue(uint256)", 42);
        Proxy newProxy = factory.createProxy(address(mockContract), initializerData);
        assertEq(MockContract(address(newProxy)).getValue(), 42);
    }

    function testCreateProxyWithNonce() public {
        bytes memory initializerData = abi.encodeWithSignature("setValue(uint256)", 42);
        Proxy newProxy = factory.createProxyWithNonce(address(mockContract), initializerData, 0);
        assertEq(MockContract(address(newProxy)).getValue(), 42);
    }

    function testCreateProxyWithCallback() public {
        bytes memory initializerData = abi.encodeWithSignature("setValue(uint256)", 42);
        Proxy newProxy = factory.createProxyWithCallback(address(mockContract), initializerData, 0, mockCallback);

        assertEq(MockContract(address(newProxy)).getValue(), 42);
        assertEq(address(mockCallback.lastCreatedProxy()), address(newProxy));
        assertEq(mockCallback.lastSingleton(), address(mockContract));
        assertEq(mockCallback.lastInitializer(), initializerData);
        assertEq(mockCallback.lastSaltNonce(), 0);
    }

    function testProxyRuntimeCode() public {
        bytes memory runtimeCode = factory.proxyRuntimeCode();
        assertEq(runtimeCode, type(Proxy).runtimeCode);
    }

    function testProxyCreationCode() public {
        bytes memory creationCode = factory.proxyCreationCode();
        assertEq(creationCode, type(Proxy).creationCode);
    }
}
