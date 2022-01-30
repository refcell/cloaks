// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import {DSTestPlus} from "./utils/DSTestPlus.sol";

import {MockEnigma} from "./mocks/MockEnigma.sol";

contract EnigmaTest is DSTestPlus {
    MockEnigma enigma;

    uint256 public creationTime = block.timestamp;

    function setUp() public {
        enigma = new MockEnigma(
            "MockEnigma",       // string memory _name,
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
        // TODO:
    }
}
