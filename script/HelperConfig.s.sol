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
