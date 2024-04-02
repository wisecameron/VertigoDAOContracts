<div align="center">
  <a href="#">
  	<img src="https://media.giphy.com/media/v1.Y2lkPTc5MGI3NjExaGpqdnlobTA5dTI4a3BuN203ODc0NHA4a2t2cTF3ejdscWdxZ3FheiZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/jhuU2BQsGsbtmM1Mda/giphy.gif" alt="project logo" height="160" />
  </a>
  <br>
  <br>
  <p>
    <b>VertigoDAO Contract Ecosystem</b>
  </p>
  <p>
     <i>VertigoDAO was a DeFi project designed to make blockchain more accessible 
     by allowing users to build passive token rewards by completing user or business-supplied tasks.  It uses a two-token model, where the secondary 
     currency can be staked to earn the primary ERC20 asset on a weekly 
     distribution, following a deflationary curve.  The project contains numerous 
     quirks and features, with an upgradeable Profile NFT system, upgradable 
     "Property" NFT system (granting permanent passive secondary token rewards), and 
     much more.</i>
  </p>
  <p>

  </p>
</div>

---

**Content**

* [Highlights](##highlights)
* [Warning](##warning)
* [Usage](##usage)
* [Examples](##examples)
* [Documentation](##documentation)

## Highlights ✨
* Unique DeFi ecosystem leveraging feature-rich ERC20 (Vertigo Token) and ERC721 (VertigoProperty, VertigoProfile) assets.
* Two staking models (one for each token), with a dedicated storage system 
for the Vertigo Token staking pool.
* Upgradeable "Properties" grant secondary token (Dark Energy -- also referred to as VCash in the contract) staking multipliers and flat income boosts.  
* Fully autonomous team payout and staking distribution systems.
* Three "Property" variants

## Warning 🐙
<p>
This project was built to be integrated with a storage system.  However, 
there was a lot that I didn't know when I built that system, and some things that I thought were true that were actually false.  Hence, it's 
not worth posting on github.  An improved (though not quite spectacular) version of 
that system is available on my profile -- called the "Express Storage System" -- if you want to run this contract system.  The initialization process is a bit of a pain, I recommend referencing 
the test suite to see how it works.  

</p>

## Usage 💡
You'll need to download the Express Storage System to run this system.  

## Examples 🖍
```
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
```

## Documentation 📄
The project whitepaper is available at vertigodao.com


---
<div align="center">
	<b>
		<a href="https://www.npmjs.com/package/get-good-readme">File generated with get-good-readme module</a>
	</b>
</div>
