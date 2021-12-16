// SPDX-License-Identifier: GPL
pragma solidity ^0.8.6;

// This library provides simple price calculations for ApeSwap tokens, accounting
// for commonly used pairings. Will break if USDT, BUSD, or DAI goes far off peg.
// Should NOT be used as the sole oracle for sensitive calculations such as 
// liquidation, as it is vulnerable to manipulation by flash loans, etc. BETA
// SOFTWARE, PROVIDED AS IS WITH NO WARRANTIES WHATSOEVER.

// Polygon mainnet version

library PriceGetter {
    using AMMData for AmmData;
    
    //Returned prices calculated with this precision (18 decimals)
    uint public constant DECIMALS = 18;
    uint private constant PRECISION = 1e18; //1e18 == $1
    
    //Token addresses
    address constant WMATIC = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
    address constant WETH = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;
    address constant USDC = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
    address constant DAI = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
    address constant USDT = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;

    //Ape LP addresses
    address private constant WMATIC_USDT_PAIR = 0x65D43B64E3B31965Cd5EA367D4c2b94c03084797;
    address private constant WMATIC_DAI_PAIR = 0x84964d9f9480a1dB644c2B2D1022765179A40F68;
    address private constant WMATIC_USDC_PAIR = 0x019011032a7ac3A87eE885B6c08467AC46ad11CD;
    
    address private constant WETH_USDT_PAIR = 0x7B2dD4bab4487a303F716070B192543eA171d3B2;
    address private constant USDC_WETH_PAIR = 0x84964d9f9480a1dB644c2B2D1022765179A40F68;
    address private constant WETH_DAI_PAIR = 0xb724E5C1Aef93e972e2d4b43105521575f4ca855;

    //Normalized to specified number of decimals based on token's decimals and
    //specified number of decimals
    function getPrice(address token, uint _decimals) external view returns (uint) {
        return normalize(getRawPrice(token), token, _decimals);
    }

    function getLPPrice(address token, uint _decimals) external view returns (uint) {
        return normalize(getRawLPPrice(token), token, _decimals);
    }
    function getPrices(address[] calldata tokens, uint _decimals) external view returns (uint[] memory prices) {
        prices = getRawPrices(tokens);
        
        for (uint i; i < prices.length; i++) {
            prices[i] = normalize(prices[i], tokens[i], _decimals);
        }
    }
    function getLPPrices(address[] calldata tokens, uint _decimals) external view returns (uint[] memory prices) {
        prices = getRawLPPrices(tokens);
        
        for (uint i; i < prices.length; i++) {
            prices[i] = normalize(prices[i], tokens[i], _decimals);
        }
    }
    
    //returns the price of any token in USD based on common pairings; zero on failure
    function getRawPrice(address token) internal view returns (uint) {
        uint pegPrice = pegTokenPrice(token);
        if (pegPrice != 0) return pegPrice;
        
        return getRawPrice(token, getMATICPrice(), getETHPrice());
    }
    
    //returns the prices of multiple tokens, zero on failure
    function getRawPrices(address[] calldata tokens) public view returns (uint[] memory prices) {
        prices = new uint[](tokens.length);
        uint maticPrice = getMATICPrice();
        uint ethPrice = getETHPrice();
        
        for (uint i; i < prices.length; i++) {
            address token = tokens[i];
            
            uint pegPrice = pegTokenPrice(token, maticPrice, ethPrice);
            if (pegPrice != 0) prices[i] = pegPrice;
            else prices[i] = getRawPrice(token, maticPrice, ethPrice);
        }
    }
    
    //returns the value of a LP token if it is one, or the regular price if it isn't LP
    function getRawLPPrice(address token) internal view returns (uint) {
        uint pegPrice = pegTokenPrice(token);
        if (pegPrice != 0) return pegPrice;
        
        return getRawLPPrice(token, getMATICPrice(), getETHPrice());
    }
    //returns the prices of multiple tokens which may or may not be LPs
    function getRawLPPrices(address[] calldata tokens) internal view returns (uint[] memory prices) {
        prices = new uint[](tokens.length);
        uint maticPrice = getMATICPrice();
        uint ethPrice = getETHPrice();
        
        for (uint i; i < prices.length; i++) {
            address token = tokens[i];
            
            uint pegPrice = pegTokenPrice(token, maticPrice, ethPrice);
            if (pegPrice != 0) prices[i] = pegPrice;
            else prices[i] = getRawLPPrice(token, maticPrice, ethPrice);
        }
    }
    //returns the current USD price of MATIC based on primary stablecoin pairs
    function getMATICPrice() internal view returns (uint) {
        (uint wmaticReserve0, uint usdtReserve,) = IApePair(WMATIC_USDT_PAIR).getReserves();
        (uint wmaticReserve1, uint daiReserve,) = IApePair(WMATIC_DAI_PAIR).getReserves();
        (uint wmaticReserve2, uint usdcReserve,) = IApePair(WMATIC_USDC_PAIR).getReserves();
        uint wmaticTotal = wmaticReserve0 + wmaticReserve1 + wmaticReserve2;
        uint usdTotal = daiReserve + (usdcReserve + usdtReserve)*1e12; // 1e18 USDC/T == 1e30 DAI
        
        return usdTotal * PRECISION / wmaticTotal; 
    }
    
    //returns the current USD price of MATIC based on primary stablecoin pairs
    function getETHPrice() internal view returns (uint) {
        (uint wethReserve0, uint usdtReserve,) = IApePair(WETH_USDT_PAIR).getReserves();
        (uint usdcReserve, uint wethReserve1,) = IApePair(USDC_WETH_PAIR).getReserves();
        (uint wethReserve2, uint daiReserve,) = IApePair(WETH_DAI_PAIR).getReserves();
        uint wethTotal = wethReserve0 + wethReserve1 + wethReserve2;
        uint usdTotal = daiReserve + (usdcReserve + usdtReserve)*1e12; // 1e18 USDC/T == 1e30 DAI
        
        return usdTotal * PRECISION / wethTotal; 
    }
    
    //Calculate LP token value in USD. Generally compatible with any UniswapV2 pair but will always price underlying
    //tokens using ape prices. If the provided token is not a LP, it will attempt to price the token as a
    //standard token. This is useful for MasterChef farms which stake both single tokens and pairs
    function getRawLPPrice(address lp, uint maticPrice, uint ethPrice) internal view returns (uint) {
        
        //if not a LP, handle as a standard token
        try IApePair(lp).getReserves() returns (uint112 reserve0, uint112 reserve1, uint32) {
            
            address token0 = IApePair(lp).token0();
            address token1 = IApePair(lp).token1();
            uint totalSupply = IApePair(lp).totalSupply();
            
            //price0*reserve0+price1*reserve1
            uint totalValue = getRawPrice(token0, maticPrice, ethPrice) * reserve0 
                + getRawPrice(token1, maticPrice, ethPrice) * reserve1;
            
            return totalValue / totalSupply;
            
        } catch {
            return getRawPrice(lp, maticPrice, ethPrice);
        }
    }

    // checks for primary tokens and returns the correct predetermined price if possible, otherwise calculates price
    function getRawPrice(address token, uint maticPrice, uint ethPrice) internal view returns (uint rawPrice) {
        uint pegPrice = pegTokenPrice(token, maticPrice, ethPrice);
        if (pegPrice != 0) return pegPrice;

        uint numTokens;
        uint pairedValue;
        
        uint lpTokens;
        uint lpValue;
        
        (lpTokens, lpValue) = pairTokensAndValueMulti(token, WMATIC);
        numTokens += lpTokens;
        pairedValue += lpValue;
        
        (lpTokens, lpValue) = pairTokensAndValueMulti(token, WETH);
        numTokens += lpTokens;
        pairedValue += lpValue;
        
        (lpTokens, lpValue) = pairTokensAndValueMulti(token, DAI);
        numTokens += lpTokens;
        pairedValue += lpValue;
        
        (lpTokens, lpValue) = pairTokensAndValueMulti(token, USDC);
        numTokens += lpTokens;
        pairedValue += lpValue;
        
        (lpTokens, lpValue) = pairTokensAndValueMulti(token, USDT);
        numTokens += lpTokens;
        pairedValue += lpValue;
        
        if (numTokens > 0) return pairedValue / numTokens;
    }
    //if one of the peg tokens, returns that price, otherwise zero
    function pegTokenPrice(address token, uint maticPrice, uint ethPrice) private pure returns (uint) {
        if (token == USDT || token == USDC) return PRECISION*1e12;
        if (token == WMATIC) return maticPrice;
        if (token == WETH) return ethPrice;
        if (token == DAI) return PRECISION;
        return 0;
    }
    function pegTokenPrice(address token) private view returns (uint) {
        if (token == USDT || token == USDC) return PRECISION*1e12;
        if (token == WMATIC) return getMATICPrice();
        if (token == WETH) return getETHPrice();
        if (token == DAI) return PRECISION;
        return 0;
    }

    //returns the number of tokens and the USD value within a single LP. peg is one of the listed primary, pegPrice is the predetermined USD value of this token
    function pairTokensAndValue(address token, address peg, address factory, bytes32 initcodehash) private view returns (uint tokenNum, uint pegValue) {

        address tokenPegPair = pairFor(token, peg, factory, initcodehash);
        
        // if the address has no contract deployed, the pair doesn't exist
        uint256 size;
        assembly { size := extcodesize(tokenPegPair) }
        if (size == 0) return (0,0);
        
        try IApePair(tokenPegPair).getReserves() returns (uint112 reserve0, uint112 reserve1, uint32) {
            uint reservePeg;
            (tokenNum, reservePeg) = token < peg ? (reserve0, reserve1) : (reserve1, reserve0);
            pegValue = reservePeg * pegTokenPrice(peg);
        } catch {
            return (0,0);
        }

    }
    
    function pairTokensAndValueMulti(address token, address peg) private view returns (uint tokenNum, uint pegValue) {
        
        //across all AMMs in AMMData library
        for (AmmData amm = AmmData.APE; uint8(amm) < AMMData.NUM_AMMS; amm = AmmData(uint(amm) + 1)) {
            (uint tokenNumLocal, uint pegValueLocal) = pairTokensAndValue(token, peg, amm.factory(), amm.pairCodeHash());
            tokenNum += tokenNumLocal;
            pegValue += pegValueLocal;
        }
    }
    
    //normalize a token price to a specified number of decimals
    function normalize(uint price, address token, uint _decimals) private view returns (uint) {
        uint tokenDecimals;
        
        try IERC20Metadata(token).decimals() returns (uint8 dec) {
            tokenDecimals = dec;
        } catch {
            tokenDecimals = 18;
        }

        if (tokenDecimals + _decimals <= 2*DECIMALS) return price / 10**(2*DECIMALS - tokenDecimals - _decimals);
        else return price * 10**(_decimals + tokenDecimals - 2*DECIMALS);
    
    }
    // calculates the CREATE2 address for a pair without making any external calls
    function pairFor(address tokenA, address tokenB, address factory, bytes32 initcodehash) private pure returns (address pair) {
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        pair = address(uint160(uint(keccak256(abi.encodePacked(
                hex'ff',
                factory,
                keccak256(abi.encodePacked(token0, token1)),
                initcodehash
        )))));
    }
    
    
}