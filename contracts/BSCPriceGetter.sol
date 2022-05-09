// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.4;

import "./libs/IAMMInfo.sol";
import "./BasePriceGetter.sol";

// This library provides simple price calculations for Crodex tokens, accounting
// for commonly used pairings. Will break if USDT, BUSD, or DAI goes far off peg.
// Should NOT be used as the sole oracle for sensitive calculations such as 
// liquidation, as it is vulnerable to manipulation by flash loans, etc. BETA
// SOFTWARE, PROVIDED AS IS WITH NO WARRANTIES WHATSOEVER.

// Cronos mainnet version

contract BSCPriceGetter is BasePriceGetter {
    
    //Token addresses
    //address constant WBTC = 0x062E66477Faf219F25D27dCED647BF57C3107d52; //8 decimals

    // PancakeSwap LP addresses
    address private constant WBNB_USDT_PAIR = 0x16b9a82891338f9bA80E2D6970FddA79D1eb0daE;
    address private constant WBNB_BUSD_PAIR = 0x58F876857a02D6762E0101bb5C46A8c1ED44Dc16;
    address private constant WBNB_USDC_PAIR = 0xd99c7F6C65857AC913a8f880A4cb84032AB2FC5b;
    
    address private constant WETH_USDT_PAIR = 0x531FEbfeb9a61D948c384ACFBe6dCc51057AEa7e;
    address private constant USDC_WETH_PAIR = 0xEa26B78255Df2bBC31C1eBf60010D78670185bD0; 
    address private constant WETH_BUSD_PAIR = 0x7213a321F1855CF1779f42c0CD85d3D95291D34C; 
    
    constructor(address _data) BasePriceGetter(
        _data,
        0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c, //wnative
        0x2170Ed0880ac9A755fd29B2688956BD959F933F8, //weth
        0x55d398326f99059fF775485246999027B3197955, // usdt
        0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d, // usdc 
        0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56 // busd 
    ) {}

    //returns the current USD price of CRO based on primary stablecoin pairs
    function getGasPrice() internal override view returns (uint) {
        (uint wbnbReserve0, uint usdtReserve,) = IUniPair(WBNB_USDT_PAIR).getReserves();
        (uint wbnbReserve1, uint daiReserve,) = IUniPair(WBNB_BUSD_PAIR).getReserves();
        (uint wbnbReserve2, uint usdcReserve,) = IUniPair(WBNB_USDC_PAIR).getReserves();
        uint wbnbTotal = wbnbReserve0 + wbnbReserve1 + wbnbReserve2;
        uint usdTotal = daiReserve + (usdcReserve + usdtReserve); // 1e18 USDC/T == 1e30 BUSD
        
        return usdTotal * PRECISION / wbnbTotal; 
    }
    
    // //returns the current USD price of CRO based on primary stablecoin pairs
    function getETHPrice() internal override view returns (uint) {
        (uint usdtReserve, uint wethReserve0,) = IUniPair(WETH_USDT_PAIR).getReserves();
//        (uint usdcReserve, uint wethReserve1,) = IUniPair(USDC_WETH_PAIR).getReserves();
//        (uint wethReserve2, uint daiReserve,) = IUniPair(WETH_BUSD_PAIR).getReserves();
        uint wethTotal = wethReserve0; //+ wethReserve1 + wethReserve2;
        uint usdTotal = usdtReserve; //daiReserve + (usdcReserve + usdtReserve)*1e12 //1e18 USDC/T == 1e30 BUSD
        
        return usdTotal * PRECISION / wethTotal; 
    }
    
}