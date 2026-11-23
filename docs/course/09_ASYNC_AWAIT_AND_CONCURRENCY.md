# Chapter 09: Asynchronous Programming & Concurrency

Modern network services, HTTP backends, and game engines cannot afford to block operating system threads on I/O. Aether introduces **Native Structured Concurrency** with `async function` and lightweight cooperative task scheduling.

---

## 1. Defining Asynchronous Routines (`async`)

An `async function` runs cooperatively in the Aether runtime fiber pool without locking the calling thread:

```aether
module async_demo;

async function FetchUserData(user_id: Int32) return String is
begin
    PrintLn("Fetching data for user " + IntToStr(user_id) + " asynchronously...");
    // Simulated non-blocking work
    return "UserPayload { id: " + IntToStr(user_id) + ", name: Alice, verified: true }";
end FetchUserData;
```

When transpiled:
- **Free Pascal Backend:** Generates `function FetchUserData(...): specialize TAetherTask<String>;` powered by Aether's multi-threaded task runtime.
- **C99 Backend:** Generates `AetherTask FetchUserData(...)` wired to a lightweight non-blocking event loop.

---

## 2. Awaiting Tasks: `await`

To retrieve the result of an asynchronous task, use `await`:

```aether
program Main;
var
    task: TAetherTask<String>;
    result: String;
begin
    // Spawns the task asynchronously:
    task := FetchUserData(42);

    // Suspends until the task completes:
    result := await task;

    PrintLn("Received result: " + result);
end async_demo.
```

---

## 3. Parallel Execution: Fan-Out & Aggregate

You can launch multiple asynchronous operations concurrently and await them all:

```aether
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
    tA: TAetherTask<Float64>;
    tB: TAetherTask<Float64>;
    temp: Float64;
    pressure: Float64;
begin
    // Fan-out: both run concurrently
    tA := FetchSensorA();
    tB := FetchSensorB();

    // Await results
    temp := await tA;
    pressure := await tB;

    PrintLn("Temperature: " + FloatToStr(temp) + " C");
    PrintLn("Atmospheric Pressure: " + FloatToStr(pressure) + " hPa");
end async_parallel.
```

---

## 4. Concurrency Guarantees with the Borrow Checker

In many languages, multi-threading introduces terrifying data races when two threads mutate shared memory without synchronization.

In Aether, **the Borrow Checker applies across thread boundaries**:
- If data is shared across threads, it must be immutable (`borrow`) or wrapped in safe synchronization primitives.
- Mutable references (`mut borrow`) can never be shared across tasks simultaneously.
- Result: **Data-race-free concurrency by design**.

---

## 5. Summary
1. Mark non-blocking functions with `async`.
2. Retrieve values cooperatively using `await`.
3. Combine asynchronous tasks with the Borrow Checker for fast, fearless concurrency.

➡️ **Next:** **[Chapter 10: Conditional Compilation & Optimizations](10_CONDITIONAL_COMPILATION_AND_OPTIMIZATIONS.md)**
