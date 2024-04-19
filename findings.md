### [H-1] Checking for address duplications by looping through an array of player addresses in `PuppyRaffle::enterRaffle` is potential of denial of service (DoS) attack. incrementing gas costs for future entrants

video stop at 5.40.31

IMPACT: MEDIUM/HIGH ( because an attackers will be cost a lot of gas to attack )
LIKELIHOOD: MEDIUM (causing users won't use the service)

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