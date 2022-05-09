// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.9;

/*
Join us at Crystl.Finance!
█▀▀ █▀▀█ █░░█ █▀▀ ▀▀█▀▀ █▀▀█ █░░ 
█░░ █▄▄▀ █▄▄█ ▀▀█ ░░█░░ █▄▄█ █░░ 
▀▀▀ ▀░▀▀ ▄▄▄█ ▀▀▀ ░░▀░░ ▀░░▀ ▀▀▀
*/

import "./IAMMInfo.sol";

contract AMMInfoBSC is IAMMInfo {

    address constant private PANCAKE_FACTORY = 0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73;
    address constant private APESWAP_FACTORY = 0x0841BD0B734E4F5853f0dD8d7Ea041c241fb0Da6;
    address constant private BABYSWAP_FACTORY = 0x86407bEa2078ea5f5EB5A52B2caA963bC1F889Da;
    address constant private BISWAP_FACTORY = 0x858E3312ed3A876947EA49d572A7C42DE08af7EE; 

    //used for internally locating a pair without an external call to the factory
    bytes32 constant private PANCAKE_PAIRCODEHASH = 0x00fb7f630766e6a796048ea87d01acd3068e8ff67d078148a3fa3f4a84f69bd5;
    bytes32 constant private APESWAP_PAIRCODEHASH = 0xf4ccce374816856d11f00e4069e7cada164065686fbef53c6167a63ec2fd8c5b;
    bytes32 constant private BABYSWAP_PAIRCODEHASH = 0x48c8bec5512d397a5d512fbb7d83d515e7b6d91e9838730bd1aa1b16575da7f5;
    bytes32 constant private BISWAP_PAIRCODEHASH = 0xfea293c909d87cd4153593f077b76bb7e94340200f4ee84211ae8e4f9bd7ffdf; 

    // Fees are in increments of 1 basis point (0.01%)
    uint8 constant private PANCAKE_FEE = 25;
    uint8 constant private APESWAP_FEE = 20;
    uint8 constant private BABYSWAP_FEE = 30;
    uint8 constant private BISWAP_FEE = 10; 

    constructor() {
        AmmInfo[] memory list = getAmmList();
        for (uint i; i < list.length; i++) {
            require(IUniRouter02(list[i].router).factory() == list[i].factory, "wrong router/factory");

            IUniFactory f = IUniFactory(list[i].factory);
            IUniPair pair = IUniPair(f.allPairs(0));
            address token0 = pair.token0();
            address token1 = pair.token1();
            
            require(pairFor(token0, token1, list[i].factory, list[i].paircodehash) == address(pair), "bad initcodehash?");

        }

    }

    function getAmmList() public pure returns (AmmInfo[] memory list) {
        list = new AmmInfo[](4);
        list[0] = AmmInfo({
            name: "PancakeSwap", 
            router: 0x10ED43C718714eb63d5aA57B78B54704E256024E, 
            factory: PANCAKE_FACTORY,
            paircodehash: PANCAKE_PAIRCODEHASH,
            fee: PANCAKE_FEE
        });
        list[1] = AmmInfo({
            name: "ApeSwap", 
            router: 0xcF0feBd3f17CEf5b47b0cD257aCf6025c5BFf3b7,
            factory: APESWAP_FACTORY,
            paircodehash: APESWAP_PAIRCODEHASH,
            fee: APESWAP_FEE
        });
        list[2] = AmmInfo({
            name: "BabySwap", 
            router: 0x8317c460C22A9958c27b4B6403b98d2Ef4E2ad32, 
            factory: BABYSWAP_FACTORY,
            paircodehash: BABYSWAP_PAIRCODEHASH,
            fee: BABYSWAP_FEE
        });
        list[3] = AmmInfo({
            name: "BiSwap", 
            router: 0x3a6d8cA21D1CF76F653A67577FA0D27453350dD8,
            factory: BISWAP_FACTORY,
            paircodehash: BISWAP_PAIRCODEHASH,
            fee: BISWAP_FEE
        });
    }

}