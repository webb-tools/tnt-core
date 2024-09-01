// SPDX-License-Identifier: UNLICENSED

// I think we need to refactor the code so we dont have stake controller here but elsewhere, tbd 
// Stake controller is being used in the OperatorVCSUpgrade.sol and VaultControllerStrategyUpgrade 
// But it is coming back as 0x000 here. so it doesnt work

pragma solidity >=0.8.19;

uint256 constant VERSION = 1;

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";

import { Adapter } from "core/lst/adapters/Adapter.sol";
import { Staking } from "chainlink-staking/Staking.sol";
import { IERC165 } from "core/lst/interfaces/IERC165.sol";

import "core/lst/base/VaultControllerStrategyUpgrade.sol";

import { console2 } from "forge-std/Script.sol";

ERC20 constant LINK = ERC20(0x514910771AF9Ca656af840dff83E8264EcF986CA);
Staking constant stakeController = Staking(0x3feB1e09b4bb0E7f0387CeE092a52e85797ab889);

contract ChainlinkAdapter is Adapter, VaultControllerStrategyUpgrade {
    using SafeTransferLib for ERC20;

    // IVault[] internal vaults;
    uint256 private totalPrincipalDeposits;

    event VaultAdded(address indexed operator);
    event DepositBufferedTokens(uint256 depositedAmount);

    /* Stake.link doesn't use a constructor but upgradable contracts */
    /// @custom:oz-upgrades-unsafe-allow constructor
    // constructor() {
    //     _disableInitializers();
    // }

    // In our case, we'll want to use a construtor normally
    constructor() {
        console2.log("WE ARE CALLING THE NROMAL CONTSTRUCTOR");
        console2.log("staking contract");
        console2.log(address(stakeController));
        __VaultControllerStrategy_init(
            address(LINK),
            address(this), // 0xb8b295df2cd735b15BE5Eb419517Aa626fc43cD5, // _stakingPool,
            stakeController,
            _vaultImplementation,
            _minDepositThreshold,
            _fees
        );
    }

    struct Storage {
        uint256 lastRebaseTimestamp;
    }

    uint256 private constant STORAGE = uint256(keccak256("xyz.liquifier.chainlink.adapter.storage.location")) - 1;

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

    /*
     * Stake.link methods 
     * This is typically called as a deployUpgradable, 
     * so it won't be called in this case.
     * const communityVCS = await deployUpgradeable('CommunityVCS', [ args ... ])
     */
    // function initialize(
    //     address _token,
    //     address _stakingPool,
    //     address _stakeController,
    //     address _vaultImplementation,
    //     uint256 _minDepositThreshold,
    //     Fee[] memory _fees,
    //     address[] calldata _initialVaults
    // ) public initializer {
    //     __VaultControllerStrategy_init(
    //         _token,
    //         _stakingPool,
    //         _stakeController,
    //         _vaultImplementation,
    //         _minDepositThreshold,
    //         _fees
    //     );
    //     // Don't bother to set up inital vaults.
    // }

    /*
     * Liqufier methods 
     */

    function previewDeposit(address, /*validator*/ uint256 assets) external pure returns (uint256) {
        return assets;
    }

    function previewWithdraw(uint256) external view returns (uint256 amount) {
        // In Chainlink, we don't have individual unlock IDs. 
        // Instead, we'll return the total staked amount.
        return stakeController.getStake(address(this));
    }

    function unlockMaturity(uint256) external view returns (uint256 maturity) {
        // Chainlink doesn't have a concept of unlock maturity.
        // We'll return the current time plus the unbonding period.
        (, uint256 endTimestamp) = stakeController.getRewardTimestamps();
        return endTimestamp;
    }

    function unlockTime() external view override returns (uint256) {
        // Return the time left until the end of the staking period
        (, uint256 endTimestamp) = stakeController.getRewardTimestamps();
        return endTimestamp > block.timestamp ? endTimestamp - block.timestamp : 0;
    }

    function currentTime() external view override returns (uint256) {
        return block.timestamp;
    }


    /*
     * Stake.link methods 
     */

    /**
     * @notice returns the maximum that can be deposited into this strategy
     * @return maximum deposits
     */
    function getMaxDeposits() public view override returns (uint256) {
        (, uint256 vaultMaxDeposits) = getVaultDepositLimits();
        return totalDeposits + vaultMaxDeposits * vaults.length - (totalPrincipalDeposits + bufferedDeposits);
    }

    /**
     * @notice returns the minimum that must remain this strategy
     * @return minimum deposits
     */
    function getMinDeposits() public view override returns (uint256) {
        return totalDeposits;
    }

    /**
     * @notice returns the vault deposit limits
     * @return minimum amount of deposits that a vault can hold
     * @return maximum amount of deposits that a vault can hold
     */
    function getVaultDepositLimits() public view override returns (uint256, uint256) {
        return stakeController.getOperatorLimits();
    }

    /**
     * @notice deploys a new vault
     * @param _operator address of operator that the vault represents
     */
    // todo: this used to be external onlyOwner
    function addVault(address _operator) public {
        bytes memory data = abi.encodeWithSignature(
            "initialize(address,address,address,address)",
            address(token),
            address(this),
            address(stakeController),
            _operator
        );
        _deployVault(data);
        emit VaultAdded(_operator);
    }

    /**
     * @notice sets a vault's operator address
     * @param _index index of vault
     * @param _operator address of operator that the vault represents
     */
    function setOperator(uint256 _index, address _operator) external onlyOwner {
        vaults[_index].setOperator(_operator);
    }

    /**
     * @notice deposits buffered tokens into vaults
     * @param _startIndex index of first vault to deposit into
     * @param _toDeposit amount to deposit
     * @param _vaultMinDeposits minimum amount of deposits that a vault can hold
     * @param _vaultMaxDeposits minimum amount of deposits that a vault can hold
     */
    function _depositBufferedTokens(
        uint256 _startIndex,
        uint256 _toDeposit,
        uint256 _vaultMinDeposits,
        uint256 _vaultMaxDeposits
    ) internal override {
        uint256 deposited = _depositToVaults(_startIndex, _toDeposit, _vaultMinDeposits, _vaultMaxDeposits);
        totalPrincipalDeposits += deposited;
        bufferedDeposits -= deposited;
        emit DepositBufferedTokens(deposited);
    }

    /*
     * Liqufier methods 
     */

    function stake(address validator, uint256 amount) public returns (uint256) {
        // Maybe what we can do is check if the validator is a valid vault 
        // If so use that else deploy a new one? 

        // First deploy a vault.
        addVault(msg.sender);
        IVault vault = vaults[vaults.length - 1];
        
        // Then deposit and stake
        LINK.safeApprove(address(vault), amount);
        vault.deposit(amount); // this calls transferAndCall(...)
        // return amount;
    }

    function unstake(address, /*validator*/ uint256 amount) external returns (uint256) {
        // Chainlink doesn't support partial unstaking, so we ignore the amount
        // and unstake everything
        stakeController.unstake();
        return stakeController.getStake(address(this));
    }

    function withdraw(address, /*validator*/ uint256) external returns (uint256 amount) {
        // Chainlink automatically withdraws when unstaking, so this function is empty
        return 0;
    }

    function rebase(address validator, uint256 currentStake) external returns (uint256 newStake) {
        console2.log("What is my chainlink staking contract");
        console2.log(address(stakeController));
        
        console2.log("Calling rebase on chainlink adapter");
        console2.log("Validator");
        console2.log(validator);
        console2.log("Current stake");
        console2.log(currentStake);
        
        Storage storage $ = _loadStorage();
        console2.log("Loading storage for rebase operation.");
        if (block.timestamp - $.lastRebaseTimestamp < 1 days) {
            console2.log("Rebase operation not needed, returning current stake.");
            return currentStake;
        }

        $.lastRebaseTimestamp = block.timestamp;
        console2.log("Updating last rebase timestamp.");

        console2.log("I should be able to get the stake.");
        console2.log(address(this));
        uint256 stakedAmount = stakeController.getStake(address(this));
        console2.log("This is the stake.");
        console2.log(stakedAmount);

        if (stakedAmount == 0) {
            // The user is not a staker
            console2.log("The contract is not yet a staker");
            return 0;
        } else {
            console2.log("The contract is already a staker somehow?");
            console2.log(stakedAmount);
            // return 0;
        }

        // Claim rewards (if any)
        uint256 baseReward = stakeController.getBaseReward(address(this));
        uint256 delegationReward = stakeController.getDelegationReward(address(this));
        console2.log("Fetching base and delegation rewards.");
        
        if (baseReward + delegationReward > 0) {
            console2.log("Rewards found, restaking them.");
            // Note: In the actual Chainlink staking contract, there might be a separate
            // function to claim rewards. This is a placeholder.
            // stakeController.claimRewards();

            // Restake rewards
            stake(validator, baseReward + delegationReward);
        } else {
            console2.log("No rewards to restake.");
        }

        // Read new stake
        newStake = stakeController.getStake(address(this));
        console2.log("Fetching new stake after rebase operation.");
    }

    function isValidator(address validator) public view override returns (bool) {
        // return stakeController.isOperator(validator);
        return true;
    }
}