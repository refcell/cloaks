// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import {Enigma, ERC721TokenReceiver} from "../../Enigma.sol";

contract ERC721User is ERC721TokenReceiver {
    Enigma enigma;

    constructor(Enigma _enigma) {
        enigma = _enigma;
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) public virtual override returns (bytes4) {
        return ERC721TokenReceiver.onERC721Received.selector;
    }

    function approve(address spender, uint256 tokenId) public virtual {
        enigma.approve(spender, tokenId);
    }

    function setApprovalForAll(address operator, bool approved) public virtual {
        enigma.setApprovalForAll(operator, approved);
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual {
        enigma.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual {
        enigma.safeTransferFrom(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public {
        enigma.safeTransferFrom(from, to, tokenId, data);
    }
}