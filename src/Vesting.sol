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

    function previewWithdraw() public view returns (uint256) {
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
