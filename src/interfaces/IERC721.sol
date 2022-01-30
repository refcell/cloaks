// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.11;

import {IERC165} from "./IERC165.sol";

/// @title ERC721 Interface
/// @dev https://eips.ethereum.org/EIPS/eip-721
/// @author Andreas Bigger <andreas@nascent.xyz>
interface IERC721 is IERC165 {
    /// @dev Emitted when a token is transferred
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId
    );

    /// @dev Emitted when a token owner approves `approved`
    event Approval(
        address indexed owner,
        address indexed approved,
        uint256 indexed tokenId
    );

    /// @dev Emitted when `owner` enables or disables `operator` for all tokens
    event ApprovalForAll(
        address indexed owner,
        address indexed operator,
        bool approved
    );

    /// @dev Returns the number of tokens owned by `owner`
    function balanceOf(address owner) external view returns (uint256 balance);

    /// @dev Returns the owner of token with id `tokenId`
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /// @dev Safely transfers the token with id `tokenId`
    /// @dev Requires the sender to be approved through an `approve` or `setApprovalForAll`
    /// @dev Emits a Transfer Event
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /// @dev Transfers the token with id `tokenId`
    /// @dev Requires the sender to be approved through an `approve` or `setApprovalForAll`
    /// @dev Emits a Transfer Event
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /// @dev Approves `to` to transfer the given token
    /// @dev Approval is reset on transfer
    /// @dev Caller must be the owner or approved
    /// @dev Only one address can be approved at a time
    /// @dev Emits an Approval Event
    function approve(address to, uint256 tokenId) external;

    /// @dev Returns the address approved for the given token
    function getApproved(uint256 tokenId)
        external
        view
        returns (address operator);

    /// @dev Sets an operator as approved or disallowed for all tokens owned by the caller
    /// @dev Emits an ApprovalForAll Event
    function setApprovalForAll(address operator, bool _approved) external;

    /// @dev Returns if the operator is allowed approved for owner's tokens
    function isApprovedForAll(address owner, address operator)
        external
        view
        returns (bool);

    /// @dev Safely transfers a token with id `tokenId`
    /// @dev Emits a Transfer Event
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;
}