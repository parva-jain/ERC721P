// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./ERC721P.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

// sample contract inheriting ERC721P
contract sampleNFT is ERC721P('Mock721', 'MOCK') {
    using Counters for Counters.Counter;
    Counters.Counter internal _tokenIdCounter;

    // wrapper function to mint token to caller
    function mint() public returns (uint256) {
        uint256 tokenId = _tokenIdCounter.current();
        _mint(msg.sender, tokenId);
        _tokenIdCounter.increment();
        return tokenId;
    }

    // wrapper function to burn token with _tokenId
    function burn(uint256 _tokenId) external {
        require(msg.sender == ownerOf(_tokenId));

        _burn(_tokenId);
    }

    /// Allows to get approved using a permit and transfer in the same call
    function safeTransferFromWithPermit(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data,
        uint256 deadline,
        bytes memory signature
    ) external {
        // use the permit to get msg.sender approved
        permit(msg.sender, tokenId, deadline, signature);

        // do the transfer
        safeTransferFrom(from, to, tokenId, _data);
    }
}