// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/IERC1155MetadataURI.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IMirror {
    function ownerOf(uint256 tokenId_) 
        external 
        view 
        returns (
            address
        );

    function isOwnerOf(
          address account
        , uint256[] calldata _tokenIds
    ) 
        external 
        view 
        returns (
            bool
        );
}

contract ERC1155 is 
      Context
    , ERC165
    , Ownable
    , IERC1155
    , IERC1155MetadataURI
{
    using Address for address;

    address[9000] internal _owners;

    /// @dev By allowing approvals on-contract we are disregarding the approvals
    ///      of the Nuclear Nerds tokens.
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    IMirror public mirror;

    constructor(
        address _mirror
    ) { 
        mirror = IMirror(_mirror);
    }

    struct InitializedBatch {
        address account;
        bool accountFirst;
        uint256[] tokenIds;
        uint256[] amounts;
    }

    function initializeSinglesToContract(
          uint256 _start
        , uint256 _end
    )
        public
        virtual
        onlyOwner()
    {
        for(
            uint256 i = _start;
            i <= _end;
            i++
        ) {
            emit TransferSingle(
                  address(this)
                , address(0)
                , address(this)
                , i
                , 1
            );
        }  
    }

    function initializeBatchToContract(
          uint256[] calldata _tokenIds
        , uint256[] calldata _amounts
    )
        public
        virtual
        onlyOwner()
    {
        // Emit transfer event for all the token ids in this batch
        emit TransferBatch(
              address(this)     
            , address(this)
            , address(0x0)
            , _tokenIds
            , _amounts
        );
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
            i <= _end;
            i++
        ) {
            emit TransferSingle(
                  msg.sender
                , address(0x0)
                , mirror.ownerOf(i)
                , i
                , 1
            );
        }  
    }

    function initializeToCalldata(
        InitializedBatch[] calldata _batches
    )
        public
        virtual
        onlyOwner()
    {
        for(
            uint256 i; 
            i < _batches.length;
            i++
        ) {
            address account = _batches[i].account;

            // Make sure that the account owns all the tokens that are about
            // to be airdropped -- Checks for the first batch of tokens for
            // every new account submit.
            if(_batches[i].accountFirst) {
                require(mirror.isOwnerOf(
                      account
                    , _batches[i].tokenIds
                ), "Token being airdropped to incorrect owner.");
            }

            // Emit transfer event for all the token ids in this batch
            emit TransferBatch(
                  account     
                , account     
                , address(0x0)
                , _batches[i].tokenIds 
                , _batches[i].amounts
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
            , _owners.length
            , address(0x0)
            , address(this)
        );
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
            interfaceId == type(IERC1155).interfaceId ||
            interfaceId == type(IERC1155MetadataURI).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @notice This implementation returns an empty string as it will be
     *         overwritten by the higher level uri() so that the on-chain
     *         metadata can be utilized.
     *         https://eips.ethereum.org/EIPS/eip-1155#metadata
     * @dev See {IERC1155MetadataURI-uri}.
     */
    function uri(uint256) 
        public 
        view 
        virtual 
        override 
        returns (
            string memory
        ) 
    {
        return "";
    }

    /**
     * @dev Updated to allow for NFT Bound Phantom Airdrop 
     * @dev See {IERC1155-balanceOf}.
     */
    function balanceOf(
          address account
        , uint256 id
    ) 
        public 
        view 
        virtual 
        override 
        returns (
            uint256
        ) 
    {
        // If there is an address in storage, use that as there
        // has been an action performed on-contract. 
        if(_owners[id] != address(0))
            return _owners[id] == account ? 1 : 0;
        
        // Fallback to the owner Nerd as the token hasn't yet been 'made real.'
        return mirror.ownerOf(id) == account ? 1 : 0; 
    }

    /**
     * @dev Using NFT Bound Phantom Airdrop balanceOf() that utilizes 
     *      owner-check of the non-fungible 1155 
     * @dev See {IERC1155-balanceOfBatch}.
     */
    function balanceOfBatch(
          address[] memory accounts
        , uint256[] memory ids
    )
        public
        view
        virtual
        override
        returns (
            uint256[] memory
        )
    {
        require(
              accounts.length == ids.length
            , "ERC1155: accounts and ids length mismatch"
        );

        uint256[] memory batchBalances = new uint256[](accounts.length);

        for (
            uint256 i; 
            i < accounts.length; 
            ++i
        ) {
            batchBalances[i] = balanceOf(
                  accounts[i]
                , ids[i]
            );
        }

        return batchBalances;
    }

    /**
     * @dev See {IERC1155-setApprovalForAll}.
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
     * @dev See {IERC1155-isApprovedForAll}.
     */
    function isApprovedForAll(
          address account
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
        return _operatorApprovals[account][operator];
    }

    /**
     * @dev See {IERC1155-safeTransferFrom}.
     */
    function safeTransferFrom(
          address from
        , address to
        , uint256 id
        , uint256 amount
        , bytes memory data
    ) 
        public 
        virtual 
        override 
    {
        require(
              from == _msgSender() || isApprovedForAll(from, _msgSender())
            , "ERC1155: caller is not owner nor approved"
        );
     
        _safeTransferFrom(
              from
            , to
            , id
            , amount
            , data
        );
    }

    /**
     * @dev See {IERC1155-safeBatchTransferFrom}.
     */
    function safeBatchTransferFrom(
          address from
        , address to
        , uint256[] memory ids
        , uint256[] memory amounts
        , bytes memory data
    ) 
        public 
        virtual 
        override 
    {
        require(
              from == _msgSender() || isApprovedForAll(from, _msgSender())
            , "ERC1155: transfer caller is not owner nor approved"
        );

        _safeBatchTransferFrom(
              from
            , to
            , ids
            , amounts
            , data
        );
    }

    /**
     * @notice Transfers (single) `amount` tokens of token type `id` 
     *         from `from` to `to`.
     * @dev Emits a {TransferSingle} event.
     * @dev If `to` refers to a smart contract, it must implement
     *      {IERC1155Receiver-onERC1155Received} and return the 
     *      acceptance magic value.
     * @dev amount can be equal to zero to be conforming to ERC1155.
     * @dev Using NFT Bound Phantom Airdrop balanceOf() that utilizes 
     *      owner-check of the non-fungible 1155 
     * @param from The address which previously owned the token
     * @param to The address which the token is going to
     * @param id The ID of the token being transferred
     * @param amount The amount of tokens being transferred
     * @param data Additional data with no specified format
     */
    function _safeTransferFrom(
          address from
        , address to
        , uint256 id
        , uint256 amount
        , bytes memory data
    ) 
        internal 
        virtual 
    {
        require(to != address(0), "ERC1155: transfer to the zero address");

        address operator = _msgSender();
        uint256[] memory ids = _asSingletonArray(id);
        uint256[] memory amounts = _asSingletonArray(amount);

        _beforeTokenTransfer(
              operator
            , from
            , to
            , ids
            , amounts
            , data
        );

        require(
              balanceOf(
                    from
                  , id
               ) > 0 && amount < 2
            , "ERC1155: insufficient balance for transfer"
        );

        /**
         * @dev The ERC1155 spec allows for transfering zero tokens, but we are *      still expected to run the other checks and emit the event. But *      we don't want an ownership change in that case 
         */
        if (amount == 1) {
            _owners[id] = to;
        }

        emit TransferSingle(
              operator
            , from
            , to
            , id
            , amount
        );

        _afterTokenTransfer(
              operator
            , from
            , to
            , ids
            , amounts
            , data
        );

        _doSafeTransferAcceptanceCheck(
              operator
            , from
            , to
            , id
            , amount
            , data
        );
    }

    /**
     * @notice Batch transfers `amount` tokens of token type `id` 
     *         from `from` to `to`.
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] 
     *      version of {_safeTransferFrom}.
     * @dev If `to` refers to a smart contract, it must implement 
     *      {IERC1155Receiver-onERC1155BatchReceived} and return the
     *      acceptance magic value.
     * @param from The address which previously owned the token
     * @param to The address which the token is going to
     * @param ids The IDs of the tokens being transferred
     * @param amounts The amounts of tokens being transferred
     * @param data Additional data with no specified format
     */
    function _safeBatchTransferFrom(
          address from
        , address to
        , uint256[] memory ids
        , uint256[] memory amounts
        , bytes memory data
    ) 
        internal 
        virtual 
    {
        require(
              ids.length == amounts.length
            , "ERC1155: ids and amounts length mismatch"
        );
        require(to != address(0), "ERC1155: transfer to the zero address");

        address operator = _msgSender();

        _beforeTokenTransfer(
              operator
            , from
            , to
            , ids
            , amounts
            , data
        );

        for (
            uint256 i; 
            i < ids.length; 
            ++i
        ) {
            uint256 id = ids[i];

            require(
                    balanceOf(
                          from
                        , id
                    ) > 0 && amounts[i] < 2
                , "ERC1155: insufficient balance for transfer"
            );

            /**
             * @dev The ERC1155 spec allows for transfering zero tokens, but 
             *      we are still expected to run the other checks and emit the
             *      event. But we don't want an ownership change in that case 
            */
            if (amounts[i] == 1) {
                _owners[id] = to;
            }
        }

        emit TransferBatch(
              operator
            , from
            , to
            , ids
            , amounts
        );

        _afterTokenTransfer(
              operator
            , from
            , to
            , ids
            , amounts
            , data
        );

        _doSafeBatchTransferAcceptanceCheck(
              operator
            , from
            , to
            , ids
            , amounts
            , data
        );
    }

    /**
     * @notice Returns whether `tokenId` exists.
     * @dev Tokens start existing when they are minted (`_mint`),
     *      and stop existing when they are burned (`_burn`).
     * @param tokenId The ID of the token being minted
     * @return Boolean that says whether or not this token is currently minted.
     */
    function _exists(uint256 tokenId)
        internal
        virtual
        view
        returns (
            bool
        )
    {
        return _owners[tokenId] != address(0);
    }
    
    /**
     * @notice Mints `amount` tokens of token type `id`, and assigns them 
     *         to `to`.
     * @dev If `to` refers to a smart contract, it must implement 
     *      {IERC1155Receiver-onERC1155BatchReceived} and return the
     *      acceptance magic value.
     * @param to The address which the token is going to
     * @param id The ID of the token being transferred
     * @param amount The amount of tokens being transferred
     * @param data Additional data with no specified format
     */
    function _mint(
          address to
        , uint256 id
        , uint256 amount
        , bytes memory data
    ) 
        internal 
        virtual 
    {
        require(to != address(0), "ERC1155: mint to the zero address");
        require(_owners[id] == address(0), "ERC1155D: supply exceeded");
        require(amount < 2, "ERC1155D: exceeds supply");

        address operator = _msgSender();
        uint256[] memory ids = _asSingletonArray(id);
        uint256[] memory amounts = _asSingletonArray(amount);

        _beforeTokenTransfer(
              operator
            , address(0)
            , to
            , ids
            , amounts
            , data
        );

        /**
         * @dev The ERC1155 spec allows for transfering zero tokens, but we are *      still expected to run the other checks and emit the event. But *      we don't want an ownership change in that case 
         */
        if (amount == 1) {
            _owners[id] = to;
        }

        emit TransferSingle(
              operator
            , address(0)
            , to
            , id
            , amount
        );

        _afterTokenTransfer(
              operator
            , address(0)
            , to
            , ids
            , amounts
            , data
        );

        _doSafeTransferAcceptanceCheck(
              operator
            , address(0)
            , to
            , id
            , amount
            , data
        );
    }

    /**
     * @notice Mints tokens of token type `id`, and assigns them to `to`.
     * @dev This does not implement smart contract checks according to ERC1155 
     *      so it exists as a separate function
     * @param to The address which the token is going to
     * @param id The ID of the token being transferred
     */
    function _mintSingle(
          address to
        , uint256 id
    ) 
        internal
        virtual 
    {
        // TODO: Do we need the other things here? Honestly I am not sure - Chance (I don't think so because this isn't part of the standard)

        require(_owners[id] == address(0), "ERC1155D: supply exceeded");
        
        _owners[id] = to; 
        
        emit TransferSingle(
              to
            , address(0)
            , to
            , id
            , 1
        );
    }

    /**
     * @notice Batch mint `amount` tokens of token type `id` 
     *         from `from` to `to`.
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {_mint}.
     * @dev If `to` refers to a smart contract, it must implement 
     *      {IERC1155Receiver-onERC1155BatchReceived} and return the
     *      acceptance magic value.
     * @param to The address which the token is going to
     * @param ids The IDs of the tokens being transferred
     * @param amounts The amounts of tokens being transferred
     * @param data Additional data with no specified format
     */

    // TODO: I don't know if we need to emit the same mint event twice now that we are emitting it for the token already when we initialize the function
    function _mintBatch(
          address to
        , uint256[] memory ids
        , uint256[] memory amounts
        , bytes memory data
    ) 
        internal 
        virtual 
    {
        require(to != address(0), "ERC1155: mint to the zero address");
        require(
              ids.length == amounts.length
            , "ERC1155: ids and amounts length mismatch"
        );

        address operator = _msgSender();

        _beforeTokenTransfer(
              operator
            , address(0)
            , to
            , ids
            , amounts
            , data
        );

        for (
            uint256 i; 
            i < ids.length; 
            i++
        ) {
            require(amounts[i] < 2, "ERC1155D: exceeds supply");
            require(_owners[ids[i]] == address(0), "ERC1155D: supply exceeded");

            /**
             * @dev The ERC1155 spec allows for transfering zero tokens, but 
             *      we are still expected to run the other checks and emit the
             *      event. But we don't want an ownership change in that case 
            */
            if (amounts[i] == 1) {
                _owners[ids[i]] = to;
            }
        }

        emit TransferBatch(
              operator
            , address(0)
            , to
            , ids
            , amounts
        );

        _afterTokenTransfer(
              operator
            , address(0)
            , to
            , ids
            , amounts
            , data
        );

        _doSafeBatchTransferAcceptanceCheck(
              operator
            , address(0)
            , to
            , ids
            , amounts
            , data
        );
    }

    /**
     * @notice Destroys `amount` tokens of token type `id` from `from`
     * @dev `from` cannot be the zero address.
     * @dev `from` must have at least `amount` tokens of token type `id`.
     * @param from The address which previously owned the token.
     * @param id The ID of the token being transferred.
     * @param amount The amount of token being transferred.
     */
    function _burn(
          address from
        , uint256 id
        , uint256 amount
    ) 
        internal 
        virtual 
    {
        require(from != address(0), "ERC1155: burn from the zero address");

        address operator = _msgSender();
        uint256[] memory ids = _asSingletonArray(id);
        uint256[] memory amounts = _asSingletonArray(amount);

        _beforeTokenTransfer(
            operator
            , from
            , address(0)
            , ids
            , amounts
            , ""
        );

        require(
                balanceOf(
                        from
                    , id
                ) > 0 && amount < 2
            , "ERC1155: insufficient balance for transfer"
        );

        /**
         * @dev The ERC1155 spec allows for transfering zero tokens, but 
         *      we are still expected to run the other checks and emit the
         *      event. But we don't want an ownership change in that case 
         */
        if (amount == 1) {
            _owners[id] = address(0);
        }

        emit TransferSingle(
              operator
            , from
            , address(0)
            , id
            , amount
        );

        _afterTokenTransfer(
              operator
            , from
            , address(0)
            , ids
            , amounts
            , ""
        );
    }

    /**
     * @notice Destroys `amount` tokens of token type `id` from `from`
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {_burn}.
     * @dev `from` cannot be the zero address.
     * @dev `from` must have at least `amount` tokens of token type `id`.
     * @param from The address which previously owned the token.
     * @param ids The ID of the token being transferred.
     * @param amounts The amount of token being transferred.
     */
    function _burnBatch(
          address from
        , uint256[] memory ids
        , uint256[] memory amounts
    ) 
        internal 
        virtual 
    {
        require(from != address(0), "ERC1155: burn from the zero address");
        require(
              ids.length == amounts.length
            , "ERC1155: ids and amounts length mismatch"
        );

        address operator = _msgSender();

        _beforeTokenTransfer(
              operator
            , from
            , address(0)
            , ids
            , amounts
            , ""
        );

        for (
            uint256 i; 
            i < ids.length; 
            i++
        ) {
            uint256 id = ids[i];

            require(
                    balanceOf(
                          from
                        , id
                    ) > 0 && amounts[i] < 2
                , "ERC1155: insufficient balance for transfer"
            );

            /**
             * @dev The ERC1155 spec allows for transfering zero tokens, but 
             *      we are still expected to run the other checks and emit the
             *      event. But we don't want an ownership change in that case 
            */
            if (amounts[i] == 1) {
                _owners[id] = address(0);
            }
        }

        emit TransferBatch(
              operator
            , from
            , address(0)
            , ids
            , amounts
        );

        _afterTokenTransfer(
              operator
            , from
            , address(0)
            , ids
            , amounts
            , ""
        );
    }

    /**
     * @notice Approve `operator` to operate on all of `owner` tokens
     * @param _owner The owner of tokens that is approving a new account.
     * @param operator The account being authorized to act on behalf.
     * @param approved The approved state of the operator
     */
    function _setApprovalForAll(
          address _owner
        , address operator
        , bool approved
    ) 
        internal 
        virtual 
    {
        require(_owner != operator, "ERC1155: setting approval status for self");
     
        _operatorApprovals[_owner][operator] = approved;
     
        emit ApprovalForAll(
              _owner
            , operator
            , approved
        );
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning, as well as batched variants.
     *
     * The same hook is called on both single and batched variants. For single
     * transfers, the length of the `id` and `amount` arrays will be 1.
     *
     * Calling conditions (for each `id` and `amount` pair):
     *
     * - When `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * of token type `id` will be  transferred to `to`.
     * - When `from` is zero, `amount` tokens of token type `id` will be minted
     * for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens of token type `id`
     * will be burned.
     * - `from` and `to` are never both zero.
     * - `ids` and `amounts` have the same, non-zero length.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
          address operator
        , address from
        , address to
        , uint256[] memory ids
        , uint256[] memory amounts
        , bytes memory data
    ) 
        internal 
        virtual {}

    /**
     * @dev Hook that is called after any token transfer. This includes minting
     * and burning, as well as batched variants.
     *
     * The same hook is called on both single and batched variants. For single
     * transfers, the length of the `id` and `amount` arrays will be 1.
     *
     * Calling conditions (for each `id` and `amount` pair):
     *
     * - When `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * of token type `id` will be  transferred to `to`.
     * - When `from` is zero, `amount` tokens of token type `id` will be minted
     * for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens of token type `id`
     * will be burned.
     * - `from` and `to` are never both zero.
     * - `ids` and `amounts` have the same, non-zero length.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(
          address operator
        , address from
        , address to
        , uint256[] memory ids
        , uint256[] memory amounts
        , bytes memory data
    ) 
        internal 
        virtual {}

    /**
     * @notice Validates that the recipient of an incoming token can 
     *         be accepted, held and used.
     * @param operator The address making this call.
     * @param from The address which previously owned the token.
     * @param to The address which the token is going to.
     * @param id The ID of the token being transferred.
     * @param amount The amount of tokens being transferred.
     * @param data Additional data with no specified format.
     */
    function _doSafeTransferAcceptanceCheck(
          address operator
        , address from
        , address to
        , uint256 id
        , uint256 amount
        , bytes memory data
    ) private {
        if (to.isContract()) {
            try IERC1155Receiver(to).onERC1155Received(
                  operator
                , from
                , id
                , amount
                , data
            ) returns (bytes4 response) {
                if (response != IERC1155Receiver.onERC1155Received.selector) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: transfer to non ERC1155Receiver implementer");
            }
        }
    }

    /**
     * @notice Batch implementation of validating that the recipient of 
     *         an incoming token(s) can be accepted, held and used.
     * @param operator The address making this call.
     * @param from The address which previously owned the token.
     * @param to The address which the token is going to.
     * @param ids The IDs of the tokens being transferred.
     * @param amounts The amounts of tokens being transferred.
     * @param data Additional data with no specified format.
     */
    function _doSafeBatchTransferAcceptanceCheck(
          address operator
        , address from
        , address to
        , uint256[] memory ids
        , uint256[] memory amounts
        , bytes memory data
    ) 
        private 
    {
        if (to.isContract()) {
            try IERC1155Receiver(to).onERC1155BatchReceived(
                  operator
                , from
                , ids
                , amounts
                , data
            ) returns (
                bytes4 response
            ) {
                if (response != IERC1155Receiver.onERC1155BatchReceived.selector) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: transfer to non ERC1155Receiver implementer");
            }
        }
    }

    /**
     * @notice Wraps a single uint256 into a uint256[]
     * @param element The number to turn into an array.
     * @return Array with the supplied element inside.
     */
    function _asSingletonArray(uint256 element) 
        internal 
        pure 
        returns (
            uint256[] memory
        ) 
    {
        uint256[] memory array = new uint256[](1);
        array[0] = element;

        return array;
    }

    /**
     * @notice Get the address that owns token `id`
     * @dev Reverts if check for non-existent token
     * @return Owning address of token
     */
    function ownerOf(uint256 id) 
        public 
        view 
        returns(
            address
        ) 
    {
        if(id < 9000 && _owners[id] == address(0x0))
            return mirror.ownerOf(id);

        return _owners[id];
    }

    /**
     * @notice Gets the full record of ownership.
     * @dev This is extremely gassy and IS NOT intended for on-chain usage.
     * @dev The return value will include address(0) as the owner of un-minted.
     * @dev This is to be used instead of the traditional walletOfOwner()
     * @return Full array of ownership address record
     */
    function getOwnershipRecordOffChain() 
        external 
        view 
        returns(
            address[9000] memory
        ) 
    {
        return _owners;
    }

    /**
     * @notice Get the balance (non-fungible implementation) of address.
     * @dev This is extremely gassy and IS NOT intended for on-chain usage.
     * @param account The address to check the total balance of.
     * @return Amount of tokens that are owned by account
     */
    function balanceOfOffChain(address account) 
        external 
        view 
        returns(
            uint256
        ) 
    {
        uint256 counter;
        
        for (
            uint256 i; 
            i < 9000; 
            i++
        ) {
            if (balanceOf(
                  account
                , i
            ) == 1) {
                counter++;
            }
        }

        return counter;
    }
}