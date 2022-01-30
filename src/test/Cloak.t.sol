// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import {DSTestPlus} from "./utils/DSTestPlus.sol";

import {MockCloak} from "./mocks/MockCloak.sol";

import {MockERC20} from "@solmate/test/utils/mocks/MockERC20.sol";

contract CloakTest is DSTestPlus {
    MockCloak cloak;

    // Mock Deposit Token
    MockERC20 public depositToken;

    uint256 public creationTime = block.timestamp;

    function setUp() public {
        cloak = new MockCloak(
            "MockCloak",       // string memory _name,
            "EGMA",             // string memory _symbol,
            100,                // uint256 _depositAmount,
            10_000,             // uint256 _minPrice,
            creationTime + 10,  // uint256 _commitStart,
            creationTime + 15,  // uint256 _revealStart,
            creationTime + 20,  // uint256 _mintStart,
            address(0),         // address _depositToken,
            1                   // uint256 _flex
        );
    }

    /// @notice Test Commitments
    function testCommit() public {
        // Expect Revert when we are before the commit phase
        vm.expectRevert(
            abi.encodeWithSignature(
                "NonAllocation(uint256,uint64,uint64)",
                allocationEnd + 1,
                allocationStart,
                allocationEnd
            )
        );
        twamBase.deposit(TOKEN_SUPPLY);

        // Jump to after the commit period
        vm.warp(allocationEnd + 1);

        // Expect Revert when we are after the allocation period
        vm.expectRevert(
            abi.encodeWithSignature(
                "NonAllocation(uint256,uint64,uint64)",
                allocationEnd + 1,
                allocationStart,
                allocationEnd
            )
        );
        twamBase.deposit(TOKEN_SUPPLY);
    }
}
