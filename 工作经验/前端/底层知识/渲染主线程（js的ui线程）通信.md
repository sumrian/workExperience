##渲染主线程（js的ui线程）通信

Chromium 的源码明确说明了 **渲染主线程（Render Main Thread）** 负责从**消息队列（Task Queue）中取出并执行任务**。具体逻辑在 `base/task/sequence_manager` 和 Blink 的 `FrameScheduler` 相关模块中实现。以下是关键源码解析：

------

### **1. 核心源码：sequence_manager 负责调度任务**

Chromium 使用 `SequenceManager` 来管理任务队列（Task Queue），并在渲染主线程的 `MessageLoop` 中循环处理任务。
关键文件：

- **base/task/sequence_manager/sequence_manager_impl.cc**

  - 定义了

     

    ```
    TakeTask()
    ```

     

    方法，从队列中取出任务并执行：

    ```
    WorkQueue* SequenceManagerImpl::GetNextTaskQueue() {
      // ... 选择优先级最高的任务队列 ...
      return active_queues_.front();
    }

    Task SequenceManagerImpl::TakeNextTask() {
      WorkQueue* queue = GetNextTaskQueue();
      return queue->TakeTask(); // 从队列头部取出任务
    }
    ```

    运行

- **base/task/sequence_manager/task_queue_impl.cc**

  - ```
    TakeTask()
    ```

     

    的实现：

    ```
    Task TaskQueueImpl::TakeTask() {
      return std::move(queue_.front()); // 取出队首任务
    }
    ```

    运行

------

### **2. 渲染主线程的 MessageLoop 驱动事件循环**

- **文件：base/message_loop/message_pump_default.cc**
  主线程通过 `MessagePump` 运行事件循环，不断调用 `DoWork()` 处理任务：

  ```
  void MessagePumpDefault::Run(Delegate* delegate) {
    for (;;) {
      bool did_work = delegate->DoWork(); // 执行任务
      if (should_exit_) break;
      if (!did_work) {
        delegate->DoIdleWork(); // 空闲时处理微任务等
      }
    }
  }
  ```

  运行

- **DoWork() 最终调用 SequenceManager::TakeNextTask()**
  任务来源包括：

  - DOM 事件（如点击、定时器）
  - IPC 通信（来自其他进程的任务）
  - JS 触发的异步回调（如 `setTimeout`）

------

### **3. Blink 中的微任务（Microtask）处理**

V8 负责微任务队列，但**触发微任务检查的仍然是渲染主线程**：

- 文件：`third_party/blink/renderer/bindings/core/v8/v8_microtask_runner.cc`

  ​

  在任务执行完成后，主线程会调用

   

  ```
  PerformCheckpoint()
  ```

   

  清空微任务队列：

  ```
  void V8MicrotaskRunner::PerformCheckpoint() {
    if (!microtask_queue_) return;
    microtask_queue_->PerformCheckpoint(); // 调用 V8 执行微任务
  }
  ```

  运行

------

### **4. W3C 规范与 Chromium 实现的对应关系**

| W3C Event Loop 概念      | Chromium 源码实现                        |
| ------------------------ | ---------------------------------------- |
| **取出并执行一个宏任务** | `SequenceManager::TakeNextTask()`        |
| **清空微任务队列**       | `V8MicrotaskRunner::PerformCheckpoint()` |
| **渲染主线程的事件循环** | `MessagePumpDefault::Run()`              |

------

### **总结**

- **谁取任务？**
  渲染主线程通过 `SequenceManager` 从消息队列中调用 `TakeNextTask()` 取出任务。
- **谁执行任务？**
  同一个线程（渲染主线程）同步执行任务的回调函数。
- **微任务何时处理？**
  在每个宏任务执行完成后，由主线程主动调用 V8 的微任务检查点。