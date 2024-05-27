// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

// REENTRANCY EXAMPLE

contract Bank {

    mapping(address user => uint256 bal) public userBalance;

    function deposit() public payable {
        userBalance[msg.sender] +=  msg.value;
    }

    /**
    * @dev a reentrancy mitigation
    * @dev follow CEI pattern (checks, effects, interactions )
    */
    function withdraw() public payable {
        uint256 balanceOfUser = userBalance[msg.sender];
        bool success;
        // effects ( state changes )
        userBalance[msg.sender] = 0;
        // interactions ( external call )
        ( success, ) = payable(msg.sender).call{value: balanceOfUser }("");
         if(!success) revert("failed");
    }
   
}

contract Attacker {
    Bank bank;

    function attack() public payable {
        bank = Bank(0x417Bf7C9dc415FEEb693B6FE313d1186C692600F);
        bank.deposit{value: msg.value}();
        bank.withdraw();
    }

    receive() external payable {
        if(address(bank).balance >= 1 ether) {
            bank.withdraw();
        }
    }
}