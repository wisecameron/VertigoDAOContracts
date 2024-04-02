/*
	Cameron Warnick https://www.linkedin.com/in/cameron-warnick-64a25222a/


	Vertigo Manager Structure
		uint256 benchmarkTime;				8		0
		uint256 yearsPassed;				8		1
		uint256 playable;					8		2
		uint256 weeksPassed;				16		3
		uint256 stakeWithdrawalCount;		64		4
		uint256 totalVCashStaked;			128		5
		uint256 payoutPerVCash;				256		6
		uint256 weeklyPayoutDecrement;		256		7
		uint256 teamPayout;					256		8
		uint256 poolPayout;					256		9
		uint256 runningPayout;				256		10
		uint256 ownerPayoutShare;			256		11
		uint256 lastReset;					256		12
		uint256 weeklyPayoutAmount;			256		13
		uint256 vertigoPoolBalance;			256		14
*/

//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import './VertigoProfile.sol';
import './VertigoProperty.sol';
import './PropertyStorage.sol';
import './VertigoTokenStakingStorage.sol';
import './StorageHandler.sol';

contract VertigoToken is ERC20
{
	address public VertigoManagerAddress;
	address public teamWallet;
	address public teamPayoutWallet;
	address public profileContract;
	address public propertyContract;
	address public stakingStorageManager;
    address public uniswapPoolAddress;
	address public owner;

	uint256 public password;
    uint256 public sellTax;

	bool public stakingEnabled;

	mapping(uint256 => bool) feeEnabled;
	mapping(address => bool) forceTransferProviders;

	/*
	FEES:

	0: vert staking fee
	1: vert property fee
	2: special property fee
	3: upgrade_property (burn or send to team)
	*/

	struct PayoutRecipient
	{		
		address user;
		uint256 payoutQuantity;
	}
	PayoutRecipient[] payoutRecipients;

	event Stake(address _from, uint256 _tokens, uint8 VCash);
	event Tax(uint256 original, uint256 end, uint256 tax);
	event PropertyCreated(bool success, uint8 typecode);
	event StakeClaimed(address _user);
	event TeamBurn(uint256 tokens);
	event Reset(address fulfiller);
	event OwnerValueSet(uint256 id, uint256 newParam);
	event Unstake(uint256 amount, address user);

	modifier OnlyOwner
	{
		require(msg.sender == owner);
		_;
	}

	constructor(
	address ownerRecipient,
	address teamWalletAddress, 
	address teamPayoutWalletAddress, 
	address VertigoManagerStorageAddress,
	address VertigoManagerStorageContractAddress)
	ERC20("Vertigo", "VERT")
	{
		_mint(msg.sender, 3000000 * 1e18);

		uint256[] memory vertigoManagerBits = new uint256[](15);
		uint256[15] memory bits = [uint256(8),8,8,16,64,128,256,256,256,256,256,256,256,256,256];

		for(uint i = 0; i < bits.length; i++)
		{
			vertigoManagerBits[i] = bits[i];
		}

		VertigoManagerAddress = VertigoManagerStorageAddress;
		StorageHandler vertigoManager = StorageHandler(VertigoManagerStorageAddress);
		vertigoManager.initialize(VertigoManagerStorageContractAddress, address(this), vertigoManagerBits, msg.sender);
		vertigoManager.push();

		password = 3;
        owner = msg.sender;

		uint256[] memory indices = new uint256[](5);
		uint256[] memory values = new uint256[](5);

		indices[0] = 2;
		indices[1] = 7;
		indices[2] = 8;
		indices[3] = 9;
		indices[4] = 11;

		values[0] = 0;
		values[1] = 267 * 1e18;
		values[2] = 7000 * 1e18;
		values[3] = 75000 * 1e18;
		values[4] = 80;

		vertigoManager.multimod(0, indices, values);
	
		PayoutRecipient memory ownerPayout;
		ownerPayout.user = ownerRecipient;
		ownerPayout.payoutQuantity = 1000;
		payoutRecipients.push(ownerPayout);

		teamWallet = teamWalletAddress;
		teamPayoutWallet = teamPayoutWalletAddress;
	}
	
    function transfer(address to, uint256 amount) 
    public 
    virtual override 
    returns (bool) 
    {
        address tokenOwner = _msgSender();

		//apply sell tax
		if(to == uniswapPoolAddress && sellTax != 0)
		{
			uint256 tax = (amount * sellTax) / 1000;
			emit Tax(amount, tax, (amount - tax));
			amount -= tax;
			_mint(teamPayoutWallet, tax);
		}

        _transfer(tokenOwner, to, amount);
        return true;
    }

	//groups all setter functions to reduce bytecode.
	function owner_set_value_handler(uint256 id, address[] memory addresses, uint256 newParam)
	external
	OnlyOwner
	{
		StorageHandler vertigoManager = StorageHandler(VertigoManagerAddress);

		if(id == 0) //set uniswap pool address
		{
			uniswapPoolAddress = addresses[0];
		}
		else if(id == 1) //set_staking_enabled
		{
			stakingEnabled = true;
		}
		else if(id == 2) //set_sell_tax
		{
			sellTax = newParam;
		}
		else if(id == 3) //set_periphery_contracts
		{
			profileContract = addresses[0];
			propertyContract = addresses[1];
			stakingStorageManager = addresses[2];

			forceTransferProviders[addresses[0]] = true; //profile
			forceTransferProviders[addresses[1]] = true; //property
		}
		else if(id == 4) //set_fee
		{
			feeEnabled[newParam] = !feeEnabled[newParam];
		}
		else if(id == 5)//set_playable
		{
			assert(vertigoManager.get_value(0, 2) == 0);		//playable
			vertigoManager.modify(0, 2, 1);			
			vertigoManager.modify(0, 12, block.timestamp);			//lastReset
		}
		else if(id == 6)
		{
			forceTransferProviders[addresses[0]] = !forceTransferProviders[addresses[0]];
		}

		emit OwnerValueSet(id, newParam);
	}

	function view_vertigo_manager()
	external view
	returns (uint256[] memory)
	{
		StorageHandler vertigoManager = StorageHandler(VertigoManagerAddress);
		uint256[] memory data = vertigoManager.get_array(0);
		return data;
	}

	/*
		0: check_configured
		1: check_playable
		2: 
	*/
	function public_view_bool(uint256 id) 
	external view
	returns (bool)
	{
		StorageHandler vertigoManager = StorageHandler(VertigoManagerAddress);

		if(id == 0)
		{
			return !(propertyContract == address(0));
		}
		return !(vertigoManager.get_value(0, 12) == 0);	//lastReset
	}

	function edit_owner_recipient(address _newRecipient)
	external
	OnlyOwner
	{
		payoutRecipients[0].user = _newRecipient;
	}

	function reset_pool_testing()
	external
	OnlyOwner
	{
		_reset_weekly_staking_pool(msg.sender);
	}

	function _reset_weekly_staking_pool(address origin) 
	internal
	{
		StorageHandler vertigoManager = StorageHandler(VertigoManagerAddress);

		//team payout
		_mint(teamPayoutWallet, vertigoManager.get_value(0,8));		//teamPayout
		_transfer(teamPayoutWallet, teamWallet, ((balanceOf(teamPayoutWallet) * 100) / 1000)); // 10% team payout tax
		_handle_team_payout();

		uint256[] memory values = vertigoManager.get_array(0);
		uint256[] memory indices = new uint256[](values.length);

		for(uint256 i = 0; i < values.length; i++)
		{
			indices[i] = i;
		}

		//check first week
		if(values[3] == 0)		//weeksPassed
		{
			values[10] = values[9]; //runningpayout, poolpayout
		}
		else
		{
			values[10] = values[10] - values[7];	//runningPayout, weeklyPayoutDecrement
		}
		
		//handle upkeep
		password += 1;
		values[6] = values[10] / values[5]; //payoutPerVcash, runningPyaout, totalVcashstaked
		values[12] = block.timestamp; //last reset
		values[5] = 0; //total vcash staked

		if(values[1] < 21) // years passed
		{
			values[3] = values[3] + 1; //weeks passed
		}

		//handle yearly reset
		if(values[3] > 52)		//weeks passed
		{
			values[1] = values[1] + 1; //years passed
			values[3] = 0; //weeks passed
			values[9] = (values[9] * 7) / 10; //poolPayout
			values[7] = (values[9] - ((values[9] * 7) / 10)) / 52; // weekly payout decrement
			values[8] = (values[8] * 7) / 10; //team payout
		}

		vertigoManager.multimod(0, indices, values);

		//payout for extra gas
		_mint(origin, (50 * 1e18)); 
		emit Reset(origin);
	}


	function reset_user_staking_values(address user)
	external
	OnlyOwner
	{
		StorageHandler vertigoManager = StorageHandler(VertigoManagerAddress);
		VertigoTokenStakingStorage stakingStorage = VertigoTokenStakingStorage(stakingStorageManager);

		uint256 stakedAmount = stakingStorage.get_user_stake_amount_tracker(user);

		if(stakedAmount > 0)
		{
			//vertigopoolbalance
			vertigoManager.modify(0, 14, vertigoManager.get_value(0, 14) - stakedAmount);
		}
		//stakeWithdrawalCount
		stakingStorage.modify_stake_index_tracker(user, vertigoManager.get_value(0,4));

		stakingStorage.modify_user_stake_amount_tracker(user, 0);

	}

	function stake_vcash(uint256 profileId, uint256 vcash) 
	external
	{
		VertigoProfile profileLink = VertigoProfile(profileContract);
		StorageHandler vertigoManager = StorageHandler(VertigoManagerAddress);

		require(vcash > 0);
		require(profileLink.ownerOf(profileId) == msg.sender);
		require(profileLink.get_profile_value(profileId, 4) == password);
		require(profileLink.stake_vcash(profileId, vcash) == 1);

		uint256 val1;
		uint256 val2;

		[val1, val2] = vertigoManager.get_array(0);

		vertigoManager.modify(0, 5, (vertigoManager.get_value(0, 5) + vcash)); //totalVcashStaked

		if((block.timestamp - vertigoManager.get_value(0, 12)) > 604800) //last reset : CLOCK RESET -- SHOULD BE 604800 
		{
			_reset_weekly_staking_pool(msg.sender);
		}

		emit Stake(msg.sender, vcash, 1);
	}

	function modify_team_payout_recipients(address _user, uint256 share)
	external
	OnlyOwner
	returns(uint256)
	{
		//Option 1: Try to find user in current array.
		//traverse.  If find user, modify share to new share, modify owner share.
		uint256 len = payoutRecipients.length;

		for(uint256 i = 1; i < len; i++)
		{
			if(payoutRecipients[i].user == _user)
			{
				//check if larger or smaller than existing share
				if(payoutRecipients[i].payoutQuantity > share) //smaller
				{
					//owner share
					payoutRecipients[0].payoutQuantity += payoutRecipients[i].payoutQuantity - share;
				}
				else //larger
				{
					assert(payoutRecipients[0].payoutQuantity > share - payoutRecipients[i].payoutQuantity);
					payoutRecipients[0].payoutQuantity -= share - payoutRecipients[i].payoutQuantity;
				}
				payoutRecipients[i].payoutQuantity = share;
				return(payoutRecipients[0].payoutQuantity);
			}
		}
		//Option 2: Try to find zero-share user.
		//if not found, traverse for zero share user.  If not found, push new point.
		for(uint256 i = 1; i < len; i++)
		{
			if(payoutRecipients[i].payoutQuantity == 0)
			{
				payoutRecipients[i].user = _user;
				payoutRecipients[i].payoutQuantity = share;
				require(payoutRecipients[0].payoutQuantity > share);
				payoutRecipients[0].payoutQuantity -= share;
				return(payoutRecipients[0].payoutQuantity);
			}
		}

		//Option 3: create new query.
		PayoutRecipient memory newRecipient;
		newRecipient.user = _user;
		newRecipient.payoutQuantity = share;

		require(payoutRecipients[0].payoutQuantity > share);
		payoutRecipients[0].payoutQuantity -= share;

		payoutRecipients.push(newRecipient);
		return(payoutRecipients[0].payoutQuantity);
	}

	function _handle_team_payout() 
	internal
	{
		PayoutRecipient[] memory localPayoutRecipients = payoutRecipients;
		uint256 length = localPayoutRecipients.length;
		uint256 payoutQuantity = balanceOf(teamPayoutWallet);

		for(uint256 i = 0; i < length; i++)
		{
			_transfer(teamPayoutWallet, localPayoutRecipients[i].user, (payoutQuantity * localPayoutRecipients[i].payoutQuantity) / 1000);
		}
	}

	function retrieve_staking_dividends_from_withdrawal_pool(address _user, uint256 userPass, uint256 stakedAmount)
	external
	returns (bool)
	{
		require(msg.sender == profileContract);

		StorageHandler vertigoManager = StorageHandler(VertigoManagerAddress);

		if(userPass == password - 1 && stakedAmount > 0)
		{
			uint256 tokensReceived = vertigoManager.get_value(0, 6) * stakedAmount;	//payoutPerVCash
			_mint(_user, tokensReceived);

			emit StakeClaimed(_user);
			return true;
		}
		return false;
	}

	function weekly_reset(uint256 profileId) 
	external
	{
		VertigoProfile profileLink = VertigoProfile(profileContract);
		StorageHandler vertigoManager = StorageHandler(VertigoManagerAddress);

		require(vertigoManager.get_value(0, 2) == 1); //playable
		require(profileLink.ownerOf(profileId) == msg.sender);
		profileLink.weekly_reset(profileId);
	}

	function buy_vcash_property(uint256 profileId) 
	external
	returns(uint256)
	{
		VertigoProfile profileLink = VertigoProfile(profileContract);
		require(profileLink.ownerOf(profileId) == msg.sender);

		uint256 propertyId = profileLink.buy_vcash_property(profileId);
		return propertyId;
	}

	function buy_vertigo_property(uint256 profileId) //feeId == 1
	external
	returns(uint256)
	{
		VertigoProfile profileLink = VertigoProfile(profileContract);
		require(profileLink.ownerOf(profileId) == msg.sender);
		(uint256 price, uint256 propertyId) = profileLink.buy_vertigo_property(profileId, balanceOf(msg.sender));

		require(price != 0);
		require(balanceOf(msg.sender) > price);

		if(feeEnabled[1])
		{
			_mint(teamPayoutWallet, price);
			emit Tax(price, price, price);
		}

		_burn(msg.sender, price);
		return propertyId;
	}

	function buy_special_property(uint256 index) //feeId == 2
	external
	returns(uint256)
	{
		uint256 balance = balanceOf(msg.sender);
        VertigoProperty propertyLink = VertigoProperty(propertyContract);
        PropertyStorage.Property memory shopProperty = propertyLink.get_property_struct(index, 3);
        require(balance > shopProperty.basePrice);
        require(shopProperty.buyable);

        uint256 propertyId = propertyLink.mint(msg.sender, 0, index, false, false);
        uint256 price = shopProperty.basePrice;

		require(price != 0);
		require(balanceOf(msg.sender) > price);

		if(feeEnabled[2])
		{
			_mint(teamPayoutWallet, price);
			emit Tax(price, price, price);
		}

		_burn(msg.sender, price);
		return propertyId;
	}

	function retrieve_vert_staking_dividends() 
	external 
	{
		VertigoTokenStakingStorage stakingStorage = VertigoTokenStakingStorage(stakingStorageManager);
		uint256 senderStakeIndex = stakingStorage.get_stake_index_tracker(msg.sender);

		require(senderStakeIndex <= stakingStorage.length()); //stakewithdrawalcount
        _update_user_vert_rewards(msg.sender);
	}


	/*
		Called by vertigo staking operations: stake, unstake.
		Calculates a user's dividends and mints the tokens to their wallet.
	*/
    function _update_user_vert_rewards(address user) 
	internal
    {
		uint256 rewardSum;

		VertigoTokenStakingStorage stakingStorage = VertigoTokenStakingStorage(stakingStorageManager);
		rewardSum = stakingStorage.update_user_vert_rewards(user);

		_mint(msg.sender, rewardSum);
		stakingStorage.modify_stake_index_tracker(user, stakingStorage.length()); 	//stakewithdrawalcount
        
    }

    function unstake_vert(uint256 amount) //BUG REPORT: Requires pending dividends (look at update_user_vert_rewards req statement)
	external
	{
		StorageHandler vertigoManager = StorageHandler(VertigoManagerAddress);
		VertigoTokenStakingStorage stakingStorage = VertigoTokenStakingStorage(stakingStorageManager);
		uint256 stakedAmount = stakingStorage.get_user_stake_amount_tracker(msg.sender);

		//fix amount for decimals
        uint256 adjustedQuantity = amount * 1e18;

		//must stake at least 1 decimal-adjusted token
		require(1000000000000000000 <= adjustedQuantity);

		//must have at least the desired unstake amount staked.								
		require(stakedAmount >= adjustedQuantity);

		//claim dividends available at this point.
		_update_user_vert_rewards(msg.sender);

		//adjustedPoolBalance: remove the unstake amount from the pool
		vertigoManager.modify(0, 14, vertigoManager.get_value(0, 14) - adjustedQuantity);

		//reduce user staked amount by the amount they unstaked.
		stakingStorage.modify_user_stake_amount_tracker(msg.sender, (stakedAmount - adjustedQuantity));


		//distribute 7.5% fee to holders for this unstake operation.
        adjustedQuantity = _distribute_vert_reward(adjustedQuantity);

		//mint (amount - fee)
		_mint(msg.sender, adjustedQuantity);

		emit Unstake(amount, msg.sender);
	}
	
	function stake_vert(uint256 amount) 
	external
	{
		StorageHandler vertigoManager = StorageHandler(VertigoManagerAddress);
		VertigoTokenStakingStorage stakingStorage = VertigoTokenStakingStorage(stakingStorageManager);

		uint256 adjustedQuantity = amount * 1e18;
		require(stakingEnabled);
		require(balanceOf(msg.sender) >= adjustedQuantity);
		require(1000000000000000000 <= adjustedQuantity); 	

        _update_user_vert_rewards(msg.sender);
        _burn(msg.sender, adjustedQuantity);
        adjustedQuantity = _distribute_vert_reward(adjustedQuantity);

		//vertigoPoolBalance
		vertigoManager.modify(0, 14, vertigoManager.get_value(0, 14) + adjustedQuantity);
		stakingStorage.modify_user_stake_amount_tracker(msg.sender, (stakingStorage.get_user_stake_amount_tracker(msg.sender) + adjustedQuantity) );
	}

	function _distribute_vert_reward(uint256 amount) //feeId == 0
	internal 
	returns(uint256)
    {
		StorageHandler vertigoManager = StorageHandler(VertigoManagerAddress);
		VertigoTokenStakingStorage stakingStorage = VertigoTokenStakingStorage(stakingStorageManager);
		
		uint256 tax = (amount * 75) / 1000;
		amount -= tax;

		if(feeEnabled[0])
		{
			uint256 teamTax = (5 * tax) / 100;
			_mint(teamPayoutWallet, teamTax);
			emit Tax(tax, teamTax, (tax - teamTax));
			tax -= teamTax;
		}
		
		stakingStorage.push_staked_amount_tracker(vertigoManager.get_value(0, 14) + amount); //vertigopoolbalance
		stakingStorage.push_stake_taxes(tax);
		vertigoManager.modify(0, 4, vertigoManager.get_value(0, 4) + 1); //stakeWithdrawalcount

        return amount;
    }

	function get_staked_vert_amount(address user)
	external view
	returns(uint256)
	{
		VertigoTokenStakingStorage stakingStorage = VertigoTokenStakingStorage(stakingStorageManager);
		uint256 stakeAmount = stakingStorage.get_user_stake_amount_tracker(user);
		return(stakeAmount);

	}
	
	function mint_profile()
	external
	returns(uint256 newId)
	{
		bool success;
		VertigoProfile profileLink = VertigoProfile(profileContract);
		(newId, success) = profileLink.mint(msg.sender);
		require(success);
	}

	/*
		Upgrades always cost $VERT. -- Change?
	*/
	function upgrade_property(uint256 propertyId, uint256 profileId)
	external
	{
		//create property link
		VertigoProperty propertyLink = VertigoProperty(propertyContract);

		//verify user owns property
		require(propertyLink.ownerOf(propertyId) == msg.sender);

		//get price
		uint256 price = propertyLink.get_user_property_upgrade_price(propertyId, profileId);
		require(balanceOf(msg.sender) > price);

		//charge user
		_burn(msg.sender, price);

		if(feeEnabled[3])
		{
			_mint(teamPayoutWallet, price);
			emit Tax(price, price, price);
		}
		
		//modify property
    	propertyLink.upgrade_property(propertyId, profileId, msg.sender);
	}

	function force_transfer(address from, address to, uint256 amount)
	external
	{
			require(forceTransferProviders[_msgSender()]);
			_transfer(from, to, amount);			
	}

}