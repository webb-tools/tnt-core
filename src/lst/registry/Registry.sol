// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.19;

import { AccessControlUpgradeable } from "openzeppelin-contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { Initializable } from "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { RegistryStorage } from "core/lst/registry/RegistryStorage.sol";
import { FACTORY_ROLE, FEE_GAUGE_ROLE, TENDERIZER_ROLE, UPGRADE_ROLE, GOVERNANCE_ROLE } from "core/lst/registry/Roles.sol";
import { IERC165 } from "core/lst/interfaces/IERC165.sol";
import { Adapter } from "core/lst/adapters/Adapter.sol";
/**
 * @title Registry
 * @author Tenderize Labs Ltd
 * @notice Registry for Tenderizer ecosystem. Role-based access, fee management and adapter updates.
 */

contract Registry is Initializable, UUPSUpgradeable, AccessControlUpgradeable, RegistryStorage {
    error InvalidAdapter(address adapter);
    error InvalidTreasury(address treasury);
    error TenderizerAlreadyExists(address asset, address validator, address tenderizer);

    event AdapterRegistered(address indexed asset, address indexed adapter);
    event NewTenderizer(address indexed asset, address indexed validator, address tenderizer);
    event FeeAdjusted(address indexed asset, uint256 newFee, uint256 oldFee);
    event TreasurySet(address indexed treasury);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _tenderizer, address _unlocks) public initializer {
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
        $.tenderizer = _tenderizer;
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
     * @notice Returns the address of the tenderizer implementation
     */
    function tenderizer() external view returns (address) {
        Storage storage $ = _loadStorage();
        return $.tenderizer;
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
     * @notice Returns whether a given address is a valid tenderizer
     * @param tenderizer Address of the tenderizer
     * @return Whether the address is a valid tenderizer
     */
    function isTenderizer(address tenderizer) external view returns (bool) {
        return hasRole(TENDERIZER_ROLE, tenderizer);
    }

    /**
     * @notice Returns the address of the tenderizer for a given asset and validator
     * @param asset Address of the underlying asset
     * @param validator Address of the validator
     * @return Address of the tenderizer
     */
    function getTenderizer(address asset, address validator) external view returns (address) {
        return _loadStorage().tenderizers[asset][validator];
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
     * @notice Registers a new tenderizer for a given asset
     * @dev Can only be called by a member of the Roles.FACTORY
     * @param asset Address of the underlying asset
     * @param validator Address of the validator
     * @param tenderizer Address of the tenderizer
     */
    function registerTenderizer(address asset, address validator, address tenderizer) external onlyRole(FACTORY_ROLE) {
        Storage storage $ = _loadStorage();
        if ($.tenderizers[asset][validator] != address(0)) {
            revert TenderizerAlreadyExists(asset, validator, $.tenderizers[asset][validator]);
        }
        $.tenderizers[asset][validator] = tenderizer;
        _grantRole(TENDERIZER_ROLE, tenderizer);
        emit NewTenderizer(asset, validator, tenderizer);
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
