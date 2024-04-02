//SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

library PropertyStorage
{
    struct Property
	{
		string propertyName;

		bool buyable; //
        bool VCashProperty; //
		bool incomeIsDelegated; //
		bool defaultProperty; //
		
		uint256 index; //
		uint256 payBonus; //
		uint256 basePrice; //
		uint256 buyLimit; //
		uint256 level;
		uint256 owner;
	}
}