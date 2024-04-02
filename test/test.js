const { expect } = require("chai");
const ethers = require("ethers")
const { assertHardhatInvariant } = require("hardhat/internal/core/errors");

const ownerRecipient = '0x9c77d74FC73BD9D2C01E35b057BDa3Ab6f7060e8';
const teamWalletAddress = '0x8b9ceb35457C9e768e49b7cE2E153ADECe66A76a';
const teamPayoutWalletAddress = '0xcd5d65fcBef85E56162fccf9C51Ef25F8a0Cb98d';

let accounts = [];
let signers;
const DECIMALS = ethers.BigNumber.from(10).pow(18)

let VertigoToken, VertigoProfile, VertigoProperty;
let VertigoInstance, ProfileInstance, PropertyInstance;

let StorageHandlerVM, StorageSystemVM;
let StorageHandlerInstanceVM, StorageSystemInstanceVM;

let VertigoTokenStakingContract, VertigoTokenStakingStorage;
let VertigoTokenStakingContractInstance, VertigoTokenStakingStorageInstance;

let ProfileStorage, ProfileStorageContract, ProfileStorageInstance, ProfileStorageContractInstance;

let StorageHandlerProperty, StorageHandlerPropertyInstance, StorageContractProperty, StorageContractPropertyInstance;

let vtsc, vtss;         //secondary staking storage and contract instances
let vtscIN, vtssIN;

let Helper, HelperInstance;

