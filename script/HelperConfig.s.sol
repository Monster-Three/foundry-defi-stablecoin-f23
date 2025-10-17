//SPDX-License-Identifier:MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "../test/mocks/MocksV3Aggregator.sol";
import {ERC20Mock} from "../test/mocks/ERC20Mock.sol";

contract HelperConfig is Script {
    //这个结构体是怎么来的？
    /* 用户需要自己定义这个结构体 */
    struct NetworkConfig {
        address wethUsdPriceFeed;
        address wbtcUsdPriceFeed;
        address weth;
        address wbtc;
        uint256 deployerKey;
    }

    uint8 public constant DECIMALS = 8;
    int256 public constant ETH_USD_PRICE = 2000e8;
    int256 public constant BTC_USD_PRICE = 1000e8;
    uint256 public DEFAULT_ANVIL_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    NetworkConfig public activeNetworkConfig;

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaConfig();
        } else {
            activeNetworkConfig = getOrCreatAnvilEthConfig();
        }
    }

    function getSepoliaConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            wethUsdPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
            wbtcUsdPriceFeed: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
            weth: 0xdd13E55209Fd76AfE204dBda4007C227904f0a81,
            wbtc: 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063,
            //这个deployerKey的作用是什么？
            /* DEFAULT_ANVIL_KEY 是一个预定义的测试私钥，通常指向 Anvil（或 Hardhat 等本地开发网络）的第一个默认账户。
            如果你真的想将合约部署到 Sepolia 测试网，你必须使用一个在 Sepolia 网络上拥有 ETH 且你自己控制的真实私钥。 
            对于 getSepoliaConfig() 中的 deployerKey: DEFAULT_ANVIL_KEY，把它理解为仅用于本地测试和模拟的目的，
            而不能用于实际的 Sepolia 部署。
            因为有结构体的限制，所以才在getSepoliaConfig()函数中添加一个deployerKey，但其实deployerKey
            在getSepoliaConfig()函数中是没有必要的*/
            deployerKey: DEFAULT_ANVIL_KEY
        });
    }

    function getOrCreatAnvilEthConfig() public returns (NetworkConfig memory) {
        //不是很理解这段代码出现的意义
        /* 这段代码是用来实现一个非常常见的编程模式，叫做**“单例模式”或者“懒加载/惰性初始化”，在部署脚本中它的作用是避免重复部署**。
        1.activeNetworkConfig 是什么？
        在你的 HelperConfig.s.sol 部署脚本中，activeNetworkConfig 是一个状态变量，类型是 NetworkConfig 结构体。
        这个 NetworkConfig 结构体里面保存着部署好的各种合约的地址（比如 wethUsdPriceFeed、wbtcUsdPriceFeed、weth、wbtc）。
        在脚本一开始，activeNetworkConfig 结构体的所有字段（包括 wethUsdPriceFeed）默认值都是 address(0)，
        因为 Solidity 中 address 类型的默认值就是 0x00...00。
        2.wethUsdPriceFeed != address(0) 是什么意思？
        wethUsdPriceFeed 是 NetworkConfig 结构体中的一个字段，它存储了 WETH/USD 价格喂价合约的地址。
        address(0) 是一个特殊的地址，表示“空地址”或者“未设置的地址”。
        所以，wethUsdPriceFeed != address(0) 这句代码就是在检查：“WETH/USD 价格喂价的地址是否已经被设置过（即它不是空地址）？” */

        //为什么只有一个activeNetworkConfig.wethUsdPriceFeed != address(0)，而不多设置几个条件，比如activeNetworkConfig.wbtcUsdPriceFeed != address(0)和activeNetworkConfig.weth、activeNetworkConfig.wbtc等一系列的条件？
        /* 
        1.原子性部署 (Atomic Deployment)：
        getOrCreatAnvilEthConfig() 函数的设计意图是要么完整地部署所有模拟合约并设置所有地址，要么什么都不做，直接返回已有的完整配置。
        在 vm.startBroadcast() 和 vm.stopBroadcast() 之间，
        所有的 new MockV3Aggregator(...) 和 new ERC20Mock(...) 都是作为一个单一的、原子性的部署操作单元来执行的。
        这意味着，如果 ethUsdPriceFeed 成功部署并将其地址赋值给了 activeNetworkConfig.wethUsdPriceFeed，
        那么可以高度确信在同一 vm.startBroadcast() / vm.stopBroadcast() 块中的其他模拟合约（如 btcUsdPriceFeed、wethMock、wbtcMock）也已经成功部署，
        并且它们的地址也已经正确地赋值给了 activeNetworkConfig 结构体中对应的字段。
        2.效率考虑：
        检查一个字段比检查所有字段要更高效。虽然对于几个地址的检查来说，性能差异微乎其微，
        但在大型项目中，这种模式可以避免不必要的重复检查。
        3.隐式信任与错误处理：
        开发者在这里隐式地信任，如果 wethUsdPriceFeed 这个关键的地址已经被设置（即它不再是 address(0)），
        那么整个 NetworkConfig 结构体都已经被正确地填充了。
        如果其中任何一个模拟合约的部署失败（例如，因为内存不足或其他 Solidity 错误），整个 vm.startBroadcast() 块的交易都会回滚，
        那么 activeNetworkConfig 结构体中的任何字段都不会被赋值为有效的非零地址。它会保持其默认的 address(0) 状态。
        因此，这个 if 条件仍然会判断为假，从而再次尝试完整的部署流程。 */

        //我还不是很懂这段检查的意义，为什么getSepoliaConfig函数里面没有这段检查呢？
        /*
        这个 if 语句为本地 Anvil 开发提供了一种优化和一种**“单例”模式**。
        1. “单例”模式： HelperConfig 合约继承了 Script，它被设计用来模拟交易。如果你有多个脚本或测试需要获取 Anvil 上的网络配置，
        你可能会多次调用 getOrCreatAnvilEthConfig()。
        2.避免重复部署： 这里的核心思想是防止在单次测试运行或脚本执行中，重复部署模拟合约（例如 MockV3Aggregator 和 ERC20Mock）。
        第一次调用 getOrCreatAnvilEthConfig() 时，activeNetworkConfig.wethUsdPriceFeed 将是它的默认零值（address(0)）。
        此时 if 条件 activeNetworkConfig.wethUsdPriceFeed != address(0) 为 false。
        代码会继续执行，部署模拟合约（在 vm.startBroadcast() 和 vm.stopBroadcast() 之间），然后将这些合约的地址赋值给 activeNetworkConfig。
        在同一次脚本执行中，如果后续再次调用 getOrCreatAnvilEthConfig()，activeNetworkConfig.wethUsdPriceFeed 将不再是 address(0)。
        它将保存已经部署的模拟价格喂价的地址。
        此时 if 条件将变为 true，函数会立即 return activeNetworkConfig，从而有效地跳过模拟合约的部署步骤。
        这使得你的本地测试和脚本运行更加高效，因为它不会浪费 Gas 和时间在重新部署那些在当前模拟环境中已经可用的模拟合约上。
         */
        //为什么 getSepoliaConfig() 没有这个检查？
        /* 
        现在，我们来看看 getSepoliaConfig()：
        function getSepoliaConfig() public view returns (NetworkConfig memory) {
            return NetworkConfig({
                wethUsdPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306, // Sepolia 上的真实地址
                wbtcUsdPriceFeed: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43, // Sepolia 上的真实地址
                // ... 其他真实地址 ...
            });
        }
        这个函数不需要这种检查，原因如下：
        1.静态、已知地址： getSepoliaConfig() 中使用的地址是硬编码的、真实的，
        并且已经部署在 Sepolia 测试网（如果你使用的是主网，那也是主网上的真实地址）。它们不是由你的脚本部署的。
        2.没有部署开销： 由于没有部署新的合约，所以通过检查它们是否已经“创建”来提高效率是没有任何意义的。
        这个函数只是简单地返回一个填充了这些固定地址的 NetworkConfig 结构体。
        3.只读功能： 注意 getSepoliaConfig() 被标记为 view，这意味着它只读取状态而不修改它。
        而 getOrCreatAnvilEthConfig() 必须是 public（不能是 view），因为它通过 vm.startBroadcast() 确实修改了区块链状态，
        部署了模拟合约。
        本质上，getOrCreatAnvilEthConfig() 处理的是测试环境中动态、即时创建的依赖项，
        而 getSepoliaConfig() 提供的是公共网络上已有的、永久依赖项的静态引用。只有在你可能重复创建某个对象时，才需要进行检查。
         */

        /*
        总结：
        因为这些部署语句：
        vm.startBroadcast();
         MockV3Aggregator ethUsdPriceFeed = new MockV3Aggregator(DECIMALS, ETH_USD_PRICE);
         ERC20Mock wethMock = new ERC20Mock("WETH", "WETH", msg.sender, 1000e8);
         MockV3Aggregator btcUsdPriceFeed = new MockV3Aggregator(DECIMALS, BTC_USD_PRICE);
         ERC20Mock wbtcMock = new ERC20Mock("WBTC", "WBTC", msg.sender, 1000e8);
         vm.stopBroadcast();
        他就有可能重新部署ethUsdPriceFeed、btcUsdPriceFeed、wethMock、wbtcMock。
        所以才需要加一个if语句：
        if (activeNetworkConfig.wethUsdPriceFeed != address(0)) {
        return activeNetworkConfig;
        }
        但是反过来说，
        vm.startBroadcast();
         MockV3Aggregator ethUsdPriceFeed = new MockV3Aggregator(DECIMALS, ETH_USD_PRICE);
         ERC20Mock wethMock = new ERC20Mock("WETH", "WETH", msg.sender, 1000e8);
         MockV3Aggregator btcUsdPriceFeed = new MockV3Aggregator(DECIMALS, BTC_USD_PRICE);
         ERC20Mock wbtcMock = new ERC20Mock("WBTC", "WBTC", msg.sender, 1000e8);
         vm.stopBroadcast();
        这些broadcast里面的内容，又是部署ethUsdPriceFeed、btcUsdPriceFeed、wethMock、wbtcMock的必要步骤。
         */
        if (activeNetworkConfig.wethUsdPriceFeed != address(0)) {
            return activeNetworkConfig;
        }

        vm.startBroadcast();
        MockV3Aggregator ethUsdPriceFeed = new MockV3Aggregator(DECIMALS, ETH_USD_PRICE);
        ERC20Mock wethMock = new ERC20Mock("WETH", "WETH", msg.sender, 1000e8);

        MockV3Aggregator btcUsdPriceFeed = new MockV3Aggregator(DECIMALS, BTC_USD_PRICE);
        ERC20Mock wbtcMock = new ERC20Mock("WBTC", "WBTC", msg.sender, 1000e8);
        vm.stopBroadcast();

        return NetworkConfig({
            wethUsdPriceFeed: address(ethUsdPriceFeed),
            wbtcUsdPriceFeed: address(btcUsdPriceFeed),
            weth: address(wethMock),
            wbtc: address(wbtcMock),
            deployerKey: DEFAULT_ANVIL_KEY
        });
    }
}
