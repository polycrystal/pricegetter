// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.4;


import "./libs/IAMMInfo.sol";
import "./libs/IUniRouter.sol";
import "./libs/IUniFactory.sol";

contract UniV2AMM {

    mapping(IUniFactory => bytes32) public initcodehashes;

    event HashAdded(IUniFactory indexed factory, bytes32 hash);

    //Returns the fee rate used by a router for determining amounts out. This SHOULD match the associated factory, but there is nothing stopping
    //people from deploying Uniswap v2 forks with mismatched components. If a router is in active use, we can, at least, be certain that the correct
    //fee rate is not higher than the return value here.
    function feeRate(IUniRouter02 router) external pure returns (uint8) {
        uint rate = (1e12 - router.getAmountOut(1e12, 2**128, 2**128)) / 1e8;
        require (rate < 256, "Invalid fee rate (or greater than 2.5%)");
        return uint8(rate);
    }

    function addinitcodehash(IUniFactory factory) external {
        try factory.INIT_CODE_PAIR_HASH() returns (bytes32 hash) {
            addinitcodehash(factory, hash);
        } catch {
            revert("Cannot automatically determine hash");
        }
    }

    function addinitcodehash(IUniFactory factory, bytes32 hash) public {
        bytes32 storedHash = initcodehashes[factory];
        require (storedHash == 0, "Hash already stored");

        IUniPair pair0 = IUniPair(factory.allPairs(0));
        require(address(pair0) == pairFor(pair0.token0(), pair0.token1(), address(factory), hash), "incorrect initcodehash");

        initcodehashes[factory] = hash;
        emit HashAdded(factory, hash);
    }

}