## Vesting Smart Contract

***In this article I teach you how to create a vesting contract in which an owner can deposit an amount of an ERC20 token into the contract and a certain receiver can withdraw `1 / n` tokens over `n` days.***

You will need to have Foundry installed (instructions below).
```shell
# Download foundry installer `foundryup`
curl -L https://foundry.paradigm.xyz | bash
# Install forge, cast, anvil, chisel
foundryup
# Install the latest nightly release
foundryup -i nightly
```

For more details, visit: https://getfoundry.sh/

First, open the terminal and type `forge init`. This will initialize a new Foundry project and once that's done, run the command `forge intsall OpenZeppelin/openzeppelin-contracts` to install the Open Zeppelin dependencies that we will make use of in this project.  
Next, delete the default `Counter` files in the `script`, `src` and `test` folders and create a file named `Vesting.sol` in the `src` folder. Open the newly created file in your code editor.

```solidity
// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;
```
The first line of the file should contain a comment representing the linces. Below that, use the `pragma` keyword to specify which compiler version should be used for this file. Keep in mind that version pragma does not change the version of the compiler. It does not enable or disable features of the compiler either. It only instructs the compiler to check if its version matches the one required by the pragma, and if it does not, the compiler will issue an error.

```solidity
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
```
Now, we will bring the dependencies we need into scope:

- IERC20 - interface for the ERC20 token
- Ownable - gain access to the `onlyOwner` modifier to protect certain functions that should only be called by authorized addresses
- SafeERC20 - library that enables us to handle more implementations of ERC20 (some tokens revert on failure, others do not return a boolean at all)

Now we can start writing the main contract

```solidity
contract Vesting is Ownable {
    using SafeERC20 for IERC20;

    address public immutable receiver;
    address public immutable token;
    uint256 public immutable numOfDays;
    uint256 public immutable amountPerDay;

    uint256 public startVesting;
    uint256 public amountWithdrawn;
    uint256 public lastWithdrawal;
}
```

We declare of `Vesting` contract and inherit from the `Ownable` contract that we imported above.

On the first line of the contract, the line `using SafeERC20 for IERC20;` allows us to attach member functions from the `SafeERC20` library to our IERC20 variable.

We then proceed to declare 7 state variables, 4 `immutable` ones that will be assigned to once in the constructor and another 3 that will be assigned to and updated later, during function calls. The `receiver` is the addressed that will have the right to withdraw tokens from the contract, `token` is the token to be withdrawn, `numOfDays` and `amountPerDay` represent the number of vesting days and the amount that the receiver can withdraw per day respectively.  
The `startVesting` variable will be set to `block.timestamp` when the owner deposits the ERC20 into the contract and it will be used along with `amountWithdrawn` and `lastWithdrawal` variables for the withdrawal calculations. We'll learn more about this later in the article.

```solidity
event Deposit(address indexed owner, uint256 numOfDays, uint256 amount);
event Withdrawal(address indexed receiver, uint256 amount);
event RescueFunds(address indexed owner, uint256 amount);

error ZeroAddress();
error ZeroDays();
error ZeroAmountPerDay();
error NotReceiver();
error TooEarly();
error WithdrawalAmountExceeded();
```

Next we declare some events and some errors that I think are pretty self-explanatory, so we will move on to the functions of the contract.

```solidity
constructor(address _receiver, address _token, uint256 _numOfDays, uint256 _amountPerDay) Ownable(msg.sender) {
        require(_token != address(0), ZeroAddress());
        require(_receiver != address(0), ZeroAddress());
        require(_numOfDays != 0, ZeroDays());
        require(_amountPerDay != 0, ZeroAmountPerDay());

        receiver = _receiver;
        token = _token;
        numOfDays = _numOfDays;
        amountPerDay = _amountPerDay;
    }
```

We start with the `constructor`, in which we do some input validation first, making use of some of the errors declared above and then we initialise the variables `receiver`, `token`, `numOfDays` and `amountPerDay`.

```solidity
function deposit() external onlyOwner {
    uint256 amount = amountPerDay * numOfDays;
    IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
    startVesting = block.timestamp;
    lastWithdrawal = block.timestamp;

    emit Deposit(msg.sender, numOfDays, amount);
}
```

Lets now go through the `deposit` function. It has the `onlyOwner` modifier attached, so only the owner can call it. It calculates the total amount of tokens as `amountPerDay * numOfDays` and then it transfers the tokens to the contract.  
Before calling this function, then owner, of course, has to call the approve function on the ERC20 `token` and let the vesting contract transfer tokens from him.  
Finally, we set the `startVesting` and `lastWithdrawal` variables to `block.timestamp` and emit the `Deposit` event.

```solidity
function previewWithdraw() public view returns(uint256) {
    uint256 daysToWithdrawFor = (block.timestamp - lastWithdrawal) / 1 days;

    uint256 amountToWithdraw = daysToWithdrawFor * amountPerDay;

    return amountToWithdraw;
}
```

