// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.11;

/// @title ERC165 Interface
/// @dev https://eips.ethereum.org/EIPS/eip-165
/// @author Andreas Bigger <andreas@nascent.xyz>
interface IERC165 {
    /// @dev Returns if the contract implements the defined interface
    /// @param interfaceId the 4 byte interface signature
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}