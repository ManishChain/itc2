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
import './Plot.sol';
import './PlotRegistry.sol';

contract PlotFactory is StateMachineFactory {
  constructor(GateKeeper gateKeeper, PlotRegistry registry) public StateMachineFactory(gateKeeper, registry) {}

  function create(
    string memory name,
    string memory caPaKey,
    address owner,
    string memory ipfsFieldContainerHash
  ) public authWithCustomReason(CREATE_STATEMACHINE_ROLE, 'Sender needs CREATE_STATEMACHINE_ROLE') {
    bytes memory memProof = bytes(name);
    require(memProof.length > 0, 'A name is required');
    Plot plot = new Plot(address(gateKeeper), name, caPaKey, owner, ipfsFieldContainerHash, _uiFieldDefinitionsHash);

    // Give every role registry a single permission on the newly created expense.
    bytes32[] memory roles = plot.getRoles();
    for (uint256 i = 0; i < roles.length; i++) {
      gateKeeper.createPermission(gateKeeper.getRoleRegistryAddress(roles[i]), address(plot), roles[i], address(this));
    }

    _registry.insert(address(plot));
    emit StateMachineCreated(address(plot));
  }
}
