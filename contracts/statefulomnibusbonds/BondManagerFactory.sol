/**
 * Copyright (C) SettleMint NV - All Rights Reserved
 *
 * Use of this file is strictly prohibited without an active license agreement.
 * Distribution of this file, via any medium, is strictly prohibited.
 *
 * For license inquiries, contact hello@settlemint.com
 *
 * SPDX-License-Identifier: UNLICENSED
 */

pragma solidity ^0.6.3;

import '@settlemint/enteth-contracts/contracts/provenance/statemachine/StateMachineFactory.sol';
import './BondManager.sol';
import './BondManagerRegistry.sol';

/**
 * @title Factory contract for stateful omnibus  bond state machines
 */
contract BondManagerFactory is StateMachineFactory {
  event BondManagerCreated(address _address, string _name);

  constructor(GateKeeper gateKeeper, BondManagerRegistry registry) public StateMachineFactory(gateKeeper, registry) {}

  /**
   * @notice Create new bondmanager
   * @dev Factory method to create a new bondmanager.
   */
  function create(string memory name, address addressStatefulOmnibusBond)
    public
    authWithCustomReason(CREATE_STATEMACHINE_ROLE, 'Sender needs CREATE_STATEMACHINE_ROLE')
    returns (address)
  {
    BondManager bondManager = new BondManager(gateKeeper, addressStatefulOmnibusBond, name, _uiFieldDefinitionsHash);

    // Give every role registry a single permission on the newly created bond manager.
    bytes32[] memory rolesBondManager = bondManager.getRoles();
    for (uint256 i = 0; i < rolesBondManager.length; i++) {
      gateKeeper.createPermission(
        gateKeeper.getRoleRegistryAddress(rolesBondManager[i]),
        address(bondManager),
        rolesBondManager[i],
        address(this)
      );
    }

    _registry.insert(address(bondManager));

    emit BondManagerCreated(address(bondManager), name);

    return address(bondManager);
  }
}
