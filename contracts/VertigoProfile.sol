//SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import './ProfileStorage.sol';
import './VertigoToken.sol';
import './PropertyStorage.sol';
import './VertigoProperty.sol';
import './StorageHandler.sol';

    /*
    Cameron Warnick https://www.linkedin.com/in/cameron-warnick-64a25222a/

    Vertigo Profiles track user data and progress.  Notably, they are 
    tradeable NFTs.

    tier: uint8 0 
    multiplier: uint32 1 
    VCashPropertyIndex: uint8 2
    VERTPropertyIndex: uint8 3
    teamPayoutShare: uint8 4
    password: uint16 5
    VCashStaked: uint256 6
    userVCashBalance: uint256 7
    payoutPerTx: uint256 8
    pendingVCashDividends: uint256  9 
    lastUpdateTime: uint128 10
    profileLevel: uint32
    profileLifeTimeVCash: uint256
    */

contract VertigoProfile is ERC721
{
    mapping(address => uint256) whitelisted;
    mapping(address => uint256) connectorMap;
    mapping(uint256 => string) specialProfileURIs;
    mapping(uint256 => string) URIManager;

    /*
    Connector Map:
    Level 0 : No perms
    Level 1: Whitelist Approved
    Level 2: lifetimeVCash approved
    */

    address public  propertyContract;
    address public  vertigoContract;
    address public  profileStorageContract;

    address private _owner;

    uint256 public DarkEnergy;
    uint256 public  mintedCount;
    uint256 public tier3UpgradeThreshold;
    uint256 public tier3UpgradeValue;

    event VCashClaimed(uint256 amount);
    event Whitelist(address user, uint256 val);

    constructor() 
    ERC721("Vertigo Profile", "VFILE")
    {
        _owner = msg.sender; 
    }

    function check_enabled()
    external view
    returns(bool)
    {
        return !(vertigoContract == address(0));
    }

    function modify_dark_energy(uint256 amount, uint256 increase)
    internal
    {
        if(increase == 1)
        {
            DarkEnergy += amount;
        }
        if(increase == 0)
        {
            require(DarkEnergy >= amount);
            DarkEnergy -= amount;
        }
    }

    function set_storage_contract(address storageHandlerContract, address storageSystemContract)
    external
    {
        require(msg.sender == _owner);
		uint256[] memory profileBits = new uint256[](15);
		uint256[15] memory bits = [uint256(8),8,8,16,64,128,256,256,256,256,256,256,256,256,256];

		for(uint i = 0; i < bits.length; i++)
		{
			profileBits[i] = bits[i];
		}

        profileStorageContract = storageHandlerContract;
        StorageHandler sh = StorageHandler(storageHandlerContract);
        sh.initialize(storageSystemContract, address(this), profileBits, msg.sender);
        sh.update_parent(propertyContract, 2, msg.sender);
    }

    function tokenURI(uint256 profileId)
    public view
    virtual override
    returns(string memory)
    {
        require(_exists(profileId));
        StorageHandler sh = StorageHandler(profileStorageContract);
        
        if((bytes(specialProfileURIs[profileId])).length != 0)
        {
            return specialProfileURIs[profileId];
        }

        return(URIManager[sh.get_value(profileId, 0)]); //tier
    }

    //Returns claimable Dark Energy for a user.
    function view_total_pending_vcash_earnings(uint256 profileId)
    external view
    returns(uint256)
    {
        require(_exists(profileId));
        StorageHandler sh = StorageHandler(profileStorageContract);

        uint256 payoutPerTx = sh.get_value(profileId, 10);
        uint256 lastUpdateTime = sh.get_value(profileId, 7);
        uint256 multiplier = sh.get_value(profileId, 5);
        uint256 pendingDEDividends = sh.get_value(profileId, 11);

        uint256 pendingEarnings = 0;
        if(payoutPerTx > 0)
        {
            uint256 elapsedTime = block.timestamp - lastUpdateTime;

            //21 day unclaimed limit
            if(elapsedTime < 1814400)
            {
                pendingEarnings = ( ( (elapsedTime * payoutPerTx) / 86400) * multiplier) / 1000;
            }
        }
        
        return pendingEarnings + pendingDEDividends;
    }

    function get_profile_data(uint256 profileId)
    external view
    returns (uint256[] memory)
    {
        StorageHandler sh = StorageHandler(profileStorageContract);
        return(sh.get_array(profileId));
    }

    function get_profile_value(uint256 profileId, uint256 index)
    external view
    returns(uint256)
    {
        StorageHandler sh = StorageHandler(profileStorageContract);
        return(sh.get_value(profileId, index));
    }

    function set_upgrade_values(uint256 threshold, uint256 scalar)
    external
    {
        require(msg.sender == _owner);

        if(threshold > 0)
        {
            tier3UpgradeThreshold = threshold;
        }
        if(scalar > 0)
        {
            tier3UpgradeValue= scalar;
        }
    }

    //establish connection to vertigoToken.sol & vertigoProperty.sol
    function set_periphery_contracts(address vertigo, address property)
    external
    {
        require(msg.sender == _owner);
        vertigoContract = vertigo;
        propertyContract = property;

        connectorMap[vertigoContract] = 419;
        connectorMap[propertyContract] = 419;
    }

    //set tiered URI, or set a special URI for an individual Profile.
    function set_URI(string memory newURI, uint256 tier, uint256 profileId) //profileID for special URI only
    external
    {
        require(msg.sender == _owner);

        if(profileId != 0)
        {
            specialProfileURIs[profileId] = newURI;
            return;
        }

        URIManager[tier] = newURI;
    }
   
    /*
        Whitelist user into one of three tiers.
    */
    function whitelist_user(address userAddress, uint256 tier)
    external 
    {
        require(msg.sender == _owner || connectorMap[msg.sender] == 1);

        whitelisted[userAddress] = tier;

        emit Whitelist(userAddress, whitelisted[userAddress]);
    }

    /********** Called by other contract **********/

    /*
        Increases or decreases Profile income: used by Property rental system.
    */
    function modify_paybonus(uint256 profileId, uint256 amount, bool VCash, bool decrease)
    external
    returns(uint256 success)
    {
        require(_exists(profileId));
        require(msg.sender == propertyContract);

        //Calculate & store pending earnings to prevent false income boosting.
        calculate_vcash_earnings(profileId);

        StorageHandler sh = StorageHandler(profileStorageContract);
        uint256 multiplier = sh.get_value(profileId, 5);
        uint256 payoutPerTx = sh.get_value(profileId, 10);

        if(decrease)
        {
            if(VCash)
            {
                require(payoutPerTx >= amount);
                //decrease payoutPerTx
                sh.modify(profileId, 10, (payoutPerTx - amount));
                return 1;
            }
            require((multiplier - amount) >= 1000);
            //decrease multiplier
            sh.modify(profileId, 5, (multiplier - amount));
            return 1;
        }
        else 
        {
            if(VCash)
            {
                //increase payoutPerTx
                sh.modify(profileId, 10, (payoutPerTx + amount));
                return 1;
            }
            //increase multiplier
            sh.modify(profileId, 5, (multiplier + amount));
            return 1;
        }
    }
    
    /*
        Mint a new profile.
        Caller: VertigoToken.sol
        Requires: whitelisted[recipient] > 0
    */
    function mint(address recipient)
    external 
    returns(uint256 newId, bool success)
    {
        require(msg.sender == vertigoContract);
        require(whitelisted[recipient] > 0);

        newId = mintedCount;
        mintedCount += 1;
        _mint(recipient, newId);

        StorageHandler sh = StorageHandler(profileStorageContract);
        sh.push();
        //multiplier
        sh.modify(newId, 5, 1000);
        //tier
        sh.modify(newId, 0, whitelisted[recipient]);

        //if tier 1, set level to max.
        if(whitelisted[recipient] == 1) 
        {
            sh.modify(newId, 6, 50);
        }

        //remove whitelisted status.
        whitelisted[recipient] = 0;
        success = true;
    }

    //Dark Energy staking -> called from VertigoToken.sol
    function stake_vcash(uint256 profileId, uint256 quantity)
    external
    returns(uint256 success)
    {
        require(msg.sender == vertigoContract);
        StorageHandler sh = StorageHandler(profileStorageContract);
        
        uint256 userDEBalance = sh.get_value(profileId, 9);
        uint256 level = sh.get_value(profileId, 6);
        uint256 tier = sh.get_value(profileId, 0);
        uint256 staked = sh.get_value(profileId, 8);

        require(quantity <= userDEBalance);

        //remove staked Dark Energy from user balance.
        sh.modify(profileId, 9, (userDEBalance - quantity));
        modify_dark_energy(quantity, 0);

        //Apply level bonus : doubled for tier 1 (max 10% bonus)
        if(level > 0)
        {
            quantity += (((quantity * level) / (tier == 1 ? 500 : 1000)));
        }

        //Credit user with stake
        sh.modify(profileId, 8, staked + quantity);
        success = 1;
    }

    /*
        * Claims all property income
        * Updates user password to current staking pool password.
        * If user is tier 2 or better, claims 150 Dark Energy default payout.
        * 
    */
    function weekly_reset(uint256 profileId)
    external
	{
        require(msg.sender == vertigoContract);
        require(_exists(profileId));

        StorageHandler sh = StorageHandler(profileStorageContract);
        uint256 userPassword = sh.get_value(profileId, 4);
        uint256 DEStaked = sh.get_value(profileId, 8);

        VertigoToken VERTLink = VertigoToken(vertigoContract);
        uint256 currentPass = VERTLink.password();

        //claim all pending income from properties.
		handle_pending_vcash(profileId);

        //If the user has already claimed this week.
        if(userPassword == currentPass)
        {
			return;
        }
        //if the user has not claimed this week & they staked in the last week's pool.
        else if(userPassword == currentPass - 1 && DEStaked > 0)
        {
            //claim staking earnings.
            VertigoToken v = VertigoToken(vertigoContract);
            v.retrieve_staking_dividends_from_withdrawal_pool(ownerOf(profileId), userPassword, DEStaked);
        }

        //set VCashStaked query to zero.
        sh.modify(profileId, 8, 0);

        //set password to current pool password.
        sh.modify(profileId, 4, currentPass);

        //Claim DE default income
        //increase user DE balance
        if(sh.get_value(profileId, 0) < 3)
        {
            sh.modify(profileId, 9, (sh.get_value(profileId, 9) + 150));
            modify_dark_energy(150, 1);
            sh.modify(profileId, 12, (sh.get_value(profileId, 12) + 150));
            return;
        } 
        else
        {
            sh.modify(profileId, 9, (sh.get_value(profileId, 9) + 15));
            modify_dark_energy(15, 1);
            sh.modify(profileId, 12, (sh.get_value(profileId, 12) + 15));
        }
	}

    function buy_vcash_property(uint256 profileId)
    external
    returns(uint256 propertyId)
	{
        require(msg.sender == vertigoContract);

        StorageHandler sh = StorageHandler(profileStorageContract);
     
        VertigoToken tokenLink = VertigoToken(vertigoContract);
        VertigoProperty propertyLink = VertigoProperty(propertyContract);
        PropertyStorage.Property memory shopProperty = propertyLink.get_property_struct(propertyId, 1);

        uint256 password_curr = tokenLink.password();
        uint256 propertyIndex = sh.get_value(profileId, 1);
        uint256 tier = sh.get_value(profileId, 0);
        uint256 DEBal = sh.get_value(profileId, 9);
        uint256 payoutPerTx = sh.get_value(profileId, 10);

        require(tier == 2 || tier == 1);
		require(DEBal >= shopProperty.basePrice);
		require(sh.get_value(profileId, 4) == password_curr);

        //Prevent boosting past income by buying property before claiming.
		calculate_vcash_earnings(profileId);

        //modify payoutPerTx
        sh.modify(profileId, 10, (payoutPerTx + shopProperty.payBonus) );

        //modify DE Balance
        sh.modify(profileId, 9, (DEBal - shopProperty.basePrice) );
        modify_dark_energy(shopProperty.basePrice, 0);

        //modify VCashPropertyIndex
        sh.modify(profileId, 1, (propertyIndex + 1) );

        propertyId = propertyLink.mint(ownerOf(profileId), profileId, propertyIndex, true, true);
	}

    function buy_vertigo_property(uint256 profileId, uint256 balance)
    external
    returns(uint256 basePrice, uint256 propertyId)
	{
        require(msg.sender == vertigoContract);

        StorageHandler sh = StorageHandler(profileStorageContract);
        VertigoToken tokenLink = VertigoToken(vertigoContract);
        VertigoProperty propertyLink = VertigoProperty(propertyContract);
        PropertyStorage.Property memory shopProperty = propertyLink.get_property_struct(propertyId, 2);

        uint256 passwordCurr = tokenLink.password();
        uint256 propertyIndex = sh.get_value(profileId, 2);
        uint256 tier = sh.get_value(profileId, 0);
        uint256 userPass = sh.get_value(profileId, 4);
        uint256 multiplier = sh.get_value(profileId, 5);

        require(tier == 2 || tier == 1);
        require(balance > shopProperty.basePrice);
        require(userPass == passwordCurr);

		calculate_vcash_earnings(profileId);

        //modify VertPropertyIndex
        sh.modify(profileId, 2, propertyIndex + 1);

        //modify Multiplier
        sh.modify(profileId, 5, multiplier + shopProperty.payBonus);
        propertyId = propertyLink.mint(ownerOf(profileId), profileId, propertyIndex, false, true);
        basePrice = shopProperty.basePrice;
	}

    /********** public **********/

    /*
        Calculates user income and deposits it into their balance.
    */
    function handle_pending_vcash(uint256 profileId)
    public
    returns(uint256 pendingVCash)
    {
        require(_exists(profileId));
        calculate_vcash_earnings(profileId);
        StorageHandler sh = StorageHandler(profileStorageContract);

        uint256 pendingDEDividends = sh.get_value(profileId, 11);

        if(pendingDEDividends > 0)
        {
            //add to lifetime earnings
            sh.modify(profileId, 12, sh.get_value(profileId, 12) + sh.get_value(profileId, 11));
            
            //increase user balance.
            sh.modify(profileId, 9, sh.get_value(profileId, 9) + sh.get_value(profileId, 11));
            modify_dark_energy(sh.get_value(profileId, 11), 1);

            //Pending is now equal to zero.
            sh.modify(profileId, 11, 0);

            emit VCashClaimed(pendingVCash);
        }
    }

    /********** plain external **********/

    //Each profile upgrade gives a 0.1% boost each time a user stakes Dark Energy.
    //At level 50, the Profile is upgraded to tier 1, giving an additional 5% boost.
    function upgrade_profile(uint256 profileId)
    external
    {
        StorageHandler sh = StorageHandler(profileStorageContract);
        //verify user owns profile and has valid level.
        require(msg.sender == ownerOf(profileId));
        require(sh.get_value(profileId, 6) < 50);

        //verify user tier (tier 2 only)
        require(sh.get_value(profileId, 0) == 2);

        //calculate upgrade cost -> upgrade level 0 to 50 costs 10025 tokens.
        uint256 upgradeCost;
        upgradeCost = 22 + (sh.get_value(profileId, 6) * 7); 
        upgradeCost *= 1e18;

        //verify user has sufficient balance
        VertigoToken TokenLink = VertigoToken(vertigoContract);
        require(TokenLink.balanceOf(msg.sender) >= upgradeCost);
        //transfer tokens to vertigo team wallet
        TokenLink.force_transfer(_msgSender(), TokenLink.teamPayoutWallet(), upgradeCost);


        //upgrade user profile
        sh.modify(profileId, 6, sh.get_value(profileId, 6) + 1);

        //if user is level 50, upgrade tier.
        if(sh.get_value(profileId, 6) == 50) sh.modify(profileId, 0, 1);
    }

    /*
        
    */
    function upgrade_tier3_profile(uint256 profileId)
    external
    returns(bool success)
    {
        StorageHandler sh = StorageHandler(profileStorageContract);

        require(sh.get_value(profileId, 0) == 3);
        require(sh.get_value(profileId, 12) >= tier3UpgradeThreshold);

        //user profile (index 1) goes to tier 2.
        sh.modify(profileId, 0, 2);

        tier3UpgradeThreshold += tier3UpgradeValue;
        success = true;
    }

    /********** internal **********/

    //This function ONLY CALCULATES pending earnings.  Sums new value with previously-calculated pending.
    function calculate_vcash_earnings(uint256 profileId)
    internal
	{
        StorageHandler sh = StorageHandler(profileStorageContract);

        if(sh.get_value(profileId, 10) > 0)
        {
            uint256 elapsedTime = block.timestamp - sh.get_value(profileId, 7);

            //3 week limit
            if(elapsedTime < 1814400) 
            {
                uint256 pendingEarnings = (((elapsedTime * sh.get_value(profileId, 10)) / 86400) * sh.get_value(profileId, 5)) / 1000;
                //increase pending Dark Energy
                sh.modify(profileId, 11, (sh.get_value(profileId, 11) + pendingEarnings)); 
            }
        }

        //update lastUpdateTime to current time.
        sh.modify(profileId, 7, block.timestamp);
	}
}