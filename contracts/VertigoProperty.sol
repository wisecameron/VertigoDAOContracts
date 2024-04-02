//SPDX-License-Identifier: Unlicensed

/*
    Cameron Warnick https://www.linkedin.com/in/cameron-warnick-64a25222a/


TODO:

Special properties -> When purchased, set mapping purchased to true
    -> This way, user can sell property nft and cannot buy again.

NEEDS WORK:
Property transfer, property ownership (unique id)

*/

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import './PropertyStorage.sol';
import './ProfileStorage.sol';
import './VertigoProfile.sol';
import './VertigoToken.sol';
import './StorageHandler.sol';

/*
    TODO:  Store PackedPRoperty data field in StorageHandler system,
    including rentalTime value.  Change packedPoperty to only include data and name.
    When name is needed for a property, simply grab it from arrays.
    -> User data is stored in a separate contract. 
    
        /*
            level               8 0
            defaultProperty     8 1
            VCashProperty       8 2
            buyable             8 3
            incomeIsDelegated   8 4
            buyLimit            16 5
            index               16 6
            owner               32 7
            payBonus            64 8
            basePrice           256 9
            rentalTime          256 10
        */


contract VertigoProperty is ERC721
{
    struct PackedProperty
    {
        uint256 data;
        string name;
    }

    struct RentalOffer
    {
        uint256 priceVert;
        uint256 dayCount;
        uint256 propertyId;
    }

	PackedProperty[] VCashProperties;
	PackedProperty[] VertigoProperties;
	PackedProperty[] SpecialProperties;

    mapping(uint256 => mapping(bool => mapping(bool => string))) URITemplates; //index -> isVCash? -> isPremium? -> uri --- URITemplates
    mapping(uint256 => mapping(bool => string)) SpecialURITemplates;  //index -> isPremium -> uri
    mapping(uint256 => mapping(address => RentalOffer)) rentalOffers;

    address public PropertyStorageContract;
    address public ProfileStorageContract;
    address public vertigoContract;
    address public profileContract;
    address public _owner;
    uint256 public minted;

    event enabled(address, address);
    event propertyCreated(uint256);

    constructor() ERC721("Property", "VPROP") 
    {
        _owner = msg.sender;
    }

    function set_periphery_contracts(address vertigo, address profile)
    external
    {
        require(msg.sender == _owner);
        vertigoContract = vertigo;
        profileContract = profile;

        emit enabled(vertigo, profile);
    }

    function set_profile_storage_contract(address storageAddress)
    external
    {
        require(msg.sender == _owner);
        ProfileStorageContract = storageAddress;
    }

    function get_property_struct(uint256 propertyID, uint256 specialIndex)
    public view
    returns(PropertyStorage.Property memory)
    {
        PropertyStorage.Property memory rawProperty;
        PackedProperty memory packed;

        if(specialIndex == 0)
        {
            return rawProperty;
        }

        if(specialIndex == 1)
        {
            packed = VCashProperties[propertyID];
        }
        else if(specialIndex == 2)
        {
            packed = VertigoProperties[propertyID];
        }
        else
        {
            packed = SpecialProperties[propertyID];
        }
        

        rawProperty.propertyName = packed.name;
        uint256 data = packed.data;

        rawProperty.basePrice = uint256(uint128(data));                                     //0 basePrice
        rawProperty.payBonus = uint256(uint32(data >> 128));                                //1 payBonus
        rawProperty.index = (uint256(uint16(data >> 160)));                                 //2 index
        rawProperty.defaultProperty = (uint256(uint8(data >> 176)) == 1) ? true : false;    //3 defaultProperty
        rawProperty.VCashProperty = (uint256(uint8(data >> 184)) == 1) ? true : false;      //4 VCashProperty
        rawProperty.buyable = (uint256(uint8(data >> 192)) == 1) ? true : false;            //5 buyable
        rawProperty.incomeIsDelegated = (uint8(data >> 200) == 1) ? true : false;           //6 incomeIsDelegated
        rawProperty.level = uint256(uint8(data >> 208));                                    //7 level
        rawProperty.buyLimit = uint256(uint16(data >> 216));                                //8 buyLimit
        rawProperty.owner = uint256(uint32(data >> 232));                                   //9 owner

        return rawProperty;
    }

    function set_storage_contract(address storageContract, address childContract)
    external
    {
        require(msg.sender == _owner);
        PropertyStorageContract = storageContract;
        StorageHandler sh = StorageHandler(PropertyStorageContract);

		uint256[] memory Bits = new uint256[](11);
		uint256[11] memory bits = [uint256(8),8,8,8,8,16,16,32,64,256,256];

		for(uint i = 0; i < bits.length; i++)
		{
			Bits[i] = bits[i];
		}

        sh.initialize(childContract, address(this), Bits, msg.sender);
    }

    function modify_packed_property_struct(uint256 index, uint256 specialIndex, uint256 newValue, uint256 packedIndex)
    external
    {
        require(msg.sender == _owner);
        _modify_packed_property_struct(index, specialIndex, newValue, packedIndex);
    }

    function _modify_packed_property_struct(uint256 propertyID, uint256 specialIndex, uint256 newValue, uint256 index)
    internal
    returns(uint256 indexChanged)
    {
        require(specialIndex > 0);

        //---- Check that number does not exceed set limit. ----//
        if(index == 0)
        {
            require(newValue <= 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF); //128 bit  limit
        }
        else if(index == 1 || index == 9)
        {
            require(newValue <= 0xFFFFFFFF); // 32 bit limit
        }
        else if(index == 2 || index == 8)
        {
            require(newValue <= 0xFFFF); //16 bit limit
        }
        else if(index < 8)
        {
            require(newValue <=  0xFF); // 8 bit limit
        }

        uint[10] memory dataArr;
        uint256 dataU = (specialIndex == 1) ? VCashProperties[propertyID].data : (specialIndex == 2) ? VertigoProperties[propertyID].data : SpecialProperties[propertyID].data;
        assert(dataU != 0);
        dataArr = get_property_array(dataU);
        
        //---- Change specified value to new value. ----//
        dataArr[index] = newValue;

        //---- Re-create data uint256. ----//
        uint256 data;
        data = dataArr[0];
        data |= dataArr[1] << 128;
        data |= dataArr[2] << 160;
        data |= dataArr[3] << 176;
        data |= dataArr[4] << 184;
        data |= dataArr[5] << 192;
        data |= dataArr[6] << 200;
        data |= dataArr[7] << 208;
        data |= dataArr[8] << 216;
        data |= dataArr[9] << 232;

        //---- Set [Game VCash Property]... to new value. ----//
        if(specialIndex == 1)
        {
            VCashProperties[propertyID].data = data;
        }
        else if(specialIndex == 2)
        {
            VertigoProperties[propertyID].data = data;
        }
        else if(specialIndex == 3)
        {
            SpecialProperties[propertyID].data = data;
        }

        return index;
    }

                                  //0 basePrice
                          //1 payBonus
                            //2 index
   //3 defaultProperty
     //4 VCashProperty
      //5 buyable
         //6 incomeIsDelegated
                               //7 level
                           //8 buyLimit
                                   //9 owner

    function get_property_array(uint256 data)
    public pure
    returns(uint256[10] memory)
    {
        uint256[10] memory rawData;

        rawData[0] = uint256(uint128(data));
        rawData[1] = uint256(uint32(data >> 128));
        rawData[2] = uint256(uint16(data >> 160));
        rawData[3] = uint256(uint8(data >> 176));
        rawData[4] = uint256(uint8(data >> 184));
        rawData[5] = uint256(uint8(data >> 192));
        rawData[6] = uint256(uint8(data >> 200));
        rawData[7] = uint256(uint8(data >> 208));
        rawData[8] = uint256(uint16(data >> 216));
        rawData[9] = uint256(uint32(data >> 232));


        return rawData;
    }

    /*
        @dev mint a property card NFT. This function can only be called by the VertigoToken contract
        @dev requires: user has purchased, but not minted, corresponding NFT
        @return the NFT's unique ID 
    */
    function mint(address recipient, uint256 profileId, uint256 propertyIndex, bool VCash, bool defaultProperty)
    external
    returns(uint256 newId)
    {
        VertigoProfile link = VertigoProfile(address(profileContract));
        StorageHandler sh = StorageHandler(PropertyStorageContract);

        if(defaultProperty)
        {
            require(link.ownerOf(profileId) == recipient);
            require(msg.sender == profileContract);
        }
        else
        {
            require(msg.sender == vertigoContract);
        }

        newId = minted;
        minted += 1;
        sh.push();

        uint256 data = (defaultProperty) ? ((VCash) ? VCashProperties[propertyIndex].data : VertigoProperties[propertyIndex].data) 
        : SpecialProperties[propertyIndex].data;

        uint256[10] memory dataArr = get_property_array(data);
        uint256[] memory values = new uint256[](11);
        uint256[] memory indices = new uint256[](11);
		uint256[11] memory valuesData = [0, dataArr[3], dataArr[4], 0, 0, 0, dataArr[2], 0, dataArr[1], dataArr[0], 0];

		for(uint i = 0; i < valuesData.length; i++)
		{
			values[i] = valuesData[i];
            indices[i] = i;
		}

        if(defaultProperty)
        {
            values[7] = profileId;
        }

        //port all data into user property
        sh.multimod(newId, indices, values);
        _mint(recipient, newId);
    }

    //VERIFIED
    function tokenURI(uint256 tokenId, bool defaultProperty)
    public view
    returns(string memory)
    {
        require(_exists(tokenId));

        StorageHandler sh = StorageHandler(PropertyStorageContract);

        uint256 index = sh.get_value(tokenId, 6);
        bool DEProperty = sh.get_value(tokenId, 2) == 1;
        bool premium = sh.get_value(tokenId, 0) == 10; //level

        if(!defaultProperty)
        {
            return(SpecialURITemplates[index][premium]);
        }

        return(URITemplates[index][DEProperty][premium]);
    }

    /*
        @dev Transfer premium NFT ownership to different address.  Does not transfer property income.
    */
    function transfer_property_ownership(address recipient, uint256 propertyId)
    external
    returns(bool)
    {
        StorageHandler sh = StorageHandler(PropertyStorageContract);

        //defaultProperty
        require(sh.get_value(propertyId, 1) == 0);

        require(msg.sender == ownerOf(propertyId));
        _transfer(msg.sender, recipient, propertyId);
        return true;
    }

    /*
        used to transfer NFT ownership after purchasing a Profile
        Note: Impossible to transfer default properties between Profile NFTs
        or transfer their income in any way.
    */
    function transfer_default_property_ownership(uint256 profileId, uint256 propertyId)
    external
    {
        VertigoProfile link = VertigoProfile(address(profileContract));

        //verify that the sender owns the profile but not the property.
        require(msg.sender == link.ownerOf(profileId));
        require(msg.sender != ownerOf(propertyId));

        //Two-way verification of above.
        StorageHandler sh = StorageHandler(PropertyStorageContract);

        uint256 owner = sh.get_value(propertyId, 7);
        uint256 defaultProperty = sh.get_value(propertyId, 1);

        require(owner == profileId);
        require(defaultProperty == 1);

        //transfer formal ownership to new address.
        _transfer(ownerOf(propertyId), msg.sender, propertyId);
    }

    
    function create_property(string memory propertyName, uint256 basePrice, uint256 payBonus, bool isVCashProperty, bool isDefaultProperty, string memory standardURI, string memory premiumURI)
    external
    returns(uint256)
	{
        require(msg.sender == _owner);
        uint256 index = (isDefaultProperty) ? (isVCashProperty) ? VCashProperties.length : VertigoProperties.length : SpecialProperties.length;

        PackedProperty memory newProperty;
		newProperty.name = propertyName;
        uint256 data = (isDefaultProperty && isVCashProperty) ? basePrice: basePrice * 1e18;
        data |= uint256(payBonus) << 128; //uint32 payBonus
        data |= index << 160; //uint16 index
        data |= uint256((isDefaultProperty) ? 1 : 0) << 176; //uint8 isDefaultProperty 
        data |= uint256((isVCashProperty) ? 1 : 0) << 184; // uint8 isVCashProperty
        newProperty.data = data;

        if(isDefaultProperty)
        {
            URITemplates[index][isVCashProperty][false] = standardURI;
            URITemplates[index][isVCashProperty][true] = premiumURI;
        }
        else
        {
            SpecialURITemplates[index][false] = standardURI;
            SpecialURITemplates[index][true] = premiumURI;
        }

        (isDefaultProperty) ? (isVCashProperty) ? VCashProperties.push(newProperty) : VertigoProperties.push(newProperty) 
        : SpecialProperties.push(newProperty);

        emit propertyCreated(index);

		return index;
	}

    function modify_URI(uint256 propertyIndex, string memory newURI, bool premium, bool VCashProperty)
    external
    {
        require(msg.sender == _owner);

        URITemplates[propertyIndex][VCashProperty][premium] = newURI;
    }

    /*
        default property only.
    */
    function upgrade_property(uint256 propertyIndex, uint256 profileId, address sender)
    external
    {
        VertigoProfile profileLink = VertigoProfile(profileContract);

        require(sender == ownerOf(propertyIndex));
        require(sender == profileLink.ownerOf(profileId));
        require(msg.sender == vertigoContract);

        //get value increase amount
        StorageHandler sh = StorageHandler(PropertyStorageContract);

        uint256 level = sh.get_value(propertyIndex, 0);
        uint256 defaultProperty = sh.get_value(propertyIndex, 1);
        //uint256 index = sh.get_value(propertyIndex, 6);
        //uint256 DEProperty = sh.get_value(propertyIndex, 2);
        uint256 payBonus = sh.get_value(propertyIndex, 8);

        require(level < 10);
        require(defaultProperty == 1);

        PropertyStorage.Property memory officialPropertyStruct = get_property_struct(sh.get_value(propertyIndex, 6), sh.get_value(propertyIndex, 2) == 1 ? 1 : 2);
        uint256 valueIncrease;

        if(level < 9)
        {
            valueIncrease = officialPropertyStruct.payBonus / 15;
        }
        else
        {
            //level 10 doubles property income.
            valueIncrease = officialPropertyStruct.payBonus;
        }

        uint256 newValue = payBonus + valueIncrease;

        uint256[] memory values;
        uint256[] memory indices;

        values[0] = level + 1;
        values[1] = newValue;
        indices[0] = 0; //level 
        indices[1] = 8; //payBonus

        //port all data into user property
        sh.multimod(propertyIndex, indices, values);
        
        //increase user income: profile -> incomePerTx
        uint256[] memory userProfile = profileLink.get_profile_data(profileId);
        require(profileLink.ownerOf(profileId) == sender);
        StorageHandler sh2 = StorageHandler(ProfileStorageContract);
        sh2.modify(profileId, 10, (userProfile[10] + valueIncrease) );
    }

    function get_user_property_upgrade_price(uint256 propertyIndex, uint256 profileId)
    external view
    returns(uint256 price)
    {
        StorageHandler sh = StorageHandler(PropertyStorageContract);

        price = sh.get_value(propertyIndex, 9);
        uint256 isDEProperty = sh.get_value(propertyIndex, 2);
        uint256 isDefaultProperty = sh.get_value(propertyIndex, 1);


        if(isDEProperty == 1 && isDefaultProperty == 1)
        {
            price *= 1e18;
            price /= 6;
        }

        VertigoProfile profileLink = VertigoProfile(profileContract);
        uint256 profileLevel = profileLink.get_profile_value(profileId, 6);
        uint256 discount = (price * profileLevel) / 500; 
        
        if(profileLevel == 50)
        {
            discount += (price * 5) / 1000;
        }
        

        price -= discount; //revert
    }

    function make_rental_offer(address propertyOwner, uint256 propertyId, uint256 price, uint256 timeInDays, uint256 senderProfileId)
    external
    {
        //verify that user you are sending to actually owns property, verify that desired time is valid
        require(ownerOf(propertyId) == propertyOwner);
        require(timeInDays <= 365 && timeInDays >= 0); // <==============

        //create offer with supplied data, upload to mapping rentalOffers to store.
        RentalOffer memory offer;
        offer.priceVert = price;
        offer.dayCount = timeInDays;
        offer.propertyId = propertyId;
        rentalOffers[senderProfileId][propertyOwner] = offer;
    }

    function accept_rental_offer(uint256 receiverProfileId, uint256 price, uint256 timeInDays, uint256 propertyId)
    external
    {
        //verify property ownership
        RentalOffer memory offer = rentalOffers[receiverProfileId][msg.sender];

        //verify time span is valid, user expected offer matches what is stored in blockchain data.
        require(offer.dayCount >= 0); 
        require(offer.dayCount == timeInDays);
        require(offer.priceVert == price);
        require(offer.propertyId == propertyId);

        StorageHandler sh = StorageHandler(PropertyStorageContract);
        uint256 rentalTime = sh.get_value(propertyId, 10);

        //verify sender is owner of property and it is not currently rented out
        require(msg.sender == ownerOf(propertyId));
        require(rentalTime == 0);

        //transfer vertigo tokens from recipient to owner.
        VertigoToken tokenLink = VertigoToken(vertigoContract);
        VertigoProfile profileLink = VertigoProfile(profileContract);

        //verify sender has requisite balance
        address f = profileLink.ownerOf(receiverProfileId);

        require(tokenLink.balanceOf(f) >= price * 1e18);

        tokenLink.force_transfer(f, msg.sender, (price * 1e18));

        //transfer property income
        transfer_property_income(offer.propertyId, receiverProfileId);
        sh.modify(propertyId, 10, block.timestamp + (timeInDays * 86400)); //set expiration date
    }

    function reclaim_rental_ownership(uint256 propertyId)
    external
    {
        StorageHandler sh = StorageHandler(PropertyStorageContract);

        //verify sender ADDRESS is special property NFT owner, verify it is rented, verify rental has expired
        require(msg.sender == ownerOf(propertyId));
        uint256 rentalTime = sh.get_value(propertyId, 10);

        require(rentalTime != 0); 
        require(rentalTime <= block.timestamp);

        VertigoProfile profileLink = VertigoProfile(address(profileContract));

        uint256 defaultProperty = sh.get_value(propertyId, 1);
        uint256 DEProperty = sh.get_value(propertyId, 2);
        uint256 propertyOwner = sh.get_value(propertyId, 7);
        uint256 payBonus = sh.get_value(propertyId, 8);

        require(defaultProperty == 0);

        //remove payout modifiers
        if(DEProperty == 1)
        {
            profileLink.modify_paybonus(propertyOwner, payBonus, true, true);
        }
        else
        {
            profileLink.modify_paybonus(propertyOwner, payBonus, false, true);
        }

        //remove ownership status, incomeDelegated status, reset rentedTime
        uint256[] memory values = new uint256[](2);
        uint256[] memory indices = new uint256[](2);

        values[0] = 0; //delegated->false
        values[1] = 0; //owner (user receiving income from property) set to 0 (null profile)

        indices[0] = 4;
        indices[1] = 7;
        
        sh.multimod(propertyId, indices, values);
        sh.modify(propertyId, 10, 0); //reset rental time
    }

        /*
        @dev allows property NFT owner to transfer property income recipient to new profile.
        //VERIFIED
    */
    function transfer_property_income(uint256 propertyId, uint256 recipientProfileId)
    internal
    returns(bool)
    {
        //must be special property type
        StorageHandler sh = StorageHandler(PropertyStorageContract);

        uint256 defaultProperty = sh.get_value(propertyId, 1);
        uint256 DEProperty = sh.get_value(propertyId, 2);
        uint256 payBonus = sh.get_value(propertyId, 8);

        require(defaultProperty == 0);

        //verify sender ADDRESS == owner of special property
        VertigoProfile profileLink = VertigoProfile(address(profileContract));
        require(msg.sender == ownerOf(propertyId));

        //increase payoutPerTx profile variable
        if(DEProperty == 1)
        {
            require(profileLink.modify_paybonus(recipientProfileId, payBonus, true, false) == 1);
        }
        else
        {
            require(profileLink.modify_paybonus(recipientProfileId, payBonus, false, false) == 1);
        }

        uint256[] memory values = new uint256[](2);
        uint256[] memory indices = new uint256[](2);

        values[0] = 1;
        values[1] = recipientProfileId;

        indices[0] = 4;
        indices[1] = 7;

        sh.multimod(propertyId, indices, values);

        return true;
    }

    function view_rental_offers(uint256 senderProfileId, address propertyOwner)
    external view
    returns(RentalOffer memory)
    {
        return(rentalOffers[senderProfileId][propertyOwner]);
    }
}