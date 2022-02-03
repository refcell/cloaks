// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import {Cloak} from "../../Cloak.sol";
import {IERC721TokenReceiver} from "../../interfaces/IERC721TokenReceiver.sol";

contract ERC721User is IERC721TokenReceiver {
    Cloak cloak;

    constructor(Cloak _cloak) {
        cloak = _cloak;
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) public virtual override returns (bytes4) {
        return IERC721TokenReceiver.onERC721Received.selector;
    }

    function approve(address spender, uint256 tokenId) public virtual {
        cloak.approve(spender, tokenId);
    }

    function setApprovalForAll(address operator, bool approved) public virtual {
        cloak.setApprovalForAll(operator, approved);
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual {
        cloak.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual {
        cloak.safeTransferFrom(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public {
        cloak.safeTransferFrom(from, to, tokenId, data);
    }
}