// SPDX-License-Identifier: UNLICENSED

// solhint-disable func-name-mixedcase
// solhint-disable var-name-mixedcase
// solhint-disable no-empty-blocks
// solhint-disable no-console

pragma solidity >=0.8.19;

import { console2 } from "forge-std/console2.sol";

import { SafeMath } from "openzeppelin-contracts/utils/math/SafeMath.sol";

import { Test } from "forge-std/Test.sol";
import { TgToken } from "core/lst/liquidtoken/TgToken.sol";
import { TestHelpers, AddressSet, LibAddressSet } from "test/helpers/Helpers.sol";

contract TestTgToken is TgToken {
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

    TestTgToken public tgtoken;
    uint256 public ghost_mintedSum;
    uint256 public ghost_burnedSum;
    uint256 public TOTAL_UNDERLYING_SUPPLY = sqrt(type(uint256).max - 1);
    uint256 public ghost_notLiquifiedSupply = TOTAL_UNDERLYING_SUPPLY;

    AddressSet internal holders;
    AddressSet internal actors;
    address internal currentActor;
    mapping(bytes32 => uint256) public calls;

    constructor(TestTgToken _tgtoken) {
        tgtoken = _tgtoken;
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
        if (ghost_notLiquifiedSupply == 0) {
            return;
        }
        createActor();

        amount = bound(amount, 1, ghost_notLiquifiedSupply);

        // Ignore cases where x * y overflows or denominator is 0
        unchecked {
            uint256 denominator = tgtoken.totalSupply();
            uint256 y = tgtoken.totalShares();
            uint256 x = amount;

            if (denominator == 0 || (x != 0 && (x * y) / x != y)) {
                return;
            }
        }

        if (tgtoken.convertToShares(amount) == 0) {
            return;
        }

        (bool success,) = SafeMath.tryAdd(tgtoken.totalShares(), tgtoken.convertToShares(amount));
        if (success == false) {
            return;
        }

        ghost_notLiquifiedSupply -= amount;
        ghost_mintedSum += amount;

        tgtoken.mint(currentActor, amount);
        holders.add(currentActor);
    }

    function transfer(uint256 actorSeed, address to, uint256 amount) public useActor(actorSeed) countCall("transfer") {
        // Ignore cases where x * y overflows or denominator is 0
        unchecked {
            uint256 y = tgtoken.totalSupply();
            uint256 denominator = tgtoken.totalShares();
            uint256 x = tgtoken.shares(currentActor);

            if (denominator == 0 || (x != 0 && (x * y) / x != y)) {
                return;
            }
        }
        if (tgtoken.balanceOf(currentActor) == 0) {
            return;
        }
        amount = bound(amount, 1, tgtoken.balanceOf(currentActor));

        vm.startPrank(currentActor);
        tgtoken.transfer(to, amount);
        holders.add(to);
        vm.stopPrank();
    }

    function approve(uint256 actorSeed, address spender, uint256 amount) public useActor(actorSeed) countCall("approve") {
        vm.startPrank(currentActor);
        tgtoken.approve(spender, amount);
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
            uint256 y = tgtoken.totalSupply();
            uint256 denominator = tgtoken.totalShares();
            uint256 x = tgtoken.shares(from);

            if (denominator == 0 || (x != 0 && (x * y) / x != y)) {
                return;
            }
        }

        if (tgtoken.balanceOf(from) == 0) {
            return;
        }

        uint256 allowance = tgtoken.allowance(from, currentActor);
        if (allowance == 0) {
            return;
        }

        amount = bound(amount, 1, allowance);

        vm.startPrank(currentActor);
        tgtoken.transferFrom(from, to, amount);
        holders.add(to);
        vm.stopPrank();
    }

    function burn(uint256 actorSeed, uint256 amount) public useActor(actorSeed) countCall("burn") {
        // Ignore cases where x * y overflows or denominator is 0
        unchecked {
            uint256 y = tgtoken.totalSupply();
            uint256 denominator = tgtoken.totalShares();
            uint256 x = tgtoken.shares(currentActor);

            if (denominator == 0 || (x != 0 && (x * y) / x != y)) {
                return;
            }
        }

        if (tgtoken.balanceOf(currentActor) == 0) {
            return;
        }
        amount = bound(amount, 1, tgtoken.balanceOf(currentActor));

        if (tgtoken.convertToShares(amount) == 0) {
            return;
        }

        (bool success,) = SafeMath.trySub(tgtoken.totalShares(), tgtoken.convertToShares(amount));
        if (success == false) {
            return;
        }

        ghost_burnedSum += amount;
        ghost_notLiquifiedSupply += amount;
        tgtoken.burn(currentActor, amount);
    }

    function setTotalSupply(uint256 totalSupply) public countCall("setTotalSupply") {
        totalSupply = bound(totalSupply, 1, TOTAL_UNDERLYING_SUPPLY);
        tgtoken.setTotalSupply(totalSupply);
        ghost_notLiquifiedSupply = TOTAL_UNDERLYING_SUPPLY - totalSupply;
    }
}

contract TgTokenInvariants is Test {
    Handler public handler;
    TestTgToken public tgtoken;

    function setUp() public {
        tgtoken = new TestTgToken();
        handler = new Handler(tgtoken);

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
        excludeSender(address(tgtoken));
        excludeSender(address(handler));
        excludeSender(address(this));
    }

    // total supply should equal  underlying - notLiquified
    function invariant_underlyingSubNotLiquified() public {
        assertEq(tgtoken.totalSupply(), handler.TOTAL_UNDERLYING_SUPPLY() - handler.ghost_notLiquifiedSupply());
    }

    // sum of holder balances should equal total supply
    function invariant_holderShares() public {
        uint256 sum = 0;
        address[] memory holders = handler.getHolders();
        for (uint256 i = 0; i < holders.length; i++) {
            sum += tgtoken.shares(holders[i]);
        }
        assertEq(tgtoken.totalShares(), sum);
    }

    function invariant_callSummary() public view {
        handler.callSummary();
    }
}
