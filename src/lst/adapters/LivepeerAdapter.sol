// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.19;

uint256 constant VERSION = 1;

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";

import { Adapter } from "core/lst/adapters/Adapter.sol";
import { ILivepeerBondingManager, ILivepeerRoundsManager } from "core/lst/adapters/interfaces/ILivepeer.sol";
import { ISwapRouter } from "core/lst/adapters/interfaces/ISwapRouter.sol";
import { IWETH9 } from "core/lst/adapters/interfaces/IWETH9.sol";
import { IERC165 } from "core/lst/interfaces/IERC165.sol";
import { TWAP } from "core/lst/utils/TWAP.sol";

ILivepeerBondingManager constant LIVEPEER_BONDING = ILivepeerBondingManager(0x35Bcf3c30594191d53231E4FF333E8A770453e40);
ILivepeerRoundsManager constant LIVEPEER_ROUNDS = ILivepeerRoundsManager(0xdd6f56DcC28D3F5f27084381fE8Df634985cc39f);
ERC20 constant LPT = ERC20(0x289ba1701C2F088cf0faf8B3705246331cB8A839);
IWETH9 constant WETH = IWETH9(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
ISwapRouter constant UNISWAP_ROUTER = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
address constant UNI_POOL = 0x4fD47e5102DFBF95541F64ED6FE13d4eD26D2546;
uint24 constant UNISWAP_POOL_FEE = 3000;
uint256 constant ETH_THRESHOLD = 1e16; // 0.01 ETH
uint32 constant TWAP_INTERVAL = 36_000;

contract LivepeerAdapter is Adapter {
    using SafeTransferLib for ERC20;

    struct Storage {
        uint256 lastRebaseRound;
    }

    uint256 private constant STORAGE = uint256(keccak256("xyz.liquifier.livepeer.adapter.storage.location")) - 1;

    function _loadStorage() internal pure returns (Storage storage $) {
        uint256 slot = STORAGE;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            $.slot := slot
        }
    }

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(Adapter).interfaceId || interfaceId == type(IERC165).interfaceId;
    }

    function previewDeposit(address, /*validator*/ uint256 assets) external pure returns (uint256) {
        return assets;
    }

    function previewWithdraw(uint256 unlockID) external view returns (uint256 amount) {
        (amount,) = LIVEPEER_BONDING.getDelegatorUnbondingLock(address(this), unlockID);
    }

    function unlockMaturity(uint256 unlockID) external view returns (uint256 maturity) {
        // calculate unlock maturity in block number
        // in Livepeer this is expressed in rounds with a fixed amount of blocks
        // roundLength = n
        // currentRound = r
        // withdrawRound = w
        // blocksRemainingInCurrentRound = b = roundLength - (block.number - currentRoundStartBlock)
        // maturity = n*(w - r - 1) + b
        (, uint256 withdrawRound) = LIVEPEER_BONDING.getDelegatorUnbondingLock(address(this), unlockID);
        uint256 currentRound = LIVEPEER_ROUNDS.currentRound();
        uint256 roundLength = LIVEPEER_ROUNDS.roundLength();
        uint256 currentRoundStartBlock = LIVEPEER_ROUNDS.currentRoundStartBlock();
        uint256 blocksRemainingInCurrentRound = roundLength - (block.number - currentRoundStartBlock);
        if (withdrawRound > currentRound) {
            maturity = block.number + roundLength * (withdrawRound - currentRound - 1) + blocksRemainingInCurrentRound;
        }
    }

    function unlockTime() external view override returns (uint256) {
        return LIVEPEER_ROUNDS.roundLength() * LIVEPEER_BONDING.unbondingPeriod();
    }

    function currentTime() external view override returns (uint256) {
        return block.number;
    }

    function stake(address validator, uint256 amount) public returns (uint256) {
        LPT.safeApprove(address(LIVEPEER_BONDING), amount);
        LIVEPEER_BONDING.bond(amount, validator);
        return amount;
    }

    function unstake(address, /*validator*/ uint256 amount) external returns (uint256 unlockID) {
        // returns the *next* Livepeer unbonding lock ID for the delegator
        // this will be the `unlockID` after calling unbond
        (,,,,,, unlockID) = LIVEPEER_BONDING.getDelegator(address(this));
        LIVEPEER_BONDING.unbond(amount);
    }

    function withdraw(address, /*validator*/ uint256 unlockID) external returns (uint256 amount) {
        (amount,) = LIVEPEER_BONDING.getDelegatorUnbondingLock(address(this), unlockID);
        LIVEPEER_BONDING.withdrawStake(unlockID);
    }

    function rebase(address validator, uint256 currentStake) external returns (uint256 newStake) {
        uint256 currentRound = LIVEPEER_ROUNDS.currentRound();

        Storage storage $ = _loadStorage();
        if ($.lastRebaseRound == currentRound) {
            return currentStake;
        }

        $.lastRebaseRound = currentRound;

        _livepeerClaimFees();

        // restake
        uint256 amount = LPT.balanceOf(address(this));
        if (amount != 0) {
            stake(validator, amount);
        }

        // Read new stake
        newStake = LIVEPEER_BONDING.pendingStake(address(this), 0);
    }

    function isValidator(address validator) public view override returns (bool) {
        return LIVEPEER_BONDING.isRegisteredTranscoder(validator);
    }

    /// @notice function for swapping ETH fees to LPT
    function _livepeerClaimFees() internal {
        // get pending fees
        uint256 pendingFees;
        if ((pendingFees = LIVEPEER_BONDING.pendingFees(address(this), 0)) < ETH_THRESHOLD) return;

        if (!LIVEPEER_ROUNDS.currentRoundInitialized()) return;

        // withdraw fees
        LIVEPEER_BONDING.withdrawFees(payable(address(this)), pendingFees);
        // get ETH balance
        uint256 ethBalance = address(this).balance;
        // convert fees to WETH
        WETH.deposit{ value: ethBalance }();
        ERC20(address(WETH)).safeApprove(address(UNISWAP_ROUTER), ethBalance);
        // Calculate Slippage Threshold
        uint160 sqrtPriceLimitX96 = TWAP.getSqrtTwapX96(UNI_POOL, TWAP_INTERVAL);
        uint256 twapPrice = TWAP.getInversePriceX96(TWAP.getPriceX96(sqrtPriceLimitX96));
        uint256 amountOut = ethBalance * twapPrice >> 96;
        // Create initial params for swap
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: address(WETH),
            tokenOut: address(address(LPT)),
            fee: UNISWAP_POOL_FEE,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: ethBalance,
            amountOutMinimum: amountOut * 897 / 1000, // 10% slippage threshold + 0.3% fee
            sqrtPriceLimitX96: 0
        });

        // execute swap
        UNISWAP_ROUTER.exactInputSingle(params);
    }
}
