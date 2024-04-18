
## Types Of Attacks
 - Denial Of Services (`DOS`) - where a function is become useless bcoz of gas cost keeps increasing causing by the code implementation and an attacker can easily attack the function to make it completely useless. ( the points is any issue (ex: gas issue, etc) that cause the transaction or function not be able to execute that is call a DOS )
  
  DOS could actually cause by alot of factors:
   - a contract that dont have a `fallback` or `receive` function tobe able to receive `ether`. bcoz of the contract cant accept ether if one of those two function exist. this can leads to preventing or reverting a function that requires a user to send `ETHER` in order to execute the function
   - a call to an external function that doesnt exist from the protocol functions.
 


 # About

 > 

 # High

 - Found a DOS

 # Informational
 `PuppyRaffle::entranceFee` is immutable and should be marked like `i_entranceFee` or `I_ENTRANCE_FEE` to make it developers or auditor easier to notice whether its a `constant` or `immutable` state variables.