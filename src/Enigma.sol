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

    ////////////////////////////////////////////////////
    ///                    EVENTS                    ///
    ////////////////////////////////////////////////////

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

    mapping(address => uint256) public balanceOf;

    mapping(uint256 => address) public ownerOf;

    mapping(uint256 => address) public getApproved;

    mapping(address => mapping(address => bool)) public isApprovedForAll;

    ////////////////////////////////////////////////////
    ///                 CONSTRUCTOR                  ///
    ////////////////////////////////////////////////////

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }

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
