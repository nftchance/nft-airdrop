// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "hardhat/console.sol";

/**
 * @title MimeticPhantomAirDrop
 * @notice This is an extremely light-weight forked version of OpenZeppelins
 *         ERC-721 implementation. Each case of implementation will vary and 
 *         thus not all nuances have been covered in the implementation.
 * @dev Implementation of https://eips.ethereum.org/EIPS/eip-721[ERC721] 
 *      Non-Fungible Token Standard, including the Metadata extension and 
 *      combining with the uage of https://nftchance.medium.com/mimetic-metadata-how-to-create-a-truly-non-dilutive-nft-collection-in-2022-746a01f886c5[Mimetic Metadata] and https://0xinuarashi.medium.com/introduction-to-phantom-minting-503a508f9560[Phantom Minting] then finally https://eips.ethereum.org/EIPS/eip-2309[EIP2309]
 * authors: nftchance, masonchain, 0xInuarashi
 */
contract ERC721 is 
      Context
    , ERC165
    , Ownable
    , IERC721
    , IERC721Metadata
{
    using Address for address;
    using Strings for uint256;

    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    // Mapping from token ID to owner address
    mapping(uint256 => address) private _owners;

    // Mapping from token ID to approved address
    mapping(uint256 => mapping(address => address)) private _tokenApprovals;

    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    uint256 internal _supply;
    IERC721 public parent;

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` 
     *      to the token collection.
     */
    constructor(
          string memory name_
        , string memory symbol_
        , uint256 supply
        , address _parent
    ) {
        _name = name_;
        _symbol = symbol_;
        _supply = supply;

        parent = IERC721(_parent);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) 
        public 
        view 
        virtual 
        override(ERC165, IERC165) 
        returns (
            bool
        )
    {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function initialize(
          uint256 _start
        , uint256 _end
    )
        public
        virtual
        onlyOwner()
    {
        for(
            uint256 i = _start;
            i < _end;
            i++
        ) {
            emit Transfer(
                  address(0x0)
                , address(this)
                , i
            );
        }  
    }

    function initializeToOwners(
          uint256 _start
        , uint256 _end
    )
        public
        virtual
        onlyOwner()
    {
        for(
            uint256 i = _start;
            i < _end;
            i++
        ) {
            emit Transfer(
                  address(0x0)
                , parent.ownerOf(i)
                , i
            );
        }  
    }

    function initializeToCalldata(
          uint256 _start
        , uint256 _end
        , address[] calldata accounts
    )
        public
        virtual
        onlyOwner()
    {
        require(
              _end - _start == accounts.length
            , "Incorrect amount of accounts provided."
        );

        uint256 index;
        for(
            uint256 i = _start;
            i < _end;
            i++
        ) {
            console.log(i);
            emit Transfer(
                  address(0x0)
                , accounts[index++]
                , i
            );
        }
    }

    /// @dev Implementing EIP-2309: https://eips.ethereum.org/EIPS/eip-2309
    event ConsecutiveTransfer(
          uint256 indexed fromTokenId
        , uint256 toTokenId
        , address indexed fromAddress
        , address indexed toAddress
    );

    /**
     * @notice This function emits an event that is listened to by NFT 
     *         marketplaces and allows for the entire collection to be 
     *         available and viewed even before ownership of tokens is 
     *         written to as per common ERC implementation.
     * @dev True ownership is determined by our parent collection
     *         interface until a transaction decouples ownership
     *         of this child token from the parent token.
     */
    function initialize2309()
        public 
        virtual 
        onlyOwner() 
    {
        
        emit ConsecutiveTransfer(
              0
            , _supply
            , address(0x0)
            , address(this)
        );
    }

    function initialize2309ToTarget(
          uint256 _start
        , uint256 _end
        , address _to
    ) 
        public
        virtual
        onlyOwner()
    {
        emit ConsecutiveTransfer(
              _start
            , _end
            , address(0x0)
            , _to
        );
    }

    /**
     * @dev This function has been sacrificed with the implementation of
     *      the supply based for-loop. For large supplies, this handling
     *      will essentially prevent the usage of balanceOf() on-chain
     *      as gas consumption will be immense since this repo is 
     *      merely intended for display purposes. (There are better ways
     *      to do this -- If you write it please make a pull request
     *      and it will get merged!)
     * @dev See {IERC721-balanceOf}.
     */
    function balanceOf(address _owner) 
        public 
        view 
        virtual 
        override 
        returns (
            uint256 balance
        ) 
    {
        require(
              _owner != address(0)
            , "ERC721: balance query for the zero address"
        );

        for(
            uint256 i = _supply;
            i > 0;
            i--
        ) {
            balance++;
        }
    }

    /**
     * @notice This function determines the active owner of the airdropped 
     *         token. An address is not written to storage until the token has
     *         been claimed (which is not neccessary). If a token doesn't exist
     *         the owner of the Parent token it utilized. 
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) 
        public 
        view 
        virtual 
        override 
        returns (
            address
        ) 
    {
        require(
              tokenId < _supply
            , "ERC721: approved query for nonexistent token"
        );

        // If the address has been written to storage use the stored address
        if(_owners[tokenId] != address(0))
            return _owners[tokenId];

        // Fallback to use owner of the token that it was migrated from
        return parent.ownerOf(tokenId);
    }

    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() 
        public 
        view 
        virtual 
        override 
        returns (
            string memory
        ) 
    {
        return _name;
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() 
        public 
        view 
        virtual 
        override 
        returns (
            string memory
        ) 
    {
        return _symbol;
    }

    /**
     * @notice This function retrieves the URI of a given token id.
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) 
        public 
        view 
        virtual 
        override 
        returns (
            string memory
        ) 
    {
        require(
              tokenId < _supply
            , "ERC721: approved query for nonexistent token"
        );

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overriden in child contracts.
     */
    function _baseURI() 
        internal 
        view 
        virtual 
        returns (
            string memory
        ) 
    {
        return "";
    }

    /**
     * @dev See {IERC721-approve}.
     */
    function approve(
          address to
        , uint256 tokenId
    ) 
        public 
        virtual 
        override 
    {
        address _owner = ERC721.ownerOf(tokenId);
        require(to != _owner, "ERC721: approval to current owner");

        require(
            _msgSender() == _owner || isApprovedForAll(_owner, _msgSender()),
            "ERC721: approve caller is not owner nor approved for all"
        );

        _approve(to, tokenId);
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 tokenId) 
        public 
        view 
        virtual 
        override 
        returns (
            address
        ) 
    {
        return _tokenApprovals[tokenId][ERC721.ownerOf(tokenId)];
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(
          address operator
        , bool approved
    ) 
        public 
        virtual 
        override 
    {
        _setApprovalForAll(
              _msgSender()
            , operator
            , approved
        );
    }

    /**
     * @dev See {IERC721-isApprovedForAll}.
     */
    function isApprovedForAll(
          address _owner
        , address operator
    ) 
        public 
        view 
        virtual 
        override 
        returns (
            bool
        ) 
    {
        return _operatorApprovals[_owner][operator];
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(
              _msgSender()
            , tokenId
        ), "ERC721: transfer caller is not owner nor approved");

        _transfer(
              from
            , to
            , tokenId
        );
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        safeTransferFrom(
              from
            , to
            , tokenId
            , ""
        );
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) 
        public 
        virtual 
        override 
    {
        require(_isApprovedOrOwner(
              _msgSender()
            , tokenId
        ), "ERC721: transfer caller is not owner nor approved");
        
        _safeTransfer(
              from
            , to
            , tokenId
            , _data
        );
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * `_data` is additional data, it has no specified format and it is sent in call to `to`.
     *
     * This internal function is equivalent to {safeTransferFrom}, and can be used to e.g.
     * implement alternative mechanisms to perform token transfer, such as signature-based.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeTransfer(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) 
        internal 
        virtual 
    {
        _transfer(
              from
            , to
            , tokenId
        );
        
        require(_checkOnERC721Received(
            from
            , to
            , tokenId
            , _data
        ), "ERC721: transfer to non ERC721Receiver implementer");
    }

    /**
     * @dev Returns whether `tokenId` exists.
     *
     * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
     *
     * Tokens start existing when they are minted (`_mint`),
     * and stop existing when they are burned (`_burn`).
     */
    function _exists(uint256 tokenId) 
        internal 
        view 
        virtual 
        returns (
            bool
        ) 
    {
        return _owners[tokenId] != address(0);
    }

    /**
     * @dev Returns whether `spender` is allowed to manage `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _isApprovedOrOwner(address spender, uint256 tokenId) 
        internal 
        view 
        virtual 
        returns (
            bool
        ) 
    {
        require(
              tokenId < _supply
            , "ERC721: approved query for nonexistent token"
        );

        address _owner = ERC721.ownerOf(tokenId);
        return (
               spender == _owner 
            || getApproved(tokenId) == spender 
            || isApprovedForAll(
                  _owner
                , spender
            )
        );
    }

    /**
     * @dev Safely mints `tokenId` and transfers it to `to`.
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeMint(
          address to
        , uint256 tokenId
    ) 
        internal 
        virtual 
    {
        _safeMint(
              to
            , tokenId
            , ""
        );
    }

    /**
     * @dev Same as {xref-ERC721-_safeMint-address-uint256-}[`_safeMint`], with an additional `data` parameter which is
     * forwarded in {IERC721Receiver-onERC721Received} to contract recipients.
     */
    function _safeMint(
        address to,
        uint256 tokenId,
        bytes memory _data
    ) 
        internal 
        virtual 
    {
        _mint(
              to
            , tokenId
        );
        
        require(
            _checkOnERC721Received(
                  address(0)
                , to
                , tokenId
                , _data
            ),
            "ERC721: transfer to non ERC721Receiver implementer"
        );
    }

    /**
     * @dev Mints `tokenId` and transfers it to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {_safeMint} whenever possible
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - `to` cannot be the zero address.
     *
     * Emits a {Transfer} event.
     */
    function _mint(
          address to
        , uint256 tokenId
    ) 
        internal 
        virtual 
    {
        require(to != address(0), "ERC721: mint to the zero address");
        require(!_exists(tokenId), "ERC721: token already minted");

        _beforeTokenTransfer(
              address(0)
            , to
            , tokenId
        );

        _owners[tokenId] = to;

        emit Transfer(address(0), to, tokenId);

        _afterTokenTransfer(address(0), to, tokenId);
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId) internal virtual {
        address _owner = ERC721.ownerOf(tokenId);

        _beforeTokenTransfer(_owner, address(0), tokenId);

        // Clear approvals
        delete _tokenApprovals[tokenId][_owner];
        emit Approval(
              _owner
            , address(0)
            , tokenId
        );

        delete _owners[tokenId];

        emit Transfer(_owner, address(0), tokenId);

        _afterTokenTransfer(_owner, address(0), tokenId);
    }

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *  As opposed to {transferFrom}, this imposes no restrictions on msg.sender.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     *
     * Emits a {Transfer} event.
     */
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {
        address _owner = ERC721.ownerOf(tokenId);

        require(
              _owner == from
            , "ERC721: transfer from incorrect owner"
        );
        require(to != address(0), "ERC721: transfer to the zero address");

        _beforeTokenTransfer(
              from
            , to
            , tokenId
        );

        // Clear approvals from the previous owner
        delete _tokenApprovals[tokenId][_owner];
        emit Approval(
              _owner
            , address(0)
            , tokenId
        );

        _owners[tokenId] = to;

        emit Transfer(
              from
            , to
            , tokenId
        );

        _afterTokenTransfer(
              from
            , to
            , tokenId
        );
    }

    /**
     * @dev Approve `to` to operate on `tokenId`
     *
     * Emits a {Approval} event.
     */
    function _approve(
          address to
        , uint256 tokenId
    ) 
        internal 
        virtual 
    {
        address _owner = ERC721.ownerOf(tokenId);

        _tokenApprovals[tokenId][_owner] = to;
        emit Approval(_owner, to, tokenId);
    }

    /**
     * @dev Approve `operator` to operate on all of `owner` tokens
     *
     * Emits a {ApprovalForAll} event.
     */
    function _setApprovalForAll(
        address _owner,
        address operator,
        bool approved
    ) 
        internal 
        virtual 
    {
        require(_owner != operator, "ERC721: approve to caller");
        _operatorApprovals[_owner][operator] = approved;
        
        emit ApprovalForAll(
              _owner
            , operator
            , approved
        );
    }

    /**
     * @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
     * The call is not executed if the target address is not a contract.
     *
     * @param from address representing the previous owner of the given token ID
     * @param to target address that will receive the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param _data bytes optional data to send along with the call
     * @return bool whether the call correctly returned the expected magic value
     */
    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) 
        private 
        returns (
            bool
        ) 
    {
        if (to.isContract()) {
            try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, _data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
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

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {}
}
