// SPDX-License-Identifier: GPL
pragma solidity ^0.8.9;

import "./libs/IVaultHealer.sol"; // polygon: 0xd4d696ad5a7779f4d3a0fc1361adf46ec51c632d
import "./libs/IUniPair.sol";
import "./libs/IMasterchef.sol";
import "./BasePriceGetter.sol"; //polygon: 0x05D6C73D7de6E02B3f57677f849843c03320681c
uint constant GAS_FACTOR = 200000;

contract VaultGetter {

    struct VaultFacts {
        //these are immutable and so are stored here in this contract
        uint16 vaultPid;
        uint16 chefPid;
        uint8 tolerance;
        address masterchefAddress;
        address wantAddress;
        address strategyAddress;
        address token0Address;
        address token1Address;
        address lpFactoryAddress;
        address earnedAddress;
        string token0Symbol;
        string token1Symbol;
    }
    struct VaultInfo {
        bool paused;
        uint wantLockedTotal;
        uint burnedAmount;
        
        uint lpTokenPrice;
        uint earnedTokenPrice;

        uint vaultSharesTotal;
        uint masterchefWantBalance;        
        //uint allocPoint;
        //uint totalAllocPoint;
    }
    struct VaultUser {
	    uint allowance;
	    uint tokenBalance;
	    uint stakedBalance;
	    uint stakedWantBalance;
	    uint stakedBalanceUSD;
    }


    mapping(address => VaultFacts[]) public vaultFacts; //vaultHealer =>
    mapping(address => uint8) internal wantDecimals;

    event VaultAdded(VaultFacts facts);
    function sync(address vaultHealerAddress) external {
        //add immutable data for all vaults not already included
        IVaultHealer vaultHealer = IVaultHealer(vaultHealerAddress);
        uint vhLen = vaultHealer.poolLength();
        uint factLen = vaultFacts[vaultHealerAddress].length;
        //assert(factLen <= vhLen);
        if (vhLen == factLen) revert("already synced");

        require(gasleft() >= GAS_FACTOR * (vhLen - factLen < 50 ? vhLen - factLen : 50)); //ensure enough gas for sync
        VaultFacts[] storage facts = vaultFacts[vaultHealerAddress];

        for (uint i = factLen; i < vhLen; i++) {
            facts.push();
            VaultFacts storage f = facts[i];
            (IERC20 _want, IStrategy _strat) = vaultHealer.poolInfo(i);
            uint16 vaultPid = uint16(i);
            uint16 chefPid;
            uint8 tolerance;
            address masterchefAddress;

            try _strat.pid() returns (uint256 _chefPid) {
                chefPid = uint16(_chefPid);
            } catch {}
            try _strat.tolerance() returns (uint256 _tolerance) {
                tolerance = uint8(_tolerance);
            } catch {}
            try _strat.masterchefAddress() returns (address _masterchef) {
                masterchefAddress = _masterchef;
            } catch {}

            //optimized to fit 4 variables in one storage slot
            f.vaultPid = vaultPid;
            f.chefPid = chefPid;
            f.tolerance = tolerance;
            f.masterchefAddress = masterchefAddress;

            f.wantAddress = address(_want);
            f.strategyAddress = address(_strat);

            IUniPair want = IUniPair(address(_want));

            try want.token0() returns (address _token0) {
                f.token0Address = _token0;
                wantDecimals[address(want)] = 18;
                try IERC20Metadata(_token0).symbol() returns (string memory _symbol0) {
                    f.token0Symbol = _symbol0;
                } catch {
                    try IERC20Metadata(address(_want)).symbol() returns (string memory _symbol0) { //no token0 so use want token instead
                        f.token0Symbol = _symbol0;
                    } catch {}
                }
                try want.token1() returns (address _token1) {
                    f.token1Address = _token1;
                    try IERC20Metadata(_token1).symbol() returns (string memory _symbol1) {
                        f.token1Symbol = _symbol1;
                    } catch {}
                    try want.factory() returns (address _factory) {
                        f.lpFactoryAddress = _factory;
                    } catch {}
                } catch {}
            } catch {
                try IERC20Metadata(address(_want)).symbol() returns (string memory _symbol0) { //no token0 so use want token instead
                    f.token0Symbol = _symbol0;
                } catch {}
                if (wantDecimals[address(want)] == 0) {
                    try IERC20Metadata(address(want)).decimals() returns (uint8 decimals) {
                        wantDecimals[address(want)] = decimals;
                    } catch {
                        wantDecimals[address(want)] = 18;
                    }
                }
            }
            try _strat.earnedAddress() returns (address _earned) {
                f.earnedAddress = _earned;
            } catch {}

            emit VaultAdded(f);
            if (gasleft() < GAS_FACTOR) return;
        }
    }

    function _getUser(address vaultHealerAddress, uint256 pid, IERC20 wantToken, IStrategy strat, uint wantLockedTotal, uint lpTokenPrice, address _user) internal view returns (VaultUser memory user) {

       if (_user != address(0)) {
            try wantToken.allowance(_user, vaultHealerAddress) returns (uint allowance) {
                user.allowance = allowance;
            } catch {}
            try wantToken.balanceOf(_user) returns (uint _balance) {
                user.tokenBalance = _balance;
            } catch {}
            
            try IVaultHealer(vaultHealerAddress).userInfo(pid, _user) returns (uint shares) {
                user.stakedBalance = shares;
                uint numerator = shares * wantLockedTotal;
                if (numerator > 0) try strat.sharesTotal() returns (uint sharesTotal) {
                    if (sharesTotal > 0) {
                        user.stakedWantBalance = numerator / sharesTotal;
                        user.stakedBalanceUSD = numerator * lpTokenPrice / sharesTotal / 10**wantDecimals[address(wantToken)];
                    }
                } catch {}
            } catch {}
        }
    }

    function getVault(address vaultHealerAddress, address priceGetterAddress, uint pid, address _user) public view returns (VaultFacts memory facts, VaultInfo memory info, VaultUser memory user) {
        (facts, info) = _getVault(vaultHealerAddress, pid);
        
        address[] memory priceTokens =  new address[](2);
        priceTokens[0] = facts.wantAddress;
        priceTokens[1] = facts.earnedAddress;
        try BasePriceGetter(priceGetterAddress).getLPPrices(priceTokens, 18) returns (uint256[] memory price) {
            info.lpTokenPrice = price[0];
            info.earnedTokenPrice = price[1];
        } catch {}

        user = _getUser(vaultHealerAddress, pid, IERC20(priceTokens[0]), IStrategy(facts.strategyAddress), info.wantLockedTotal, info.lpTokenPrice, _user);
    }

    function _getVault(address vaultHealerAddress, uint pid) internal view returns (VaultFacts memory facts, VaultInfo memory info) {

        facts = vaultFacts[vaultHealerAddress][pid];

        IStrategy strat = IStrategy(facts.strategyAddress);
        try strat.paused() returns (bool _paused) {
            info.paused = _paused;
        } catch {}
        try strat.vaultSharesTotal() returns (uint _vaultSharesTotal) {
            info.vaultSharesTotal = _vaultSharesTotal;
        } catch{ }
        IERC20 wantToken = IERC20(facts.wantAddress);

        try wantToken.balanceOf(address(strat)) returns (uint _stratWantBalance) {
            info.wantLockedTotal = info.vaultSharesTotal + _stratWantBalance;
        } catch {}
        try strat.burnedAmount() returns (uint _burnedAmount) {
            info.burnedAmount = _burnedAmount;
        } catch{ }
        if (facts.masterchefAddress != address(0)) try wantToken.balanceOf(facts.masterchefAddress) returns (uint _chefWantBalance) {
            info.masterchefWantBalance = _chefWantBalance;
        } catch {}

    } 

    function getVaults(address vaultHealerAddress, address priceGetterAddress, address _user) external view returns (
        VaultFacts[] memory facts, 
        VaultInfo[] memory infos, 
        VaultUser[] memory user
    ) {
        (facts, infos) =  getVaults(vaultHealerAddress, priceGetterAddress, 0, 0);
        uint len = facts.length;
        user = new VaultUser[](len);

        for (uint i; i < len; i++) {
            user[i] = _getUser(vaultHealerAddress, i, IERC20(facts[i].wantAddress), IStrategy(facts[i].strategyAddress), infos[i].wantLockedTotal, infos[i].lpTokenPrice, _user);
        }
    }

    function getVaults(address vaultHealerAddress, address priceGetterAddress) external view returns (
        VaultFacts[] memory facts, 
        VaultInfo[] memory infos
    ) {
        return getVaults(vaultHealerAddress, priceGetterAddress, 0, 0);
    }

    function getVaults(address vaultHealerAddress, address priceGetterAddress, uint start, uint end, address _user) external view returns (
    VaultFacts[] memory facts, 
    VaultInfo[] memory infos,
    VaultUser[] memory user
    ) {
        (facts, infos) = getVaults(vaultHealerAddress, priceGetterAddress, start, end);
        uint len = end - start;
        user = new VaultUser[](len);
        for (uint i; i < len; i++) {
            user[i] = _getUser(vaultHealerAddress, i + start, IERC20(facts[i].wantAddress), IStrategy(facts[i].strategyAddress), infos[i].wantLockedTotal, infos[i].lpTokenPrice, _user);
        }
    }

    function getVaults(address vaultHealerAddress, address priceGetterAddress, uint start, uint end) public view returns (
    VaultFacts[] memory facts, 
    VaultInfo[] memory infos
    ) {
        uint len = vaultFacts[vaultHealerAddress].length;
        if (end == 0 || end > len) end = len;
        if (start >= end) revert("invalid range");

        len = end - start;
        facts = new VaultFacts[](len);
        infos = new VaultInfo[](len);
        address[] memory priceTokens =  new address[](2 * len);

        for (uint i; i < len; i++) {
            (facts[i], infos[i]) = _getVault(vaultHealerAddress, i + start);
            priceTokens[2*i] = facts[i].wantAddress;
            priceTokens[2*i + 1] = facts[i].earnedAddress;
        }

        try BasePriceGetter(priceGetterAddress).getLPPrices(priceTokens, 18) returns (uint256[] memory price) {
            for (uint i; i < len; i++) {
                infos[i].lpTokenPrice = price[2*i];
                infos[i].earnedTokenPrice = price[2*i + 1];
            }
        } catch {}

    }
}