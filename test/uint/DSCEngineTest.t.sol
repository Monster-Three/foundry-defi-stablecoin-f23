//SPDX-License-Identifier:MIT
pragma solidity ^0.8.18;

import {MockV3Aggregator} from "../mocks/MocksV3Aggregator.sol";
import {Test, console} from "forge-std/Test.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockMoreDebtDSC} from "../mocks/MockMoreDebtDSC.sol";

contract DSCEngineTest is Test {
    DeployDSC deployer;
    DecentralizedStableCoin dsc;
    DSCEngine dsce;
    HelperConfig config;
    address ethUsdPriceFeed;
    address btcUsdPriceFeed;
    address weth;

    address public USER = makeAddr("user");
    uint256 private constant AMOUNT_COLLATERAL = 10 ether;
    uint256 private constant AMOUNT_TO_MINT = 100 ether;
    uint256 private constant STARTING_ERC20_BALANCE = 10 ether;
    uint256 private constant AMOUNT_DSC = 2 ether;
    uint256 private constant MINT_TOO_MANY_AMOUNT_DSC = 1000000 ether;
    uint256 private constant DSC_MINT_IN_LIQUIDATE_TEST = 700 ether;

    // Liquidation
    address public liquidator = makeAddr("liquidator");
    uint256 public collateralToCover = 20 ether;

    uint256 amountCollateral = 10 ether;
    uint256 amountToMint = 10 ether;
    address public user = address(1);

    function setUp() public {
        deployer = new DeployDSC();
        (dsc, dsce, config) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth,,) = config.activeNetworkConfig();
        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
    }

    //////////////////////
    // Constructor Test //
    //////////////////////
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    //不是很懂这个测试函数的逻辑
    /* 哈哈，我们只传入了一个token的地址，后面却传入了两个pricefeed。所以会revert错误 */
    function testRevertsIfTokenLengthDonesntMatchPriceFeed() public {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(ethUsdPriceFeed);
        priceFeedAddresses.push(btcUsdPriceFeed);

        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength.selector);
        new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
    }

    //////////////////////////////////////
    // depositCollateralAndMintDsc Test //
    //////////////////////////////////////

    // function testRevertsIfMintDscBreakHealthFactor() public {
    //     vm.startPrank(USER);
    //     ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
    //     vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__BreakHealthFactor.selector));
    //     dsce.depositCollateralAndMintDsc(weth, amountCollateral, amountToMinTInThisTest);
    //     vm.stopPrank();
    // }

    function testRevertsIfMintedDscBreaksHealthFactor() public {
        (, int256 price,,,) = MockV3Aggregator(ethUsdPriceFeed).latestRoundData();
        uint256 amountToMinTInThisTest =
            (AMOUNT_COLLATERAL * (uint256(price) * dsce.getadditonalfeedprecison())) / dsce.getPrecision();
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);

        uint256 expectedHealthFactor =
            dsce.calculateHealthFactor(amountToMinTInThisTest, dsce.getUsdValue(weth, AMOUNT_COLLATERAL));
        //这里加了一个expectedHealthFactor有什么作用呢？
        /* 当你使用 vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__BreakHealthFactor.selector,
        expectedHealthFactor)); 时，你是在告诉 Foundry 不仅仅要期望一个特定 DSCEngine__BreakHealthFactor 错误的回滚，
        而且这个错误必须包含精确的 expectedHealthFactor 值作为它的第一个参数。
        在这个时候就需要检查DSCEngine__BreakHealthFactor()的括号里面带没带参数 */

        // //这里为什么要加一个abi.encodeWithSelector()呢？
        /* vm.expectRevert() 是 Forge 测试框架提供的一个作弊码（cheatcode），用来断言一个函数调用会回滚（revert）。它有几种用法：
        1.vm.expectRevert(): 最简单的用法，只检查函数是否回滚，不关心回滚的具体原因或错误类型。
        2.vm.expectRevert("Error Message"): 检查函数是否回滚，并且回滚原因是特定的字符串（比如 require("Error Message") 抛出的）。
        3.vm.expectRevert(CustomError.selector): 检查函数是否回滚，并且回滚的错误类型是特定的自定义错误（比如 revert CustomError() 抛出的），但不关心这个自定义错误是否有参数。
        .selector 是该错误签名的 Keccak-256 哈希值的前 4 个字节。
        4.vm.expectRevert(CustomError(arg1, arg2, ...)): 检查函数是否回滚，并且回滚的错误类型和所有参数都完全匹配。这是最精确的用法。
        现在回到你的问题：
        vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__BreakHealthFactor.selector, expectedHealthFactor));
        这里的 DSCEngine__BreakHealthFactor 是一个自定义错误（Custom Error），而且根据你的代码，它带有一个 uint256 类型的参数，
        即 healthFactor。
        在 DSCEngine.sol 中，你可能这样定义了这个错误：error DSCEngine__BreakHealthFactor(uint256 healthFactor);
        当你使用 abi.encodeWithSelector() 时，你正在做的是：
        1.DSCEngine.DSCEngine__BreakHealthFactor.selector： 获取 DSCEngine__BreakHealthFactor 这个自定义错误的唯一标识符（即它的函数选择器，前 4 个字节的哈希）。
        2.expectedHealthFactor： 提供你期望这个自定义错误在回滚时会携带的 healthFactor 值。
        3.abi.encodeWithSelector(...)： 将错误的选择器和其参数一起编码成一个完整的字节序列。
        这个字节序列就是当你合约抛出这个带有特定参数的自定义错误时，实际回滚时附带的错误数据。 */
        vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__BreakHealthFactor.selector, expectedHealthFactor));
        dsce.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, amountToMinTInThisTest);
        vm.stopPrank();
    }

    modifier depositCollateralAndMintDsc() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, AMOUNT_TO_MINT);
        vm.stopPrank();
        _;
    }

    function testCanMintWithDepositedCollateral() public depositCollateralAndMintDsc {
        //这里为什么是dsc而不是weth呢？
        /* 因为mint dsc是由dscengine控制dsc合约进行的 */
        /* 封装以太币的意思就是以太币的流通按照ERC20标准进行 */

        //dsc的价格如何确定的呢？
        /* 在MockV3Aggregator里面隐含地假设 DSC 的价值是 1 美元 */

        //那我想让dsc的价值是10美元该怎么办呢？
        /* 让 DSC 的价值目标为 10 美元，最关键的是要在 DSCEngine 合约中：
        1.明确定义 DSC_USD_PRICE = 10 美元 (以合适的精度表示)。
        2.在所有涉及 DSC 数量与美元价值转换的计算中，使用这个 DSC_USD_PRICE 进行乘除法，尤其是在铸造、销毁和计算健康因子时。 */
        uint256 userBalance = dsc.balanceOf(USER);
        assertEq(userBalance, AMOUNT_TO_MINT);
    }

    ////////////////
    // Price Test //
    ////////////////

    //在DSCEngine里面的getUsdValue函数如何体现了这个测试的价值呢？/* 第三个uint256那里 */
    function testGetUsdValue() public view {
        //这里为什么是e18呢？
        /* 以太坊（Ether）和大多数 ERC-20 代币都是以10的18次方个最小单位来表示 1 个完整的大单位
        因为1 Ether = 10的18次方WEI */
        uint256 ethAmount = 1e18;
        uint256 expectedUed = 2000e18;
        uint256 actualUsd = dsce.getUsdValue(weth, ethAmount);
        console.log(actualUsd);
        assertEq(expectedUed, actualUsd);
    }

    function testgetTokenAmountFromUsd() public view {
        //这里usd的单位用的是ether
        uint256 usdAmount = 2000 ether;
        uint256 expectedAmount = 1 ether;
        uint256 actualAmount = dsce.getTokenAmountFromUsd(weth, usdAmount);
        assertEq(expectedAmount, actualAmount);
    }

    /////////////////////////////
    // DepositeCollateral Test //
    /////////////////////////////

    function testRevertsIfCollateralIsZero() public {
        //vm.startPrank(USER);这段代码的意思是什么呢？
        /* 从现在开始，接下来的所有交易都将由 USER 这个地址发起，直到 vm.stopPrank() 被调用之前，
        而不是测试合约的默认地址（address(this)）。 */
        vm.startPrank(USER);
        //对这段代码不是很能理解
        /* ERC20Mock(...) 是一种显式的类型转换（或“向下转型”）。在 Solidity 中，你不能直接在一个 address 类型的变量上调用合约方法，因为 
        address 类型本身不知道它指向的是一个什么类型的合约，更不知道它有哪些方法。通过 ERC20Mock(weth)，你是在告诉 Solidity 编译器和 
        EVM：“weth 这个地址上部署的合约，请把它当作一个 ERC20Mock 类型的合约来对待。一旦你将其转换为 ERC20Mock 类型，编译器就知道这个
        “合约实例”拥有 ERC20Mock 合约中定义的所有公共和外部函数（包括它继承自 ERC20 的 approve 函数），从而允许你调用 .approve(...)。” */
        /* address(dsce)这个与 ERC20Mock(weth) 类似，但方向相反。dsce 是一个 DSCEngine 类型的合约实例变量。address(dsce) 是将这个
         DSCEngine 合约实例转换回其原始的 address 类型。 */

        //为什么 ERC-20 代币不能像原生 Ether 那样直接通过 transfer() 或 send() 发送给其他合约并触发合约逻辑？
        /* 根本原因在于 Ether (ETH) 是以太坊区块链的“原生货币”，而 ERC-20 代币是部署在区块链上的“智能合约”。它们的处理机制在 EVM 
        (Ethereum Virtual Machine) 层面是不同的。 
        Ether (ETH) 的特殊性：ETH 是以太坊区块链的原生价值单位，与比特币类似，是账户余额直接在区块链协议层面进行维护的。当你将 ETH 发送到一个合约地址时，
        这个合约如果有一个 receive() 或 fallback() 函数，EVM 会自动执行这个函数，从而触发合约内部的逻辑。这是一个内置的、协议层面的行为。
        所以，你可以直接 address(contract).transfer(amount) 或 address(contract).call{value: amount}("") 来发送 ETH，
        并且如果合约有相应的函数，它就会被通知并执行逻辑。
        ERC-20 代币的本质：ERC-20 代币不是原生货币。它们只是一个智能合约。代币的“余额”实际上是存储在 ERC-20 合约内部的一个 
        mapping(address => uint256) 状态变量中，类似于一个分布式账本。当你执行 token.transfer(recipient, amount) 时，
        你只是在调用 ERC-20 代币合约上的一个函数。这个函数修改了合约内部的 balances 映射，将 msg.sender 的余额减少，
        recipient 的余额增加，并发出一个 Transfer 事件。关键点： 这个 transfer() 函数本身并不涉及 EVM 将“值”发送给 recipient 地址的操作。
        它只是合约内部状态的改变。因此，当 recipient 是另一个智能合约时，EVM 不会自动触发 recipient 合约的任何 receive() 或 
        fallback() 函数，因为它没有接收到“原生 Ether”。 ERC-20 代币合约也没有内置机制来通知接收方合约有代币入账
        因此，为了让一个智能合约能够“知道”它收到了 ERC-20 代币并进行相应处理，就需要一个两步过程：
        1.用户调用代币合约的 approve() 函数：用户授权一个智能合约（如 DSCEngine）可以从自己的账户中提取代币。
        2.合约调用代币合约的 transferFrom() 函数：当用户与 DApp 交互（例如调用 DSCEngine 的 depositCollateral 函数）时，
        DSCEngine 合约会调用 它自己被授权的代币合约 的 transferFrom() 函数，将代币从用户的账户转移到 DSCEngine 合约的账户。
        这样，DSCEngine 合约就“知道”并控制了这些代币，然后可以触发自己的内部逻辑。*/

        //在授权ERC-20合约的时候，能只授一部分还是必须一次性全部授权？
        /* 你可以只授权一部分，也可以一次性全部授权。这是由 approve 函数的设计决定的。
        ps:一次性全部授权（无限授权）： 常见的做法是授权一个非常大的值，通常是 type(uint256).max (Solidity 中的最大 uint256 值，
        即2的256次方-1 
        好处： 这样你只需授权一次，DApp 就能在未来无限次地从你账户中花费代币（直到你的余额耗尽或你撤销授权），用户体验更好，
        省去了多次授权的 Gas 费。
        风险： 如果 DApp 的合约存在漏洞或被黑客攻击，那么黑客理论上可以花费你所有授权给这个 DApp 的代币。
        因此，无限授权需要对 DApp 有很高的信任。
        */

        //但是weth在helperconfig中有具体的合约地址，那么是否就意味着它的合约里有相应的函数呢？为什么不能直接weth.approve(address(dsce), AMOUNT_COLLATERAL);这样呢？
        /* 1.为什么不能直接 weth.approve(address(dsce), AMOUNT_COLLATERAL);？
            Solidity 编译器不知道 weth 这个 address 类型变量指向的是一个实现了 approve 函数的合约。 
            让我详细解释一下：
            address 类型是通用的：
        当你在 Solidity 中声明一个变量为 address 类型时，它只是一个 20 字节的数字，代表区块链上的一个地址。这个地址可以是：
        一个外部拥有账户 (EOA) 的地址（由私钥控制）。
        一个智能合约的地址。
        编译器只知道它是一个地址，但不知道这个地址背后部署的合约（如果它是一个合约）具有哪些函数或状态变量。它就像一个指向某个位置的通用指针，但不知道这个位置里具体是什么东西。
        Solidity 的强类型特性：
        Solidity 是一种强类型语言。这意味着在编译时，编译器需要明确知道你正在尝试调用的函数是否存在于你正在操作的类型上。
        如果你有一个 MyContract 类型的变量 myContractInstance，并且 MyContract 中定义了 doSomething() 函数，那么 myContractInstance.doSomething() 是合法的。
        但如果你有一个 address 类型的变量 someAddress，你不能直接 someAddress.doSomething()，除非 someAddress 被明确转换成了编译器知道有 doSomething() 函数的类型。
        ERC20Mock(weth) 的作用（类型转换/接口实现）：
        ERC20Mock 是一个合约类型。当你将 weth（一个 address）转换为 ERC20Mock(weth) 时，你是在告诉编译器：“请相信我，weth 这个地址指向的合约是一个 ERC20Mock 合约（或者至少它实现了 ERC20Mock 所实现的所有公共/外部接口，特别是 approve 函数）。现在你可以允许我调用 ERC20Mock 类型上的方法了。”
        这实际上是编译器层面的一种断言。如果 weth 实际指向的合约并没有 approve 函数，那么尽管这段代码能通过编译，但在运行时调用 approve 时会失败（通常是 bad jump destination 或 function not found 错误，取决于 EVM 的具体行为）。*/

        //weth 在 HelperConfig 中有具体合约地址意味着什么？
        /* 是的，你在 HelperConfig 中：
        在 getSepoliaConfig() 中，weth 是一个硬编码的 WETH 代币合约地址。
        在 getOrCreatAnvilEthConfig() 中，weth 是通过 new ERC20Mock(...) 部署的 ERC20Mock 合约地址。
        这意味着 weth 这个地址：
        在 Sepolia 上，它是一个真实的、已经部署的 WETH ERC-20 代币合约的地址。
        在 Anvil 上，它是一个你刚刚部署的模拟 ERC20Mock 合约的地址。
        简而言之：
        你知道 weth 指向一个 ERC-20 代币合约。
        编译器只知道 weth 是一个 address。
        为了弥合这个鸿沟，你需要使用 ERC20Mock(weth) 进行类型转换，告诉编译器这个 address 可以被视为一个 ERC20Mock 实例，从而允许调用其方法。
        这就是为什么 ERC20Mock(weth).approve(...) 是必要的。 */

        //这里面weth合约的作用是什么?
        /* weth 在你的 Foundry 测试中，不是一个存有 ETH 币的地址（私钥）。它是一个模拟的 ERC-20 代币合约的地址。
        weth是一个智能合约，当我往里面存入（相当于质押）一个eth时，它就会产出一个weth。
        在生产环境中，你会像这样进行类型转换：IERC20(token).transferFrom(msg.sender, address(this), amount); */
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        //这里是不是希望其返回一个DSCEngine__AmountNeedsMoreThanZero的错误呢?
        /* 是的，当一个 Solidity 合约中定义了自定义错误（例如 error MyCustomError(uint256 code, string message);）
        并且在代码中通过 revert MyCustomError(123, "Something went wrong"); 抛出时：
        1.EVM 实际上会返回一个特殊的错误数据，这个数据以 错误的 4 字节选择器 开头。
        2.这个 4 字节选择器是通过对错误签名（包括错误名称和参数类型）进行 Keccak-256 哈希，然后取前 4 字节得到的。
        3.例如，MyCustomError(uint256,string) 的选择器是 bytes4(keccak256("MyCustomError(uint256,string)"))。
        你的 DSCEngine__AmountNeedsMoreThanZero 错误没有参数，所以它的选择器是 
        bytes4(keccak256("DSCEngine__AmountNeedsMoreThanZero()"))。 */
        //为什么使用.selector 而不是 DSCEngine__AmountNeedsMoreThanZero()？
        /* DSCEngine__AmountNeedsMoreThanZero() 后面加上括号，通常表示调用一个函数。
        但 DSCEngine__AmountNeedsMoreThanZero 在这里是一个自定义错误类型，而不是一个函数。
        如果你直接写 DSCEngine__AmountNeedsMoreThanZero()，编译器会认为你试图实例化或调用这个错误，
        这在 Solidity 中不是一个合法的表达式 */
        vm.expectRevert(DSCEngine.DSCEngine__AmountNeedsMoreThanZero.selector);
        dsce.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertsWithUnapprovedCollateral() public {
        //这行代码的目的是什么？
        /* 为了创建一个新的ERC20Mock合约 */
        //ERC20Mock合约与DSCEngine产生连接的方式时什么？
        /* DSCEngine 通过在构造函数中预设或通过其他方法添加，来“知道”哪些代币地址是它允许作为抵押品
        并与之交互的。它会存储这些代币地址（通常还会关联它们的价格喂价），并在其核心逻辑中使用这些地址。 */
        ERC20Mock ranToken = new ERC20Mock("RAN", "RAN", USER, AMOUNT_COLLATERAL);
        vm.startPrank(USER);
        //这里的DSCEngine为什么不能用dsce？
        /* 当你在 DSCEngine.sol 中定义 error DSCEngine__NotAllowedTokens(); 时，这个错误是属于 
        DSCEngine 合约类型的。它不是某个具体合约实例 dsce 的成员。要访问一个自定义错误的 selector，
        你需要使用定义该错误的合约类型名称来限定它，而不是该合约的一个具体实例。 */
        vm.expectRevert(DSCEngine.DSCEngine__NotAllowedTokens.selector);
        dsce.depositCollateral(address(ranToken), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    //nonReentrant暂时没有进行测试，现在对于它还不够了解，但以后应该会的

    modifier depositCollateral() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        //为什么这里要用weth而不用address(dsce)？
        /* 这里的ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);的意思是
        weth允许address(dsce)使用AMOUNT_COLLATERAL那么多的代币，而不是直接转给了它。
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);然后再将AMOUNT_COLLATERAL数量的weth转入dsce中. */
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    function testCanDepositCollateralAndGetAccountInfo() public depositCollateral {
        (uint256 totalDSCMinted, uint256 collateralValueInUsd) = dsce.getAccountInformation(USER);
        uint256 expectedDSCMinted = 0;
        uint256 expectedcollateralAmount = dsce.getTokenAmountFromUsd(weth, collateralValueInUsd);
        assertEq(totalDSCMinted, expectedDSCMinted);
        assertEq(AMOUNT_COLLATERAL, expectedcollateralAmount);
    }

    function testRevertIftransferFromFailed() public depositCollateral {
        vm.startPrank(USER);
        //为什么这里是address(weth)而不是address(dsce)？
        /* 当你在测试中调用 dsce.depositCollateral(...) 时，会发生以下步骤：
        1.代码执行进入 DSCEngine 合约的 depositCollateral 函数。
        2.在 depositCollateral 函数内部，执行了 IERC20(tokenCollateralAddress).transferFrom(...) 这一行。
        3.请注意，这里的 tokenCollateralAddress 实际上是你的 WETH 代币合约的地址（在测试中，你用 weth 变量来代表它）。
        4.所以，这一行代码的含义是：DSCEngine 合约正在向 WETH 合约 发送一个 外部调用，要求 WETH 合约执行 transferFrom 函数。
        vm.mockCall() 的工作原理
        vm.mockCall(目标地址, 函数选择器, 返回数据) 的作用是告诉 Foundry：
        “当任何合约（包括你的 DSCEngine 合约）尝试向 目标地址 调用某个 函数选择器 对应的函数时，不要真正执行那个目标地址的函数，
        而是直接返回我指定的 返回数据。” 
        所以，根据这个规则：
        目标地址（第一个参数）必须是你想要“拦截”或“模拟”其函数调用的那个合约的地址。
        在你的 depositCollateral 函数中，是 DSCEngine 合约在调用 weth 合约的 transferFrom 函数。
        因此，被调用的目标是 weth 合约。所以，vm.mockCall 的目标地址必须是 address(weth)。*/

        //为什么IERC20.transferFrom.selector不像IERC20(tokenCollateralAddress).transferFrom.selector这样写呢？
        /* 
        为什么是 IERC20.transferFrom.selector？
        IERC20 是一个接口 (Interface)。 它定义了 ERC20 代币标准中包含的函数签名（例如 transferFrom、approve、balanceOf 等），但它没有实现这些函数。
        当你写 IERC20.transferFrom.selector 时，你是在对 IERC20 接口中定义的 transferFrom 函数的签名来计算选择器。
        这个选择器 0x23b872dd (或者其他实际值) 是 ERC20 标准中 transferFrom 函数的通用选择器。任何遵循 ERC20 标准并实现了 transferFrom 函数的合约，
        它的 transferFrom 函数都会有这个选择器。      
        为什么不能是 IERC20(tokenCollateralAddress).transferFrom.selector？
        IERC20(tokenCollateralAddress) 是将一个 address 类型转换为 IERC20 接口类型。这实际上是创建了一个指向该地址的接口实例。
        虽然这是一个有效的 Solidity 语法，用于在代码中发起实际的外部调用（就像你在 DSCEngine 合约中做的那样：
        IERC20(tokenCollateralAddress).transferFrom(...)），但当你试图在其后面直接加上 .selector 时，编译器会混淆或报错。
        因为 .selector 是用于获取 函数定义 的选择器，而不是获取 特定实例上函数调用的选择器。你已经有了一个具体的地址 tokenCollateralAddress，
        你无法在运行时从一个具体的地址实例上去“提取”一个编译时常量。
        vm.mockCall 的 selector 参数需要的就是这个编译时确定的 4 字节函数选择器，它不关心这个选择器是从哪个具体合约实例上“发出”的。
        它只关心“当这个选择器被调用在那个目标地址上时”。
        总结：
        IERC20.transferFrom.selector: 这是获取 函数签名 的选择器。它是一个编译时常量，代表 ERC20 标准中 transferFrom 函数的通用标识符。
        vm.mockCall 需要的就是这个通用的标识符。
        IERC20(tokenCollateralAddress).transferFrom(...): 这是一种 类型转换和外部调用 的语法。它用于在你的合约代码中，
        向一个已知地址发起一个实际的 transferFrom 调用。在这种情况下，tokenCollateralAddress 是一个运行时变量，
        而不是一个在编译时就能确定函数签名所属的类型。你不能直接对一个实例化的调用表达式去取 selector。
        vm.mockCall 语法设计就是为了让你指定：
        哪个合约地址（目标地址） 会被调用。
        哪个函数签名（通过选择器） 会被调用。
        它不需要知道你是在哪个具体的变量上进行的类型转换才发出的调用。只要调用最终是发往 address(weth) 
        并且选择器是 IERC20.transferFrom.selector，vm.mockCall 就会拦截。*/

        //为什么说tokenCollateralAddress 是一个运行时变量呢？
        /* 在你的 depositCollateral 函数中，tokenCollateralAddress 是一个函数参数：
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        函数参数的特性：
        当一个函数被调用时，它的参数的值是由调用者在运行时提供的。
        例如，用户 A 调用 depositCollateral(wethAddress, 100 ether)，那么 tokenCollateralAddress 在这次调用中就是 wethAddress 的值。
        用户 B 调用 depositCollateral(daiAddress, 50 ether)，那么在另一次调用中，tokenCollateralAddress 就是 daiAddress 的值。 
        不可预测性：
        在编译 DSCEngine.sol 合约的时候，编译器并不知道 tokenCollateralAddress 会具体是哪个代币的地址。它可能在部署时确定，
        也可能在每次函数调用时由调用者提供。
        这种值在编译时无法确定，必须在程序实际运行时才能获取的变量，就是 运行时变量（runtime variable）。*/

        //为什么不能在运行时变量上取 .selector？
        /* 编译器在处理 .selector 时，它需要知道它是在对一个函数定义取选择器，而不是一个表达式的运行时结果。
        IERC20.transferFrom.selector： 编译器知道 IERC20 是一个接口，并且 transferFrom 是这个接口中定义的一个函数。
        它可以在编译时直接计算出这个函数的选择器。
        IERC20(tokenCollateralAddress).transferFrom.selector：
        1.tokenCollateralAddress 是一个运行时变量，它的具体值在编译时是未知的。
        2.IERC20(tokenCollateralAddress) 这是一个类型转换操作，表示“将这个运行时地址视为一个 IERC20 接口”。
        这个操作的结果在编译时也是未知的。
        3.所以，你不能在编译器还不知道具体是哪个合约实例的时候，就要求它去“静态地”计算一个函数的 .selector。
        .selector 只能用于直接引用的函数定义，而不能用于通过运行时变量获得的实例。 
        简单来说，.selector 是用来识别函数模板的，而不是用来识别某个具体对象的某个动作的。
        因此，当 Foundry 的 vm.mockCall 需要一个 selector 参数时，它需要的是那个通用且不变的、标识函数签名的 4 字节哈希值，
        而不是一个依赖于运行时地址的表达式。这个通用哈希值就是 IERC20.transferFrom.selector。*/
        vm.mockCall(address(weth), IERC20.transferFrom.selector, abi.encode(false));
        vm.expectRevert(DSCEngine.DSCEngine__TransferFailed.selector);
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    ///////////////////////////////////
    // redeemCollateralForDsc Tests //
    //////////////////////////////////

    function testMustRedeemMoreThanZero() public depositCollateralAndMintDsc {
        vm.startPrank(USER);
        dsc.approve(address(dsce), AMOUNT_TO_MINT);
        vm.expectRevert(DSCEngine.DSCEngine__AmountNeedsMoreThanZero.selector);
        dsce.redeemCollateralForDsc(weth, 0, AMOUNT_TO_MINT);
        vm.stopPrank();
    }

    function testCanRedeemDepositedCollateral() public depositCollateralAndMintDsc {
        vm.startPrank(USER);
        dsc.approve(address(dsce), AMOUNT_TO_MINT);
        dsce.redeemCollateralForDsc(weth, AMOUNT_COLLATERAL, AMOUNT_TO_MINT);
        vm.stopPrank();

        uint256 userBalance = dsc.balanceOf(USER);
        assertEq(userBalance, 0);
    }

    //////////////////////////////////
    // redeemCollateral Tests ////////
    //////////////////////////////////

    function testRevertsIfRedeemAmountIsZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, AMOUNT_TO_MINT);
        vm.expectRevert(DSCEngine.DSCEngine__AmountNeedsMoreThanZero.selector);
        dsce.redeemCollateral(weth, 0);
        vm.stopPrank();
    }

    function testCanRedeemCollateral() public depositCollateral {
        vm.startPrank(USER);
        uint256 userBalanceBeforeRedeem = dsce.getCollateralBalanceOfUser(USER, weth);
        assertEq(userBalanceBeforeRedeem, AMOUNT_COLLATERAL);
        dsce.redeemCollateral(weth, AMOUNT_COLLATERAL);
        uint256 userBalanceAfterRedeem = dsce.getCollateralBalanceOfUser(USER, weth);
        assertEq(userBalanceAfterRedeem, 0);
        vm.stopPrank();
    }

    function testRevertIfDSCEngine__TransferFailed() public depositCollateral {
        vm.startPrank(USER);
        vm.mockCall(address(weth), IERC20.transfer.selector, abi.encode(false));
        vm.expectRevert(DSCEngine.DSCEngine__TransferFailed.selector);
        dsce.redeemCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    //////////////////
    // burnDsc Test //
    //////////////////

    function testRevertsIfBurnAmountIsZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, AMOUNT_TO_MINT);
        vm.expectRevert(DSCEngine.DSCEngine__AmountNeedsMoreThanZero.selector);
        dsce.burnDsc(0);
        vm.stopPrank();
    }

    function testCantBurnMoreThanUserHas() public {
        vm.prank(USER);
        vm.expectRevert();
        dsce.burnDsc(1);
    }

    function testCanBurnDsc() public depositCollateralAndMintDsc {
        vm.startPrank(USER);
        dsc.approve(address(dsce), AMOUNT_TO_MINT);
        dsce.burnDsc(AMOUNT_TO_MINT);
        vm.stopPrank();

        uint256 userBalance = dsc.balanceOf(USER);
        assertEq(userBalance, 0);
    }

    function testburnDscRevrtsIfDSCEngine__TransferFailed() public depositCollateralAndMintDsc {
        vm.startPrank(USER);
        vm.mockCall(address(dsc), dsc.transferFrom.selector, abi.encode(false));
        vm.expectRevert(DSCEngine.DSCEngine__TransferFailed.selector);
        dsce.burnDsc(AMOUNT_DSC);
        vm.stopPrank();
    }

    //////////////////
    // mintDsc Test //
    //////////////////

    function testMintDscRevertsIfAmountIsZero() public {
        vm.startPrank(USER); // 模拟用户调用
        // 这里不需要抵押品，因为会在修饰符层面就回滚
        vm.expectRevert(DSCEngine.DSCEngine__AmountNeedsMoreThanZero.selector); // 或者，如果你有针对这种特定回滚的自定义错误，使用 DSCEngine.SomeZeroAmountError.selector
        dsce.mintDsc(0); // 尝试铸造 0 个 DSC
        vm.stopPrank();
    }

    function testCanMintDscSuccessfullyAndVerifyBalances() public depositCollateral {
        vm.startPrank(USER);
        dsce.mintDsc(AMOUNT_DSC);
        (uint256 totalDSCMinted,) = dsce.getAccountInformation(USER);
        vm.stopPrank();
        assertEq(totalDSCMinted, AMOUNT_DSC);
        assertEq(dsc.balanceOf(USER), AMOUNT_DSC);
    }

    function testIfMintTooMuchDscAndRevert() public depositCollateral {
        vm.startPrank(USER);
        uint256 expectedHealthFactor =
            dsce.calculateHealthFactor(MINT_TOO_MANY_AMOUNT_DSC, dsce.getUsdValue(weth, AMOUNT_COLLATERAL));
        vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__BreakHealthFactor.selector, expectedHealthFactor));
        dsce.mintDsc(MINT_TOO_MANY_AMOUNT_DSC);
        vm.stopPrank();
    }

    function testRevertIfMintFailed() public depositCollateral {
        vm.startPrank(USER);
        // Mock the DSC.mint function to return false
        //vm.mockCall() 的作用
        /* 在 Foundry 测试中，vm.mockCall() 是一个强大的工具，它允许你模拟（mock）
        某个智能合约在特定函数调用时的行为。这意味着当你的合约 A 调用合约 B 的某个函数时，
        你可以用vm.mockCall() 来控制合约 B 的函数会返回什么值，或者它是否会回滚（revert），
        而不需要合约 B 真的去执行其内部逻辑。  */
        //为什么要模拟？
        /* 1.隔离测试： 当你测试一个合约（比如 DSCEngine）时，你可能不希望它依赖于其他复杂合约
        （比如 DecentralizedStableCoin 或 MockV3Aggregator）的完整逻辑。通过模拟外部调用，
        你可以确保只测试 DSCEngine 的行为，而不会被它所依赖的合约中的错误或复杂性所干扰。
        这被称为“单元测试”的关键原则。
        2.强制特定场景： 有些场景在真实情况下很难或不可能发生，但在测试中你希望模拟它们。例如：
        某个外部函数返回 false（而不是回滚）。
        某个外部函数回滚并带有一个特定的错误消息。
        某个外部函数返回一个非常特定的、边缘情况下的值。
        3.提高测试速度： 模拟通常比执行完整的合约逻辑更快，因为你跳过了复杂的内部计算和存储操作。 */
        /* vm.mockCall() 的用法
        vm.mockCall() 有几种重载形式，但最常用的是以下两种：

        模拟函数返回值：
        vm.mockCall(address target, bytes4 selector, bytes memory retdata)
        address target: 你要模拟调用的合约的地址。
        bytes4 selector: 你要模拟的函数的 function selector（函数签名哈希的前 4 字节）。
        你可以通过 MyContract.myFunction.selector 来获取。
        bytes memory retdata: 你希望该函数返回的 ABI 编码的数据。如果函数返回 bool，
        你就编码 true 或 false。如果函数返回 uint256，你就编码相应的 uint256。
        模拟函数回滚：
        vm.mockCall(address target, bytes4 selector, bytes memory revertdata, uint256 revertStringLength)
        address target, bytes4 selector: 同上。
        bytes memory revertdata: 你希望该函数回滚时带的 ABI 编码的错误数据（例如，自定义错误的 selector 或字符串错误）。
        uint256 revertStringLength: 如果 revertdata 是一个字符串错误（例如 abi.encodeRevert("My Error")），
        你需要指定字符串的长度。对于自定义错误，这个参数通常可以忽略或设置为 0 */
        vm.mockCall(address(dsc), dsc.mint.selector, abi.encode(false));

        // Expect your custom revert error
        vm.expectRevert(DSCEngine.DSCEngine__MintFailed.selector);

        // Call the function under test
        dsce.mintDsc(AMOUNT_DSC);
        vm.stopPrank();
    }

    ////////////////////
    // liquidate Test //
    ////////////////////

    function testliquidateRevertsIfAmountIsZero() public depositCollateral {
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__AmountNeedsMoreThanZero.selector);
        dsce.liquidate(address(weth), USER, 0);
        vm.stopPrank();
    }

    function testliquidateRevertsIfHealthFactorIsOk() public depositCollateral {
        vm.startPrank(USER);
        dsce.mintDsc(AMOUNT_DSC);
        vm.expectRevert(DSCEngine.DSCEngine__HealthFactorIsOk.selector);
        dsce.liquidate(address(weth), USER, AMOUNT_DSC); //这里随便用了一个数字，填0的话不会报这个错误
        vm.stopPrank();
    }

    modifier liquidated() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, AMOUNT_TO_MINT);
        vm.stopPrank();
        int256 ethUsdUpdatedPrice = 18e8; //eth的价格为$18

        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(ethUsdUpdatedPrice);
        uint256 userHealthFactor = dsce.getHealthFactor(USER);

        ERC20Mock(weth).mint(liquidator, collateralToCover); //这个collateralToCover为20

        vm.startPrank(liquidator);
        ERC20Mock(weth).approve(address(dsce), collateralToCover);
        dsce.depositCollateralAndMintDsc(weth, collateralToCover, amountToMint); //这个amountToMint为10
        dsc.approve(address(dsce), amountToMint);
        dsce.liquidate(weth, USER, amountToMint);
        vm.stopPrank();
        _;
    }

    function testLiquidationPayoutIsCorrect() public liquidated {
        /* 注意，这里的liquidatorWethBalance的数值应该等于：dsc(单位：1美元)的数量乘以dsc的价格，最后再除以eth的价格 */
        uint256 liquidatorWethBalance = ERC20Mock(weth).balanceOf(liquidator);
        //这里原来为uint256 expectedWeth = dsce.getTokenAmountFromUsd(weth, collateralToCover)，是错误的
        /* 因为我原来理解的是：ERC20Mock(weth).balanceOf(liquidator)的余额应该为21 ether，
        因为collateralToCover为20，而他deposit的Collateral为20 ether，mint的dsc为10 ether，
        他要用这10 dsc去liquidat用户，所以从liquidat函数里获得的资金应该为11 ether，所以liquidator的余额应该为21 ether。
        幸运的是，我们发现这是错误的。 
        关键点：清算人的 WETH 余额来源
        清算人的 WETH 余额主要有两个潜在来源：
        1.他自己持有的 WETH：这些可能是测试开始时 mint 给他的，或者他自己存入抵押品时使用的。
        2.通过清算获得的抵押品：这是清算奖励。
        您的计算：collateralToCover 为 20 ether，depositCollateral 为 20 ether。这个 20 ether 到底是清算人自己本来持有的 WETH，
        还是他从清算中获得的？从您的描述和之前的 trace 来看：
        ERC20Mock(weth).mint(liquidator, collateralToCover): 这一行表示测试环境给 liquidator mint 了 20 ether 的 WETH。
        这是清算人初始持有的 WETH。
        dsce.depositCollateralAndMintDsc(weth, collateralToCover, amountToMint): 这一行是清算人自己存入 20 ether WETH 作为抵押品，
        并铸造 10 ether DSC。
        重要！ 当清算人将 20 ether WETH depositCollateral 后，这 20 ether 就不再属于清算人的直接余额了，
        它们被锁定在 DSCEngine 合约中作为抵押品。
        而在liquidate函数中，有一行_redeemCollateral代码，就决定了回到liquidator账户里面的余额*/

        //那在测试开始时mint给清算人的weth和他自己存入抵押品后再mint的weth必须是同一种类型的eth吗，还是我们可以自己定义一种weth？
        /* 可以这样理解：eth是以太坊的原生货币，而智能合约是规定它们如何流通的法律 */

        //那现在如果liquidator想赎回他全部的eth的话，是不是调用redeemCollateral函数就可以了呢？
        /* 是的，如果 liquidator 想赎回他自己存入 DSCEngine 合约中的全部 ETH (WETH) 抵押品，
        那么调用 redeemCollateral 函数通常是正确的做法。
        但是，有几个非常重要的条件和细节需要注意：
        1.偿还所有 DSC 债务： redeemCollateral 函数通常会检查调用者的健康因子 (healthFactor)。如果用户仍然有未偿还的 DSC 债务，
        并且赎回抵押品会导致他们的健康因子低于最小阈值（例如 1），那么 redeemCollateral 调用将会失败并回滚 (revert)。
        核心原则： 在去中心化稳定币协议中，你不能在仍有未偿债务的情况下将所有抵押品全部取回，
        因为这会使协议变得抵押不足（undercollateralized）。
        解决方案： liquidator 必须首先烧毁 (burn) 他自己铸造的所有 DSC，或者确保他有足够的剩余抵押品来覆盖剩余的 DSC 债务，
        以保持健康因子在安全范围内。在您的测试场景中，liquidator 自己也铸造了 10 ether DSC。因此，他需要先烧毁这 10 ether DSC。
        2.redeemCollateral 函数的参数：
        redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        tokenCollateralAddress: 需要赎回的抵押品代币的地址 (例如 weth 的地址)。
        amountCollateral: 需要赎回的抵押品数量。如果你想赎回全部，你需要知道你存入了多少。 
        3.liquidator 的 WETH 来源：
        正如我们之前讨论的，在您的测试中，liquidator 有两部分 WETH：
        他自己作为借款人存入 DSCEngine 的 20 ether (在 depositCollateralAndMintDsc 调用中)。
        他作为清算人从清算中获得的 ~0.611 ether (这部分直接转到了他的钱包，不在 DSCEngine 合约里作为他的抵押品)。
        redeemCollateral 只能赎回他自己作为借款人存入 DSCEngine 的那部分抵押品 (即 20 ether)。 
        清算所得的 ~0.611 ether 已经在他的钱包里了，不需要赎回。*/

        //总计清算所得: 0.555555555555555555 + 0.055555555555555555 = 0.611111111111111110 ether，
        //0.555555555555555555的十分之一的不应该是0.0555555555555555555吗，最后一位是被消除了吗？
        /* 在 Solidity 和 EVM 中，所有数学运算都是基于整数进行的。它没有内置的浮点数类型。这意味着当进行除法时，
        任何小数部分都会被截断（truncate），而不是四舍五入。
        现在计算奖金部分：
        bonusWeth = (collateralReceivedWithoutBonus * dsce.getLiquidationBouns()) / dsce.getLiquidationPrecision();
        bonusWeth = (555555555555555555 * 10) / 100;
        乘法部分：
        555555555555555555 * 10 = 5555555555555555550
        除法部分（关键）：
        5555555555555555550 / 100
        在整数除法中：
        5555555555555555550 除以 100 等于 55555555555555555，余数是 50。
        这个余数 50 被直接丢弃了。所以，结果就是 55555555555555555。
        这就是为什么你看到的是 0.055555555555555555 而不是 0.0555555555555555555。最后一位的 5 是因为整数除法被截断而消失的。 */
        uint256 expectedWeth = dsce.getTokenAmountFromUsd(weth, amountToMint)
            + (
                (dsce.getTokenAmountFromUsd(weth, amountToMint) * dsce.getLiquidationBouns())
                    / dsce.getLiquidationPrecision()
            );
        uint256 hardCodedExpected = 611_111_111_111_111_110;
        assertEq(liquidatorWethBalance, expectedWeth);
        assertEq(liquidatorWethBalance, hardCodedExpected);
    }

    function testUserStillHasSomeEthAfterLiquidation() public liquidated {
        // Get how much WETH the user lost
        uint256 amountLiquidated = dsce.getTokenAmountFromUsd(weth, amountToMint)
            + (dsce.getTokenAmountFromUsd(weth, amountToMint) * dsce.getLiquidationBouns() / dsce.getLiquidationPrecision());

        uint256 usdAmountLiquidated = dsce.getUsdValue(weth, amountLiquidated);
        uint256 expectedUserCollateralValueInUsd = dsce.getUsdValue(weth, AMOUNT_COLLATERAL) - (usdAmountLiquidated);

        uint256 userCollateralValueInUsd = dsce.getAccountCollateralValue(USER);
        uint256 hardCodedExpectedValue = 169_000_000_000_000_000_020;
        assertEq(userCollateralValueInUsd, expectedUserCollateralValueInUsd);
        assertEq(userCollateralValueInUsd, hardCodedExpectedValue);
    }

    function testLiquidatorTakesOnUsersDebt() public liquidated {
        (uint256 liquidatorDscMinted,) = dsce.getAccountInformation(liquidator);
        assertEq(liquidatorDscMinted, amountToMint);
    }

    function testHowMuchDscUserMinted() public liquidated {
        //user和USER的区别？
        /* 
        1.user (小写 u)
        在你当前的设置中，address public user = address(1); 表示：
        它是一个状态变量： user 和 USER 一样，都是在合约层面声明的变量。
        它被直接初始化： 在测试合约部署时，它被赋予了一个固定的值 address(1)。这意味着 user 将始终指向地址 0x000...01。
        它的命名是小写： 这通常表示它是一个普通的变量，而不是一个需要用全大写字母来突出其常量性质的全局常量。
        2.USER (大写 U)
        在你当前的设置中，address public USER = makeAddr("user"); 表示：
        它也是一个状态变量： 和 user 一样，USER 也在合约层面声明。
        它使用了 makeAddr("user")： 这是一个 Forge 特有的作弊码 (cheatcode)。makeAddr("user") 会根据字符串 "user" 生成一个独有的、确定性的地址。通常，这比直接使用 address(1) 更受欢迎，因为 makeAddr 创建的地址不会与常见的 Hardhat/Anvil 默认地址（比如 address(1) 经常是）发生冲突。
        它的命名是大写： 这通常表示这是一个常量或不可变的值，在测试执行期间不会改变，符合这种值的常见命名约定。 */
        (uint256 userDscMinted,) = dsce.getAccountInformation(USER);
        uint256 userdebt = 90_000_000_000_000_000_000;
        assertEq(userDscMinted, userdebt);
    }
}
