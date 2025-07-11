// SPDX-License-Identifier: MIT

// Handler is going to narrow down the way we call function

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "../mocks/MocksV3Aggregator.sol";

contract Handler is Test {
    DSCEngine dsce;
    DecentralizedStableCoin dsc;

    ERC20Mock weth;
    ERC20Mock wbtc;

    uint256 public timesMintIsCalled;
    address[] public userWithCollateralDeposited;
    MockV3Aggregator public ethUsdPriceFeed;

    uint256 MAX_DEPOSIT_SIZE = type(uint96).max; // the max uint96 value(not enough to reach the biggest value, but really big)

    //DSCEngine和DecentralizedStableCoin是我们想handler管理调用的合约
    //这里为什么不用constructor(address _dsce, address _dsc)呢？
    /* 主要是为了类型安全和方便调用接口。
    类型安全 (Type Safety): 当你传入一个 DSCEngine 类型时，
    编译器会确保传入的地址确实是一个 DSCEngine 合约的实例（或者至少是一个兼容 DSCEngine 接口的合约）。
    如果你只传入 address 类型，那么在后续的赋值操作 dsce = _dsce; 中，你需要进行显式类型转换：dsce = DSCEngine(_dsce);。
    直接使用合约类型作为参数，避免了这种额外的转换，并提前进行类型检查。 
    方便调用接口 (Interface Usability): 一旦 dsce 被声明为 DSCEngine 类型，
    你就可以直接通过 dsce.someFunction() 来调用 DSCEngine 合约中定义的所有公共函数，而不需要再进行类型转换。
    如果 dsce 只是一个 address 类型，你就无法直接调用其方法，必须先将其转换为 DSCEngine(address)。*/
    constructor(DSCEngine _dsce, DecentralizedStableCoin _dsc) {
        dsce = _dsce;
        dsc = _dsc;

        address[] memory collateralTokens = dsce.getCollateralTokens();
        //这里为什么要加一个ERC20Mock呢?
        /* 由于weth和wbtc不能隐式的转换为ERC20Mock类型，并且在depositCollateral中的调用需要他们为ERC20Mock类型来完成一系列的功能调用。
        还有就是测试目的： ERC20Mock 是一个**模拟（Mock）**的 ERC20 代币合约，它通常包含一些额外的、方便测试的功能。 */
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);

        ethUsdPriceFeed = MockV3Aggregator(dsce.getCollateralTokenPriceFeed(address(weth)));
    }

    function mintDsc(uint256 amount, uint256 addressSeed) public {
        vm.assume(userWithCollateralDeposited.length != 0);
        /* 10 % 3 = 3, 10 / 3 = 1 */
        address sender = userWithCollateralDeposited[addressSeed % userWithCollateralDeposited.length];
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dsce.getAccountInformation(sender);

        int256 maxDscToMint = (int256(collateralValueInUsd) / 2) - int256(totalDscMinted);
        /* vm.assume关键字: If the boolean expression evaluates to false, the fuzzer will discard the current fuzz
            inputs and start a new fuzz run */

        //不满足vm.assume(maxDscToMint >= 0)的情况是意味着函数被revert还是什么情况？
        /* 当 vm.assume(maxDscToMint >= 0) 中的条件 maxDscToMint >= 0 不满足时（即 maxDscToMint < 0），函数不会被 revert。
        相反，这意味着： 
        1.当前这一轮的测试执行会被 Foundry 立即放弃。
        2.Foundry 不会将其视为测试失败，也不会将其记录为回滚。
        3.Foundry 会立即生成新的随机输入，并从头开始新的测试迭代，试图找到一个能满足 vm.assume 条件的输入组合。*/

        // if (maxDscToMint < 0) {
        //     return;
        // }
        vm.assume(maxDscToMint > 0);
        amount = bound(amount, 0, uint256(maxDscToMint));
        // if (amount == 0) {
        //     return;
        // }
        vm.assume(amount != 0);
        vm.startPrank(sender);
        dsce.mintDsc(amount);
        vm.stopPrank();
        /* 每当调用一次mintDsc函数， timesMintIsCalled就会加1，在测试函数中，'timesMintIsCalled++;'用于追踪mintDsc函数的调用次数。
        可以将其放置在函数的不同位置，来看一看具体是函数的哪一个部分没有被调用。 */
        timesMintIsCalled++;

        //虽然depositCollateral函数和mintDsc函数在同一合约中，为什么还需要添加userWithCollateralDeposited数组才能满足它们使用了同一地址？
        /* 这是一个非常好的问题，它触及到了 Foundry 模糊测试中状态管理和**vm.prank 的作用**
        这是一个非常好的问题，它触及到了 Foundry 模糊测试中状态管理和**vm.prank 的作用**。
        虽然 depositCollateral 和 mintDsc 都在同一个 Handler 合约中，你还需要 userWithCollateralDeposited 数组来共享地址的原因是：
        1. 每次函数调用都是独立的事务
        在 Foundry 的模糊测试中，尤其是在不变性测试的 "handler" (处理函数) 层面：
        每一个 public 或 external 的 handler 函数（例如 depositCollateral, mintDsc）在被 Foundry 调用时，
        都被视为一次独立的、随机发起的 "事务" **或 "操作"。
        **默认情况下，每次事务的 msg.sender 都是 Foundry 随机生成的不同地址。
        **这意味着 depositCollateral 可能由 0x111... 调用，而紧接着的 mintDsc 可能由 0x222... 调用。
        2. vm.prank 控制的是当前事务的 msg.sender
        vm.prank(someAddress) 确实允许你设置当前这次 Foundry 调用的 msg.sender。
        在 depositCollateral 中，你使用了 vm.prank(msg.sender)。
        这里的 msg.sender 是 Foundry 为这次 depositCollateral 随机选择的调用者。
        你用 vm.prank 来确保是这个随机选择的地址在执行 collateral.mint 和 collateral.approve。
        但是，这个 vm.prank 的效果只持续到当前这个 depositCollateral 函数执行结束。 
        当 depositCollateral 返回后，Foundry 接下来随机选择调用的另一个 handler 函数（比如 mintDsc）时，
        它的 msg.sender 又会是 Foundry 随机生成的新地址，而不是上一个函数的 msg.sender。
        3. userWithCollateralDeposited 数组的作用
        因此，userWithCollateralDeposited 数组在这里扮演了连接不同操作的关键角色：
        保存状态： 当 depositCollateral 函数成功执行后，
        userWithCollateralDeposited.push(msg.sender) 将当前进行存款的用户的地址保存起来。
        这个数组是 Handler 合约的状态变量，它的值在不同的 handler 调用之间是持久存在的。
        共享上下文： 这样，在 mintDsc 函数被调用时，
        它就可以从 userWithCollateralDeposited 数组中随机选择一个已经存入过抵押品的地址（address sender = userWithCollateralDeposited[addressSeed % userWithCollateralDeposited.length];），
        然后用 vm.prank(sender) 将这个地址设置为当前的 msg.sender。 */
    }

    //redeem collateral <-
    function depositCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        /* bound是StdUtils合约自带的一个函数，限制了amountCollateral的大小 */
        amountCollateral = bound(amountCollateral, 1, MAX_DEPOSIT_SIZE);

        vm.startPrank(msg.sender);
        collateral.mint(msg.sender, amountCollateral);
        collateral.approve(address(dsce), amountCollateral);
        dsce.depositCollateral(address(collateral), amountCollateral);
        vm.stopPrank();
        /* double push:如果相同的地址被推送两次。 */
        userWithCollateralDeposited.push(msg.sender);
    }

    function redeemCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        uint256 maxCollateralToRedeem = dsce.getCollateralBalanceOfUser(msg.sender, address(collateral));
        amountCollateral = bound(amountCollateral, 0, maxCollateralToRedeem);
        if (amountCollateral == 0) {
            return;
        }
        dsce.redeemCollateral(address(collateral), amountCollateral);
    }

    // This breaks our invariant test suite !!!
    // function updateCollateralPrice(uint96 newPrice) public {
    //     int256 newPriceInt = int256(uint256(newPrice));
    //     ethUsdPriceFeed.updateAnswer(newPriceInt);
    // }

    // Helper Functions
    function _getCollateralFromSeed(uint256 collateralSeed) private view returns (ERC20Mock) {
        if (collateralSeed % 2 == 0) {
            return weth;
        } else {
            return wbtc;
        }
    }
}
