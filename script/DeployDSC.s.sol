//SPDX-License-Identifier:MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";

contract DeployDSC is Script {
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    //为什么要加一个HelperConfig？ /* 为了在DSCEngine.t.sol中调用HelperConfig */
    function run() external returns (DecentralizedStableCoin, DSCEngine, HelperConfig) {
        HelperConfig config = new HelperConfig();

        (address wethUsdPriceFeed, address wbtcUsdPriceFeed, address weth, address wbtc, uint256 deploykey) =
            config.activeNetworkConfig();

        //2025.5.31 当时有点不理解数组的定义和往里面添加元素的方式
        /* [weth, wbtc]: This is an array literal. It directly creates an array containing the values of weth and wbtc.
        When you assign this array literal to tokenAddresses, the tokenAddresses array will now hold weth at index 0 and
        wbtc at index 1. It's length will be 2. */
        tokenAddresses = [weth, wbtc];
        priceFeedAddresses = [wethUsdPriceFeed, wbtcUsdPriceFeed];

        //这里的括号里面为什么加一个deploykey呢？
        /* 这不是因为结构体的限制，而是 vm.startBroadcast() 函数的设计要求。
        vm.startBroadcast() 是 Foundry Vm 库提供的一个特殊函数，用于在 Foundry 脚本中模拟交易签名。它有两种主要形式：
        1.vm.startBroadcast(): 不带参数，使用 Foundry 默认的部署者私钥（通常是测试链的第一个账户）。
        vm.startBroadcast(uint256 privateKey): 传入一个 uint256 类型的私钥。这会告诉 Foundry，从现在开始，
        所有后续的交易都应该使用这个特定的 privateKey 进行签名。 */

        //在sepolia测试网上测试的时候，添加的这个deploykey不会与sepolia私钥发生冲突吗？
        /* 是的，会发生冲突，或者说，在实际部署到 Sepolia 时，这种方式会出问题。 */

        //在终端命令行加上自己的私钥也会与deploykey发生冲突吗？
        /* 在终端命令行加上自己的私钥（例如 --private-key <YOUR_PRIVATE_KEY>）会与 vm.startBroadcast(deploykey) 
        中的 deploykey 发生冲突。
        然而，vm.startBroadcast(uint256 privateKey) 是一个特殊的 Foundry Vm 作弊码（cheat code），它在合约内部被调用。
        这个作弊码的作用是：
        明确指示 Foundry 模拟使用传入的 privateKey 来进行后续交易的签名。
        它会覆盖 Foundry 对当前交易执行上下文的任何默认私钥设置，包括从命令行 --private-key 传入的私钥。
        所以，当你的脚本执行到 vm.startBroadcast(deploykey) 这一行时：
        即使你在命令行中提供了 forge script ... --private-key <YOUR_SEPOLIA_PRIVATE_KEY>
        vm.startBroadcast() 也会忽略这个命令行私钥，并强制使用你从 config.activeNetworkConfig() 中获取的 deploykey
        （在 Sepolia 配置中通常是 DEFAULT_ANVIL_KEY）。 */

        /* 正确的做法（生产级别）：
        在部署到真实测试网或主网时，你通常会这样做：
        1.从 HelperConfig 中移除 deployerKey 字段。 NetworkConfig 结构体就不应该包含它。
        2.在 DeployDSC.s.sol 的 run() 函数中，不要从 config.activeNetworkConfig() 中获取 deploykey。
        3.完全依赖 forge script 命令行的 --private-key 参数来指定部署私钥。 */
        vm.startBroadcast(deploykey);
        DecentralizedStableCoin dsc = new DecentralizedStableCoin();
        DSCEngine engine = new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
        dsc.transferOwnership(address(engine));
        vm.stopBroadcast();
        return (dsc, engine, config);
    }
}
