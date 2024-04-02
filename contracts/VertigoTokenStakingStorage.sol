//SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

/*
Connects to a VertigoTokenStakingStorageContract instance in the current epoch.  

Cameron Warnick https://www.linkedin.com/in/cameron-warnick-64a25222a/
*/



import './VertigoTokenStakingStorageContract.sol';
import './VertigoToken.sol';

contract VertigoTokenStakingStorage
{

    bool initialized = false;
    address tokenContract;

    mapping(address => uint256) userEpoch;
    mapping(uint256 => address) storageContracts;

    uint256 public epoch;
    uint256 public epochLowerLimit;
    address private _owner;

    constructor()
    {
        _owner = msg.sender;
    }

    modifier Auth
    {
        require(msg.sender == tokenContract || msg.sender == address(this) || msg.sender ==  _owner);
        _;
    }

    function storage_contract_address()
    external view
    returns(address)
    {
        return(storageContracts[epoch]);
    }

    function set_epoch_lower_limit(uint256 lowerLimit)
    external
    {
        require(msg.sender == _owner);

        epochLowerLimit = lowerLimit;
    }

    function initialize(address storageContract, address tokenAddress)
    external
    {
        require(!initialized);
        require(msg.sender == _owner);

        storageContracts[epoch] = storageContract;
        tokenContract = tokenAddress;
        initialized = true;
    }

    function cycle(address newStorageContract)
    external
    {
        epoch += 1;
        storageContracts[epoch] = newStorageContract;
    }

    function set_user_epoch(address user)
    Auth
    public
    {
        userEpoch[user] = epoch;
    }

    function add_stake_tax(uint256 newTax)
    Auth
    public
    {
        VertigoTokenStakingStorageContract sc = VertigoTokenStakingStorageContract(storageContracts[epoch]);

        sc.add_stake_tax(newTax);
    }

    function add_stake(uint256 amount)
    Auth
    public
    {
        VertigoTokenStakingStorageContract sc = VertigoTokenStakingStorageContract(storageContracts[epoch]);

        sc.add_stake(amount);
    }

    function modify_stake_index_tracker(address user, uint256 index)
    Auth
    public
    {
        VertigoTokenStakingStorageContract sc = VertigoTokenStakingStorageContract(storageContracts[epoch]);

        sc.modify_stake_index_tracker(user, index);
    }

    function modify_user_stake_amount_tracker(address user, uint256 amount)
    Auth
    public
    {
        VertigoTokenStakingStorageContract sc = VertigoTokenStakingStorageContract(storageContracts[epoch]);
        sc.modify_user_stake_amount_tracker(user, amount);
    }

    function get_stake_index_tracker(address user)
    Auth
    public view
    returns (uint256)
    {
        VertigoTokenStakingStorageContract sc = VertigoTokenStakingStorageContract(storageContracts[epoch]);

        uint256 index = sc.get_stake_index_tracker(user);

        return index;
    }

    function get_user_stake_amount_tracker(address user)
    Auth
    public view
    returns(uint256)
    {
        VertigoTokenStakingStorageContract sc = VertigoTokenStakingStorageContract(storageContracts[epoch]);
        return(sc.get_user_stake_amount_tracker(user));
    }

    function push_stake_taxes(uint256 amount)
    Auth
    public
    {
        VertigoTokenStakingStorageContract sc = VertigoTokenStakingStorageContract(storageContracts[epoch]);
        sc.add_stake_tax(amount);
    }

    function push_staked_amount_tracker(uint256 amount)
    Auth
    public
    {
        VertigoTokenStakingStorageContract sc = VertigoTokenStakingStorageContract(storageContracts[epoch]);
        sc.add_stake(amount);
    }

    function get_stake_taxes(uint256 i)
    Auth
    public view
    returns(uint256)
    {
        address current = storageContracts[epoch];
        VertigoTokenStakingStorageContract sc = VertigoTokenStakingStorageContract(current);
        uint256 value = sc.get_stake_tax(i);
        return(value);
    }

    function get_staked_amount(uint256 i)
    Auth
    public view
    returns(uint256)
    {
        VertigoTokenStakingStorageContract sc = VertigoTokenStakingStorageContract(storageContracts[epoch]);
        return(sc.stakedAmountTracker(i));
    }

    function length()
    public view
    returns(uint256)
    {
        VertigoTokenStakingStorageContract sc = VertigoTokenStakingStorageContract(storageContracts[epoch]);
        return sc.length();
    }

    function view_user_vert_dividends(address user)
    Auth
    public view
    returns(uint256)
    {
        uint256 rewardSum;
        uint256 upperLimit;
		uint256 stakedAmount = get_user_stake_amount_tracker(user);
        VertigoTokenStakingStorageContract sc = VertigoTokenStakingStorageContract(storageContracts[epoch]);
        uint256 userStakeIndex = get_stake_index_tracker(user);

        //if user epoch is before current accepted, they are moved up to the beginning of current accepted.
        uint256 uEpoch = userEpoch[user];

        if(uEpoch < epochLowerLimit)
        {
            uEpoch = epochLowerLimit;
        }

        //calculate rewards before current epoch
        if(uEpoch < epoch)
        {
            for(uint256 i = uEpoch; i < epoch; i++)
            {
                //iterate through entire epoch
                uint256 lowerLimit = 0;

                if(i == uEpoch)
                {
                    lowerLimit = sc.get_stake_index_tracker(user);
                }

                upperLimit = sc.length();

                uint256 stakeTax;
                uint256 stakedAmountTrackerInterval;

                for(uint256 j = lowerLimit; j < upperLimit; j++)
                {
                    stakeTax = sc.get_stake_tax(i);
					stakedAmountTrackerInterval = sc.stakedAmountTracker(j);
					rewardSum += (stakedAmount * stakeTax) / stakedAmountTrackerInterval;
                }
            }

        }

        upperLimit = sc.length();
        //final iteration
		if(userStakeIndex < upperLimit && stakedAmount > 0)      //stakeWithdrawalcount
		{
			uint256 lowerLimit = userStakeIndex;

			uint256 stakeTax;
			uint256 stakedAmountTrackerInterval;

			if(upperLimit > lowerLimit)
			{
				for(uint256 i = lowerLimit; i < upperLimit; i++)
				{
					stakeTax = sc.get_stake_tax(i);
					stakedAmountTrackerInterval = sc.stakedAmountTracker(i);
					rewardSum += (stakedAmount * stakeTax) / stakedAmountTrackerInterval;
				}
			}
        }

        return rewardSum;
    }

    function update_user_vert_rewards(address user)
    Auth
    external
    returns(uint256)
    {
        uint256 dividends = view_user_vert_dividends(user);

        if(userEpoch[user] < epoch)
        {
            userEpoch[user] = epoch;
        }

        return dividends;
    }

}