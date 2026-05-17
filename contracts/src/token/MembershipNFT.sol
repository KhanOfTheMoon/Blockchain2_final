// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721 as OZERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract MembershipNFT is ERC721URIStorage, Ownable {
    uint256 public nextTokenId;

    event MembershipMinted(address indexed to, uint256 indexed tokenId, string tokenUri);

    error ZeroAddress();
    error EmptyTokenUri();

    constructor() OZERC721("Membership NFT", "MNFT") Ownable(msg.sender) {}

    /// @notice Template mint hook for membership or game-item style NFTs.
    function safeMint(address to, string calldata tokenUri) external onlyOwner returns (uint256 tokenId) {
        if (to == address(0)) revert ZeroAddress();
        if (bytes(tokenUri).length == 0) revert EmptyTokenUri();

        tokenId = nextTokenId++;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, tokenUri);
        emit MembershipMinted(to, tokenId, tokenUri);
    }
}