describe("Vertigo Token Test", function()
{
    it("creates signers and accounts arrays", async() =>
    {
        signers = await hre.ethers.getSigners();
    
        for(let i = 0; i < 20; i++)
        {
            accounts[i] = await signers[i].getAddress();
        }

    })

    it("Deploys the Helper.sol library", async() =>
    {
        Helper = await hre.ethers.getContractFactory("Helper");
        HelperInstance = await Helper.deploy();
    })

    it("Storage Contracts", async() =>
    {
        StorageHandlerVM = await hre.ethers.getContractFactory("StorageHandler",
        {
            libraries:
            {
                Helper: HelperInstance.address,
            }
        })

        StorageSystemVM = await hre.ethers.getContractFactory("StorageSystem", 
        {
            libraries:
            {
                Helper: HelperInstance.address,
            }
        })

        StorageHandlerInstanceVM = await StorageHandlerVM.deploy();
        StorageSystemInstanceVM = await StorageSystemVM.deploy(false, StorageHandlerInstanceVM.address);

        ProfileStorage = await hre.ethers.getContractFactory("StorageHandler",
        {
            libraries:
            {
                Helper: HelperInstance.address,
            }
        })

        ProfileStorageContract = await hre.ethers.getContractFactory("StorageSystem", 
        {
            libraries:
            {
                Helper: HelperInstance.address,
            }
        })

        ProfileStorageInstance = await ProfileStorage.deploy();
        ProfileStorageContractInstance = await ProfileStorageContract.deploy(false, ProfileStorageInstance.address);

        StorageHandlerProperty = await hre.ethers.getContractFactory("StorageHandler",
        {
            libraries:
            {
                Helper: HelperInstance.address,
            }
        })

        StorageContractProperty = await hre.ethers.getContractFactory("StorageSystem", 
        {
            libraries:
            {
                Helper: HelperInstance.address,
            }
        })

        StorageHandlerPropertyInstance = await StorageHandlerProperty.deploy();
        StorageContractPropertyInstance = await StorageContractProperty.deploy(false, StorageHandlerPropertyInstance.address);
    })

    it("Deploys the core system", async() =>
    {
        VertigoToken = await hre.ethers.getContractFactory("VertigoToken");
        VertigoProfile = await hre.ethers.getContractFactory("VertigoProfile");
        VertigoProperty = await hre.ethers.getContractFactory("VertigoProperty");

        VertigoInstance = await VertigoToken.deploy(ownerRecipient,
            teamWalletAddress, 
            teamPayoutWalletAddress, 
            StorageHandlerInstanceVM.address, 
            StorageSystemInstanceVM.address);

        ProfileInstance = await VertigoProfile.deploy();
        PropertyInstance = await VertigoProperty.deploy();
    })

    it("Deploys Vertigo Token staking storage", async() =>
    {
        VertigoTokenStakingStorage = await hre.ethers.getContractFactory("VertigoTokenStakingStorage");
        VertigoTokenStakingContract = await hre.ethers.getContractFactory("VertigoTokenStakingStorageContract");

        VertigoTokenStakingStorageInstance = await VertigoTokenStakingStorage.deploy();
        VertigoTokenStakingContractInstance = await VertigoTokenStakingContract.deploy(VertigoTokenStakingStorageInstance.address);
    })

    it("Handles owner initialization", async() =>
    {
        let VertAddress = VertigoInstance.address;
        let ProfileAddress = ProfileInstance.address;
        let PropertyAddress = PropertyInstance.address;
        let storageContractAddress = VertigoTokenStakingContractInstance.address;
        let storageAddress = VertigoTokenStakingStorageInstance.address;

        //set peripheral contracts
        await VertigoInstance.owner_set_value_handler(3, [ProfileAddress, PropertyAddress, storageAddress], 0);

        await VertigoTokenStakingStorageInstance.initialize(storageContractAddress, VertAddress);
    
        //enable staking.
        await VertigoInstance.owner_set_value_handler(1, [], 0);
    
        //set playable
        await VertigoInstance.owner_set_value_handler(5, [], 0);
    
        await ProfileInstance.set_periphery_contracts(VertAddress, PropertyAddress);
        await PropertyInstance.set_periphery_contracts(VertAddress, ProfileAddress);

        console.log(ProfileStorageInstance.address);
        console.log(ProfileStorageContractInstance.address);

        await ProfileInstance.set_storage_contract(ProfileStorageInstance.address, ProfileStorageContractInstance.address);
        await PropertyInstance.set_storage_contract(StorageHandlerPropertyInstance.address, StorageContractPropertyInstance.address);
        await PropertyInstance.set_profile_storage_contract(ProfileStorageInstance.address);

    })

    it("Whitelists two users", async() =>
    {
        //whitelist owner, account1.
        await ProfileInstance.whitelist_user(accounts[0], 1);
        await ProfileInstance.whitelist_user(accounts[1], 3);

        //mint profiles
        await VertigoInstance.mint_profile();
        await VertigoInstance.connect(signers[1]).mint_profile();

        //verify correct minting and ownership.
        let secondProfileOwner = await ProfileInstance.ownerOf(1)
        expect(secondProfileOwner).to.equal(accounts[1]);
    })

    it("Creates special property & sets it buyable", async function () 
    {
      /*
      create [SPECIAL] property, set buyable
      queries: propertyName, basePrice, payBonus, isVCashProperty, isDefaultProperty, standardURI, premiumURI
      */
      await PropertyInstance.create_property('name', 100, 86400, true, false, 'uri', 'uri2');
      await PropertyInstance.modify_packed_property_struct(0, 3, 1, 5);
    });
  
    it("Retrieves default income", async function() 
    {
      await VertigoInstance.weekly_reset(0);
      await VertigoInstance.connect(signers[1]).weekly_reset(1);
    });
  
    it("Buys special property.", async function() 
    {
      await VertigoInstance.buy_special_property(0);
    });
  
    it("Transfers special property ownership to tier 3 profile", async function() 
    {
      await PropertyInstance.transfer_property_ownership(accounts[1], 0);
      let PropertyOwner = await PropertyInstance.ownerOf(0);
  
      expect(PropertyOwner).to.equal(accounts[1]);
    });
  
    it("Self-rents property to extract income", async function() 
    {
      await PropertyInstance.connect(signers[1]).make_rental_offer(accounts[1], 0, 0, 0, 1);
      await PropertyInstance.connect(signers[1]).accept_rental_offer(1, 0, 0, 0);
    });
  
    it("Transfers property back to original owner", async function() 
    {
      await PropertyInstance.connect(signers[1]).transfer_property_ownership(accounts[0], 0);
      await PropertyInstance.reclaim_rental_ownership(0);
    });
  
    it("Properly self-rents property on accounts[0]", async function() 
    {
      await PropertyInstance.make_rental_offer(accounts[0], 0, 0, 1, 0);
      await expect(PropertyInstance.accept_rental_offer(0, 0, 2, 0)).to.be.reverted;
      await PropertyInstance.accept_rental_offer(0, 0, 1, 0)
    });
  
    it("Create Dark Energy Property", async function() 
    {
      await PropertyInstance.create_property('name', 1, 420, true, true, 'uri', 'uri2');
    });
  
    it("Tier 1 can purchase default properties, tier 3 cannot", async function() 
    {
      await VertigoInstance.buy_vcash_property(0);
      await expect(VertigoInstance.connect(signers[1]).buy_vcash_property(1)).to.be.reverted;
    })
  
    it("Tier 3 profile upgrades, can now pruchase the property.", async function() 
    {
      await ProfileInstance.connect(signers[1]).upgrade_tier3_profile(1);
      await VertigoInstance.connect(signers[1]).weekly_reset(1);
      await VertigoInstance.connect(signers[1]).buy_vcash_property(1);
    })
  
    it("Account[1] can receive tokens from owner", async function()
    {
      await VertigoInstance.transfer(accounts[1], ethers.BigNumber.from(4000).mul(DECIMALS));
      let val = await VertigoInstance.balanceOf(accounts[1])
      expect(val).to.equal(ethers.BigNumber.from(4000).mul(DECIMALS));
    })
  
  
    it("Properly transfers profile ownership", async function()
    {
      await ProfileInstance.transferFrom(accounts[0], accounts[1], 0);
    });
  
    it("Properly transfers default Property ownership.", async function() 
    {
      await PropertyInstance.connect(signers[1]).transfer_default_property_ownership(0, 1);
      await PropertyInstance.ownerOf(1).then((res) => expect(res).to.equal(accounts[1]))
    })
  
    it("Creates Vertigo Property", async function()
    {
      await PropertyInstance.create_property("H", 1, 269, false, true, "", "");
    })
  
    it("Transfers Profile & Property ownership back to accounts[0]", async function()
    {
      await ProfileInstance.connect(signers[1]).transferFrom(accounts[1], accounts[0], 0);
      await PropertyInstance.transfer_default_property_ownership(0, 1);
    })
  
    it("Buys Vertigo Property", async function()
    {
      await VertigoInstance.buy_vertigo_property(0);
    })
  
    it("Stakes VCash", async function()
    {
      await VertigoInstance.stake_vcash(0, 100);
      //await VertigoInstance.connect(signers[1]).weekly_reset(1);
      //await VertigoInstance.connect(signers[1]).stake_vcash(1, 69);
      //let value = await StorageHandlerInstanceVM.get_array(0, 5);
      //console.log(value);

      //StorageHandlerInstanceVM.modify(0, 5, 269);
      //let values = await StorageHandlerInstanceVM.get_array(0);
    })

    
    it("Resets the pool", async function()
    {
      await VertigoInstance.reset_pool_testing();
      await expect(VertigoInstance.stake_vcash(0, 10)).to.be.reverted;
    })
  
    it("Logs VertigoManager data", async function()
    {
        //let arr = await StorageHandlerInstanceVM.get_array(0);
        //console.log(arr);
    })

    it("Properly receives reward from staking.", async function()
    {
      //await VertigoInstance.balanceOf(accounts[1]).then((res) => console.log(res))
      await VertigoInstance.connect(signers[1]).weekly_reset(1);
      await VertigoInstance.weekly_reset(0);
      //await VertigoInstance.balanceOf(accounts[1]).then((res) => console.log(res))
      //await ProfileInstance.connect(A1).get_profile_struct(1).then(res => console.log(res.userVCashBalance))
    })
  
    it("Whitelisting & profile Minting stress test.", async function()
    {
      //mint all 20 profiles.
      let profileIndex = 2;
  
      for(profileIndex; profileIndex < 20; profileIndex++)
      {
        await ProfileInstance.whitelist_user(accounts[profileIndex], 2)
        await VertigoInstance.connect(signers[profileIndex]).mint_profile()
        //await ProfileInstance.get_profile_struct(profileIndex).then((res) => console.log(res))
      }
    });
  
    it("Weekly_reset stress test", async function()
    {
      let profileIndex = 2;
  
      for(profileIndex; profileIndex < 20; profileIndex++)
      {
        await VertigoInstance.connect(signers[profileIndex]).weekly_reset(profileIndex);
      }
    })
  
    it("Pool reset stress test (1 year+), 1 || 17 accounts", async function()
    {
      let count = 0;
  
      await VertigoInstance.connect(signers[3]).stake_vcash(3, 1);
  
      let preBal = ethers.BigNumber.from(0)
  
      for(count; count < 20; count++)
      {
        await VertigoInstance.reset_pool_testing();
  
        await VertigoInstance.connect(signers[3]).weekly_reset(3);
        await VertigoInstance.connect(signers[3]).stake_vcash(3, 1);
  
        /* 17 accounts
        for(let i = 3; i < 20; i++)
        {
          await VertigoInstance.connect(signers[i]).weekly_reset(i);
          await VertigoInstance.connect(signers[i]).stake_vcash(i, 1);
        }
  
        */
        //let amt = await VertigoInstance.balanceOf(accounts[3]);
        //console.log(`Earned this iteration: ${ethers.BigNumber.from(amt).sub((preBal)).div(DECIMALS)} iteration num: ${count} total bal: ${ethers.BigNumber.from(amt).div(DECIMALS)}`);
        //preBal = ethers.BigNumber.from(amt);
      }
  
      /*Show balances
      for(let i = 3; i< 20; i++)
      {
        console.log(await VertigoInstance.balanceOf(accounts[i]))
      }
      */
    });
  
    it("Stakes & unstakes Vertigo Successfully", async function()
    {
      await VertigoInstance.connect(signers[3]).stake_vert(800);
      await VertigoInstance.connect(signers[3]).unstake_vert(500);
    })
  
    it("Transfer stress test", async function()
    {
      let count = 4;
  
      for(count; count < 20; count++)
      {
        await VertigoInstance.connect(signers[3]).transfer(accounts[count], ethers.BigNumber.from(400).mul(DECIMALS));
      }
    });

  
    it("Staking stress test", async function()
    {
      let count = 4;
  
      for(count; count < 20; count++)
      {
        await VertigoInstance.connect(signers[count]).stake_vert(400);
        //await VertigoInstance.balanceOf(accounts[count]).then((res) => console.log(`It ${count} balance: ${ethers.BigNumber.from(res).div(DECIMALS)}`));
      }
    });
  
    
    it("Unstaking stress test", async function()
    {
      let count = 4;
  
      for(count; count < 20; count++)
      {
        //await VertigoInstance.balanceOf(accounts[count]).then((res) => console.log(`It ${count} balance: ${ethers.BigNumber.from(res).div(DECIMALS)}`))
        await VertigoInstance.connect(signers[count]).unstake_vert(250)
        //console.log("UNSTOOK")
        //await VertigoInstance.balanceOf(accounts[count]).then((res) => console.log(`It ${count} balance: ${ethers.BigNumber.from(res).div(DECIMALS)}`))
      }
    })

    it("Get stake taxes", async function()
    {
      
      for(let i = 0; i < 15; i++)
      {
        let value = await VertigoTokenStakingStorageInstance.get_stake_taxes(i);
        console.log(i, "TAX: ", value);
      }
      
    })

    it("Cycles successfully", async function()
    {
      let a = await VertigoTokenStakingStorageInstance.storage_contract_address();
      vtsc = await hre.ethers.getContractFactory("VertigoTokenStakingStorageContract");
      vtscIN = await vtsc.deploy(VertigoTokenStakingStorageInstance.address);
      await VertigoTokenStakingStorageInstance.cycle(vtscIN.address);

      a = await VertigoTokenStakingStorageInstance.storage_contract_address();
    })

    it("Retrieve staking dividends stress test", async function()
    {
      let count = 4;
  
      for(count; count < 20; count++)
      {
        //await VertigoInstance.balanceOf(accounts[count]).then((res) => console.log(`It ${count} balance: ${ethers.BigNumber.from(res).div(DECIMALS)}`))
        await VertigoInstance.connect(signers[count]).retrieve_vert_staking_dividends();
        //await VertigoInstance.balanceOf(accounts[count]).then((res) => console.log(`It ${count} balance: ${ethers.BigNumber.from(res).div(DECIMALS)}`))
      }
    })
  
    it("Staking stress test", async function()
    {
      let count = 4;
  
      for(count; count < 20; count++)
      {
        await VertigoInstance.connect(signers[count]).stake_vert(100);
        //await VertigoTokenStakingStorageInstance.get_user_stake_amount_tracker(accounts[count]).then((res) => console.log(`It ${count} staked amount: ${ethers.BigNumber.from(res).div(DECIMALS)}`))
      }
    });
  
  
    
    it("Unstaking stress test", async function()
    {
      let count = 4;
  
      for(count; count < 20; count++)
      {
        await VertigoInstance.connect(signers[count]).unstake_vert(40)
        //console.log("UNSTOOK")
        //await VertigoInstance.balanceOf(accounts[count]).then((res) => console.log(`It ${count} balance: ${ethers.BigNumber.from(res).div(DECIMALS)}`))
      }
    })

    it("Get stake taxes", async function()
    {
      
      for(let i = 0; i < 15; i++)
      {
        let value = await vtscIN.get_stake_tax(i);
        console.log(i, "TAX: ", value);
      }
      
    })
  
    it("Retrieve staking dividends stress test", async function()
    {
      let count = 4;
  
      for(count; count < 20; count++)
      {
        //await VertigoInstance.balanceOf(accounts[count]).then((res) => console.log(`It ${count} balance: ${ethers.BigNumber.from(res).div(DECIMALS)}`))
        await VertigoInstance.connect(signers[count]).retrieve_vert_staking_dividends();
        //await VertigoInstance.balanceOf(accounts[count]).then((res) => console.log(`It ${count} balance: ${ethers.BigNumber.from(res).div(DECIMALS)}`))
      }
    })
  
    it("Adds & removes users to team payout successfully.", async function()
    {
      for(let i = 4; i < 10; i++)
      {
        await VertigoInstance.modify_team_payout_recipients(accounts[i], 50)
        await VertigoInstance.balanceOf(accounts[i]).then((res) => {console.log(ethers.BigNumber.from(res).div(DECIMALS), i)})
      }
    })
  
    it("Gives team payout properly", async function()
    {
      //let wall = await VertigoInstance.teamPayoutWallet()
      //await VertigoInstance.balanceOf(teamPayoutWalletAddress).then((res) => {console.log(ethers.BigNumber.from(res).div(DECIMALS), "wall")})
      
      await VertigoInstance.connect(signers[3]).stake_vcash(3, 1);
      for(let count = 0; count < 10; count++)
      {
        await VertigoInstance.reset_pool_testing();
  
        await VertigoInstance.connect(signers[3]).weekly_reset(3);
        await VertigoInstance.connect(signers[3]).stake_vcash(3, 1);
        console.log("LOGGING")
        for(let i = 4; i < 10; i++)
        {
          await VertigoInstance.balanceOf(accounts[i]).then((res) => {console.log(ethers.BigNumber.from(res).div(DECIMALS), i)})
        }
      }
    })
  
    it("Removes users from team payout successfully", async function()
    {
      for(let i = 4; i < 10; i++)
      {
        await VertigoInstance.modify_team_payout_recipients(accounts[i], 0)
      }
    })

    it("Gets user data", async function()
    {

      for(let i = 0; i < 10; i++)
      {
        //console.log(i)
        //console.log(await ProfileStorageInstance.get_array(i));
        //console.log();
      }
    })



})
