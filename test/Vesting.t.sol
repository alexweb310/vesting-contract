// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {Vesting} from "../src/Vesting.sol";
import {Token} from "./mocks/Token.sol";

contract VestingTest is Test {
    Vesting public vesting;
    Token public token;

    address receiver = address(1);
    uint256 numOfDays = 10;
    uint256 amountPerDay = 100 ether;

    event Deposit(address indexed owner, uint256 numOfDays, uint256 amount);
    event Withdrawal(address indexed receiver, uint256 amount);
    event RescueFunds(address indexed owner, uint256 amount);

    error ZeroAddress();
    error ZeroDays();
    error ZeroAmountPerDay();
    error NotReceiver();
    error TooEarly();
    error OwnableUnauthorizedAccount(address);
    error WithdrawalAmountExceeded();

    function setUp() public {
        token = new Token();
        token.mint(address(this), 1000 ether);
        vesting = new Vesting(receiver, address(token), numOfDays, amountPerDay);
        token.approve(address(vesting), 1000 ether);
    }

    function testCanNotDeployWithZeroValues() public {
        vm.expectRevert(ZeroAddress.selector);
        new Vesting(address(0), address(token), numOfDays, amountPerDay);

        vm.expectRevert(ZeroAddress.selector);
        new Vesting(receiver, address(0), numOfDays, amountPerDay);

        vm.expectRevert(ZeroDays.selector);
        new Vesting(receiver, address(token), 0, amountPerDay);

        vm.expectRevert(ZeroAmountPerDay.selector);
        new Vesting(receiver, address(token), numOfDays, 0);
    }

    function testOwnerCanDeposit() public {
        uint256 balanceVestingBefore = token.balanceOf(address(vesting));
        assertEq(balanceVestingBefore, 0);
        assertEq(vesting.startVesting(), 0);
        assertEq(vesting.lastWithdrawal(), 0);

        vm.expectEmit(true, true, true, true);
        emit Deposit(address(this), vesting.numOfDays(), vesting.amountPerDay() * vesting.numOfDays());
        vesting.deposit();

        uint256 expectedAmount = vesting.amountPerDay() * vesting.numOfDays();

        uint256 balanceVestingAfter = token.balanceOf(address(vesting));
        assertEq(balanceVestingAfter, expectedAmount);
        assertEq(vesting.startVesting(), block.timestamp);
        assertEq(vesting.lastWithdrawal(), block.timestamp);
    }

    function testAnotherAddressCanNotDeposit(address notOwner) public {
        vm.assume(notOwner != address(this));

        vm.prank(notOwner);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, notOwner));
        vesting.deposit();
    }

    function testPreviewWithdraw() public {
        vesting.deposit();

        uint256 timestamp = block.timestamp;

        for (uint256 i = 0; i <= 10; i++) {
            vm.warp(timestamp + i * 1 days);
            uint256 amount = vesting.previewWithdraw();
            assertEq(amount, vesting.amountPerDay() * i);
        }
    }

    function testReceiverCanWithdraw() public {
        vesting.deposit();

        uint256 timestamp = block.timestamp;

        for (uint256 i = 1; i <= 10; i++) {
            vm.warp(timestamp + i * 1 days);

            uint256 balanceBefore = token.balanceOf(receiver);
            assertEq(balanceBefore, vesting.amountPerDay() * (i - 1));

            vm.expectEmit(true, true, true, true);
            emit Withdrawal(receiver, vesting.amountPerDay());

            vm.prank(receiver);
            vesting.withdraw();

            uint256 balanceAfter = token.balanceOf(receiver);
            assertEq(balanceAfter, vesting.amountPerDay() * i);
        }

        vm.warp(timestamp + 12 days);
        vm.prank(receiver);
        vm.expectRevert(WithdrawalAmountExceeded.selector);
        vesting.withdraw();
    }

    function testAnotherAddressCanNotWithdraw(address notReceiver) public {
        vm.assume(notReceiver != receiver);

        vm.prank(notReceiver);
        vm.expectRevert(NotReceiver.selector);
        vesting.withdraw();
    }

    function testOwnerCanRescueFunds() public {
        vesting.deposit();

        vm.warp(block.timestamp + 15 days);

        uint256 balanceContractBefore = token.balanceOf(address(vesting));
        uint256 balanceOwnerBefore = token.balanceOf(address(this));

        vm.expectEmit(true, true, true, true);
        emit RescueFunds(address(this), balanceContractBefore);

        vesting.rescueFunds();

        uint256 balanceContractAfter = token.balanceOf(address(vesting));
        uint256 balanceOwnerAfter = token.balanceOf(address(this));
        assertEq(balanceContractAfter, 0);
        assertEq(balanceOwnerAfter, balanceOwnerBefore + balanceContractBefore);
    }

    function testAnotherAddressCanNotRescueFunds(address notOwner) public {
        vm.assume(notOwner != address(this));

        vm.prank(notOwner);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, notOwner));
        vesting.rescueFunds();
    }

    function testOwnerCanOnlyRescueAfterDeadline() public {
        vesting.deposit();

        vm.warp(block.timestamp + 8 days);

        vm.expectRevert(TooEarly.selector);
        vesting.rescueFunds();
    }
}
