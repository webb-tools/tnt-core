// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.19;

import { AccessControlUpgradeable } from "openzeppelin-contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { Initializable } from "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { RegistryStorage } from "core/lst/registry/RegistryStorage.sol";
import { FACTORY_ROLE, FEE_GAUGE_ROLE, LIQUIFIER_ROLE, UPGRADE_ROLE, GOVERNANCE_ROLE } from "core/lst/registry/Roles.sol";
import { IERC165 } from "core/lst/interfaces/IERC165.sol";
import { Adapter } from "core/lst/adapters/Adapter.sol";
/**
 * @title Registry
 * @author Tangle Labs
 * @notice Registry for Liquifier ecosystem. Role-based access, fee management and adapter updates.
 */

contract Registry is Initializable, UUPSUpgradeable, AccessControlUpgradeable, RegistryStorage {
    error InvalidAdapter(address adapter);
    error InvalidTreasury(address treasury);
    error LiquifierAlreadyExists(address asset, address validator, address liquifier);

    event AdapterRegistered(address indexed asset, address indexed adapter);
    event NewLiquifier(address indexed asset, address indexed validator, address liquifier);
    event FeeAdjusted(address indexed asset, uint256 newFee, uint256 oldFee);
    event TreasurySet(address indexed treasury);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _liquifier, address _unlocks) public initializer {
        __AccessControl_init();
        _grantRole(UPGRADE_ROLE, msg.sender);
        _grantRole(GOVERNANCE_ROLE, msg.sender);
        _grantRole(FEE_GAUGE_ROLE, msg.sender);

        _setRoleAdmin(GOVERNANCE_ROLE, GOVERNANCE_ROLE);
        _setRoleAdmin(FACTORY_ROLE, GOVERNANCE_ROLE);
        _setRoleAdmin(FEE_GAUGE_ROLE, FEE_GAUGE_ROLE);
        // Only allow UPGRADE_ROLE to add new UPGRADE_ROLE memebers
        // If all members of UPGRADE_ROLE are revoked, contract upgradability is revoked
        _setRoleAdmin(UPGRADE_ROLE, UPGRADE_ROLE);
        Storage storage $ = _loadStorage();
        $.liquifier = _liquifier;
        $.unlocks = _unlocks;
    }

    // Getters

    /**
     * @notice Returns the address of the adapter for a given asset
     * @param asset Address of the underlying asset
     */
    function adapter(address asset) external view returns (address) {
        return _loadStorage().protocols[asset].adapter;
    }

    /**
     * @notice Returns the address of the liquifier implementation
     */
    function liquifier() external view returns (address) {
        Storage storage $ = _loadStorage();
        return $.liquifier;
    }

    /**
     * @notice Returns the address of the treasury
     */
    function treasury() external view returns (address) {
        Storage storage $ = _loadStorage();
        return $.treasury;
    }

    /**
     * @notice Returns the address of the unlocks contract
     */
    function unlocks() external view returns (address) {
        Storage storage $ = _loadStorage();
        return $.unlocks;
    }

    /**
     * @notice Returns the fee for a given asset
     * @param asset Address of the underlying asset
     */
    function fee(address asset) external view returns (uint96) {
        return _loadStorage().protocols[asset].fee;
    }

    /**
     * @notice Returns whether a given address is a valid liquifier
     * @param liquifier Address of the liquifier
     * @return Whether the address is a valid liquifier
     */
    function isLiquifier(address liquifier) external view returns (bool) {
        return hasRole(LIQUIFIER_ROLE, liquifier);
    }

    /**
     * @notice Returns the address of the liquifier for a given asset and validator
     * @param asset Address of the underlying asset
     * @param validator Address of the validator
     * @return Address of the liquifier
     */
    function getLiquifier(address asset, address validator) external view returns (address) {
        return _loadStorage().liquifiers[asset][validator];
    }

    // Setters

    /**
     * @notice Registers a new adapter for a given asset
     * @dev Can only be called by a member of the Roles.GOVERNANCE
     * @param asset Address of the underlying asset
     * @param adapter Address of the adapter
     */
    function registerAdapter(address asset, address adapter) external onlyRole(GOVERNANCE_ROLE) {
        if (adapter == address(0) || !IERC165(adapter).supportsInterface(type(Adapter).interfaceId)) revert InvalidAdapter(adapter);
        Storage storage $ = _loadStorage();
        $.protocols[asset].adapter = adapter;
        emit AdapterRegistered(asset, adapter);
    }

    /**
     * @notice Registers a new liquifier for a given asset
     * @dev Can only be called by a member of the Roles.FACTORY
     * @param asset Address of the underlying asset
     * @param validator Address of the validator
     * @param liquifier Address of the liquifier
     */
    function registerLiquifier(address asset, address validator, address liquifier) external onlyRole(FACTORY_ROLE) {
        Storage storage $ = _loadStorage();
        if ($.liquifiers[asset][validator] != address(0)) {
            revert LiquifierAlreadyExists(asset, validator, $.liquifiers[asset][validator]);
        }
        $.liquifiers[asset][validator] = liquifier;
        _grantRole(LIQUIFIER_ROLE, liquifier);
        emit NewLiquifier(asset, validator, liquifier);
    }

    /**
     * @notice Sets the fee for a given asset
     * @dev Can only be called by a member of the Roles.FEE_GAUGE
     * @param asset Address of the underlying asset
     * @param fee New fee
     */
    function setFee(address asset, uint96 fee) external onlyRole(FEE_GAUGE_ROLE) {
        Storage storage $ = _loadStorage();
        uint256 oldFee = $.protocols[asset].fee;
        $.protocols[asset].fee = fee;
        emit FeeAdjusted(asset, fee, oldFee);
    }

    /**
     * @notice Sets the treasury
     * @dev Can only be called by a member of the Roles.GOVERNANCE
     * @param treasury Address of the treasury
     */
    function setTreasury(address treasury) external onlyRole(GOVERNANCE_ROLE) {
        if (treasury == address(0)) revert InvalidTreasury(treasury);
        Storage storage $ = _loadStorage();
        $.treasury = treasury;
        emit TreasurySet(treasury);
    }

    ///@dev required by the OZ UUPS module
    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address) internal override onlyRole(UPGRADE_ROLE) { }
}
