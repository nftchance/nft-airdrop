// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import { MimeticMetadata } from "../Mimetics/MimeticMetadata.sol";
import { INonDilutive } from "../INonDilutive.sol";

import { ERC721 } from "./ERC721.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

error MintExceedsMaxSupply();
error MintCostMismatch();
error MintNotEnabled();

error MigrationNotEnabled();
error MigrationDuplicateBlocked();
error MigrationExceedsMaxSupply();

error GenerationAlreadyLoaded();
error GenerationNotDifferent();
error GenerationNotEnabled();
error GenerationNotDowngradable();
error GenerationNotToggleable();
error GenerationCostMismatch();

error TokenNonExistent();
error TokenNotRevealed();
error TokenRevealed();
error TokenOwnerMismatch();

error WithdrawFailed();

contract NonDilutive721 is 
     ERC721
    ,MimeticMetadata
    ,INonDilutive
{
    using Strings for uint256;

    bool public migrationOpen;

    constructor(
         string memory _name
        ,string memory _symbol
        ,string memory _baseUnrevealedURI
        ,string memory _baseURI
        ,uint256 _MAX_SUPPLY
        ,address _migratedFrom
        
    ) ERC721(
          _name
        , _symbol
        , _MAX_SUPPLY
        , _migratedFrom
    ) {
        MAX_SUPPLY = _MAX_SUPPLY;

        baseUnrevealedURI = _baseUnrevealedURI;

        loadGeneration( 
              0             // layer
            , true          // enabled   (can be focused by holders)
            , true          // locked    (cannot be removed by project owner)
            , true         // sticky    (cannot be removed by owner)
            , 0            // cost      (does not cost to convert to or back to)
            , 0            // closure   (can be swapped to forever)
            , _baseURI
        );


    }

    /**
     * @notice Function that controls which metadata the token is currently 
     *         utilizing. By default every token is using layer zero which is 
     *         loaded during the time of contract deployment. Cannot be 
     *         removed, is immutable, holders can always revert back. However, 
     *         if at any time they choose to "wrap" their token then it is 
     *         automatically reflected here.
     * @notice Errors out if the token has not yet been revealed within 
     *         this collection.
     * @param _tokenId the token we are getting the URI for.
     * @return _tokenURI The internet accessible URI of the token .
     */
    function tokenURI(
        uint256 _tokenId
    ) 
        override 
        public 
        view 
        returns (
            string memory
        ) 
    {
        return _tokenURI(_tokenId);
    }

    /**
     * @notice Allows any user to see the layer that a token currently has enabled.
     */
    function getTokenGeneration(
        uint256 _tokenId
    )
        override
        public
        virtual
        view
        returns(
            uint256
        )
    {
        return _getTokenGeneration(_tokenId);
    }

    /**
     * @notice Function that allows token holders to focus a generation and 
     *         wear their skin. This is not in control of the project 
     *         maintainers once the layer has been initialized.
     * @dev This function is utilized when building supporting functions around
     *      the concept of extendable metadata. For example, if Doodles were to
     *      drop their spaceships, it would be loaded and then enabled by the 
     *      holder through this function on a front-end.
     * @param _layerId The layer that this generation belongs on. 
     *                 The bottom is zero.
     * @param _tokenId the token that we are updating the metadata for
     */
    function focusGeneration(
         uint256 _layerId
        ,uint256 _tokenId
    )
        override
        public
        virtual
        payable
    {
        // Make sure the owner of the token is operating
        if(ownerOf(_tokenId) != msg.sender) revert TokenOwnerMismatch();
        // if(true == false) revert TokenOwnerMismatch();


        _focusGeneration(_layerId, _tokenId);
    }

    /**
     * @notice Withdraws the money from this contract to Chance + the owner.
     */
    function withdraw() 
        public 
        payable 
        onlyOwner 
    {
        /**
         * @dev Pays Chance 5% -- Feel free to remove this or leave it. Up to
         *      you. You really don't even need to credit me in your code. 
         *      Realistically, you can yoink all of this without me ever 
         *      knowing or caring. That's why this is open source. But 
         *      of course, I have to keep on the lights somehow :)
         */ 
        (bool chance, ) = payable(
            0x62180042606624f02D8A130dA8A3171e9b33894d
        ).call{
            value: address(this).balance * 5 / 100
        }("");
        if(!chance) revert WithdrawFailed();
        
        (bool creator, ) = payable(
            owner()
        ).call{
            value: address(this).balance
        }("");
        if(!creator) revert WithdrawFailed();
    }

    /**
     * @dev This is the most extreme of the basic sale enables. When using
     *      this, you will start your sale through Flashbots so that bots 
     *      cannot backrun you.
     */
    function toggleMigration()
        public
        virtual
        onlyOwner
    { 
        migrationOpen = !migrationOpen;
    }

    /**
     * @notice The public minting function of this contract while making 
     *         sure that supply is not exceeded and the proper $$ has 
     *         been supplied.
     */
    function migrate(uint256 _tokenId) 
        public 
        virtual 
        payable 
    {
        if(!migrationOpen) revert MigrationNotEnabled();
        
        // Validate existing supply
        if(_exists(_tokenId)) revert MigrationDuplicateBlocked();
        if(_tokenId >= MAX_SUPPLY) revert MigrationExceedsMaxSupply();

        // Validate they are the owner of the Parent/Child
        if(msg.sender != ownerOf(_tokenId)) revert TokenOwnerMismatch();

        _mint(msg.sender, _tokenId);
    }
}