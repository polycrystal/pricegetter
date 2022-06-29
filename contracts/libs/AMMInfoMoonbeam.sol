// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.9;

/*
Join us at Crystl.Finance!
█▀▀ █▀▀█ █░░█ █▀▀ ▀▀█▀▀ █▀▀█ █░░ 
█░░ █▄▄▀ █▄▄█ ▀▀█ ░░█░░ █▄▄█ █░░ 
▀▀▀ ▀░▀▀ ▄▄▄█ ▀▀▀ ░░▀░░ ▀░░▀ ▀▀▀
*/


import "./IAMMInfo.sol";

contract AMMInfoMoonbeam is IAMMInfo {

    address constant private STELLA_FACTORY = 0x68A384D826D3678f78BB9FB1533c7E9577dACc0E;
    address constant private BEAM_FACTORY = 0x985BcA32293A7A496300a48081947321177a86FD;

    //used for internally locating a pair without an external call to the factory
    bytes32 constant private STELLA_PAIRCODEHASH = hex'48a6ca3d52d0d0a6c53a83cc3c8688dd46ea4cb786b169ee959b95ad30f61643';
    bytes32 constant private BEAM_PAIRCODEHASH = hex'e31da4209ffcce713230a74b5287fa8ec84797c9e77e1f7cfeccea015cdc97ea';

    // Fees are in increments of 1 basis point (0.01%)
    uint8 constant private STELLA_FEE = 25; 
    uint8 constant private BEAM_FEE = 17;

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
        list = new AmmInfo[](2);
        list[0] = AmmInfo({
            name: "StellaSwap", 
            router: 0x70085a09D30D6f8C4ecF6eE10120d1847383BB57,
            factory: STELLA_FACTORY,
            paircodehash: STELLA_PAIRCODEHASH,
            fee: STELLA_FEE
        });
        list[1] = AmmInfo({
            name: "BeamSwap", 
            router: 0x96b244391D98B62D19aE89b1A4dCcf0fc56970C7,
            factory: BEAM_FACTORY,
            paircodehash: BEAM_PAIRCODEHASH,
            fee: BEAM_FEE
        });
    }
}