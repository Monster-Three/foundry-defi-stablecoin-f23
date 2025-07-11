//SPDX-License-Identifier:MIT

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

pragma solidity ^0.8.18;

import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol"; /*在depositCollateral函数中nonReentrant关键字*/
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol"; //IERC20与ERC20的区别？
/* IERC20 是一个 接口（Interface）。它定义了 ERC-20 代币标准所必须实现的所有函数签名（函数名称、参数类型、返回类型）。
ERC20（通常指的是 OpenZeppelin 库中的 ERC20.sol）是一个 具体实现（Implementation）。它是一个完整的、可部署的智能合约，
包含了所有 ERC-20 标准的函数逻辑以及状态变量（如 _balances mapping）。 */
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {Oracle} from "./LIibraries/Oraclelib.sol";

/**
 * @title DSCEngine
 * @author Adam
 * @notice This contract is the core of the DSC system, It handes all the logic for minting
 * and redeeming(赎回) DSC, as well as depositing & withdrawing collateral.
 * @notice This contract is VERY loosely based on the MakerDAO DSS(DAI) system
 *
 * The system is designed to be as minimal as possible, and have the tokens maintain a 1
 * token == $1 peg.
 * This stablecoin has the properties:
 * - Exogenous Collateral
 * - Dollar Pegged
 * - Algoritmically Stable
 *
 * It is similar to DAI if DAI had no governance, no fees, and was only backed by WETH and
 * WBTC.
 *
 * Our DSC system should always be "overcollateralized". At no point, should the value of
 * all collateral <= the $ backed value of all the DSC.
 */
