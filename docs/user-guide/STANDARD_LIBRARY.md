# DelSafe Standard Library & Intrinsics Reference

DelSafe ships with its standard library in `std/*.dels` alongside built-in compiler intrinsics supported identically across Free Pascal and GCC/Clang C99 backends.

Import any standard library module using `import <Module>;` (for example, `import Math;`, `import FS;`, `import Sync;`).

---

## 1. Standard Library Modules (`std/*.dels`)

### `Collections` (`std/collections.dels`)
- **Types:** `FixedBuffer { capacity: UInt32; count: UInt32; }`, `StringBuilder { buffer: String; length: UInt32; }`
- **Routines:**
  - `NewBuffer(borrow cap: UInt32) return FixedBuffer`
  - `IsFull(borrow buf: FixedBuffer) return Bool`
  - `Available(borrow buf: FixedBuffer) return UInt32`
  - `PushItem(mut borrow buf: FixedBuffer) return Bool`
  - `NewStringBuilder() return StringBuilder`
  - `Append(mut borrow sb: StringBuilder; borrow text: String)`
  - `ToString(borrow sb: StringBuilder) return String`

### `FS` (`std/fs.dels`)
- **Types:** `FileInfo { path: String; size_bytes: Int64; exists: Bool; is_dir: Bool; }`
- **Routines:**
  - `MakeDir(borrow path: String) return Bool`
  - `DeleteDir(borrow path: String) return Bool`
  - `RemoveFile(borrow path: String) return Bool`
  - `HasDir(borrow path: String) return Bool`
  - `GetFileSize(borrow path: String) return Int64`
  - `ReadDir(borrow path: String) return array of String`
  - `CopyFileTo(borrow src, dst: String) return Bool`
  - `MoveFile(borrow old_path, new_path: String) return Bool`
  - `GetFileInfo(borrow path: String) return FileInfo`

### `IO` (`std/io.dels`)
- **Types:** `IOError = enum FileNotFound, PermissionDenied, DiskError end enum;`
- **Routines:**
  - `LogInfo(borrow message: String)` / `WriteOut(borrow text: String)` / `ReadLine() return String`
  - `GetEnvVar(borrow name: String) return String` / `SetEnvVar(borrow name, value: String) return Bool`
  - `Exists(borrow path: String) return Bool`
  - `ReadAll(borrow path: String) return String` / `WriteAll(borrow path, content: String) return Bool`

### `JSON` (`std/json.dels`)
- **Types:** `JsonBuilder { buffer: String; count: UInt32; }`
- **Builder Routines:** `NewJsonBuilder()`, `AddString`, `AddInt`, `AddFloat`, `AddBool`, `AddRaw`, `Build(borrow jb) return String`
- **Parser & Query Routines:**
  - `Validate(borrow json: String) return Bool`
  - `HasKey(borrow json, key: String) return Bool`
  - `ExtractString`, `ExtractInt`, `ExtractFloat`, `ExtractBool`, `ExtractObject`, `ExtractArray`
  - `ArrayLength(borrow json_array: String) return Int32`
  - `ArrayGet`, `ArrayGetString`, `ArrayGetInt`, `ArrayGetFloat`

### `Math` (`std/math.dels`)
- **Types:** `MathError = enum DivisionByZero, InvalidDomain end enum;`
- **Routines:** `Abs`, `Max`, `Min`, `Clamp` (with `require min_val <= max_val`), `SqrtSafe(borrow x: Float64) return Result<Float64, MathError>`

### `Strings` (`std/strings.dels`)
- **Routines:** `IsEmpty`, `Equals`, `PrintMessage`, `StrLen`, `GetChar`, `Substr`, `SplitBy`, `JoinWith`, `PadStart`, `PadEnd`, `RepeatText`, `ParseFloat`, `TryParseInt`, `TryParseFloat`

### `Net` (`std/net.dels`) & `HTTP` (`std/http.dels`)
- **`Net` Types:** `Socket`, `HttpRequest`, `HttpResponse`
- **`Net` Routines:** `NewSocket`, `Connect`, `SendData`, `CloseSocket`, `SocketListenServer`, `SocketAcceptClient`, `SocketConnectClient`, `SocketSendString`, `SocketRecvString`, `SocketCloseHandle`, `SocketSetTimeoutMs`, `SocketGetPeerIP`, `SocketSendRawHex`, `SocketRecvRawHex`, `BuildHttpRequest`, `BuildHttpResponse`, `ParseHttpRequest`, `ParseHttpResponse`
- **`HTTP` Types:** `Client`, `Server`
- **`HTTP` Routines:** `NewClient`, `Get`, `Post`, `NewServer`, `AcceptRequest`, `SendResponse`, `StopServer`

### `Sync` (`std/sync.dels`)
- **Types:** `AtomicInt32`, `Mutex`
- **Atomics:** `NewAtomic`, `AtomicLoad`, `AtomicStore`, `AtomicFetchAdd`, `AtomicAdd`, `AtomicCompareExchange`, `AtomicDestroy`
- **Mutexes:** `NewMutex`, `Lock`, `Unlock`, `IsLocked`, `MutexLock`, `MutexTryLock`, `MutexUnlock`, `MutexDestroy`

### `Time` (`std/time.dels`)
- **Types:** `Timer { start_ns: UInt64; stop_ns: UInt64; is_running: Bool; }`
- **Routines:** `NowNs`, `Sleep(ms: UInt32)`, `NewTimer`, `StartTimer`, `StopTimer`, `ElapsedNs`, `ElapsedMs`

---

## 2. Built-In Compiler Intrinsics & UFCS Methods

These intrinsics are available globally without extra imports:

- **Console & Assertions:** `Print(...)`, `PrintLn(...)`, `ReadLn()`, `Assert(cond[, msg])`
- **Strings & Conversions:** `Length(s)`, `CharAt(s, idx)`, `Substring(s, start, count)`, `Trim`, `UpperCase`, `LowerCase`, `StartsWith`, `EndsWith`, `Contains`, `IndexOf`, `Replace`, `Split`, `Join`, `PadLeft`, `PadRight`, `RepeatStr`, `IntToStr`, `FloatToStr`, `StrToInt`, `StrToFloat`, `TryStrToInt`, `TryStrToFloat`, `Ord(ch)`, `Chr(n)`
- **Math:** `Abs`, `Min`, `Max`, `Clamp`, `Sqrt`, `Floor`, `Ceil`, `Round`, `Pow`, `Exp`, `Log`, `Sin`, `Cos`, `Tan`, `Atan2`, `RandomInt`, `RandomFloat`
- **Dynamic Arrays (`array of T`) & Maps (`map[K]V`):** `SetLength`, `Length`, `.Push()`, `.Pop()`, `.Clear()`, `.Insert()`, `.Delete()`, `.Slice()`, `.Contains()`, `.Remove()`, `.Count()`
- **File System & Environment:** `FileExists`, `ReadFile`, `WriteFile`, `CreateDir`, `RemoveDir`, `DeleteFile`, `DirExists`, `ListDir`, `CopyFile`, `RenameFile`, `GetEnv`, `SetEnv`
- **Memory & Concurrency:** `Box(val)`, `Free(x)`, `Dispose(x)`, `Default(T)`, `SizeOf(T)`, `Inc(x)`, `Dec(x)`, `NewChannel<T>(cap)`, `Send`, `Recv`, `TrySend`, `TryRecv`, `CloseChannel`, `IsChannelEmpty`, `IsChannelClosed`, `ChannelLen`, `DestroyChannel`
