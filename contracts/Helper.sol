/*
    This library contains functions that address specific problems 
    that can be solved with bitwise operations.
*/

//SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

library Helper
{
    function get_total_values(uint256[][] memory values)
    external pure
    returns (uint256 len)
    {
        uint256 l = values.length;
        uint256 v;

        for(uint256 i = 0; i < l; i++)
        {
            v += values[i].length;
        }

        return v;
    }

    /*
        This function calculates the number of uint256 variables preceeding
        the variable that will store the value at index, based on the bit counts
        present in the structure array.
    */
    function get_page(uint256[] memory structure, uint256 index)
    external pure
    returns(uint256)
    {
        uint256 bits;
        uint256 page;

        for(uint i = 0; i <= index; i++)
        {
            if(structure[i] + bits > 256)
            {
                page += 1;
                bits = structure[i];
            }
            else
            {
                bits += structure[i];
            }
        }

        return page;
    }

    /*
        Returns the uint limit of a given bit count.
    */
    function num_to_bit_limit(uint256 n)
    external pure
    returns(uint256)
    {
        if(n == 8) return 0xFF;
        else if(n == 16) return 0xFFFF;
        else if(n == 32) return 0xFFFFFFFF;
        else if(n == 64) return 0xFFFFFFFFFFFFFFFF;
        else if(n == 128) return 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
        else if(n == 256) return 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
        return 0;
    }

    /*
        Constricts a value to within a given bit range.
    */
    function constrict(uint256 value, uint256 bits)
    external pure
    returns(uint256)
    {
        if(bits == 8)
        {
            return (uint256(uint8(value)));
        }
        else if(bits == 16)
        {
            return (uint256(uint16(value)));
        }
        else if(bits == 32)
        {
            return (uint256(uint32(value)));
        }
        else if(bits == 64)
        {
            return (uint256(uint64(value)));
        }
        else if(bits == 128)
        {
            return (uint256(uint128(value)));
        }
        else if(bits == 256)
        {
            return value;
        }

        else require(false);

        return value;
    }

    /*
        Tells if an integer is a power of 2.
    */
    function is_power_of_two(uint256 value)
    external pure
    returns(bool b)
    {
        if ((value & (value - 1)) == 0) b = true;
    }

    /*
        Tells if an integer is a power of 2.
    */
    function is_power_of_two_gte_eight(uint256 value)
    external pure
    returns(bool b)
    {
        require(value >= 8);
        if ((value & (value - 1)) == 0) b = true;
    }


    /*
        Converts a mapping to an array.
    */
    function to_arr(mapping(uint256 => uint256) storage m, uint256 len)
    external view
    returns(uint256[] memory)
    {
        uint256[] memory st = new uint256[](len);
        for(uint i = 0 ; i < len; i++)
        {
            st[i] = m[i];
        }
        return st;
    }


}