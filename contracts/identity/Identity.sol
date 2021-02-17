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
pragma experimental ABIEncoderV2;

import '@settlemint/enteth-contracts/contracts/provenance/digitaltwin/DigitalTwin.sol';
import '@settlemint/enteth-contracts/contracts/authentication/Secured.sol';

contract Identity is DigitalTwin, Secured {
  bytes32 public constant MANAGE_DIGITALTWIN_ROLE = 'MANAGE_DIGITALTWIN_ROLE';
  bytes32 public constant UPDATE_UIFIELDDEFINITIONS_ROLE = 'UPDATE_UIFIELDDEFINITIONS_ROLE';

  constructor(address gateKeeper) public Secured(gateKeeper) {}

  function create(
    bytes32 idNumber,
    bytes32 kind,
    string memory ipfsHash
  ) public authWithCustomReason(MANAGE_DIGITALTWIN_ROLE, 'Sender needs MANAGE_DIGITALTWIN_ROLE Role') {
    string memory DID = generateDID(idNumber);

    addClaimWithIdentifier(DID, kind, ipfsHash);
    assertClaim(DID);
  }

  function generateDID(bytes32 idNumber) internal pure returns (string memory) {
    return string(abi.encodePacked('did:mint:identity:', idNumber));
  }

  function edit(bytes32 idNumber, string memory ipfsHash)
    public
    authWithCustomReason(MANAGE_DIGITALTWIN_ROLE, 'Sender needs MANAGE_DIGITALTWIN_ROLE Role')
  {
    string memory DID = generateDID(idNumber);
    require(claimExists(DID), 'Claim does not exists');

    editClaimWithIdentifier(DID, ipfsHash);
  }

  function get(bytes32 idNumber)
    public
    view
    authWithCustomReason(MANAGE_DIGITALTWIN_ROLE, 'Sender needs MANAGE_DIGITALTWIN_ROLE Role')
    returns (string memory ipfsHash, bytes32 Nomor_Identitas)
  {
    string memory DID = generateDID(idNumber);
    require(claimExists(DID), 'Claim does not exists');

    return (getClaimWithIdentifier(DID), idNumber);
  }

  /**
   * @notice returns the number of claims
   */
  function getIndexLength() public view returns (uint256 length) {
    length = _claimRegistry.length;
  }

  /**
   * @notice returns claim at index
   * @param index index of the claim to be retrieved
   */
  function getByIndex(uint256 index) public view returns (Claim memory item) {
    item = _claimRegistry[index];
  }

  /**
   * @notice returns claim for given DID
   * @param DID DID of the claim to be retrieved
   */
  function getByKey(string memory DID) public view returns (Claim memory item) {
    uint256 claimIndex1B = _claimIndex[DID];
    if (claimIndex1B > 0) {
      item = _claimRegistry[claimIndex1B - 1];
    }
  }

  /**
   * @notice returns all claims
   */
  function getContents() public view returns (Claim[] memory items) {
    items = _claimRegistry;
  }

  //////
  // UI Field Definition Functions
  //////
  string public _uiFieldDefinitionsHash;

  /**
   * @notice Set the UI field definition hash
   * @param uiFieldDefinitionsHash IPFS hash containing the UI field definitions JSON
   */
  function setUIFieldDefinitionsHash(string memory uiFieldDefinitionsHash)
    public
    authWithCustomReason(UPDATE_UIFIELDDEFINITIONS_ROLE, 'Sender needs UPDATE_UIFIELDDEFINITIONS_ROLE')
  {
    _uiFieldDefinitionsHash = uiFieldDefinitionsHash;
  }

  /**
   * @notice Returns the UI field definition hash
   */
  function getUIFieldDefinitionsHash() public view returns (string memory) {
    return _uiFieldDefinitionsHash;
  }
}
