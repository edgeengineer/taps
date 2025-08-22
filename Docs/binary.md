There are a few main types of "bag of bytes" data structures:

- `Array<UInt8>` (stdlib)
- `InlineArray<size, UInt8>` (stdlib)
- `Span<UInt8>` (stdlib)
- `UnsafeBufferPointer<UInt8>` (stdlib)
- `Data` (Foundation/FoundationEssentials)
- `ByteBuffer` (SwiftNIO)

All of these types are used to represent binary data, where a byte is a `UInt8` in Swift. All of these types have value semantics (a `struct`).

## Data

`Data` is a macOS and iOS native type, and exists as part of the `Foundation` framework. On non-apple platforms, you can use the `FoundationEssentials` module to get access to it as well.
Data is a dynamically sized, array of bytes, but not always contiguous (on Apple platforms).

FoundationEssentials is a subset of the `Foundation` framework, containing no locale/internationalization support, in order to reduce the size of the framework.
Even FoundationEssentials itself is pretty big, about 15-40MB (depending on code stripping). It's not availble in Embedded Swift.

## ByteBuffer

`ByteBuffer` is a type that is part of the `SwiftNIO` framework. It is a mutable buffer of bytes, and is used to represent binary data. It's main purpose is to be a cross-platform, high-performance bag of bytes type that **does not** rely on Foundation (for aforementioned reasons).
ByteBuffer is a dynamically sized, contiguous array of bytes.

ByteBuffer is a very good choice for network protocools, for it's serialization and parsing utilities, plus the performance of these utilities.
But it's not availble in Embedded Swift either, and is used in many Linux applications that rely on SwiftNIO.

## UnsafeBufferPointer

`UnsafeBufferPointer<UInt8>` is a type that is part of the `stdlib`. It is a pointer to a buffer of bytes, and is used to represent binary data. It's main purpose is to be a low-level type that can be used to represent binary data, and is used in many places in the stdlib.
UnsafeBufferPointer is a raw pointer to a buffer of bytes, and is used to represent binary data. It's not a growable collection, and cannot be appended to. As such you need to manage the memory yourself.

UnsafeBufferPointer is available on any platform, but is unsafe through having no guarantees in terms of memory safety or lifetime management. Don't use this type unless you know what you're doing and are interacting with C or C++ code.

## Array

`Array<UInt8>` is a type that is part of the `stdlib`. It's effectively a safe, cross-platform, growable collection of bytes. Arrays can be passed around to C/C++ functions as pointers, through any escaping of this data pointer might lead to undefined behaviour.

Arrays are a great choice for representing binary data, as they are safe, cross-platform, and growable.

## InlineArray

If you need a more performant (stack allocated) array of bytes, you can use `InlineArray<size, UInt8>`.

```swift
let array = InlineArray<10, UInt8>(repeating: 0x00)
```

InlineArray is a type that is part of the `stdlib`. It's usually a stack allocated, fixed-size array of bytes, and is used to represent binary data. It's main purpose is to be a low-level type that can be used to represent binary data, and is used in many places in the stdlib.

# Span

Spans are not a single type, but a family of types that are used to work with binary data. Any type backed by a `UnsafeBufferPointer<UInt8>` can be converted to a `Span<UInt8>`. This includes `Data`, `ByteBuffer`, `Array<UInt8>`, `InlineArray<size, UInt8>`, `UnsafeBufferPointer<UInt8>`.

Because each platform and use case has different requirements, they have a different ideal bag of bytes type. The problem with this is that you can't just pass a `Data` into a function that expects a `ByteBuffer`, or an `Array<UInt8>`.

One solution is to accept any of these types, so the caller can provide the best type for the job - based on platform specific requirements. In addition, you don't want to copy the data into a new type, as this is extremely inefficient.
However, even just _referencing_ the `Data` type will require a dependency on Foundation, which is not desirable for binary size. Likewise for SwiftNIO and other frameworks/libraries that are not in stdlib.

## Parsing

The solution is to use a `Span<UInt8>`, which is a pointer to another bag of bytes type. A span borrows the lifetime of the underlying type, and can be used to read the underlying data. For this duration of the Span's lifetime, the underlying data is guaranteed to be valid and inaccessible by other code. This ensures memory safety, while enabling performant access without ARC calls.

```swift
var array = [UInt8](repeating: 0x00, count: 10)
let span = array.span

// You can now read the data from the span
let value = span[0]
```

`Span` is a _read-only_ view of the underlying data. It's a pointer to the underlying data, and can be used to read the data.
If you need a mutable view of the data, you can use `MutableSpan<UInt8>`, which is a pointer to a mutable buffer of bytes.

```swift
var array = [UInt8](repeating: 0x00, count: 10)
var mutableSpan = array.mutableSpan

// You can now read the data from the span
mutableSpan[0] = 0x01
```

However, both `Span` and `MutableSpan` are a fixed-size view of the underlying data, with all elements being populated. While this is great for parsing, it's not great for writing.

The final member is `OutputSpan<UInt8>`, which allows writing into a growable yet limited buffer of bytes. It enables the holder, like `Array`, to pre-allocate a maximum size.
Data can be appended to the `OutputSpan` (and thereby the Array), so long as the capacity is not exceeded.

```swift
var array = [UInt8](capacity: 100) { outputSpan in
    outputSpan.append(0x01)
    outputSpan.append(0x02)
}
print(array.count) // 2
```

All of these types are available on any platform, and are safe to use through built-in bounds checks.
When using `OutputSpan` for serialization, you need to pre-calculate the maximum size of the data.

# Conclusion

- For iOS and macOS-only projects, `Data` is a great choice due to it's Framework integration and minimal impact on binary size on these specifics platforms.
- In SwiftNIO based projects, `ByteBuffer` is preferred due to it _required_ for any Network and Disk I/O.
- `[UInt8]` and `InlineArray` are amazing for embedded projects, though it lacks the benefits on other platforms.
- `Span<UInt8>` is a universally great choice, enabling any backing data type but requires Swift 6.2 or later.

## References

A library for parsing and serialization based on spans is coming up: https://github.com/apple/swift-binary-parsing
