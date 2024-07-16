// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.19;

uint256 constant VERSION = 1;

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";

import { Adapter } from "core/lst/adapters/Adapter.sol";
import { Staking } from "chainlink-staking/Staking.sol";
import { IERC165 } from "core/lst/interfaces/IERC165.sol";

import "core/lst/base/VaultControllerStrategyUpgrade.sol";

ERC20 constant LINK = ERC20(0x514910771AF9Ca656af840dff83E8264EcF986CA);
Staking constant stakeController = Staking(0x3feB1e09b4bb0E7f0387CeE092a52e85797ab889);

contract ChainlinkAdapter is Adapter, VaultControllerStrategyUpgrade {
    using SafeTransferLib for ERC20;

    // IVault[] internal vaults;
    uint256 private totalPrincipalDeposits;

    event VaultAdded(address indexed operator);
    event DepositBufferedTokens(uint256 depositedAmount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
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
     */
    function initialize(
        address _token,
        address _stakingPool,
        address _stakeController,
        address _vaultImplementation,
        uint256 _minDepositThreshold,
        Fee[] memory _fees,
        address[] calldata _initialVaults
    ) public initializer {
        __VaultControllerStrategy_init(
            _token,
            _stakingPool,
            _stakeController,
            _vaultImplementation,
            _minDepositThreshold,
            _fees
        );
        // Don't bother to set up inital vaults.
    }

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
        Storage storage $ = _loadStorage();
        if (block.timestamp - $.lastRebaseTimestamp < 1 days) {
            return currentStake;
        }

        $.lastRebaseTimestamp = block.timestamp;

        // Claim rewards (if any)
        uint256 baseReward = stakeController.getBaseReward(address(this));
        uint256 delegationReward = stakeController.getDelegationReward(address(this));
        
        if (baseReward + delegationReward > 0) {
            // Note: In the actual Chainlink staking contract, there might be a separate
            // function to claim rewards. This is a placeholder.
            // stakeController.claimRewards();

            // Restake rewards
            stake(validator, baseReward + delegationReward);
        }

        // Read new stake
        newStake = stakeController.getStake(address(this));
    }

    function isValidator(address validator) public view override returns (bool) {
        return stakeController.isOperator(validator);
    }
}