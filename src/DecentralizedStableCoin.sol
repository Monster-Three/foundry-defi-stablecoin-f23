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

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title DecentralizedStableCoin
 * @author Adam
 * Collareral: Exogenous (ETH &BTC)
 * Minting: Algorithmic
 * Relative Stability: Pegged to USD
 *
 * This is the contract meant to be governed by DSCEngine. This contract is just the ERC20
 * implementation of our stablecoin system.
 *
 */

//抽象合约的意思？
contract DecentralizedStableCoin is ERC20Burnable, Ownable {
    error DecentralizedStableCoin__MustBeMoreThanZero();
    error DecentralizedStableCoin__BurnAmountExceedsBalance();
    error DecentralizedStableCoin__NotZeroAddress();

    constructor() ERC20("DecentralizedStableCoin", "DSC") Ownable(msg.sender) {}

    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if (_amount <= 0) {
            revert DecentralizedStableCoin__MustBeMoreThanZero();
        }
        if (balance < _amount) {
            revert DecentralizedStableCoin__BurnAmountExceedsBalance();
        }
        super.burn(_amount); /*super关键字表示使用父合约(ERC20Burnable)中的burn关键字*/
    }

    function mint(address _to, uint256 _amount) external onlyOwner returns (bool) {
        //address(0)在这里的作用？
        /* 地址为0x00000...的意思*/
        if (_to == address(0)) {
            revert DecentralizedStableCoin__NotZeroAddress();
        }
        if (_amount <= 0) {
            revert DecentralizedStableCoin__MustBeMoreThanZero();
        }
        _mint(_to, _amount); /*由于我们这里没有override函数。所以这里没有super关键字*/
        return true;
    }

    //DecentralizedStableCoin 如何与 DSCEngine 产生连接？
    /* DecentralizedStableCoin (DSC) 合约与 DSCEngine 合约的连接是通过 DSCEngine 的构造函数参数 和 所有权转移 来实现的。
    DSCEngine 构造函数中的参数： 
    在 DSCEngine 合约的定义中，它的构造函数通常会接受 DecentralizedStableCoin 合约的地址作为参数。
    所有权转移 (transferOwnership)：
    你在 DecentralizedStableCoin 合约中定义了 mint 和 burn 函数，并且这两个函数都带有 onlyOwner 修改器。这意味着只有 
    DecentralizedStableCoin 的 owner 才能调用这些函数。为了让 DSCEngine 能够管理 DecentralizedStableCoin 的铸造和销毁
    （这是稳定币系统的核心逻辑），DecentralizedStableCoin 合约的所有权必须转移给 DSCEngine 合约。*/

    //那我在哪里可以设置DecentralizedStableCoin的发行总量呢？
    /* 你提出的问题非常重要，因为它直接关系到 DecentralizedStableCoin (DSC) 的代币经济模型。
    在你的 DecentralizedStableCoin 合约代码中，没有一个直接设置“发行总量”的地方。 
    DecentralizedStableCoin 合约本身并没有一个“硬编码”的发行总量。它的总量是动态的，完全由DSCEngine 合约的逻辑来控制。
    DSCEngine 扮演了整个稳定币系统的“大脑”，根据用户存入的抵押品价值和健康因子等参数，算法性地决定何时铸造多少 DSC，
    以及何时销毁多少 DSC。*/

    //在我的DecentralizedStableCoin.sol中，如何确定谁是它的onlyowner呢?
    /* 在构造函数中的Ownable(msg.sender)就已经确定了 */

    //为什么 DecentralizedStableCoin 中只需要 mint 和 burn（以及 ERC-20 基本功能）?
    /* 
    1.ERC-20 标准函数已继承：
    ERC20 合约（ERC20Burnable 继承自它）已经提供了所有标准的 ERC-20 函数：
    transfer(address to, uint256 amount)：用于将代币从一个地址发送到另一个地址。
    transferFrom(address from, address to, uint256 amount)：允许第三方（如交易所或其他合约）在用户授权后代表用户转移代币。
    approve(address spender, uint256 amount)：授予第三方花费代币的权限。
    balanceOf(address account)：检查账户的代币余额。
    totalSupply()：获取代币的总供应量。
    allowance(address owner, address spender)：检查某个消费者被允许转移多少代币。 
    这些继承的函数处理了所有常见的代币交互（发送、检查余额、授权），所以你不需要重新编写它们。
    2.burn 函数：
    你明确地重写了 ERC20Burnable 中的 burn 函数。
    目的： 这个函数对于减少 DSC 代币的供应量至关重要。当用户在 DSCEngine 中偿还债务时，
    DSCEngine 很可能会调用 DSC 合约上的 burn 函数来销毁这些被归还的 DSC，从而减少稳定币的总供应量。
    onlyOwner 修饰符： burn 函数上的 onlyOwner 修饰符意味着只有 DSC 合约的所有者才能调用它。
    根据你的注释，DSCEngine 旨在管理 DSC。因此，DSCEngine 合约将被设置为 DSC 合约的所有者，从而拥有销毁代币的独家权限。
    3.mint 函数：
    你明确地定义了一个 mint 函数。
    目的： 这个函数对于增加 DSC 代币的供应量至关重要。当用户在 DSCEngine 中存入抵押品时，
    DSCEngine 将调用 DSC 合约上的 mint 函数来创建新的 DSC 代币并将其发送给用户。
    onlyOwner 修饰符： 与 burn 类似，mint 也仅限于所有者 (DSCEngine) 调用。这确保只有你的 DSCEngine 协议可以创建新的 DSC 代币，
    从而根据抵押规则控制稳定币的供应。
    4.职责分离：
    这种设计遵循软件工程中的“职责分离”原则。
    DecentralizedStableCoin.sol (DSC 合约)： 
    仅处理代币的属性（名称、符号、总供应量、余额）以及增发/销毁其供应量的基本操作（mint/burn）。它是一个“只听指令”的代币合约，
    只服从其所有者。
    DSCEngine.sol (引擎合约)： 包含你稳定币系统的所有复杂业务逻辑：
    管理抵押品（存入、取出）。
    计算健康因子。
    处理清算。
    根据抵押率和风险参数决定何时以及铸造或销毁多少 DSC。
    与价格预言机交互。
    通过保持 DSC 合约的最小化，你可以使其：
    更易于审计： 代码量少意味着更少的 Bug 可能性。
    更专注： 其目的明确——作为一个稳定币。
    更安全： 攻击面更小。
    DSCEngine 是你稳定币系统所有“智能”的所在地，它根据用户操作和市场条件，在需要时调用 DSC 合约的 mint 和 burn 函数来管理稳定币的供应。*/

    //在重写来自于继承合约里面的函数时，需要注意些什么？
    /* 
    1. 使用 override 关键字
    这是最基本也是最重要的。当你在子合约中重新实现一个父合约（或接口）中已有的函数时，必须明确使用 override 关键字。
    语法： function myFunction() public override returns (bool)
    作用： 显式地告诉编译器你打算重写这个函数。这有助于编译器检查，如果父合约中没有这个函数或者函数签名不匹配，编译器就会报错，
    避免你无意中创建了一个新的、而不是重写的函数。
    多重继承： 如果一个函数在多个父合约中都存在，并且你在子合约中重写了它，你需要列出所有被重写的父合约名称。
    例如：function myFunction() public override(ParentA, ParentB) returns (bool)。 
    2. 保持函数签名一致
    被重写的函数必须与父合约中的函数具有完全相同的签名：
    函数名： 必须一致。
    参数类型和顺序： 必须一致。
    返回类型和顺序： 必须一致。
    如果签名不一致，你实际上是在创建一个新的函数，而不是重写，编译器通常会报错
    （除非你没有使用 override 关键字，那它就把它当成一个新函数了）。
    3. 可见性修饰符
    重写函数的可见性修饰符（public, external, internal, private）必须与父合约中的函数兼容或更严格，但通常情况下，
    为了保持行为一致性，建议保持相同。
    public 可以重写 public 或 external。
    external 可以重写 public 或 external。
    internal 可以重写 internal。
    private 函数不能被重写（它们不被继承）。
    通常，如果你重写的是 public 或 external 函数，最好也保持其为 public 或 external。
    4. 状态可变性修饰符
    重写函数的状态可变性修饰符（view, pure, payable, nonpayable）必须与父合约中的函数兼容或更严格。
    pure 函数可以重写 pure, view, nonpayable。
    view 函数可以重写 view, nonpayable。
    nonpayable 函数可以重写 nonpayable。
    payable 函数只能重写 payable。
    例如，你可以用 view 函数重写一个 nonpayable 函数（因为它更严格，不修改状态），
    但不能用 nonpayable 函数重写一个 view 函数（因为它允许修改状态，不如 view 严格）。
    5. 调用父合约函数 (super)
    在重写函数内部，你通常需要（或至少有机会）调用父合约的实现。这可以通过 super 关键字来完成。
    语法： super.functionName(arguments);
    作用： 这允许你扩展父合约的行为，而不是完全替换它。例如，你可能想在执行父合约逻辑之前或之后添加一些额外的检查、事件发射或状态更新。
    多重继承（线性化）： 如果你有复杂的继承链（如钻石继承问题），super 关键字会遵循 C3 线性化规则来确定调用哪个父合约的实现。
    这意味着你需要理解 Solidity 的继承解析顺序。
    6. virtual 关键字（Solidity 0.6.0+）
    在 Solidity 0.6.0 及更高版本中，如果你希望一个函数可以在子合约中被重写，你必须在父合约中使用 virtual 关键字来标记它。
    语法： function myFunction() public virtual returns (bool)
    作用： 没有 virtual 标记的函数是“最终的” (final)，不能被重写。这提供了一种明确的控制，表明哪些函数是可扩展的，哪些不是。
    7. 理解访问控制和逻辑流
    当你重写一个函数时，你是在改变或扩展它的行为。务必仔细思考：
    访问控制： 你是否需要为重写函数添加或修改访问控制（如 onlyOwner）？这会影响谁可以调用这个函数。
    内部逻辑： 你添加或修改的逻辑是否正确，并且不会引入新的漏洞或非预期行为？
    事件发射： 如果父合约的函数会触发事件，你重写后是否还需要触发相同的事件，或者触发新的事件？*/
}
