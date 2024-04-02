//SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

library ProfileStorage
{

    struct Profile
	{
        uint256 multiplier;
        uint256 VCashPropertyIndex;
        uint256 VERTPropertyIndex;
        uint256 teamPayoutShare;
        uint256 password;
        uint256 VCashStaked;
        uint256 userVCashBalance;
        uint256 payoutPerTx;
        uint256 pendingVCashDividends;
        uint256 lastUpdateTime;
        uint256 tier;
	}
}