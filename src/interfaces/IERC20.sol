// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.11;

/// @title ERC20 Interface
/// @dev https://eips.ethereum.org/EIPS/eip-20
/// @author Andreas Bigger <andreas@nascent.xyz>
interface IERC20 {
    /// @dev The circulating supply of tokens
    function totalSupply() external view returns (uint256);

    /// @dev The number of tokens owned by the account
    /// @param account The address to get the balance for
    function balanceOf(address account) external view returns (uint256);

    /// @dev Transfers the specified amount of tokens to the recipient from the sender
    function transfer(address recipient, uint256 amount) external returns (bool);

    /// @dev The amount of tokens the spender is permitted to transfer from the owner
    function allowance(address owner, address spender) external view returns (uint256);

    /// @dev Permits a spender to transfer an amount of tokens
    function approve(address spender, uint256 amount) external returns (bool);

    /// @dev Transfers tokens from the sender using the caller's allowance
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    /// @dev Emitted when tokens are transfered
    /// @param from The address that is sending the tokens
    /// @param to The token recipient
    /// @param value The number of tokens
    event Transfer(address indexed from, address indexed to, uint256 value);

    /// @dev Emitted when an owner permits a spender
    /// @param owner The token owner
    /// @param spender The permitted spender
    /// @param value The number of tokens
    event Approval(address indexed owner, address indexed spender, uint256 value);
}