// SPDX-License-Identifier: MIT

// Have our invariant aka(as known as) properties

// What are our invariant?

// 1. The total supply of DSC should less than the total value of collateral
// 2. Getter view functions should never revert <- evergreen invariant

pragma solidity ^0.8.18;

import {StdInvariant} from "forge-std/StdInvariant.sol";
import {Test, console} from "forge-std/Test.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Handler} from "./Handler.t.sol";

contract Invariants is StdInvariant, Test {
    DeployDSC deployer;
    DecentralizedStableCoin dsc;
    DSCEngine dsce;
    HelperConfig config;
    address weth;
    address wbtc;
    Handler handler;

    function setUp() external {
        deployer = new DeployDSC();
        (dsc, dsce, config) = deployer.run();
        (,, weth, wbtc,) = config.activeNetworkConfig();
        //targetContract(address(dsce));
        handler = new Handler(dsce, dsc);
        targetContract(address(handler));
        // hey, don't call redeemcollateral, unless there is collateral to redeem
    }

    function invariant_protocoMustHaveMoreValueThanTotalSupply() public view {
        uint256 totalSupply = dsc.totalSupply();
        uint256 totalWethDeposited = IERC20(weth).balanceOf(address(dsce));
        uint256 totalWbtcDeposited = IERC20(wbtc).balanceOf(address(dsce));

        uint256 wethValue = dsce.getUsdValue(weth, totalWethDeposited);
        uint256 wbtcValue = dsce.getUsdValue(wbtc, totalWbtcDeposited);

        //可以直接这样查看timesMintIsCalled的大小吗，为什么要在timesMintIsCalled后面加上一个()呢？
        /* 这里涉及到 Solidity 状态变量的自动生成 Getter 函数的特性，以及 Foundry 不变性测试的执行模型。
        在 Solidity 中，当你声明一个 public 类型的状态变量时，编译器会自动为这个变量生成一个同名的 public view 类型的 getter 函数。
        这个 getter 函数的作用是允许外部合约或 EOA (外部拥有账户) 读取该状态变量的值。
        例如，如果你在 Handler 合约中定义：uint256 public timesMintIsCalled;
        Solidity 编译器实际上会为你生成一个看起来像这样的隐式函数：
        function timesMintIsCalled() public view returns (uint256) {
        return timesMintIsCalled; 
        }
        因此，当你在 Invariants.t.sol 合约中尝试从 handler 实例读取这个变量的值时，你实际上是在调用它自动生成的 getter 函数。
        这就是为什么你需要使用 handler.timesMintIsCalled() 而不是 handler.timesMintIsCalled。 */
        console.log("Times mint callled: ", handler.timesMintIsCalled());

        assert(totalSupply <= wethValue + wbtcValue);
    }

    function invariant_gettersShouldNotRevert() public view {
        dsce.getLiquidationBouns();
        dsce.getPrecision();
    }
}
