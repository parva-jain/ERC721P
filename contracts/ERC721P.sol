//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import '@openzeppelin/contracts/utils/cryptography/ECDSA.sol';
import '@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol';

// taken from openzepplin's template
interface IERC721Receiver {
    /**
     * @dev Whenever an {IERC721} `tokenId` token is transferred to this contract via {IERC721-safeTransferFrom}
     * by `operator` from `from`, this function is called.
     *
     * It must return its Solidity selector to confirm the token transfer.
     * If any other value is returned or the interface is not implemented by the recipient, the transfer will be reverted.
     *
     * The selector can be obtained in Solidity with `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

// ERC721 implementation with additional functionalities(permit)
contract ERC721P {
    // using Address library for helper functins(isContract)
    using Address for address;

    string public contractName;
    string public contractSymbol;
    bytes32 public constant PERMIT_TYPEHASH =
        keccak256(
            'Permit(address spender,uint256 tokenId,uint256 nonce,uint256 deadline)'
        );
    bytes32 private _domainSeparator;
    uint256 private _domainChainId;

    // tokenId => tokenOwner
    mapping(uint256 => address) internal _tokenId2Owner;

    // tokenOwner => tokenCount
    mapping(address => uint256) internal _balance;

    // tokenId => tokenApprovals
    mapping(uint256 => address) private _tokenId2Approvals;

    // tokenId => nonce
    mapping(uint256 => uint256) private _nonces;

    // emitted when token is transferred, minted or burned
    event Transfer(address indexed _from , address indexed _to, uint256 indexed _tokenId);

    // emitted when owner of a token approves an address to manage the token
    event Approval(address indexed _owner, address indexed _approved, uint256 indexed _tokenId);

    // checks whether tokenId exists or not
    modifier exists(uint256 tokenId) {
        require(_tokenId2Owner[tokenId] != address(0), "TokenId should exist");
        _;
    }

    constructor(string memory _name, string memory _symbol){
        contractName = _name;
        contractSymbol = _symbol;
        uint256 chainId;
        assembly {
            chainId := chainid()
        }

        _domainChainId = chainId;
        _domainSeparator = _calculateDomainSeparator();
    }

    // getter function for name of contract
    function name() public view returns (string memory) {
        return contractName;
    }

     // getter function for symbol of contract   
    function symbol() public view returns (string memory) {
        return contractSymbol;
    }

    // mints token with _tokenId and transfers it to _to address
    function _mint(address _to, uint256 _tokenId) internal {
        require(_to != address(0), "Reciever can't be zero address");
        _tokenId2Owner[_tokenId] = _to;
        _balance[_to]++;

        emit Transfer(address(0), _to, _tokenId);
    }

    // mints token even when _to is any contract address 
    function _safeMint(
        address _to,
        uint256 _tokenId,
        bytes memory _data
    ) internal {
        _mint(_to, _tokenId);
        require(
            _checkOnERC721Received(address(0), _to, _tokenId, _data),
            "Transfer to non ERC721Receiver implementer"
        );
    }

    // transfer token to zero address
    function _burn(uint256 _tokenId) internal {
        address owner = ERC721P.ownerOf(_tokenId);

        // Clear approvals
        _approve(address(0), _tokenId);

        _balance[owner] -= 1;
        delete _tokenId2Owner[_tokenId];

        emit Transfer(owner, address(0), _tokenId);
    }

    // getter function for owner of a token
    function ownerOf(uint256 _tokenId) public view returns (address) {
        address owner = _tokenId2Owner[_tokenId];
        require(owner != address(0), "Token should exist");
        return owner;
    }

    // getter function for balance of an address
    function balanceOf(address _owner) public view returns (uint256) {
        require(_owner != address(0), "Cannot query zero address");
        return _balance[_owner];
    }

    // approves _to to manage token with _tokenId
    function _approve(address _to, uint256 _tokenId) internal virtual {
        _tokenId2Approvals[_tokenId] = _to;
        emit Approval(ERC721P.ownerOf(_tokenId), _to, _tokenId);
    }

    // wrapper function on _approve with couple of checks
    function approve(address _to, uint256 _tokenId) public {
        address owner = ERC721P.ownerOf(_tokenId);
        require(_to != owner, "Owner cannot approve himself");
        require(msg.sender == owner, "Only owner can approve any address");

        _approve(_to, _tokenId);
    }
    
    // getter function for approvers of token with _tokenId
    function getApproved(uint256 _tokenId) public view exists(_tokenId) returns (address) {
        return _tokenId2Approvals[_tokenId];
    }

    // getter function for nonce of token with _tokenId
    function getNonce(uint256 _tokenId) public view exists(_tokenId) returns (uint256) {
        return _nonces[_tokenId];
    }

    // checks whether _spender is owner/approver of token with _tokenId
    function _isApprovedOrOwner(address _spender, uint256 _tokenId) internal view exists(_tokenId) returns (bool) {
        address owner = ERC721P.ownerOf(_tokenId);
        return (_spender == owner || getApproved(_tokenId) == _spender);
    }

    // transfers _tokenId from _from to _to and increases the nonce
    function _transfer(
        address _from,
        address _to,
        uint256 _tokenId
    ) internal {
        require(ERC721P.ownerOf(_tokenId) == _from, "Transfer from incorrect owner");
        require(_to != address(0), "Transfer to the zero address");

        // increment the nonce to be sure it can't be reused
        _nonces[_tokenId]++;

        // Clear approvals from the previous owner
        _approve(address(0), _tokenId);

        _balance[_from] -= 1;
        _balance[_to] += 1;
        _tokenId2Owner[_tokenId] = _to;

        emit Transfer(_from, _to, _tokenId);
    }

    // wrapper function on _transfer with a check
    function transferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    ) public {
        require(_isApprovedOrOwner(msg.sender, _tokenId), "Only owner or approver can transfer token");
        _transfer(_from, _to, _tokenId);
    }
    
    // this function needs to be implemented to transfer a token to the contract address
    function _checkOnERC721Received(
        address _from,
        address _to,
        uint256 _tokenId,
        bytes memory _data
    ) private returns (bool) {
        if (_to.isContract()) {
            try IERC721Receiver(_to).onERC721Received(msg.sender, _from, _tokenId, _data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("Transfer to non ERC721Receiver implementer");
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    // transfers token to contract address as well
    function _safeTransfer(
        address _from,
        address _to,
        uint256 _tokenId,
        bytes memory _data
    ) internal virtual {
        _transfer(_from, _to, _tokenId);
        require(_checkOnERC721Received(_from, _to, _tokenId, _data), "Transfer to non ERC721Receiver implementer");
    }

    // wrapper function on _safeTransfer with a check
    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId,
        bytes memory _data
    ) public {
        require(_isApprovedOrOwner(msg.sender, _tokenId), "Transfer caller is not owner nor approved");
        _safeTransfer(_from, _to, _tokenId, _data);
    }

    // calculates hash of EIP712 Domain_Seperator
    function _calculateDomainSeparator()
        internal
        view
        returns (bytes32)
    {
        return
            keccak256(
                abi.encode(
                    keccak256(
                        'EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'
                    ),
                    keccak256(bytes(name())),
                    keccak256(bytes('1')),
                    block.chainid,
                    address(this)
                )
            );
    }

    /// Builds the DOMAIN_SEPARATOR (eip712) at time of use
    /// returns the DOMAIN_SEPARATOR of eip712
    function DOMAIN_SEPARATOR() public view returns (bytes32) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }

        return
            (chainId == _domainChainId)
                ? _domainSeparator
                : _calculateDomainSeparator();
    }

    /// Builds the permit digest to sign
    /// returns the digest (following eip712) to sign
    function _buildDigest(
        address _spender,
        uint256 _tokenId,
        uint256 _nonce,
        uint256 _deadline
    ) public view returns (bytes32) {
        return
            ECDSA.toTypedDataHash(
                DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        PERMIT_TYPEHASH,
                        _spender,
                        _tokenId,
                        _nonce,
                        _deadline
                    )
                )
            );
    }

    /// function to be called to approve _spender using a Permit signature
    function permit(
        address _spender,
        uint256 _tokenId,
        uint256 _deadline,
        bytes memory _signature
    ) public {
        require(_deadline >= block.timestamp, 'permit expired');

        bytes32 digest = _buildDigest(
            // owner,
            _spender,
            _tokenId,
            _nonces[_tokenId],
            _deadline
        );

        (address recoveredAddress, ) = ECDSA.tryRecover(digest, _signature);
        require(
            // verify if the recovered address is owner or approved on tokenId
            // and make sure recoveredAddress is not address(0), else getApproved(tokenId) might match
            (recoveredAddress != address(0) &&
                _isApprovedOrOwner(recoveredAddress, _tokenId)) ||
                // else try to recover signature using SignatureChecker, which also allows to recover signature made by contracts
                SignatureChecker.isValidSignatureNow(
                    ownerOf(_tokenId),
                    digest,
                    _signature
                ),
            'invalid permit signature'
        );

        _approve(_spender, _tokenId);
    }

}