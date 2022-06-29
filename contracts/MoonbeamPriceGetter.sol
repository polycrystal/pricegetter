// SPDX-License-Identifier: GPL
pragma solidity ^0.8.6;


import "./libs/IAMMInfo.sol";
import "./BasePriceGetter.sol";

// This library provides simple price calculations for tokens, accounting
// for commonly used pairings. Will break if USDT, BUSD, or USDC goes far off peg.
// Should NOT be used as the sole oracle for sensitive calculations such as 
// liquidation, as it is vulnerable to manipulation by flash loans, etc. BETA
// SOFTWARE, PROVIDED AS IS WITH NO WARRANTIES WHATSOEVER.

// Moonbeam mainnet version

contract MoonbeamPriceGetter is BasePriceGetter {

    //Ape LP addresses
    address private constant WGLMR_USDCmulti_PAIR = 0x555B74dAFC4Ef3A5A1640041e3244460Dc7610d1;
    address private constant WGLMR_BUSD_PAIR = 0x367c36dAE9ba198A4FEe295c22bC98cB72f77Fe1;
    address private constant WGLMR_USDC_PAIR = 0x9bFcf685e641206115dadc0C9ab17181e1d4975c;
    
    address private constant WETH_USDC_PAIR = 0x6BA3071760d46040FB4dc7B627C9f68efAca3000;
    address private constant USDC_BNB_PAIR = 0xAc2657ba28768FE5F09052f07A9B7ea867A4608f;
    address private constant BUSD_BNB_PAIR = 0x34A1F4AB3548A92C6B32cd778Eed310FcD9A340D;

    constructor(address _data) BasePriceGetter(
        _data,
        0xAcc15dC74880C9944775448304B263D191c6077F, //wnative
        0x30D2a9F5FDf90ACe8c17952cbb4eE48a55D916A7, //weth
        0xeFAeeE334F0Fd1712f9a8cc375f427D9Cdd40d73, //usdt
        0x818ec0A7Fe18Ff94269904fCED6AE3DaE6d6dC0b, //usdc
        0xA649325Aa7C5093d12D6F98EB4378deAe68CE23F //busd
    ) {}

    //returns the current USD price of MATIC based on primary stablecoin pairs
    function getGasPrice() internal override view returns (uint) {
        (uint wmaticReserve0, uint usdtReserve,) = IUniPair(WGLMR_USDCmulti_PAIR).getReserves();
        (uint wmaticReserve1, uint busdReserve,) = IUniPair(WGLMR_BUSD_PAIR).getReserves();
        (uint wmaticReserve2, uint usdcReserve,) = IUniPair(WGLMR_USDC_PAIR).getReserves();
        uint wmaticTotal = wmaticReserve0 + wmaticReserve1 + wmaticReserve2;
        uint usdTotal = busdReserve + (usdcReserve + usdtReserve)*1e12; // 1e18 USDC/T == 1e30 BUSD
        
        return usdTotal * PRECISION / wmaticTotal; 
    }
    
    //returns the current USD price of MATIC based on primary stablecoin pairs
    function getETHPrice() internal override view returns (uint) {
        (uint wethReserve0, uint usdtReserve,) = IUniPair(WETH_USDC_PAIR).getReserves();
        (uint usdcReserve, uint wethReserve1,) = IUniPair(USDC_BNB_PAIR).getReserves();
        (uint wethReserve2, uint busdReserve,) = IUniPair(BUSD_BNB_PAIR).getReserves();
        uint wethTotal = wethReserve0 + wethReserve1 + wethReserve2;
        uint usdTotal = busdReserve + (usdcReserve + usdtReserve)*1e12; // 1e18 USDC/T == 1e30 BUSD
        
        return usdTotal * PRECISION / wethTotal; 
    }
    
}