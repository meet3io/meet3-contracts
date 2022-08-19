// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract SBT is ERC721, ERC721Enumerable, Pausable, Ownable, ERC721Burnable {
    using Counters for Counters.Counter;
    using Strings for uint256;

    Counters.Counter private _tokenIdCounter;

    string public _uriPrefix = "";
    string public _uriSuffix = ".json";

    constructor() ERC721("SoulboundToken", "SBT") {}

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function safeMint(address to) public onlyOwner {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
    }

    function mintForAddress(address[] memory receivers) public onlyOwner {
        uint256 receiverLength = receivers.length;
        for (uint256 i = 0; i < receiverLength; i++) {
            address receiver = receivers[i];
            uint256 tokenId = _tokenIdCounter.current();
            _tokenIdCounter.increment();
            _safeMint(receiver, tokenId);
        }
    }

    function updateAndMint(string memory uriPrefix, address[] memory receivers)
        public
        onlyOwner
    {
        setUriPrefix(uriPrefix);
        uint256 receiverLength = receivers.length;
        for (uint256 i = 0; i < receiverLength; i++) {
            address receiver = receivers[i];
            uint256 tokenId = _tokenIdCounter.current();
            _tokenIdCounter.increment();
            _safeMint(receiver, tokenId);
        }
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        string memory baseURI = _baseURI();
        return
            bytes(baseURI).length > 0
                ? string(
                    abi.encodePacked(baseURI, tokenId.toString(), _uriSuffix)
                )
                : "";
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _uriPrefix;
    }

    function setUriPrefix(string memory uriPrefix) public onlyOwner {
        _uriPrefix = uriPrefix;
    }

    function setUriSuffix(string memory uriSuffix) public onlyOwner {
        _uriSuffix = uriSuffix;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) whenNotPaused {
        require(from == address(0), "SBT can not be transfered!");
        super._beforeTokenTransfer(from, to, tokenId);
    }

    // The following functions are overrides required by Solidity.

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
