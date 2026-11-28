# Chapter 13: Capstone Project: High-Performance In-Memory Cache

Congratulations on reaching the final chapter of the DelSafe Masterclass! In this hands-on project, you will build an **In-Memory Secure Cache Service** that integrates every pillar of the language:

1. **Records with Compiler Derivations** (`[derive(Debug, JSON, Clone, Equals)]`).
2. **Algebraic Enums with Exhaustive `match`** (`CacheResult`).
3. **Design by Contract (DbC)** (`require` & `ensure`).
4. **Ownership & Borrow Checking** (`borrow`, `mut borrow`).
5. **Cross-Platform Conditional Compilation** (`@cfg`).
6. **Inlined Hot Paths** (`@inline(always)`).
7. **Zero Memory Leaks Verification** with `delsafec profile`.

---

## 1. Project Architecture

Create a project with `delsafec new secure_cache` or create a standalone file named `secure_cache.dels`:

```delsafe
module secure_cache;

import pascal SysUtils;

// 1. Data Models with Automatic Compiler Derivations
[derive(Debug, JSON, Clone, Equals)]
type
    CacheItem = record
        key: String;
        payload: String;
        created_at: UInt64;
        access_count: Int32;
    end record;

// 2. Algebraic Return Type for Robust Error Handling
type
    CacheLookupResult = enum
        Hit(CacheItem),
        Miss,
        Expired
    end enum;

// 3. Main Cache Storage Structure
type
    SecureCache = record
        name: String;
        ttl_seconds: UInt64;
        total_queries: Int32;
    end record;

// 4. Inlined Calculation for Hash/Key Normalization
@inline(always)
function NormalizeKey(k: String) return String is
begin
    return Trim(k);
end NormalizeKey;

// 5. Cache Constructor with Pre-condition Contracts
function CreateCache(name: String; ttl: UInt64) return SecureCache is
contract
    require
        ttl > 0;
        Length(name) > 0;
begin
    return SecureCache(name, ttl, 0);
end CreateCache;

// 6. Inspecting Cache State via Read-Only Borrowing (borrow)
procedure PrintCacheReport(borrow cache: SecureCache) is
begin
    PrintLn("========================================");
    PrintLn(" Cache Report: " + cache.name);
    PrintLn(" TTL Policy:   " + IntToStr(Int32(cache.ttl_seconds)) + "s");
    PrintLn(" Total Ops:    " + IntToStr(cache.total_queries));
    PrintLn("========================================");
end PrintCacheReport;

// 7. Simulating Cache Query with Mutation (mut borrow)
function QueryItem(mut borrow cache: SecureCache; raw_key: String) return CacheLookupResult is
var
    norm_key: String;
    now_ticks: UInt64;
    dummy_item: CacheItem;
begin
    cache.total_queries := cache.total_queries + 1;
    norm_key := NormalizeKey(raw_key);

    now_ticks := GetTickCount64();

    if norm_key = "user:session:1001" then
        dummy_item := CacheItem(norm_key, "{\"user_id\": 1001, \"role\": \"admin\"}", now_ticks, 1);
        return CacheLookupResult.Hit(dummy_item);
    else if norm_key = "user:session:expired" then
        return CacheLookupResult.Expired;
    else
        return CacheLookupResult.Miss;
    end if;
end QueryItem;

program Main;
var
    cache: SecureCache;
    lookup: CacheLookupResult;
    item_clone: CacheItem;
begin
    PrintLn("Starting DelSafe Secure Cache Engine...\n");

    // Initialize cache with contract validation:
    cache := CreateCache("ZephyrAuthCache", 3600);

    // Query 1: Cache Hit
    lookup := QueryItem(mut borrow cache, "  user:session:1001  ");
    match lookup with
        CacheLookupResult.Hit(item) =>
            PrintLn("[CACHE HIT] Key: " + item.key);
            PrintLn("Payload (JSON): " + item.payload);
            PrintLn("Debug Repr:     " + item.ToString());

            // Clone item safely:
            item_clone := item.Clone();
            if item.Equals(borrow item_clone) then
                PrintLn("[INTEGRITY] Cloned item matches original perfectly!");
            end if;
        CacheLookupResult.Miss =>
            PrintLn("[CACHE MISS] Key not found.");
        CacheLookupResult.Expired =>
            PrintLn("[CACHE EXPIRED] Item TTL exceeded.");
    end match;

    PrintLn("");

    // Query 2: Cache Miss
    lookup := QueryItem(mut borrow cache, "user:session:9999");
    match lookup with
        CacheLookupResult.Hit(it) =>
            PrintLn("[CACHE HIT] " + it.key);
        CacheLookupResult.Miss =>
            PrintLn("[CACHE MISS] Key 'user:session:9999' not found in cache.");
        CacheLookupResult.Expired =>
            PrintLn("[CACHE EXPIRED] Key expired.");
    end match;

    PrintLn("");

    // Read-only report via borrow:
    PrintCacheReport(borrow cache);

    PrintLn("\nCapstone project completed successfully with 100% memory safety!");
end secure_cache.
```

---

## 2. Compiling and Verifying

### Step 1: Native Compilation (Pascal Backend)
```bash
delsafec secure_cache.dels -o bin/secure_cache.exe
./bin/secure_cache.exe
```

### Step 2: Native Compilation (C99 Backend)
```bash
delsafec secure_cache.dels --target=c -o bin/secure_cache_c.exe
./bin/secure_cache_c.exe
```

### Step 3: Zero Memory Leak Profiling
Run DelSafe's built-in memory profiler to verify that every single allocation is safely deallocated without leaks:

```bash
delsafec profile secure_cache.dels
```

Output:
```text
========================================================
  DelSafe Memory & Heap Audit
========================================================
  Heap Allocations: 18 blocks
  Heap Freed:       18 blocks
  Unfreed Blocks:   0 blocks (0 bytes leaked)
  Result:           100% MEMORY SAFE (ZERO LEAKS CERTIFIED)
========================================================
```

---

## 3. Graduation & Next Steps

Congratulations! You now have a comprehensive, production-grade grasp of the DelSafe programming language:
- You write code that is clean, readable, and structured like modern Pascal.
- You enjoy the compile-time memory safety of an affine Borrow Checker without a garbage collector.
- You enforce software reliability through Design-by-Contract.
- You can target Free Pascal, C99, and WebAssembly with seamless FFI and zero-cost abstractions.

Welcome to the DelSafe ecosystem! 🚀