contract DSCEngine is ReentrancyGuard {
    //////////////////
    // Errors       //
    //////////////////
    error DSCEngine__AmountNeedsMoreThanZero();
    error DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();
    error DSCEngine__NotAllowedTokens();
    error DSCEngine__TransferFailed();
    error DSCEngine__BreakHealthFactor(uint256 healthFactor);
    error DSCEngine__MintFailed();
    error DSCEngine__HealthFactorIsOk();
    error DSCEngine__HealthFactorNotImproved();

    ////////////////
    // Types      //
    ////////////////
    using Oracle for AggregatorV3Interface;

    ///////////////////////////
    // State Variables       //
    ///////////////////////////
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 5;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant LIQUIDATION_BONUS = 10;

    //不是很懂这个的逻辑
    /* 当 DSCEngine 合约需要知道某个抵押品代币（例如 WETH）的当前美元价值时，它会：
        1、通过 s_priceFeeds[WETH_ADDRESS] 获取到 WETH 的价格预言机地址。
        2、然后，它会调用这个价格预言机合约上的一个函数（例如 latestRoundData()）来获取 WETH 的实时价格。 */
    mapping(address token => address priceFeed) private s_priceFeeds; // tokenToPriceFeed
    mapping(address user => mapping(address token => uint256 amount)) public s_collateralDeposited;
    mapping(address user => uint256 amountDscMinted) private s_DSCMinted;
    address[] private s_collateralTokens;

    DecentralizedStableCoin private immutable i_dsc;

    //////////////////
    // Events       //
    //////////////////
    event CollateralDeposited(address indexed user, address indexed token, uint256 amount);
    //indexed的意义？
    event CollateralRedeemed(
        address indexed redeemFrom, address indexed redeemTo, address indexed token, uint256 amount
    );

    //////////////////
    // Modifiers    //
    //////////////////
    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert DSCEngine__AmountNeedsMoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address token) {
        if (s_priceFeeds[token] == address(0)) {
            revert DSCEngine__NotAllowedTokens();
        }
        _;
    }

    //////////////////
    // Functions    //
    //////////////////
    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address dscAddress) {
        //tokenAddresses.length != priceFeedAddresses.length的合理性来源？
        /* 我认为这应该是因为一种代币就要对应一个pricefeed地址 */
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();
        }
        //For example ETH / USD, BTC / USD, MKD / USD, etc
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }
        i_dsc = DecentralizedStableCoin(dscAddress);
        /* DecentralizedStableCoin(...) 告诉 Solidity 编译器：在 dscAddress 这个地址上，
        部署了一个 DecentralizedStableCoin 类型的合约,通过这种方式，
        Solidity 编译器就知道如何在该地址上调用 DecentralizedStableCoin 合约所定义的公共（public）和外部（external）函数。*/
        /* 这行代码的目的是在 DSCEngine 合约被部署时，
        将其内部的一个状态变量 i_dsc 初始化为一个指向已部署的 DecentralizedStableCoin (DSC) 代币合约的引用。
        这样，DSCEngine 合约就能够直接与 DSC 代币合约进行通信，例如，当用户存入抵押品后，
        DSCEngine 可以调用 i_dsc.mint() 来铸造 DSC 代币给用户。 */
    }

    ///////////////////////////
    // External Functions    //
    ///////////////////////////

    /**
     *
     * @param tokenCollateralAddress The address of the token to deposite as collateral
     * @param amountCollateral The amount of the collateral to deposite
     * @param amountDscToMint The amount of the DSC(decentralized stablecoin) to mint
     * @notice this function will deposite your collateral and mint DSC in one transaction
     */
    function depositCollateralAndMintDsc(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountDscToMint
    ) external {
        depositCollateral(tokenCollateralAddress, amountCollateral);
        mintDsc(amountDscToMint);
    }

    /**
     * @notice follws CEI // ??? CEI是什么？Checks-Effects-Interactions (检查-影响-交互)
     * @param tokenCollateralAddress The address of the token to deposit as collateral
     * @param amountCollateral The amount of the collateral to deposit
     */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        //Checks
        moreThanZero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant //这个与重入攻击有关,目前还没有去测试这个nonReentrant。2025.6.23
    {
        //Effects
        //s_collateralDeposited[msg.sender][tokenCollateralAddress]这个就体现了存入代币的数量
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        //为什么这里没有push函数？
        /* mapping 不是一个数组，它本质上是一个 哈希表 (hash table)。你不能“添加”元素到 mapping
        的“末尾”，因为 mapping 没有固定的顺序，也没有“末尾”的概念。当你使用 mapping[key] = value;
        这样的语法时，你实际上是在：1、设置 (set) 一个特定键的值。2、如果这个键之前没有值，它会被初
        始化为默认值（对于 uint256 是 0），然后被赋予新值。3、如果这个键已经有值，它的值会被更新。
        s_collateralDeposited 是一个嵌套的 mapping (映射)，而不是一个数组。它不存储一个元素的列表，
        而是存储 键-值对。 */
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);
        //Interactions
        //这段表示既转了账又返回一个bool值,from: msg.sender, to: address(this)
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    /**
     * This function burns DSC and redeems underlying collateral in one transaction
     * @param tokenCollateralAddress The address of collateral to redeem
     * @param amountCollateral The amount of collateral to redeem
     * @param amountDscToBurn The amount of collateral to burn
     */
    function redeemCollateralForDsc(address tokenCollateralAddress, uint256 amountCollateral, uint256 amountDscToBurn)
        external
        moreThanZero(amountCollateral)
    {
        burnDsc(amountDscToBurn); //先烧毁DSC，再赎回Collateral
        redeemCollateral(tokenCollateralAddress, amountCollateral);
        //redeemCollateral already checks health factor
    }

    //In order to redeem collateral:
    //1. Health factor must be over 1 AFTER collateral pulled
    //在计算机科学中有一个概念:DRY Don't repeat yourself
    //2. Burn your DSC

    //nonReentrant 是什么？
    /* nonReentrant 修改器是一个至关重要的安全特性，通常从 OpenZeppelin 的 ReentrancyGuard 合约导入。它的主要目的是防止重入攻击。 */
    // 什么是重入攻击？
    /* 当一个智能合约向外部（例如，另一个合约或一个外部账户）发起调用，而在发起调用方合约的初始执行完成之前，
    外部调用又“流回”到发起调用方合约时，就会发生重入攻击。 */
    function redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        nonReentrant
    {
        _redeemCollateral(msg.sender, msg.sender, tokenCollateralAddress, amountCollateral);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /**
     * @notice Follow the CEI
     * @param amountDscMint The amount of the decentralized stablecoin to mint
     * @notice They must have more collateral value than the minimum threshold(门槛)
     */
    function mintDsc(uint256 amountDscMint) public moreThanZero(amountDscMint) nonReentrant {
        s_DSCMinted[msg.sender] += amountDscMint;
        //if they minted too much ($150 DSC, $100 ETH)
        _revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_dsc.mint(msg.sender, amountDscMint);
        if (!minted) {
            revert DSCEngine__MintFailed();
        }
    }

    function burnDsc(uint256 amount) public moreThanZero(amount) {
        _burnDsc(amount, msg.sender, msg.sender);
        //Do we need to check if this breaks health factor?
        _revertIfHealthFactorIsBroken(msg.sender); /* I don't think this would ever hit.. 我认为这条命令不会触发,因为与collateral没关系 */
    }

    // If we do start nearing undercollateralization, we need someone to liquidate positions

    // $100 ETH backing $50 DSC
    // $20 ETH back $50 DSC <- DSC isn't worth $1!!!

    /*If someone is almost undercollateraluzed, we will pay you to liquidate them!(这里的理解应该是
    我买下以$50的价格买下DSC，然后我会得到其剩余的ETH)*/

    /**
     *
     * @param collateral The ERC20 collateral address to liquidate from the user
     * @param user The user who has broken the health factor, Thier _healthfactor should
     * below MIN_HEALTH_FACTOR
     * @param debtToCover The amount of DSC you want to burn to improve the users health factor
     * @notice You can partially liquidate a user
     * @notice You will get a liquidate bouns for taking the users funds
     * @notice This function working assumes the protocol will be roughly 200% overcollateralized
     * in order for this to work
     * @notice A known bug(一个已知的bug) would be if the protocol were 100% or less collateralized, then we wouldn't
     * be able to incentive the liquidators
     * For example, if the price of the collateral plummeted before anyone could be liquidated.
     *
     * Follows CEI:Checks, Effects, Interfaces
     *
     */
    function liquidate(address collateral, address user, uint256 debtToCover)
        external
        moreThanZero(debtToCover)
        nonReentrant
    {
        // First, we need to check the health factor of the user
        uint256 startinguserHealthFactor = _healthFactor(user);
        if (startinguserHealthFactor >= MIN_HEALTH_FACTOR) {
            revert DSCEngine__HealthFactorIsOk();
        }
        // Then, we want to burn thier DSC "debt",and take thier collateral
        // Bad User: $140 ETH, $100 DSC
        // debtToCover = $100
        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsd(collateral, debtToCover);
        // And give them a 10% bouns
        // So we are giving the liquidator %110 of WETH for 100 DSC
        // We should implement a feature to liquidate in the event the protocol is insolvent
        // And sweep extra amounts into a treasury ,这个Patrick说不会在这里实现
        // (0.5e18 eth * 10) / 100 = 0.05e18 eth
        uint256 bonusCollateral = (tokenAmountFromDebtCovered * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;
        uint256 totalCollateralToRedeem = bonusCollateral + tokenAmountFromDebtCovered;
        _redeemCollateral(user, msg.sender, collateral, totalCollateralToRedeem); /*patirck视频里面原来为debtToCover，
        我在这里把它改成了totalCollateralToRedeem*/
        _burnDsc(debtToCover, user, msg.sender);

        //我觉得这里应该用msg.sender吧
        uint256 endingUserHealthFactor = _healthFactor(user);
        if (endingUserHealthFactor <= startinguserHealthFactor) {
            revert DSCEngine__HealthFactorNotImproved(); //这里我没有测试到，我想不出有什么可以revert这个错误
        }
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    //////////////////////////////////////////
    // Internal View & Private Functions    //
    //////////////////////////////////////////

    /**
     * @dev Low-level internal function, do not call unless the function calling it is
     * checking for health factor being broken
     */
    //为什么弄成两个address，直接一个address不行吗？
    function _burnDsc(uint256 amountDscToBurn, address onBehalfOf, address dscFrom) private {
        s_DSCMinted[onBehalfOf] -= amountDscToBurn;
        bool success = i_dsc.transferFrom(dscFrom, address(this), amountDscToBurn);
        // This conditional is hypothtically unreachable
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
        i_dsc.burn(amountDscToBurn);
    }

    function _redeemCollateral(address from, address to, address tokenCollateralAddress, uint256 tokenCollateralAmount)
        private
    {
        // 如果用户账户上有100个eth，但是他想赎回1000个，那么在新版本的solidity中，这条代码将会revert
        s_collateralDeposited[from][tokenCollateralAddress] -= tokenCollateralAmount;
        emit CollateralRedeemed(from, to, tokenCollateralAddress, tokenCollateralAmount);
        //本来这里应该检查health factor的，但是这样就有点违反CEI原则，并且gas inefficient，所以这里就继续转账的指令，反正转账失败会revert
        bool success = IERC20(tokenCollateralAddress).transfer(to, tokenCollateralAmount); /* 这里是transfer，而不是transferfrom */
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    function _getAccountInformation(address user)
        private
        view
        returns (uint256 totalDSCMinted, uint256 collateralValueInUsd)
    {
        totalDSCMinted = s_DSCMinted[user];
        collateralValueInUsd = getAccountCollateralValue(user);
    }

    /**
     * Returns how close to liquidation a user is
     * If a user goes below 1, then they can get liquidated(清算)
     */
    //we can tell developers it's a internal function by adding a '_' before the function name
    function _healthFactor(address user) internal view returns (uint256) {
        //total DSC minted
        //total collateral Value
        //We have to make sure total collateral Value > total DSC minted
        (uint256 totalDSCMinted, uint256 collateralValueInUsd) = _getAccountInformation(user);
        if (totalDSCMinted == 0) {
            return type(uint256).max;
        }
        uint256 collatralAjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collatralAjustedForThreshold * PRECISION) / totalDSCMinted;
    }

    function _calculateHealthFactor(uint256 totalDscMinted, uint256 collateralValueInUsd)
        internal
        pure
        returns (uint256)
    {
        //type(uint256)是什么意思呢？
        /* 在 Solidity 中，type(T).max 是一个内置成员（built-in member），它返回给定基本类型 T 的最大可能值。
        uint256：这是 Solidity 中的无符号整数类型，可以存储从 0 到 2 的(256 - 1)次方的值。
        type(uint256).max：因此，它特指 uint256 变量可以容纳的最大数字。这个值是 2 的(256 - 1)次方，
        这是一个非常庞大的数字： 115792089237316195423570985008687907853269984665640564039457584007913129639935。
        由于 Solidity 中没有 uint256 的“无限”概念（它是一个固定大小的整数类型），
        返回 type(uint256).max 是一种实用方法来表示这种**“无上限”或“完美”的健康状态**。
        任何实际可计算的健康因子都将是一个远小于 type(uint256).max 的有限数字，因此这个最大值有效地表明了“没有风险”的健康状况。 */
        if (totalDscMinted == 0) return type(uint256).max;
        uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForThreshold * PRECISION) / totalDscMinted;
    }

    function _revertIfHealthFactorIsBroken(address user) internal view {
        // 1.check health factor (do they have enough collateral?)
        // health factor is coming form the aave website section:risk parameters
        // 2.revert if they don't
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine__BreakHealthFactor(userHealthFactor);
        }
    }

    //////////////////////////////////////////
    // Public View & Pure Functions    ///////
    //////////////////////////////////////////

    function getTokenAmountFromUsd(address token, uint256 usdAmountInWei) public view returns (uint256) {
        // price of ETH (token)
        // $/ETH 用美元换算ETH，也就是我们这里的美元可以换成多少ETH
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);

        // priceFeed怎么能调用staleCheckLatesRoundData()函数呢？priceFeed是AggregatorV3Interface类型的变量，它与library Oracle在表面上没有关系
        /* 这里的魔术在于 Solidity 的一个特殊语法：using A for B;。
        using A for B;：给类型注入库函数
        在 Solidity 中，当你看到这样的语句：
        using Oracle for AggregatorV3Interface;
        这意味着你将 Oracle 库中的所有（或部分）函数绑定到了 AggregatorV3Interface 这个类型上。
        绑定之后，如果 Oracle 库中有一个函数，它的第一个参数类型恰好与 for 后面指定的类型（这里是 AggregatorV3Interface）匹配，
        那么你就可以以成员函数调用的方式来使用它。
        工作原理分析：
        1.Oracle 库中的函数签名：
        你的 Oracle 库中有这个staleCheckLatesRoundData函数:它接受一个 AggregatorV3Interface 类型的参数 priceFeed。
        2.using Oracle for AggregatorV3Interface; 的作用：
        当你在 DSCEngine 合约的某个地方（通常在文件顶部，合约定义之前或内部）声明了 using Oracle for AggregatorV3Interface;，
        Solidity 编译器就会知道：
        任何 AggregatorV3Interface 类型的变量，都可以像拥有 Oracle 库中的函数并可以调用其中的函数。
        编译器会悄悄地将这种成员函数调用转换为对库函数的常规调用，并把AggregatorV3Interface 实例作为第一个参数传入。
        3.你的调用 priceFeed.staleCheckLatesRoundData();：
        当你写 priceFeed.staleCheckLatesRoundData(); 时：
        priceFeed 是一个 AggregatorV3Interface 类型的变量。
        编译器发现你已经通过 using Oracle for AggregatorV3Interface; 将 staleCheckLatesRoundData 绑定到了 AggregatorV3Interface 类型上。
        编译器会自动将这个调用重写为：Oracle.staleCheckLatesRoundData(priceFeed);
        所以，实际被调用的函数是 Oracle 库中的 staleCheckLatesRoundData，并且 priceFeed 变量被作为第一个参数传递给了这个库函数。 */

        //为什么不直接使用函数来检测secondsSince是否超时，而是用一个库函数呢？这样做有什么好处呢？用函数不应该更简洁一点吗？
        /* 这样做主要有以下几个核心优势：
        1.代码复用与模块化 (Code Reusability & Modularity) 
        集中管理： 如果你的协议中有多个地方需要检查预言机数据的“新鲜度”
        （例如，getTokenAmountFromUsd 检查，可能还有清算函数、借贷上限检查等），将这个逻辑放在一个独立的 Oracle 库中，
        就意味着你只编写和测试一次这段核心逻辑。
        统一标准： 任何需要这个检查的地方都可以直接调用 Oracle.staleCheckLatesRoundData()。
        这确保了所有地方都遵循相同的超时逻辑和错误处理，避免了代码复制粘贴可能引入的不一致性或错误。
        高内聚，低耦合： Oracle 库只关心“预言机数据是否新鲜”这个单一职责，与 DSCEngine 的核心业务逻辑（如铸币、抵押、清算）解耦。
        2.可维护性与可升级性 (Maintainability & Upgradeability)
        易于修改： 假如未来你想调整超时时间 TIMEOUT，或者改进检查逻辑，
        你只需要修改和重新部署 Oracle 库（假设 DSCEngine 通过代理模式等实现了可升级性，或者你需要重新部署整个 DSCEngine）。
        如果逻辑分散在多个函数中，修改起来会非常麻烦且容易出错。
        减少部署成本 (对于大型项目)：对于非常大的项目，将通用逻辑抽离到库中并使用 DELEGATECALL，可以帮助主合约满足 24KB 的代码大小限制。
        虽然你的 DSCEngine 可能还没达到这个限制，但这是一个重要的设计考虑。
        3.安全审计与信任 (Security Audits & Trust)
        焦点清晰： 独立出来的库函数更容易进行专业的安全审计。审计师可以专注于这个库的功能，确保其逻辑的健壮性和安全性，
        而不必在整个庞大的合约中寻找这段小逻辑。
        建立信任： 经过严格审计和验证的通用库（如 SafeMath、OpenZeppelin 的库）在社区中建立了信任。
        通过使用这些成熟的库，你的合约也间接获得了更高的信任度。*/
        (, int256 price,,,) = priceFeed.staleCheckLatesRoundData();
        /* 我觉得用这种方式(乘以精确度)就很好的解决了solidity没有小数的问题 */
        return ((usdAmountInWei * PRECISION) / (uint256(price) * ADDITIONAL_FEED_PRECISION));
    }

    function getAccountCollateralValue(address user) public view returns (uint256 tokenCollateralValueInUsd) {
        /* loop through each collateral token, get the amount they have deposite, 
        and map it to the price, to get the USD value */
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[user][token];
            tokenCollateralValueInUsd += getUsdValue(token, amount);
        }
        return tokenCollateralValueInUsd;
    }

    function getUsdValue(address token, uint256 amount) public view returns (uint256) {
        //我还发现在我的getUsdValue函数中，只有AggregatorV3Interface类型的priceFeed能提供查价格的功能，但是在我测试的时候，我用的是MockV3Aggregator类型的ethUsdPriceFeed，这是怎么实现的呢？
        /* 这是一个非常好的问题，它触及到了 Solidity 中**接口（Interface）和多态性（Polymorphism）的核心概念，
        以及在测试中常用的模拟（Mocking）**技巧。
        问题的核心：接口与多态性
        你观察到 getUsdValue 函数中使用了 AggregatorV3Interface 类型的 priceFeed 来查询价格，但在你的测试中，
        你实际传入的是 MockV3Aggregator 类型的 ethUsdPriceFeed。这之所以能工作，是因为：
        1.MockV3Aggregator 实现了 AggregatorV3Interface。
        MockV3Aggregator 是 Chainlink 官方提供的一个模拟（Mock）合约，它被设计用来在测试环境中模拟真实的 AggregatorV3Interface 行为。
        它的关键特性就是它实现了 AggregatorV3Interface 接口中定义的所有函数（例如 latestRoundData()）。
        2.Solidity 的多态性。
        在 Solidity 中，如果一个合约 A 实现了接口 I，那么你就可以将合约 A 的实例当作接口 I 的类型来使用。
        当你在 getUsdValue 函数中执行 AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]); 时：
        s_priceFeeds[token] 会返回你为特定 token 配置的地址。
        然后，你将这个地址强制类型转换为 AggregatorV3Interface。
        只要这个地址指向的合约（无论是真实的 AggregatorV3 还是 MockV3Aggregator）确实实现了 AggregatorV3Interface 中定义的所有函数，
        这种类型转换就是有效的，并且你就可以通过 priceFeed 变量来调用这些函数。
        简单类比
        你可以将 AggregatorV3Interface 看作是一个“智能手机接口标准”，它定义了所有智能手机都必须有的功能（比如“拨打电话”、“发送短信”）。
        真实的 AggregatorV3 合约就像是“华为手机”，它完全符合这个智能手机接口标准。
        MockV3Aggregator 合约就像是“小米手机”，它也完全符合这个智能手机接口标准，尽管它的内部实现可能更简单，是为了测试目的而制造的。
        在你的 getUsdValue 函数中，你声明了一个变量 priceFeed，它的类型是“智能手机接口标准”。
        然后你把“华为手机”或“小米手机”的地址赋值给它。因为这两种手机都符合“智能手机接口标准”，
        所以你可以通过这个 priceFeed 变量来调用“拨打电话”或“发送短信”功能，而不用关心它具体是华为还是小米。 */
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        //那MockV3Aggregator 合约怎么满足Oraclelib合约里面的staleCheckLatesRoundData测试呢，它模拟的eth价格一直没变都嘛
        /* MockV3Aggregator 通常默认情况下会返回一个固定的价格和 updatedAt 时间戳（通常是部署时的 block.timestamp）。
        这意味着，如果你的 DSCEngine 合约直接调用 priceFeed.latestRoundData() 并检查 updatedAt，那么在测试过程中，
        这个 updatedAt 值是不会变化的。 */

        /* 如果想测试的话，得用Foundry 提供了一系列 vm (Virtual Machine) 函数来模拟 EVM 的行为，包括时间前进：
        vm.warp(uint256 newTimestamp): 将当前 block.timestamp 设置为 newTimestamp。
        vm.roll(uint256 newBlockNumber): 将当前 block.number 设置为 newBlockNumber。*/
        (, int256 price,,,) = priceFeed.staleCheckLatesRoundData();
        //因为price的单位为1e8,为了方便计算，乘以ADDITIONAL_FEED_PRECISION(1e10)
        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
    }

    //为什么不直接将_getAccountInformation改为public view类型的函数，而是在这里重新引用一下呢？
    /* _getAccountInformation 是一个私有辅助函数，负责核心逻辑。
        getAccountInformation 是一个公共接口函数，负责暴露功能。
        这种模式是智能合约（以及许多其他编程范式）中的一种良好设计实践，它提高了代码的可读性、
        安全性、可维护性和灵活性。它清晰地划分了合约内部逻辑和外部可访问功能之间的界限。 */
    function getAccountInformation(address user)
        public
        view
        returns (uint256 totalDSCMinted, uint256 collateralValueInUsd)
    {
        //这种return方式完全合法，是来调用一个返回多个值的函数的一种标准且推荐的方式
        (totalDSCMinted, collateralValueInUsd) = _getAccountInformation(user);
    }

    function getHealthFactor(address user) public view returns (uint256 healthFactor) {
        (healthFactor) = _healthFactor(user);
    }

    function getCollateralBalanceOfUser(address user, address token) external view returns (uint256) {
        return s_collateralDeposited[user][token];
    }

    function calculateHealthFactor(uint256 totalDscMinted, uint256 collateralValueInUsd)
        public
        pure
        returns (uint256)
    {
        return _calculateHealthFactor(totalDscMinted, collateralValueInUsd);
    }

    function getLiquidationBouns() public pure returns (uint256) {
        return LIQUIDATION_BONUS;
    }

    function getLiquidationPrecision() public pure returns (uint256) {
        return LIQUIDATION_PRECISION;
    }

    function getadditonalfeedprecison() public pure returns (uint256) {
        return ADDITIONAL_FEED_PRECISION;
    }

    function getCollateralTokenPriceFeed(address token) external view returns (address) {
        return s_priceFeeds[token];
    }

    function getPrecision() public pure returns (uint256) {
        return PRECISION;
    }

    function getCollateralTokens() external view returns (address[] memory) {
        return s_collateralTokens;
    }
}
