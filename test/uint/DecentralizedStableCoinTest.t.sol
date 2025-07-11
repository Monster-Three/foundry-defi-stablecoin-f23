//SPDX-License-Identifier:MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";

contract DecentralizedStableCoinTest is Test {
    DeployDSC deployer;
    DSCEngine dsce;
    HelperConfig config;
    DecentralizedStableCoin dsc;
    address wethUsdPriceFeed;
    address wbtcUsdPriceFeed;
    address weth;

    //这里为什么要加 private 和 constant 呢？
    /* 
    constant 的作用
    编译时已知： constant 变量的值在编译时就必须确定。一旦编译，它的值就固定了，不能在运行时改变。
    Gas 效率： constant 变量不占用合约的存储空间。编译器会直接将它们的值替换到代码中使用它们的地方，
    从而节省 Gas 费（因为不需要从存储中读取）。
    语义清晰： 声明为 constant 明确表明这个变量是一个固定不变的量，提高了代码的可读性和意图表达。
    private 的作用
    可见性限制： private 关键字意味着这个变量只能在定义它的合约内部访问。子合约无法继承或直接访问它，外部账户和合约也无法访问。
    封装性： 隐藏内部实现细节，只暴露必要的接口。这在合约设计中是一种良好的实践，有助于防止外部意外修改或依赖不应暴露的内部状态。
    避免自动生成 Getter： 由于 private 变量不能被外部访问，Solidity 编译器不会为其自动生成 public getter 函数。
    如果你希望它能被外部读取但又不希望是 public 状态变量，你可以手动编写一个 public 或 external 的 getter 函数。

    在这个特定的测试合约 DecentralizedStableCoinTest 中：
    STARTING_BALANCE 是用于测试的一个固定值，它在整个测试生命周期中不会改变，所以用 constant 是非常合适的。
    这个 STARTING_BALANCE 仅仅是这个测试合约内部用来设置用户初始余额的一个辅助值。它不需要被其他合约或外部账户读取。
    将其声明为 private 可以确保这个测试专用的常量不会意外地暴露出去，保持了测试代码的封装性。 */
    uint256 private constant ownerDscBalance = 50e18;
    uint256 private constant amountToBurn = 100e18;
    uint256 private constant amountToMint = 1;

    //这里为什么要加public呢？
    /* 将 USER 声明为 public 主要是为了方便在测试中进行调试和审查。虽然在同一个合约的测试函数中，
    internal 变量也能直接访问，但 public 的一个额外好处是： 
    如果你在调试时想要通过 Foundry 的 console.log 或者在另一个测试合约中检查 USER 的值，你可以直接调用 myTestContract.USER() 来获取它。
    在某些更复杂的测试设置中，一个测试合约可能需要访问另一个测试合约的状态变量，public 就显得更重要了。
    当一个状态变量没有明确指定可见性关键字时（或者被指定为 internal），它的默认可见性是 internal。
    public 关键字：
    当一个状态变量被声明为 public 时，Solidity 编译器会自动为它生成一个同名的 public view 类型的 getter 函数。
    这个 getter 函数允许**外部合约和外部账户（EOA）**直接通过调用这个函数来读取该状态变量的值。
    例如，如果你部署了包含这个变量的合约，其他合约或你的前端应用可以通过调用 yourContractInstance.USER() 来获取 USER 的地址。*/
    address public USER = makeAddr("user");

    function setUp() public {
        // 我在第一次测试时忘记添加deployer = new DeployDSC();这行语句，导致了[FAIL: EvmError: Revert] setUp() (gas: 0)
        /* 值得注意的是：在这次报错的语句中就直接指明了出错的函数。我当时还没有注意到出错的函数在哪里 */

        //那为什么会失败呢？
        /* 在 Solidity 中，引用类型（如合约实例）在被使用之前必须被初始化。
        如果你只是声明了 DeployDSC deployer; 而没有 deployer = new DeployDSC();，
        那么 deployer 变量实际上不指向任何有效的合约实例。尝试调用一个空地址上的函数，或者调用一个不存在的实例上的函数，
        都会导致 EVM 报错。 */
        deployer = new DeployDSC();
        (dsc, dsce,) = deployer.run();
    }

    function testBurnFunctionRevertsIf_amountLessThanZero() public {
        vm.startPrank(address(dsce));
        vm.expectRevert(DecentralizedStableCoin.DecentralizedStableCoin__MustBeMoreThanZero.selector);
        dsc.burn(0);
        vm.stopPrank();
    }

    function testBurnFunctionRevertsIf_balanceLessThanAmount() public {
        address dscOwner = dsc.owner();

        deal(address(dsc), dscOwner, ownerDscBalance);
        vm.startPrank(dscOwner);
        vm.expectRevert(DecentralizedStableCoin.DecentralizedStableCoin__BurnAmountExceedsBalance.selector);
        dsc.burn(amountToBurn);
        vm.stopPrank();
    }

    function testMintFunctionRevertsIf_toAddressIsZero() public {
        vm.startPrank(address(dsce));
        vm.expectRevert(DecentralizedStableCoin.DecentralizedStableCoin__NotZeroAddress.selector);
        dsc.mint(address(0), amountToBurn);
        vm.stopPrank();
    }

    function testMintFunctionRevertsIf_amountIsZero() public {
        vm.startPrank(address(dsce));
        vm.expectRevert(DecentralizedStableCoin.DecentralizedStableCoin__MustBeMoreThanZero.selector);
        dsc.mint(USER, 0);
        vm.stopPrank();
    }
}
