# Chapter 09: Asynchronous Programming & Concurrency

Modern network services, HTTP backends, and systems engines cannot afford to block on sequential I/O. DelSafe provides **Structured Concurrency** powered by real OS threads (`spawn` / `await` / `Task<T>`), cooperative `yield;`, hardware atomics and OS mutexes (`import Sync;`), and bounded generic channels (`Channel<T>`).

---

## 1. Asynchronous Routines & `Task<T>` (`async`, `spawn`, `await`)

An `async function` (or `async procedure` returning `Task<Void>`) runs concurrently and returns a `Task<T>` handle. Calling `spawn` explicitly dispatches either an `async` or regular routine on a worker thread:

```delsafe
module async_demo;

async function FetchUserData(user_id: Int32) return String is
begin
    yield;
    PrintLn("Fetching data for user " + IntToStr(user_id) + " concurrently...");
    return "UserPayload { id: " + IntToStr(user_id) + ", name: Alice, verified: true }";
end FetchUserData;

async procedure NotifyAudit(user_id: Int32) is
begin
    yield;
    PrintLn("Audit recorded for user " + IntToStr(user_id));
end NotifyAudit;
```

When transpiled:
- **Free Pascal Backend:** Uses `BeginThread` / `WaitForThreadTerminate` and `specialize TDelSafeTask<T>`.
- **C99 Backend:** Uses Win32 `CreateThread` on Windows or POSIX `pthread_create` (`-pthread`) on Linux/macOS with `DelSafeTask`.

---

## 2. Awaiting Tasks: `await`

To wait for a `Task<T>` to finish and extract its result, use `await`:

```delsafe
program Main;
var
    task: Task<String>;
    audit: Task<Void>;
    res: String;
begin
    task := FetchUserData(42);
    audit := spawn NotifyAudit(42);

    res := await task;
    await audit;

    PrintLn("Received result: " + res);
end async_demo.
```

---

## 3. Parallel Execution: Fan-Out & Aggregate

You can spawn multiple tasks concurrently and `await` each handle:

```delsafe
module async_parallel;

async function FetchSensorA() return Float64 is
begin
    return 24.5;
end FetchSensorA;

async function FetchSensorB() return Float64 is
begin
    return 1013.25;
end FetchSensorB;

program Main;
var
    tA: Task<Float64>;
    tB: Task<Float64>;
    temp: Float64;
    pressure: Float64;
begin
    tA := spawn FetchSensorA();
    tB := spawn FetchSensorB();

    temp := await tA;
    pressure := await tB;

    PrintLn("Temperature: " + FloatToStr(temp) + " C");
    PrintLn("Atmospheric Pressure: " + FloatToStr(pressure) + " hPa");
end async_parallel.
```

---

## 4. Real Synchronization Primitives (`import Sync;`)

The `Sync` standard library module (`std/sync.dels`) exposes hardware-level atomics and OS mutexes:

- **Atomic Integers (`AtomicInt32`):** `NewAtomic(initial)`, `AtomicLoad(borrow a)`, `AtomicStore(borrow a, val)`, `AtomicFetchAdd(borrow a, delta)`, `AtomicAdd(borrow a, delta)`, `AtomicCompareExchange(borrow a, expected, desired)`, `AtomicDestroy(mut borrow a)`.
- **OS Mutexes (`Mutex`):** `NewMutex()`, `MutexLock(borrow m)` / `Lock(mut borrow m)`, `MutexTryLock(borrow m)`, `MutexUnlock(borrow m)` / `Unlock(mut borrow m)`, `IsLocked(borrow m)`, `MutexDestroy(mut borrow m)`.

---

## 5. Bounded Generic Channels (`Channel<T>`)

For safe message passing between concurrent tasks, DelSafe provides a built-in ring-buffer `Channel<T>` returning `Option<T>` on receive:

- `NewChannel<T>(capacity)`: Creates a bounded channel.
- `Send(ch, val)` / `TrySend(ch, val)`: Sends a value (blocking or non-blocking).
- `Recv(ch)` / `TryRecv(ch)`: Returns `Option<T>` (`is_some` when a value is received, `is_none` if closed/empty).
- `CloseChannel(ch)`, `IsChannelEmpty(ch)`, `IsChannelClosed(ch)`, `ChannelLen(ch)`, `DestroyChannel(ch)`.

---

## 6. Concurrency Guarantees with the Borrow Checker

In DelSafe, **the Borrow Checker applies across task boundaries**:
- Shared read access uses `borrow`, while mutable access (`mut borrow`) cannot be aliased concurrently.
- Combined with `AtomicInt32`, `Mutex`, and `Channel<T>`, concurrent programs remain free of data races.

---

## 7. Summary
1. Mark concurrent routines with `async` (functions return `Task<T>`, procedures return `Task<Void>`).
2. Dispatch work with `spawn` and synchronize results with `await` (plus cooperative `yield;`).
3. Coordinate shared state safely using `Sync` (`AtomicInt32`, `Mutex`) and `Channel<T>`.

➡️ **Next:** **[Chapter 10: Conditional Compilation & Optimizations](10_CONDITIONAL_COMPILATION_AND_OPTIMIZATIONS.md)**