Now, we'll create the `previewWithdraw()` function that the receiver can use to check how many tokens he is elligible to withdraw at any time. This function will also be used in the calculations of the actual `withdraw` function that will transfer tokens to the receiver.  
The function is relatively simple, it first determines the number of days that have passed since the receiver's last withdrawal and then multiplies that number by `amountPerDay`. And that's the amount the receiver can withdraw at that given moment.

```solidity
function withdraw() external {
    require(msg.sender == receiver, NotReceiver());

    uint256 amountToWithdraw = previewWithdraw();
    require(amountWithdrawn + amountToWithdraw <= numOfDays * amountPerDay, WithdrawalAmountExceeded());

    lastWithdrawal = block.timestamp;
    amountWithdrawn += amountToWithdraw;

    IERC20(token).safeTransfer(msg.sender, amountToWithdraw);

    emit Withdrawal(receiver, amountToWithdraw);
}
```

We're next going to go through the `withdraw` function. We check if the `receiver` is the one who called it, and if it is not, we throw an error and revert the transaction.  
We then make use of the `previewWithdraw` function to see what amount of tokens the user is allowed to withdraw at that moment. We also check that the amount the user can withdraw + the amount already withdrawn do not exceed the maximum amount of `numOfDays * amountPerDay` tokens.  
After that we update the `lastWithdrawal` and `amountWithdrawn` variables, we transfer the tokens to the `msg.sender`, which can only be the `receiver` because of our `require` statement in the first line of the function.  
After the transfer, we emit a `Withdrawal`. And that is the end of the function. One more to go!

```solidity
function rescueFunds() external onlyOwner {
    require(block.timestamp >= startVesting + numOfDays * 1 days + 5 * 1 days, TooEarly());

    uint256 amount = IERC20(token).balanceOf(address(this));

    IERC20(token).safeTransfer(msg.sender, amount);

    emit RescueFunds(msg.sender, amount);
}
```

We want to give the owner the chance to rescue the tokens if, for instance, the `receiver` loses his private key. Note the `onlyOwner` modifier attached to the function, only the owner can call it! First, we check that the vesting time has passed and we give the `receiver` an extra 5 days to get the tokens. If he doesn't, the owner can call the `rescueFunds` function, which will transfer the entire token balance of the vesting contract to the owner. It also emits the `RescueFunds` event.

And that's all! Below, you can see the entire contract. I recommend that you check out the tests as well (see the `test` folder, there is 100% coverage of the code).

```solidity
// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Vesting is Ownable {
    using SafeERC20 for IERC20;

    address public immutable receiver;
    address public immutable token;
    uint256 public immutable numOfDays;
    uint256 public immutable amountPerDay;

    uint256 public startVesting;
    uint256 public amountWithdrawn;
    uint256 public lastWithdrawal;

    event Deposit(address indexed owner, uint256 numOfDays, uint256 amount);
    event Withdrawal(address indexed receiver, uint256 amount);
    event RescueFunds(address indexed owner, uint256 amount);

    error ZeroAddress();
    error ZeroDays();
    error ZeroAmountPerDay();
    error NotReceiver();
    error TooEarly();
    error WithdrawalAmountExceeded();

    constructor(address _receiver, address _token, uint256 _numOfDays, uint256 _amountPerDay) Ownable(msg.sender) {
        require(_token != address(0), ZeroAddress());
        require(_receiver != address(0), ZeroAddress());
        require(_numOfDays != 0, ZeroDays());
        require(_amountPerDay != 0, ZeroAmountPerDay());

        receiver = _receiver;
        token = _token;
        numOfDays = _numOfDays;
        amountPerDay = _amountPerDay;
    }

    function deposit() external onlyOwner {
        uint256 amount = amountPerDay * numOfDays;
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        startVesting = block.timestamp;
        lastWithdrawal = block.timestamp;

        emit Deposit(msg.sender, numOfDays, amount);
    }

    function previewWithdraw() public view returns(uint256) {
        uint256 daysToWithdrawFor = (block.timestamp - lastWithdrawal) / 1 days;

        uint256 amountToWithdraw = daysToWithdrawFor * amountPerDay;

        return amountToWithdraw;
    }

    function withdraw() external {
        require(msg.sender == receiver, NotReceiver());

        uint256 amountToWithdraw = previewWithdraw();
        require(amountWithdrawn + amountToWithdraw <= numOfDays * amountPerDay, WithdrawalAmountExceeded());

        lastWithdrawal = block.timestamp;
        amountWithdrawn += amountToWithdraw;

        IERC20(token).safeTransfer(msg.sender, amountToWithdraw);

        emit Withdrawal(receiver, amountToWithdraw);
    }

    function rescueFunds() external onlyOwner {
        require(block.timestamp >= startVesting + numOfDays * 1 days + 5 * 1 days, TooEarly());

        uint256 amount = IERC20(token).balanceOf(address(this));

        IERC20(token).safeTransfer(msg.sender, amount);

        emit RescueFunds(msg.sender, amount);
    }
}
```
