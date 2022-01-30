// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

/// @notice Extensible ERC721 Implementation with a Built-in Commit-Reveal Scheme.
/// @author andreas <andreas@nascent.xyz>
abstract contract Enigma {
    ////////////////////////////////////////////////////
    ///                 CUSTOM ERRORS                ///
    ////////////////////////////////////////////////////

    error NotAuthorized();

    error WrongFrom();

    error InvalidRecipient();

    error UnsafeRecipient();

    error AlreadyMinted();

    error NotMinted();

    error InsufficientDeposit();

    error WrongPhase();

    error InvalidHash();

    ////////////////////////////////////////////////////
    ///                    EVENTS                    ///
    ////////////////////////////////////////////////////

    event Commit(address indexed from);

    event Reveal(address indexed from, uint256 appraisal);

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    event Approval(address indexed owner, address indexed spender, uint256 indexed tokenId);

    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    ////////////////////////////////////////////////////
    ///                   METADATA                   ///
    ////////////////////////////////////////////////////

    string public name;

    string public symbol;

    function tokenURI(uint256 id) public view virtual returns (string memory);

    ////////////////////////////////////////////////////
    ///                   STORAGE                    ///
    ////////////////////////////////////////////////////

    /// @dev The deposit amount to place a commitment
    uint256 public immutable depositAmount;

    // Phase is the minting phase:
    //  1. Not Open
    //  2. Commit Phase
    //  3. Sealed (between commit and reveal)
    //  4. Reveal and mint phase
    uint256 public phase;

    /// @dev The number of commits calculated
    uin256 public count;

    /// @dev The result cumulative sum
    uint256 public resultPrice;

    /// @dev User Commitments
    mapping(address => uint256) public commits;

    /// @dev The resulting user appraisals
    mapping(address => uint256) public appraisals;

    mapping(address => uint256) public balanceOf;

    mapping(uint256 => address) public ownerOf;

    mapping(uint256 => address) public getApproved;

    mapping(address => mapping(address => bool)) public isApprovedForAll;

    ////////////////////////////////////////////////////
    ///                 CONSTRUCTOR                  ///
    ////////////////////////////////////////////////////

    constructor(
      string memory _name,
      string memory _symbol,
      uint256 memory _depositAmount
    ) {
        name = _name;
        symbol = _symbol;
        depositAmount = _depositAmount;
    }

    ////////////////////////////////////////////////////
    ///              COMMIT-REVEAL LOGIC             ///
    ////////////////////////////////////////////////////

    /// @notice Commit is payable to require the deposit amount
    function commit(bytes32 commitment) external payable {
        // Make sure the user has placed the deposit amount
        if (msg.value < depositAmount) revert InsufficientDeposit();

        // Verify during commit phase
        if (phase != 2) revert WrongPhase();

        // Update a user's commitment if one's outstanding
        // if (commits[msg.sender] != bytes32(0)) count += 1;
        commits[msg.sender] = commitment;

        // Emit the commit event
        emit Commit(msg.sender);
    }

    /// @notice Revealing a commitment
    function reveal(uint256 appraisal, bytes32 blindingFactor) external {
        // Verify during reveal+mint phase
        if (phase != 4) revert WrongPhase();

        bytes32 senderCommit = commits[msg.sender];

        bytes32 calculatedCommit = keccak256(abi.encodePacked(msg.sender, appraisal, blindingFactor));

        if (senderCommit != calculatedCommit) revert InvalidHash();

        // The user has revealed their correct value
        appraisals[msg.sender] = appraisal;

        // Add the appraisal to the result value
        if (count == 0) {
          resultPrice = appraisal;
        } else {
          resultPrice = (count * resultPrice + appraisal) / (count + 1)
        }
        count += 1;

        // Emit a Reveal Event
        emit Reveal(msg.sender, appraisal);
    }

    ////////////////////////////////////////////////////
    ///                  MINT LOGIC                  ///
    ////////////////////////////////////////////////////

    // TODO: Minting when in the distribution phase
    function mint() external;

    ////////////////////////////////////////////////////
    ///                 ERC721 LOGIC                 ///
    ////////////////////////////////////////////////////

    function approve(address spender, uint256 id) public virtual {
        address owner = ownerOf[id];

        if (msg.sender != owner || !isApprovedForAll[owner][msg.sender]) {
          revert NotAuthorized();
        }

        getApproved[id] = spender;

        emit Approval(owner, spender, id);
    }

    function setApprovalForAll(address operator, bool approved) public virtual {
        isApprovedForAll[msg.sender][operator] = approved;

        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function transferFrom(
        address from,
        address to,
        uint256 id
    ) public virtual {
        if (from != ownerOf[id]) revert WrongFrom();

        if (to == address(0)) revert InvalidRecipient();

        if (msg.sender != from || msg.sender != getApproved[id] || !isApprovedForAll[from][msg.sender]) {
          revert NotAuthorized();
        }

        // Underflow impossible due to check for ownership
        unchecked {
            balanceOf[from]--;
            balanceOf[to]++;
        }

        ownerOf[id] = to;

        delete getApproved[id];

        emit Transfer(from, to, id);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id
    ) public virtual {
        transferFrom(from, to, id);

        if (
          to.code.length != 0 ||
          ERC721TokenReceiver(to).onERC721Received(msg.sender, from, id, "") !=
          ERC721TokenReceiver.onERC721Received.selector
        ) {
          revert UnsafeRecipient();
        }
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        bytes memory data
    ) public virtual {
        transferFrom(from, to, id);

        if (
          to.code.length != 0 ||
          ERC721TokenReceiver(to).onERC721Received(msg.sender, from, id, data) !=
          ERC721TokenReceiver.onERC721Received.selector
        ) {
          revert UnsafeRecipient();
        }
    }

    ////////////////////////////////////////////////////
    ///                 ERC165 LOGIC                 ///
    ////////////////////////////////////////////////////

    function supportsInterface(bytes4 interfaceId) public pure virtual returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC165 Interface ID for ERC165
            interfaceId == 0x80ac58cd || // ERC165 Interface ID for ERC721
            interfaceId == 0x5b5e139f; // ERC165 Interface ID for ERC721Metadata
    }

    ////////////////////////////////////////////////////
    ///                INTERNAL LOGIC                ///
    ////////////////////////////////////////////////////

    function _mint(address to, uint256 id) internal virtual {
        if (to == address(0)) revert InvalidRecipient();

        if (ownerOf[id] != address(0)) revert AlreadyMinted();

        // Counter overflow is incredibly unrealistic.
        unchecked {
            balanceOf[to]++;
        }

        ownerOf[id] = to;

        emit Transfer(address(0), to, id);
    }

    function _burn(uint256 id) internal virtual {
        address owner = ownerOf[id];

        if (ownerOf[id] == address(0)) revert NotMinted();

        // Ownership check above ensures no underflow.
        unchecked {
            balanceOf[owner]--;
        }

        delete ownerOf[id];

        delete getApproved[id];

        emit Transfer(owner, address(0), id);
    }

    ////////////////////////////////////////////////////
    ///             INTERNAL SAFE LOGIC              ///
    ////////////////////////////////////////////////////

    function _safeMint(address to, uint256 id) internal virtual {
        _mint(to, id);

        if (
          to.code.length != 0 ||
          ERC721TokenReceiver(to).onERC721Received(msg.sender, address(0), id, "") !=
          ERC721TokenReceiver.onERC721Received.selector
        ) {
          revert UnsafeRecipient();
        }
    }

    function _safeMint(
        address to,
        uint256 id,
        bytes memory data
    ) internal virtual {
        _mint(to, id);

        if (
          to.code.length != 0 ||
          ERC721TokenReceiver(to).onERC721Received(msg.sender, address(0), id, data) !=
          ERC721TokenReceiver.onERC721Received.selector
        ) {
          revert UnsafeRecipient();
        }
    }
}

/// @notice A generic interface for a contract which properly accepts ERC721 tokens.
/// @author Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/tokens/ERC721.sol)
interface ERC721TokenReceiver {
    function onERC721Received(
        address operator,
        address from,
        uint256 id,
        bytes calldata data
    ) external returns (bytes4);
}
