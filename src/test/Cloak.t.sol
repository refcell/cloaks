// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import {DSTestPlus} from "./utils/DSTestPlus.sol";

import {MockCloak} from "./mocks/MockCloak.sol";

import {MockERC20} from "@solmate/test/utils/mocks/MockERC20.sol";

contract CloakTest is DSTestPlus {
    MockCloak cloak;

    // Cloak Arguments and Metadata
    string public name = "MockCloak";
    string public symbol = "EGMA";
    uint256 public depositAmount = 100;
    uint256 public minPrice = 10;
    uint256 public creationTime = block.timestamp;
    uint256 public commitStart = creationTime + 10;
    uint256 public revealStart = creationTime + 20;
    uint256 public mintStart = creationTime + 30;
    address public depositToken = address(0);
    uint256 public flex = 1;

    bytes32 public blindingFactor = bytes32(bytes("AllTheCoolKidsHateTheDiamondPattern"));

    function setUp() public {
        cloak = new MockCloak(
            name,               // string memory _name,
            symbol,             // string memory _symbol,
            depositAmount,      // uint256 _depositAmount,
            minPrice,           // uint256 _minPrice,
            commitStart,        // uint256 _commitStart,
            revealStart,        // uint256 _revealStart,
            mintStart,          // uint256 _mintStart,
            depositToken,       // address _depositToken,
            flex                // uint256 _flex
        );
    }

    /// @notice Tests metadata and immutable config
    function testConfig() public {
        assert(keccak256(abi.encodePacked((cloak.name()))) == keccak256(abi.encodePacked((name))));
        assert(keccak256(abi.encodePacked((cloak.symbol()))) == keccak256(abi.encodePacked((symbol))));
        assert(cloak.depositAmount() == depositAmount);
        assert(cloak.minPrice() == minPrice);
        assert(cloak.commitStart() == commitStart);
        assert(cloak.revealStart() == revealStart);
        assert(cloak.mintStart() == mintStart);
        assert(cloak.depositToken() == depositToken);
        assert(cloak.flex() == flex);
    }

    ////////////////////////////////////////////////////
    ///                 COMMIT LOGIC                 ///
    ////////////////////////////////////////////////////

    /// @notice Test Commitments
    function testCommit() public {
        bytes32 commitment = keccak256(abi.encodePacked(address(this), uint256(10), blindingFactor));

        // Expect Revert when we don't send at least the depositAmount
        vm.expectRevert(abi.encodePacked(bytes4(keccak256("InsufficientDeposit()"))));
        cloak.commit(commitment);

        // Expect Revert when we are not in the commit phase
        vm.expectRevert(abi.encodePacked(bytes4(keccak256("WrongPhase()"))));
        cloak.commit{value: depositAmount}(commitment);

        // Jump to after the commit phase
        vm.warp(revealStart);

        // Expect Revert when we are not in the commit phase
        vm.expectRevert(abi.encodePacked(bytes4(keccak256("WrongPhase()"))));
        cloak.commit{value: depositAmount}(commitment);

        // Jump to during the commit phase
        vm.warp(commitStart);

        // Successfully Commit
        cloak.commit{value: depositAmount}(commitment);
    }

    ////////////////////////////////////////////////////
    ///                 REVEAL LOGIC                 ///
    ////////////////////////////////////////////////////

    /// @notice Test Reveals
    function testReveal(uint256 invalidConcealedBid) public {
        // Create a Successful Commitment
        bytes32 commitment = keccak256(abi.encodePacked(address(this), uint256(10), blindingFactor));
        vm.warp(commitStart);
        cloak.commit{value: depositAmount}(commitment);

        // Fail to reveal pre-reveal phase
        vm.expectRevert(abi.encodePacked(bytes4(keccak256("WrongPhase()"))));
        cloak.reveal(uint256(10), blindingFactor);

        // Fail to reveal post-reveal phase
        vm.warp(mintStart);
        vm.expectRevert(abi.encodePacked(bytes4(keccak256("WrongPhase()"))));
        cloak.reveal(uint256(10), blindingFactor);

        // Warp to the reveal phase
        vm.warp(revealStart);

        // Fail to reveal with invalid value
        uint256 concealed = invalidConcealedBid != 10 ? invalidConcealedBid : 11;
        vm.expectRevert(abi.encodePacked(bytes4(keccak256("InvalidHash()"))));
        cloak.reveal(uint256(concealed), blindingFactor);

        // Successfully Reveal During Reveal Phase
        cloak.reveal(uint256(10), blindingFactor);

        // We shouldn't be able to double reveal
        vm.expectRevert(abi.encodePacked(bytes4(keccak256("InvalidHash()"))));
        cloak.reveal(uint256(10), blindingFactor);

        // Validate Price and Variance Calculations
        assert(cloak.resultPrice() == uint256(10));
        assert(cloak.count() == uint256(1));
    }

    /// @notice Test Multiple Reveals
    function testMultipleReveals() public {
        // Create a Successful Commitment and Reveal
        bytes32 commitment = keccak256(abi.encodePacked(address(this), uint256(10), blindingFactor));
        vm.warp(commitStart);
        cloak.commit{value: depositAmount}(commitment);
        vm.warp(revealStart);
        cloak.reveal(uint256(10), blindingFactor);

        // Validate Price and Variance Calculations
        assert(cloak.resultPrice() == uint256(10));
        assert(cloak.count() == uint256(1));

        // Initiate Hoax
        startHoax(address(1337), address(1337), type(uint256).max);

        // Create Another Successful Commitment and Reveal
        bytes32 commitment2 = keccak256(abi.encodePacked(address(1337), uint256(20), blindingFactor));
        vm.warp(commitStart);
        cloak.commit{value: depositAmount}(commitment2);
        vm.warp(revealStart);
        cloak.reveal(uint256(20), blindingFactor);

        // Validate Price and Variance Calculations
        assert(cloak.resultPrice() == uint256(15));
        assert(cloak.count() == uint256(2));
        assert(cloak.rollingVariance() == uint256(50));
        
        // Stop Hoax (prank under-the-hood)
        vm.stopPrank();

        // Initiate Another Hoax
        startHoax(address(420), address(420), type(uint256).max);

        // Create Another Successful Commitment and Reveal
        bytes32 commitment3 = keccak256(abi.encodePacked(address(420), uint256(30), blindingFactor));
        vm.warp(commitStart);
        cloak.commit{value: depositAmount}(commitment3);
        vm.warp(revealStart);
        cloak.reveal(uint256(30), blindingFactor);

        // Validate Price and Variance Calculations
        assert(cloak.resultPrice() == uint256(20));
        assert(cloak.count() == uint256(3));
        assert(cloak.rollingVariance() == uint256(100));
        
        // Stop Hoax (prank under-the-hood)
        vm.stopPrank();
    }

    ////////////////////////////////////////////////////
    ///                  MINT LOGIC                  ///
    ////////////////////////////////////////////////////

    /// @notice Test Minting
    function testMinting() public {
        // Commit+Reveal 1
        bytes32 commitment = keccak256(abi.encodePacked(address(this), uint256(10), blindingFactor));
        vm.warp(commitStart);
        cloak.commit{value: depositAmount}(commitment);
        vm.warp(revealStart);
        cloak.reveal(uint256(10), blindingFactor);

        // Minting fails outside mint phase
        vm.expectRevert(abi.encodePacked(bytes4(keccak256("WrongPhase()"))));
        cloak.mint();

        // Mint should fail without value
        vm.warp(mintStart);
        vm.expectRevert(abi.encodePacked(bytes4(keccak256("InsufficientValue()"))));
        cloak.mint();

        // We should be able to mint
        cloak.mint{value: 10}();
        assert(cloak.reveals(address(this)) == 0);
        assert(cloak.balanceOf(address(this)) == 1);
        assert(cloak.totalSupply() == 1);

        // Double mints are prevented with Reveals Mask
        vm.expectRevert(abi.encodePacked(bytes4(keccak256("InvalidAction()"))));
        cloak.mint{value: 10}();
    }

    /// @notice Test Multiple Mints
    function testMultipleMints() public {
        // Commit+Reveal 1
        bytes32 commitment = keccak256(abi.encodePacked(address(this), uint256(10), blindingFactor));
        vm.warp(commitStart);
        cloak.commit{value: depositAmount}(commitment);
        vm.warp(revealStart);
        cloak.reveal(uint256(10), blindingFactor);

        // Commit+Reveal 2
        startHoax(address(1337), address(1337), type(uint256).max);
        bytes32 commitment2 = keccak256(abi.encodePacked(address(1337), uint256(20), blindingFactor));
        vm.warp(commitStart);
        cloak.commit{value: depositAmount}(commitment2);
        vm.warp(revealStart);
        cloak.reveal(uint256(20), blindingFactor);
        vm.stopPrank();

        // Commit+Reveal 3
        startHoax(address(420), address(420), type(uint256).max);
        bytes32 commitment3 = keccak256(abi.encodePacked(address(420), uint256(30), blindingFactor));
        vm.warp(commitStart);
        cloak.commit{value: depositAmount}(commitment3);
        vm.warp(revealStart);
        cloak.reveal(uint256(30), blindingFactor);
        vm.stopPrank();

        // Minting fails outside mint phase
        vm.expectRevert(abi.encodePacked(bytes4(keccak256("WrongPhase()"))));
        cloak.mint();

        // Mint should fail without value
        vm.warp(mintStart);
        vm.expectRevert(abi.encodePacked(bytes4(keccak256("InsufficientValue()"))));
        cloak.mint();

        // We should be able to mint
        cloak.mint{value: 20}();
        assert(cloak.reveals(address(this)) == 0);
        assert(cloak.balanceOf(address(this)) == 1);
        assert(cloak.totalSupply() == 1);

        // Double mints are prevented with Reveals Mask
        vm.expectRevert(abi.encodePacked(bytes4(keccak256("InvalidAction()"))));
        cloak.mint{value: 20}();

        // Next user mints
        startHoax(address(1337), address(1337), type(uint256).max);
        vm.warp(mintStart);
        cloak.mint{value: 20}();
        assert(cloak.balanceOf(address(1337)) == 1);
        assert(cloak.totalSupply() == 2);
        vm.stopPrank();

        // Third user mints
        startHoax(address(420), address(420), type(uint256).max);
        vm.warp(mintStart);
        cloak.mint{value: 20}();
        assert(cloak.balanceOf(address(420)) == 1);
        assert(cloak.totalSupply() == 3);
        vm.stopPrank();
    }

    ////////////////////////////////////////////////////
    ///                  FORGO LOGIC                 ///
    ////////////////////////////////////////////////////

    /// @notice Test Forgos
    function testForgo() public {
        // Commit+Reveal
        bytes32 commitment = keccak256(abi.encodePacked(address(this), uint256(10), blindingFactor));
        vm.warp(commitStart);
        cloak.commit{value: depositAmount}(commitment);
        vm.warp(revealStart);
        cloak.reveal(uint256(10), blindingFactor);

        // Forgo fails outside mint phase
        vm.expectRevert(abi.encodePacked(bytes4(keccak256("WrongPhase()"))));
        cloak.forgo();

        // We should be able to forgo
        vm.warp(mintStart);
        assert(cloak.reveals(address(this)) != 0);
        cloak.forgo();
        assert(cloak.reveals(address(this)) == 0);
        assert(cloak.balanceOf(address(this)) == 0);
        assert(cloak.totalSupply() == 0);

        // Double forgos are prevented with Reveals Mask
        vm.expectRevert(abi.encodePacked(bytes4(keccak256("InvalidAction()"))));
        cloak.forgo();
    }

        /// @notice Test Multiple Forgos
    function testMultipleForgos() public {
        // Commit+Reveal 1
        bytes32 commitment = keccak256(abi.encodePacked(address(this), uint256(10), blindingFactor));
        vm.warp(commitStart);
        cloak.commit{value: depositAmount}(commitment);
        vm.warp(revealStart);
        cloak.reveal(uint256(10), blindingFactor);

        // Commit+Reveal 2
        startHoax(address(1337), address(1337), type(uint256).max);
        bytes32 commitment2 = keccak256(abi.encodePacked(address(1337), uint256(20), blindingFactor));
        vm.warp(commitStart);
        cloak.commit{value: depositAmount}(commitment2);
        vm.warp(revealStart);
        cloak.reveal(uint256(20), blindingFactor);
        vm.stopPrank();

        // Commit+Reveal 3
        startHoax(address(420), address(420), type(uint256).max);
        bytes32 commitment3 = keccak256(abi.encodePacked(address(420), uint256(30), blindingFactor));
        vm.warp(commitStart);
        cloak.commit{value: depositAmount}(commitment3);
        vm.warp(revealStart);
        cloak.reveal(uint256(30), blindingFactor);
        vm.stopPrank();

        // Forgo fails outside mint phase
        vm.expectRevert(abi.encodePacked(bytes4(keccak256("WrongPhase()"))));
        cloak.forgo();

        // We should be able to forgo
        vm.warp(mintStart);
        assert(cloak.reveals(address(this)) != 0);
        cloak.forgo();
        assert(cloak.reveals(address(this)) == 0);
        assert(cloak.balanceOf(address(this)) == 0);
        assert(cloak.totalSupply() == 0);

        // Double forgos are prevented with Reveals Mask
        vm.expectRevert(abi.encodePacked(bytes4(keccak256("InvalidAction()"))));
        cloak.forgo();

        // Next user forgos
        startHoax(address(1337), address(1337), type(uint256).max);
        vm.warp(mintStart);
        cloak.forgo();
        assert(cloak.balanceOf(address(1337)) == 0);
        assert(cloak.totalSupply() == 0);
        vm.stopPrank();

        // Third user forgos
        startHoax(address(420), address(420), type(uint256).max);
        vm.warp(mintStart);
        cloak.forgo();
        assert(cloak.balanceOf(address(420)) == 0);
        assert(cloak.totalSupply() == 0);
        vm.stopPrank();
    }

    ////////////////////////////////////////////////////
    ///                  LOST REVEALS                ///
    ////////////////////////////////////////////////////

    /// @notice Tests deposit withdrawals on reveal miss
    function testLostReveal() public {
        // Commit
        bytes32 commitment = keccak256(abi.encodePacked(address(this), uint256(10), blindingFactor));
        vm.warp(commitStart);
        cloak.commit{value: depositAmount}(commitment);
        vm.warp(revealStart);

        // Should fail to withdraw since still reveal phase
        vm.expectRevert(abi.encodePacked(bytes4(keccak256("WrongPhase()"))));
        cloak.lostReveal(); 

        // Skip reveal and withdraw
        vm.warp(mintStart);
        cloak.lostReveal();

        // We shouldn't be able to withdraw again since commitment is gone
        vm.expectRevert(abi.encodePacked(bytes4(keccak256("InvalidAction()"))));
        cloak.lostReveal(); 
    }
}
