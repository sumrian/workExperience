

## 前言

对于我们前端开发来说，无时无刻不在接触着[闭包](https://zhida.zhihu.com/search?content_id=239568476&content_type=Article&match_order=1&q=%E9%97%AD%E5%8C%85&zhida_source=entity)。比如在 `React Hooks` 中利用了闭包来捕获组件的状态，并在组件的生命周期中保持状态的一致性。在 `Vue` 中利用闭包来定义计算属性和监听器，以及在组件之间共享数据。在 `Angular` 中利用闭包可以用于创建服务和依赖注入。

所以理解闭包产生的原因和原理对我们的日常开发非常重要。

## 热个身

其实 JavaScript 本身的特性决定了一定要实现闭包：

1. JavaScript 允许在函数内部定义新的函数。
2. 因为 `词法作用域`，可以在内部函数中访问父函数中定义的变量。
3. 函数作为一等公民，函数可以作为返回值。

利用上面三点列举一个贯穿全文的 JavaScript 经典闭包代码：

```
function multi() {
    var a = 10;
    return function inner() {
        return a * 10;
    }
}
const p = multi();
```

此段代码声明了 multi 函数，在函数内部定义了变量 a，并且返回了 inner 函数，inner 函数中访问 multi 函数中声明的 a，最后执行了 multi 函数并且将返回值返回给 p。这个时候闭包就创建完成啦，闭包让开发者可以从内部函数访问外部函数的作用域，p 函数始终能访问到 multi 函数中的 a。

但是大家都知道，multi 函数执行完之后，理应内部声明的变量都会被销毁，但是因为闭包的原因，这个 a 变量突破了这种限制。

为了实现闭包，我们来看看 V8 都是怎么做的吧。

## V8 是如何执行一段 JavaScript 代码的

我们都知道，我们写的 JavaScript 代码，是需要经过编译的步骤，让 CPU 获取到一串二进制的指令去执行的。完成这一步的通常有两种方法：

1. 解释执行，将源代码通过解析器生成中间代码，然后用解释器解释执行，它的优势在于快速启动执行，但执行速度相对较慢。
2. 编译执行，也是先生成中间代码，然后通过编译器将中间代码直接转换成二进制代码，执行的时候直接执行二进制文件即可，它的优势在于执行时直接操作二进制文件，执行速度更快，并且编译过程只进行了一次，所以在多次执行相同代码时，编译执行的性能更高，但是相对的启动速度就会比较慢。

V8 采取的策略是混合编译执行和解释执行，也就是我们经常听到的 JIT，是一种对上述两种策略的一种权衡。流程如下：

![img](https://picx.zhimg.com/v2-886cc39d8c3e2edb08940c4df4233fc5_1440w.jpg)

V8 执行代码

1. 初始化执行环境，比如堆栈空间、事件循环系统等。
2. 解析器解析代码生成 [AST](https://zhida.zhihu.com/search?content_id=239568476&content_type=Article&match_order=1&q=AST&zhida_source=entity) 和作用域。
3. 根据 AST 和作用域生成中间代码，也就是[字节码](https://zhida.zhihu.com/search?content_id=239568476&content_type=Article&match_order=1&q=%E5%AD%97%E8%8A%82%E7%A0%81&zhida_source=entity)。
4. 解释器解释执行中间代码输出结果。
5. 监控解释器执行，发现频繁执行的热点代码会生成二进制代码以提高执行速度。
6. 热点代码改变或者执行频率下降，编译器会执行反优化重新让这段代码生成字节码。

## V8 遇到函数是如何编译的？

上面说到执行 JavaScript 代码需要经过编译到中间代码的步骤，但是实际上 V8 并不会把所有代码全部进行解析，是因为如果一次性编译所有 JavaScript 代码，编译时间会很长，需要全部编译完才能执行代码，对用户来说会感到严重的延迟特别是大型项目。并且编译产生的大量中间代码会非常占用内存资源，特别是移动设备，内存的消耗是需要谨慎考虑的。

所以包括 V8，所有主流浏览器都实现了`延迟解析（lazy parsing）`。顾名思义，V8 会推迟对代码的解析，直到代码被实际执行时才进行解析。具体就是在解析器遇到函数声明时，只会解析函数的声明部分，而不会解析函数内部的代码。在执行函数的时候 V8 会对函数进行各种优化，例如内联优化、类型推断等。延迟解析也可以使 V8 有更多的执行上下文和运行时信息，从而更好地进行优化，提高代码的执行效率。

我们来使用 D8 工具具体看个例子：

```
var top = 1;
function multi(a) {
    return a * 10;
}
```

通过 `d8 --print-ast` 命令打印出 AST 信息：

> V8 首先会接收到我们书写的源代码，为了理解这段源代码，它需要结构化这段字符串来生成源代码中的语法结构和关系，便于后续 V8 的理解。比如语言转换器 Babel、语法检查工具 ESLint 等，底层都使用了 AST 去实现。

```
--- AST ---
FUNC at 0
. KIND 0
. LITERAL ID 0
. SUSPEND COUNT 0
. NAME ""
. INFERRED NAME ""
. DECLS
. . VARIABLE (0x7fa6a5810050) (mode = VAR, assigned = true) "top"
. . FUNCTION "multi" = function multi
. BLOCK NOCOMPLETIONS at -1
. . EXPRESSION STATEMENT at 10
. . . INIT at 10
. . . . VAR PROXY unallocated (0x7fa6a5810050) (mode = VAR, assigned = true) "top"
. . . . LITERAL 1
```

简单解释下这段被解析器解析生成的 AST，着重看 `DECLS` 和 `EXPRESSION STATEMENT`。

`DECLS` 代表一组声明，此处声明了一个名为 top 的变量，并且该变量被赋值（assigned = true）。还声明了一个名为 multi 的函数。

`EXPRESSION STATEMENT` 表示一个表达式语句节点，这里就是 `var top = 1;`，下面的内容代表这段表达式的结构化表述，将变量 top 的 proxy（指向了实际 top 的值，可以看到 `0x7fbc75010c50` 地址相同）并且初始化为字面量 1。

所以自始至终解析器并没有解析函数体内部的代码，仅仅只解析了函数的声明部分。

我们也可以通过 `d8 --print-scopes` 打印此时 multi 函数的作用域：

```
Global scope:
global { // (0x7ff32601e030) (0, 53)
  // will be compiled
  // NormalFunction
  // 1 stack slots
  // temporary vars:
  TEMPORARY .result;  // (0x7ff32601e530) local[0]
  // local vars:
  VAR top;  // (0x7ff32601e250) 
  VAR multi;  // (0x7ff32601e4a0) 

  function multi () { // (0x7ff32601e2e0) (27, 53)
    // lazily parsed
    // NormalFunction
    // 2 heap slots
  }
}
```

我们可以看到它没有为 multi 函数生成作用域，而是进行 `lazily parsed`。

那我们执行一下这个 multi 函数，看看 AST 会是什么样子：

```
var top = 1;
function multi(a) {
    return a * 10;
}
multi(3);

[generating bytecode for function: multi]
--- AST ---
FUNC at 27
. KIND 0
. LITERAL ID 1
. SUSPEND COUNT 0
. NAME "multi"
. PARAMS
. . VAR (0x7fe75782f670) (mode = VAR, assigned = false) "a"
. DECLS
. . VARIABLE (0x7fe75782f670) (mode = VAR, assigned = false) "a"
. RETURN at 37
. . MUL at 46
. . . VAR PROXY parameter[0] (0x7fe75782f670) (mode = VAR, assigned = false) "a"
. . . LITERAL 10
```

执行 multi 函数时，从 multi 函数对象中取出函数代码，和顶层代码一样编译为 AST 和字节码，然后再解释执行，这里我们简单看看生成的 AST 吧：

`PARAMS` 代表函数参数部分，表示函数有一个参数 a，且该参数未被赋值（在执行阶段才会指向堆和栈中相应的数据）。`DECLS` 中声明了 a 变量，地址与参数 a 相同。`RETURN at` 代表函数返回语句位于源代码的位置。`MUL at` 代表返回值是一个乘法表达式。下面一行代表乘法表达式的第一个操作数是参数 a。`LITERAL 10` 代表乘法表达式的第二个操作数是字面量 10。

## 延迟解析 & 闭包

当延迟解析遇到了闭包，那么情况就又复杂了，我们来稍微改造一下上面的 multi 函数。

```
function multi() {
    var a = 10;
    return function inner() {
        return a * 10;
    }
}
const p = multi();
```

这是一段闭包代码，我们简单分析下上述代码的执行流程：

- 执行 multi 函数时，multi 函数会将它的内部函数 inner 返回给全局变量 p。
- 然后 multi 函数执行结束，执行上下文被 V8 销毁。

> V8 用执行上下文来维护执行当前代码所需要的变量声明、this 指向等，比如这里的 a 变量。

- 虽然 multi 函数的执行上下文被销毁了，但是被全局 p 引用的 inner 函数引用了 multi 函数作用域中的变量 a。

> 为什么 inner 函数中的 a 引用的是 multi 中的 a，这是因为 JavaScript 是基于词法作用域，是静态的作用域，和函数如何调用如何执行没有关系，是代码编译阶段就决定好的，查找顺序都是照当前函数作用域向上冒泡，最后到全局作用域。所以这里的变量查找规则为 inner 函数作用域 -> multi 函数作用域 -> 全局作用域。

所以这里就会带来两个问题？

1. 当 multi 函数执行完成时，因为闭包的存在，此时 multi 的执行上下文被销毁，但是 a 变量又被引用了，肯定不能被销毁，那么 V8 会采取什么策略。
2. 因为 V8 采用的延迟解析，在 inner 函数未执行的时候，是不会解析 inner 内部的代码的，所以 V8 并不知道是否引用了外部作用域中的变量。

## 预解析器（preparser）

V8 为了解决这两个问题的，引入了 `预解析器（preparser）` 模块来解决，主要是做了两件事：

1. 当解析到顶层函数时，预解析器并不会直接跳过该函数，而是对该函数做一次快速的预解析，是为了判断当前函数是不是存在一些语法上的错误。

![img](https://pica.zhimg.com/v2-fc037064844304bd466d2f70826f204a_1440w.jpg)

报错

> 在过去的版本中，预解析器在解析脚本时会忽略变量声明，例如在同一作用域中两次声明同名的变量应该被视为语法错误，但预解析器会允许这样的代码通过预解析阶段。当时是为了追求性能的提升，预解析器忽略了变量声明的处理。现在修复后的预解析器能够正确处理变量声明和引用，符合ECMAScript规范，并且也没有明显的性能损失。

1. 当执行函数时，只会将当前函数生成 AST 以及字节码，对内部声明的其他函数进行预解析，是为了检查函数内部是否引用了外部变量。如果函数内部引用了外部变量，预解析器会将这些变量从栈中复制（值类型复制值，引用类型复制地址）到堆中。这样，在下次执行该函数时，函数可以直接使用堆中的引用，从而解决了闭包所带来的问题。

我们来具体通过执行 multi 函数的字节码来理解下，通过 `d8 --print-bytecode` 来打印：

> 其实早期的 V8 为了提升代码的执行速度，是直接将 JavaScript 源代码编译成了没有优化的二进制的机器代码，但是随着移动设备的普及，V8 团队逐渐发现将 JavaScript 源码直接编译成二进制代码存在两个致命的问题。第一是编译时间过久，影响代码启动速度；第二是缓存编译后的二进制代码占用更多的内存。所以便引入字节码来解决上述启动问题和空间问题。

```
[generated bytecode for function: multi (0x06d300259e19 <SharedFunctionInfo multi>)]
Bytecode length: 14
Parameter count 1
Register count 1
Frame size 8
Bytecode age: 0
         0x6d30025a092 @    0 : 83 00 01          CreateFunctionContext [0], [1]
         0x6d30025a095 @    3 : 1a fa             PushContext r0
         0x6d30025a097 @    5 : 0d 0a             LdaSmi [10]
         0x6d30025a099 @    7 : 25 02             StaCurrentContextSlot [2]
         0x6d30025a09b @    9 : 80 01 00 02       CreateClosure [1], [0], #2
         0x6d30025a09f @   13 : a9                Return
Constant pool (size = 2)
0x6d30025a061: [FixedArray] in OldSpace
 - map: 0x06d300002231 <Map(FIXED_ARRAY_TYPE)>
 - length: 2
           0: 0x06d300259ff9 <ScopeInfo FUNCTION_SCOPE>
           1: 0x06d30025a029 <SharedFunctionInfo inner>
Handler Table (size = 0)
Source Position Table (size = 0)
```

我们看到 `Bytecode age: 0` （代表字节码的执行状态，数字增加代表函数的热度，也就是上面说的热点代码，V8 就会对这串代码进行针对性优化）下的一条条指令就是字节码啦，这六条指令解释器执行完就代表 multi 函数执行完成了，上面打印出来的字节码只是全部的冰山一角，若有同学有兴趣的话，可以到[V8源码](https://link.zhihu.com/?target=https%3A//github.com/v8/v8/blob/master/src/interpreter/bytecodes.h)查看更多。

这里的字节码最终通过解释器解释执行，在执行的过程中，需要通过某些手段去保存参数、中间计算结果等，V8 的解释器（Ignition）采用的是基于寄存器的架构，他通过寄存器来保存所需要的数据。有兴趣的同学可以详细查看[Ignition 设计文档](https://link.zhihu.com/?target=https%3A//docs.google.com/document/d/11T2CRex9hXxoJwbYqVQ32yIPMh0uouUZLdyrtmMoL44/edit%23heading%3Dh.6jz9dj3bnr8t)中的 register 相关内容。

下面我来简单逐行解释下打印出来的代码。

`Bytecode length` 表示函数 multi 的字节码长度。`Parameter count 1` 表示函数 multi 接收一个参数，这里是隐式地传入了 `this`。`Register count` 表示使用的寄存器数量。`Frame size` 代表栈帧大小（因为 V8 是通过栈结构来管理函数调用，栈帧是一个用于存储参数、被调用者的返回值、局部变量和寄存器的空间）。

`CreateFunctionContext` 是用来创建函数上下文的，会把 multi 函数上下文和作用域信息存到寄存器中，当然 inner 函数也会存进去。`PushContext` 用于将寄存器中的上下文推入执行上下文栈。`LdaSmi` 和 `StaCurrentContextSlot` 代表将值 10 加载到寄存器中并且存储到当前上下文中。`CreateClosure` 就是通过传入上下文的一些信息，若发现内部有引用外层作用域链上的变量，则输出带有闭包信息的新的 inner 函数存进寄存器中最后返回。

我们重点看下下面的字节码，`Constant pool` 代表常量池，当代码中使用了多个相同的常量值时，V8 引擎会将这些常量值存储在 `Constant pool` 中，并在需要使用时直接引用它们，而不是重复创建多个相同的常量值。继续往下看 `[FixedArray] in OldSpace` 代表下面的常量存到了老生代中，老生代中的对象更稳定，不容易被回收，通常用于用于存储生命周期较长的对象，例如函数、闭包、大型对象。下面的 `ScopeInfo FUNCTION_SCOPE` 表示函数作用域信息的数据结构，它记录了函数内部的变量和作用域链等信息。`SharedFunctionInfo inner` 表示用于存储 inner 函数的字节码等。这两个常量同时存在表示内部函数 inner 与外部函数的作用域存在关联，通过 `ScopeInfo` 中的作用域链查找到内部函数访问了外部函数的变量。最后在 `SharedFunctionInfo` 中会存储内部函数引用的外部函数的变量作用域范围的信息，这里就是存储了闭包变量 a 的作用域范围，存储到了堆中供后续 inner 函数执行访问。

所以 V8 通过预解析器使得 JavaScript 的闭包特性得以实现。

## 总结

本文我们介绍了在 V8 中是如何实现闭包这一特性的，V8 在处理函数的时候采用的延迟解析来提高启动速度，但是延迟解析和闭包存在天然的矛盾，所以当一个函数中存在闭包并且执行时，V8 会通过引入预解析器去扫描内部函数使用到的外部变量，并且复制到堆中，下次执行内部函数的时候就是直接访问堆中的引用。

最后我们要注意闭包可能导致的内存泄露问题，我们书写闭包代码时如果引用了一些后续用不到的变量，比如说引用了一个大对象，但是我们只用这个对象中的一个属性值，那么就会导致这个大对象不会被销毁，导致内存泄漏，解决方式们就是要将需要的属性值提取出来成为一个新变量，在函数中引用此新变量就可以。还有一些引用 dom 节点产生的泄露等问题。