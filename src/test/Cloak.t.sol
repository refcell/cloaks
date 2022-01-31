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
    uint256 public commitStart = creationTime + 10;
    uint256 public revealStart = creationTime + 20;
    uint256 public mintStart = creationTime + 30;

    bytes32 blindingFactor = bytes32("AllTheCoolKidsHateTheDiamondPattern");

    function setUp() public {
        cloak = new MockCloak(
            "MockCloak",        // string memory _name,
            "EGMA",             // string memory _symbol,
            100,                // uint256 _depositAmount,
            10_000,             // uint256 _minPrice,
            commitStart,        // uint256 _commitStart,
            revealStart,        // uint256 _revealStart,
            mintStart,          // uint256 _mintStart,
            address(0),         // address _depositToken,
            1                   // uint256 _flex
        );
    }

    /// @notice Test Commitments
    function testCommit() public {
        bytes32 public commitment = keccak256(abi.encodePacked(msg.sender, 10, blindingFactor));

        // Expect Revert when we don't send at least the depositAmount
        vm.expectRevert(abi.encodePacked(bytes4(keccak256("InsufficientDeposit()"))));
        cloak.commit(commitment);

        // Expect Revert when we are not in the commit phase
        vm.expectRevert(abi.encodePacked(bytes4(keccak256("WrongPhase()"))));
        cloak.commit(commitment);

        // Jump to after the commit phase
        vm.warp(revealStart);

        // Expect Revert when we are not in the commit phase
        vm.expectRevert(abi.encodePacked(bytes4(keccak256("WrongPhase()"))));
        cloak.commit(commitment);

        // Jump to during the commit phase
        vm.warp(commitStart);

        // TODO: should successfully commit

        // Expect Revert when we are after the allocation period
        // vm.expectRevert(
        //     abi.encodeWithSignature(
        //         "NonAllocation(uint256,uint64,uint64)",
        //         allocationEnd + 1,
        //         allocationStart,
        //         allocationEnd
        //     )
        // );
        // twamBase.deposit(TOKEN_SUPPLY);
    }
}
