// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {Test} from "lib/forge-std/src/Test.sol";

import {ERC20} from "src/YulERC20.sol";

contract SampleContractTest is Test {

    ERC20 public erc20;
    address bob = vm.addr(111);
    address bill = vm.addr(222);
   
  function setUp() public {
    vm.label(bob, "BOB");
    vm.label(bill, "BILL");
   
    // bob initialize
    vm.prank(bob);
    erc20 = new ERC20();
  }

  function testGetName() public {
    assertEq("yul token", erc20.name());
  }

  function testGetSymbol() public {
    assertEq("YUL", erc20.symbol());
  }

  function testGetDecimal () public {
    assertEq(18, erc20.decimals());
  }

  function testGetTotalSupply() public {
    // eq to some big ass number
    assertEq(452312848583266388373324160190187140051835877600158453279131187530910662655, erc20.totalSupply());
  }

  function testGetBalanceOf() public {
    // since bob initialized, he get big ass balance
    assertEq(452312848583266388373324160190187140051835877600158453279131187530910662655, erc20.balanceOf(bob));
  }

  function testTranfer() public {
    vm.startPrank(bob);
    erc20.transfer(bill, 100);
    assertEq(erc20.balanceOf(bill), 100);
  }

  function testTransferAllTokens() public {
    uint256 max = 452312848583266388373324160190187140051835877600158453279131187530910662655;
    vm.startPrank(bob);
    erc20.transfer(bill, max);
    assertEq(erc20.balanceOf(bill), max);
  }

  function testTransferOneToken() public {
    vm.startPrank(bob);
    erc20.transfer(bill, 1);
    assertEq(erc20.balanceOf(bill), 1);
  }

  function testFailOnTransfer(
  ) public {
    uint256 max = 4523128485832663883733241601901871400518358776001584532791311875309106626550; // <- added extra 0
    vm.startPrank(bob);
    erc20.transfer(bill, max);
    assertEq(erc20.balanceOf(bill), max);
  }

   function testFailTransferZero() public {
    vm.startPrank(bill);
    erc20.transfer(bob, 1);
    assertEq(erc20.balanceOf(bob), 1);
    }
}