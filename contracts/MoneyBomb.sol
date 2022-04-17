// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.4;

contract MoneyBomber {

    event Payment(address indexed from, address indexed to, uint amount);

    function pay(address payable recipient) external payable {
        assembly {
            mstore(21,0xff)
            mstore(20,recipient)
            mstore(0,0x73)
            pop(create(callvalue(), 31, 22))
        }
        emit Payment(msg.sender, recipient, msg.value);
    }
}