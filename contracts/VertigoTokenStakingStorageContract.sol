//SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

/*
    Cameron Warnick https://www.linkedin.com/in/cameron-warnick-64a25222a/

    Child staking storage contract for a given staking epoch.
    Managed by VertigoTokenStakingStorage
*/
contract VertigoTokenStakingStorageContract
{
    uint256 public stores = 0;

    uint256[] public stakeTaxes;
	uint256[] public stakedAmountTracker;
    address[] private addresses;

	mapping(address => uint256) stakeIndexTracker;
	mapping(address => uint256) userStakeAmountTracker;

    address private _parent;
    address public owner;

    modifier OnlyParent
    {
        require(msg.sender == _parent);
        _;
    }

    constructor(address parentContract)
    {
        _parent = parentContract;
        owner = tx.origin;
    }

    /*
        Gives the amount of queries in the storage system.
        A stake tax is always added when a new entry is made.
    */
    function length()
    external view
    returns(uint256)
    {
        return stakeTaxes.length;
    }

    function decimate()
    external
    {
        require(msg.sender == owner);

        uint256 len = addresses.length;
        address curr;

        for(uint256 i = 0; i < len; i++)
        {
            curr = addresses[i];
            stakeIndexTracker[curr] = 0;
            userStakeAmountTracker[curr] = 0;
        }

        delete addresses;
        delete stakeTaxes;
        delete stakedAmountTracker;
    }

    function add_stake_tax(uint256 amount)
    external
    OnlyParent
    {
        stakeTaxes.push(amount);
        stores += 1;
    }

    function add_stake(uint256 amount)
    external
    OnlyParent
    {
        stakedAmountTracker.push(amount);
        stores += 1;
    }

    function modify_stake_index_tracker(address user, uint256 index)
    external
    OnlyParent
    {
        if(index == 0 && stores > 0)
        {
            stores -= 1;
        }
        else if(stakeIndexTracker[user] == 0)
        {
            stores += 1;
        }

        stakeIndexTracker[user] = index;
    }

    function modify_user_stake_amount_tracker(address user, uint256 amount)
    external
    OnlyParent
    {
        if(amount == 0)
        {
            stores -= 1;
        }
        else if(userStakeAmountTracker[user] == 0)
        {
            stores += 1;
        }

        userStakeAmountTracker[user] = amount;
    }

    function get_stake_index_tracker(address user)
    external view
    OnlyParent
    returns (uint256)
    {
        return stakeIndexTracker[user];
    }

    function get_user_stake_amount_tracker(address user)
    external view
    OnlyParent
    returns(uint256)
    {
        return userStakeAmountTracker[user];
    }

    function get_stake_tax(uint256 index)
    external view
    returns(uint256)
    {
        return(stakeTaxes[index]);
    }
}