// SPDX-License-Identifier: UNLICENSED

// solhint-disable func-name-mixedcase
// solhint-disable var-name-mixedcase
// solhint-disable no-empty-blocks
// solhint-disable no-console

pragma solidity >=0.8.19;

import { console2 } from "forge-std/console2.sol";

import { SafeMath } from "openzeppelin-contracts/utils/math/SafeMath.sol";

import { Test } from "forge-std/Test.sol";
import { TToken } from "core/lst/tendertoken/TToken.sol";
import { TestHelpers, AddressSet, LibAddressSet } from "test/helpers/Helpers.sol";

contract TestTToken is TToken {
    function name() public view override returns (string memory) { }

    function symbol() public view override returns (string memory) { }

    function burn(address from, uint256 amount) public {
        _burn(from, amount);
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

    function totalShares() public view returns (uint256) {
        Storage storage $ = _loadStorage();
        return $._totalShares;
    }

    function shares(address owner) public view returns (uint256) {
        Storage storage $ = _loadStorage();
        return $.shares[owner];
    }

    function setTotalSupply(uint256 amount) public {
        _setTotalSupply(amount);
    }
}

contract Handler is Test, TestHelpers {
    using LibAddressSet for AddressSet;

    TestTToken public ttoken;
    uint256 public ghost_mintedSum;
    uint256 public ghost_burnedSum;
    uint256 public TOTAL_UNDERLYING_SUPPLY = sqrt(type(uint256).max - 1);
    uint256 public ghost_notTenderizedSupply = TOTAL_UNDERLYING_SUPPLY;

    AddressSet internal holders;
    AddressSet internal actors;
    address internal currentActor;
    mapping(bytes32 => uint256) public calls;

    constructor(TestTToken _ttoken) {
        ttoken = _ttoken;
    }

    modifier countCall(bytes32 key) {
        calls[key]++;
        _;
    }

    modifier useActor(uint256 actorIndexSeed) {
        currentActor = actors.rand(actorIndexSeed);
        _;
    }

    function getHolders() public view returns (address[] memory) {
        return holders.addrs;
    }

    function createActor() public {
        currentActor = msg.sender;
        actors.add(msg.sender);
    }

    function callSummary() public view {
        console2.log("Call summary:");
        console2.log("-------------------");
        console2.log("mint", calls["mint"]);
        console2.log("burn", calls["burn"]);
        console2.log("transfer", calls["transfer"]);
        console2.log("approve", calls["approve"]);
        console2.log("transferFrom", calls["transferFrom"]);
        console2.log("setTotalSupply", calls["setTotalSupply"]);
    }

    function mint(uint256 amount) public countCall("mint") {
        if (ghost_notTenderizedSupply == 0) {
            return;
        }
        createActor();

        amount = bound(amount, 1, ghost_notTenderizedSupply);

        // Ignore cases where x * y overflows or denominator is 0
        unchecked {
            uint256 denominator = ttoken.totalSupply();
            uint256 y = ttoken.totalShares();
            uint256 x = amount;

            if (denominator == 0 || (x != 0 && (x * y) / x != y)) {
                return;
            }
        }

        if (ttoken.convertToShares(amount) == 0) {
            return;
        }

        (bool success,) = SafeMath.tryAdd(ttoken.totalShares(), ttoken.convertToShares(amount));
        if (success == false) {
            return;
        }

        ghost_notTenderizedSupply -= amount;
        ghost_mintedSum += amount;

        ttoken.mint(currentActor, amount);
        holders.add(currentActor);
    }

    function transfer(uint256 actorSeed, address to, uint256 amount) public useActor(actorSeed) countCall("transfer") {
        // Ignore cases where x * y overflows or denominator is 0
        unchecked {
            uint256 y = ttoken.totalSupply();
            uint256 denominator = ttoken.totalShares();
            uint256 x = ttoken.shares(currentActor);

            if (denominator == 0 || (x != 0 && (x * y) / x != y)) {
                return;
            }
        }
        if (ttoken.balanceOf(currentActor) == 0) {
            return;
        }
        amount = bound(amount, 1, ttoken.balanceOf(currentActor));

        vm.startPrank(currentActor);
        ttoken.transfer(to, amount);
        holders.add(to);
        vm.stopPrank();
    }

    function approve(uint256 actorSeed, address spender, uint256 amount) public useActor(actorSeed) countCall("approve") {
        vm.startPrank(currentActor);
        ttoken.approve(spender, amount);
        vm.stopPrank();
    }

    function transferFrom(
        uint256 actorSeed,
        address from,
        address to,
        uint256 amount
    )
        public
        useActor(actorSeed)
        countCall("transferFrom")
    {
        // Ignore cases where x * y overflows or denominator is 0
        unchecked {
            uint256 y = ttoken.totalSupply();
            uint256 denominator = ttoken.totalShares();
            uint256 x = ttoken.shares(from);

            if (denominator == 0 || (x != 0 && (x * y) / x != y)) {
                return;
            }
        }

        if (ttoken.balanceOf(from) == 0) {
            return;
        }

        uint256 allowance = ttoken.allowance(from, currentActor);
        if (allowance == 0) {
            return;
        }

        amount = bound(amount, 1, allowance);

        vm.startPrank(currentActor);
        ttoken.transferFrom(from, to, amount);
        holders.add(to);
        vm.stopPrank();
    }

    function burn(uint256 actorSeed, uint256 amount) public useActor(actorSeed) countCall("burn") {
        // Ignore cases where x * y overflows or denominator is 0
        unchecked {
            uint256 y = ttoken.totalSupply();
            uint256 denominator = ttoken.totalShares();
            uint256 x = ttoken.shares(currentActor);

            if (denominator == 0 || (x != 0 && (x * y) / x != y)) {
                return;
            }
        }

        if (ttoken.balanceOf(currentActor) == 0) {
            return;
        }
        amount = bound(amount, 1, ttoken.balanceOf(currentActor));

        if (ttoken.convertToShares(amount) == 0) {
            return;
        }

        (bool success,) = SafeMath.trySub(ttoken.totalShares(), ttoken.convertToShares(amount));
        if (success == false) {
            return;
        }

        ghost_burnedSum += amount;
        ghost_notTenderizedSupply += amount;
        ttoken.burn(currentActor, amount);
    }

    function setTotalSupply(uint256 totalSupply) public countCall("setTotalSupply") {
        totalSupply = bound(totalSupply, 1, TOTAL_UNDERLYING_SUPPLY);
        ttoken.setTotalSupply(totalSupply);
        ghost_notTenderizedSupply = TOTAL_UNDERLYING_SUPPLY - totalSupply;
    }
}

contract TTokenInvariants is Test {
    Handler public handler;
    TestTToken public ttoken;

    function setUp() public {
        ttoken = new TestTToken();
        handler = new Handler(ttoken);

        bytes4[] memory selectors = new bytes4[](6);
        selectors[0] = Handler.mint.selector;
        selectors[1] = Handler.burn.selector;
        selectors[2] = Handler.transfer.selector;
        selectors[3] = Handler.approve.selector;
        selectors[4] = Handler.transferFrom.selector;
        selectors[5] = Handler.setTotalSupply.selector;

        targetSelector(FuzzSelector({ addr: address(handler), selectors: selectors }));
        targetContract(address(handler));

        // these excludes are needed because there's a bug when using contract addresses as senders
        // https://github.com/foundry-rs/foundry/issues/4163
        // https://github.com/foundry-rs/foundry/issues/3879
        excludeSender(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        excludeSender(0x4e59b44847b379578588920cA78FbF26c0B4956C);
        excludeSender(address(ttoken));
        excludeSender(address(handler));
        excludeSender(address(this));
    }

    // total supply should equal  underlying - notTenderized
    function invariant_underlyingSubNotTenderized() public {
        assertEq(ttoken.totalSupply(), handler.TOTAL_UNDERLYING_SUPPLY() - handler.ghost_notTenderizedSupply());
    }

    // sum of holder balances should equal total supply
    function invariant_holderShares() public {
        uint256 sum = 0;
        address[] memory holders = handler.getHolders();
        for (uint256 i = 0; i < holders.length; i++) {
            sum += ttoken.shares(holders[i]);
        }
        assertEq(ttoken.totalShares(), sum);
    }

    function invariant_callSummary() public view {
        handler.callSummary();
    }
}
