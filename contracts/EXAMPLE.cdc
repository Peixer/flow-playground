// SPDX-License-Identifier: Unlicense

import NonFungibleToken from "./NonFungibleToken.cdc"
import MetadataViews from "./MetadataViews.cdc"

pub contract EXAMPLE: NonFungibleToken {

  // -----------------------------------------------------------------------
  // EXAMPLE contract-level fields.
  // These contain actual values that are stored in the smart contract.
  // -----------------------------------------------------------------------
  
  // The total supply that is used to create NFT. 
  // Every time a NFT is created,  
  // totalSupply is incremented by 1 and then is assigned to NFT's ID.
  pub var totalSupply: UInt64

  // The next template ID that is used to create Template. 
  // Every time a Template is created, nextTemplateId is assigned 
  // to the new Template's ID and then is incremented by 1.
  pub var nextTemplateId: UInt64
    
  // The next NFT ID that is used to create NFT. 
  // Every time a NFT is created, nextNFTId is assigned 
  // to the new NFT's ID and then is incremented by 1.
  pub var nextNFTId: UInt64

  // Variable size dictionary of Template structs
  access(account) var templateDatas: {UInt64: Template}  

  // Variable size dictionary of minted templates structs
  access(account) var numberMintedByTemplate: {UInt64: UInt64}
  
  /// Path where the public capability for the `Collection` is available
  pub let collectionPublicPath: PublicPath

  /// Path where the `Collection` is stored
  pub let collectionStoragePath: StoragePath

  /// Path where the private capability for the `Collection` is available
  pub let collectionPrivatePath: PrivatePath
  
  /// Event used on create template
  pub event TemplateCreated(templateId: UInt64, databaseID: String)

  /// Event used on destroy NFT from collection
  pub event NFTDestroyed(nftId: UInt64)

  /// Event used on withdraw NFT from collection
  pub event Withdraw(id: UInt64, from: Address?)

  /// Event used on deposit NFT to collection
  pub event Deposit(id: UInt64, to: Address?)
  
  /// Event used on mint NFT
  pub event NFTMinted(nftId: UInt64, edition: UInt64, packID: UInt64, templateId: UInt64, owner: Address)

  /// Event used on contract initiation
  pub event ContractInitialized()
    
  // -----------------------------------------------------------------------
  // EXAMPLE contract-level Composite Type definitions
  // -----------------------------------------------------------------------
  // These are just *definitions* for Types that this contract
  // and other accounts can use. These definitions do not contain
  // actual stored values, but an instance (or object) of one of these Types
  // can be created by this contract that contains stored values.
  // ----------------------------------------------------------------------- 
  
  // Template is a Struct that holds metadata associated with a specific 
  // nft
  //
  // NFT resource will all reference a single template as the owner of
  // its metadata. The templates are publicly accessible, so anyone can
  // read the metadata associated with a specific NFT ID
  //
  pub struct Template {
    pub let templateId: UInt64
    pub let maxEditions: UInt64
    pub let creationDate: UInt64    
    pub let rarity: UInt64    
    pub let metadata: {String: String}

    init(metadata: {String: String}, maxEditions: UInt64, creationDate: UInt64, rarity: UInt64, databaseID: String) {
      pre {
        metadata.length != 0: "metadata cannot be empty"
        maxEditions != 0: "maxEditions cannot be 0"
        rarity != 0: "rarity cannot be 0"
      }

      self.templateId = EXAMPLE.nextTemplateId
      self.metadata = metadata
      self.maxEditions = maxEditions
      self.creationDate = creationDate
      self.rarity = rarity

      EXAMPLE.nextTemplateId = EXAMPLE.nextTemplateId + UInt64(1)

      emit TemplateCreated(templateId: self.templateId, databaseID: databaseID)
    }
  }

  // NFTData is a Struct that holds template's ID, metadata, 
  // edition number and rarity field
  //
  pub struct NFTData {
    pub let templateId: UInt64
    pub let edition: UInt64
    pub let rarity: UInt64
    pub let packID: UInt64
    pub let metadata: {String: String}

    init(metadata: {String: String}, templateId: UInt64, edition: UInt64, rarity: UInt64, packID: UInt64) {
      self.templateId = templateId
      self.metadata = metadata
      self.edition = edition
      self.rarity = rarity
      self.packID = packID
    }
  }

  // The resource that represents the NFT
  //
  pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
    pub let id: UInt64
    pub let data: NFTData

    init(edition: UInt64, metadata: {String: String}, templateId: UInt64, rarity: UInt64, packID: UInt64, owner: Address) {
      self.id = EXAMPLE.nextNFTId

      self.data = NFTData(metadata: metadata, templateId: templateId, edition: edition, rarity: rarity, packID: packID)

      emit NFTMinted(nftId: self.id, edition: self.data.edition, packID: self.data.packID, templateId: templateId, owner: owner)
      EXAMPLE.nextNFTId = EXAMPLE.nextNFTId + UInt64(1)
      EXAMPLE.totalSupply = EXAMPLE.totalSupply + 1
    }

    pub fun getViews(): [Type] {
        return [
        ]
    }

    pub fun resolveView(_ view: Type): AnyStruct? {
        return nil
    }

    destroy() {
      EXAMPLE.totalSupply = EXAMPLE.totalSupply - 1
      emit NFTDestroyed(nftId: self.id)
    }
  }

  pub resource interface CollectionPublic {
    pub fun deposit(token: @NonFungibleToken.NFT) 
    pub fun getIDs(): [UInt64]
    pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT 
    pub fun borrow(id: UInt64): &EXAMPLE.NFT?
  }

  // Collection is a resource that every user who owns NFTs 
  // will store in their account to manage their NFTS
  //
  pub resource Collection: NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, CollectionPublic, MetadataViews.ResolverCollection { 
    
    // Dictionary of NFTs conforming tokens
    // NFT is a resource type with a UInt64 ID field
    pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

    init() {
      self.ownedNFTs <- {}
    }

    // withdraw removes an EXAMPLE from the Collection and moves it to the caller
    //
    // Parameters: withdrawID: The ID of the NFT 
    // that is to be removed from the Collection
    //
    // returns: @NFT the token that was withdrawn
    pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
      // Remove the nft from the Collection
      let token <- self.ownedNFTs.remove(key: withdrawID) 
          ?? panic("Cannot withdraw: EXAMPLE does not exist in the collection")

      emit Withdraw(id: token.id, from: self.owner?.address)
      
      // Return the withdrawn token
      return <-token
    }


    // deposit takes a EXAMPLE and adds it to the Collections dictionary
    //
    // Paramters: token: the NFT to be deposited in the collection
    //
    pub fun deposit(token: @NonFungibleToken.NFT) {
      let token <- token as! @NFT

      let id = token.id

      let oldToken <-self.ownedNFTs[id] <-token

      if self.owner?.address != nil {
        emit Deposit(id: id, to: self.owner?.address)
      }

      destroy oldToken
    }

    // getIDs returns an array of the IDs that are in the Collection
    pub fun getIDs(): [UInt64] {
      return self.ownedNFTs.keys
    }

    // borrow Returns a borrowed reference to a EXAMPLE in the Collection
    // so that the caller can read its ID
    //
    // Parameters: id: The ID of the NFT to get the reference for
    //
    // Returns: A reference to the NFT
    //
    pub fun borrow(id: UInt64): &EXAMPLE.NFT? {
      if self.ownedNFTs[id] != nil {
        let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
        return ref as! &EXAMPLE.NFT
      } else {
        return nil
      }
    }
    
    pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
      return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
    }

    pub fun borrowViewResolver(id: UInt64): &{MetadataViews.Resolver} {      
      let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
      let EXAMPLEsNFT = nft as! &NFT
      return EXAMPLEsNFT as &{MetadataViews.Resolver}
    }
    
    // If a transaction destroys the Collection object,
    // All the NFTs contained within are also destroyed!
    // Much like when Damian Lillard destroys the hopes and
    // dreams of the entire city of Houston.
    //
    destroy() {
      destroy self.ownedNFTs
    }
  }

  // -----------------------------------------------------------------------
  // EXAMPLE contract-level function definitions
  // -----------------------------------------------------------------------

  // createEmptyCollection creates a new Collection a user can store 
  // it in their account storage.
  //
  pub fun createEmptyCollection(): @Collection {
    return <-create EXAMPLE.Collection()
  }

  init() {
    // Paths
    self.collectionPublicPath = /public/EXAMPLECollection
    self.collectionStoragePath = /storage/EXAMPLECollection
    self.collectionPrivatePath = /private/EXAMPLECollection

    self.nextTemplateId = 1
    self.nextNFTId = 1
    self.totalSupply = 0
    self.templateDatas = {}
    self.numberMintedByTemplate = {}
    
    emit ContractInitialized()
  }
}
