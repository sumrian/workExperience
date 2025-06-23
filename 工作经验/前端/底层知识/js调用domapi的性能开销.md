## js调用domapi的性能开销



主要是进程间通信的开销，回流重绘不是大头

## 二、JS 线程调用 DOM API 的源码流程

### 1. **ScriptController 调用 V8 执行脚本**

在浏览器中，JS 脚本的执行是由 `ScriptController` 控制的。`ScriptController` 会调用 V8 引擎来执行 JavaScript 代码。以下是关键代码片段：

```
// script_controller.cc
void ScriptController::ExecuteScriptInMainWorld(
    const ScriptSourceCode& source_code,
    const KURL& base_url,
    const ScriptFetchOptions& fetch_options,
    AccessControlStatus access_control_status) {
  v8::HandleScope handle_scope(GetIsolate());
  EvaluateScriptInMainWorld(source_code, base_url, fetch_options,
                            access_control_status,
                            kDoNotExecuteScriptWhenScriptsDisabled);
}
```

运行

- `GetIsolate()` 获取当前的 V8 隔离（Isolate），用于隔离不同的 JavaScript 环境。
- `EvaluateScriptInMainWorld()` 是 V8 内部函数，用于在主世界中执行脚本。

### 2. **V8 执行脚本并调用 DOM API**

当 V8 执行脚本时，如果遇到 DOM API 调用（如 `document.getElementById()`），V8 会通过 `BUILTIN(HandleApiCall)` 调用 Blink 的 DOM API 实现。以下是关键代码片段：

```
// v8/src/execution/microtask-queue.h
class MicrotaskQueue {
 public:
  static std::unique_ptr<MicrotaskQueue> New(Isolate* isolate);
  // ...
};
```

运行

- `MicrotaskQueue` 是 V8 中用于管理微任务的类，`New(Isolate* isolate)` 是其构造函数。
- 当 JS 线程调用 DOM API 时，V8 会通过 `BUILTIN(HandleApiCall)` 调用 Blink 的 DOM API 实现。

### 3. **Blink 处理 DOM API 调用**

在 Blink 中，DOM API 的实现通常通过 `ScriptWrappable` 类进行封装。`ScriptWrappable` 提供了两个方法，用于在 Blink 和 V8 之间进行对象互转。

```
// blink/core/ScriptWrappable.h
class ScriptWrappable {
 public:
  virtual void AddToScriptWrappableMap() = 0;
  virtual void RemoveFromScriptWrappableMap() = 0;
  // ...
};
```

运行

- `AddToScriptWrappableMap()` 和 `RemoveFromScriptWrappableMap()` 用于注册和注销 DOM 对象到 V8 的绑定系统中。
- Blink 通过 `V8CallbackTable` 将 DOM API 的调用映射到实际的 C++ 实现。

### 4. **DOM API 调用的源码示例**

以下是一个简单的示例，展示了 `document.getElementById()` 的调用过程：

```
// blink/core/Document.cc
void Document::setIdAttribute(const AtomicString& name, const AtomicString& value) {
  // ...
  if (name == "id") {
    // ...
    id = value;
    // ...
    ScriptWrappable::AddToScriptWrappableMap();
    // ...
  }
}
```

运行

- `setIdAttribute` 是 `Document` 类的成员函数，用于设置元素的 `id` 属性。
- `ScriptWrappable::AddToScriptWrappableMap()` 用于将 DOM 对象注册到 V8 的绑定系统中。

------

## 三、总结

JS 线程调用 DOM API 的流程如下：

1. **JS 线程执行同步代码**。
2. **遇到 DOM API 调用**，将其交给 Web API 线程处理。
3. **Web API 线程处理**，将回调函数推入 JS 主线程的消息队列。
4. **事件循环机制** 从消息队列中取出回调函数并执行。
5. **回调函数执行**，可能再次触发 Web API，形成循环。

在源码层面，JS 线程调用 DOM API 的流程涉及以下几个关键组件：

- **V8 引擎**：负责解析、编译和执行 JavaScript 代码。
- **Blink 渲染引擎**：负责处理 DOM API 的调用。
- **ScriptController**：负责控制 JS 脚本的执行。
- **ScriptWrappable**：负责在 Blink 和 V8 之间进行对象互转。
- **V8CallbackTable**：负责将 DOM API 的调用映射到实际的 C++ 实现。

通过这些组件的协作，JS 线程可以安全、高效地调用 DOM API，实现对网页内容的动态操作。