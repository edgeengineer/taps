# Structured vs. Unstructured Concurrency

**Structured concurrency** is a programming paradigm where the lifetime of concurrent tasks is strictly bound to the scope in which they are created. In Swift, this means that child tasks are created within a parent task, and they cannot outlive the parent. When the parent task completes or is cancelled, all of its child tasks are automatically cancelled as well. The parent task only ends when all child tasks are completely finished or cancelled as well. This leads to safer, more predictable, and easier-to-reason-about concurrent code.

**Unstructured concurrency**, on the other hand, allows tasks to be created independently of any parent scope. These "detached" tasks can outlive the function or context that created them, making it harder to manage their lifecycle, cancellation, and error propagation. This can lead to resource leaks, unpredictable behavior, and more complex error handling.

**Key Differences:**

- **Lifetime Management:**
  - *Structured:* Child tasks are tied to the parent’s lifetime.
  - *Unstructured:* Tasks can outlive their creator, leading to potential leaks.

- **Cancellation:**
  - *Structured:* Cancellation propagates automatically from parent to children.
  - *Unstructured:* Manual cancellation is required.

- **Error Handling:**
  - *Structured:* Errors bubble up the task hierarchy automatically.
  - *Unstructured:* Errors must be handled manually for each task, and can in some cases even be 'forgotten'.

- **Code Clarity:**
  - *Structured:* Easier to reason about, maintain, and debug. Various Xcode instruments available.
  - *Unstructured:* Can become complex and error-prone in large codebases.

**In summary:**  
Structured concurrency enforces clear relationships and lifetimes for tasks, making concurrent code safer and more maintainable. Unstructured concurrency offers more flexibility but at the cost of safety and clarity.

## General Guidelines

- Avoid unstructured logic like `Task` and `DispatchQueue.async`

# Patterns

## 1. Async Sequences

Use AsyncSequences for any stream of data. Common examples include socket I/O (network and file system), database cursors.

```swift
for try await value in stream {
    // Handle value
}
```

### Benefits

Async Streams request elements one at a time, while still allowing the backing implementation to pre-fetch data or fetch in batches. However, due to these explicit suspension points, implementations can enforce backpressure. This ensures systems have a low memory usage, preventing resource exhaustion.

## 2. Parallelisation

When you need to run multiple tasks in parallel, there are two structured solutions, `async let` and `TaskGroup`.

Async lets allow running a function in parallel, then awaiting the result later. This can help reduce latency.

```swift
async let userProfile = fetchUserProfile(forUserID: userID)
async let chatRooms = fetchChatRooms(forUserID: userID)
// Both requests are running in parallel

// Combine the results in one or more expressions
return try await APIResponse(
    userProfile: userProfile,
    chatRooms: chatRooms
)
```

You use an `async let` when there's a predetermined set of tasks that will always be created in a function's scope.

### Task Groups

Task groups are more flexible, as they are created dynamically based on the requirements of the task. A great example is when you have multiple IDs that you need to resolve to objects.

```swift
func fetchUserProfiles(forUserIDs userIDs: [String]) async throws -> [UserProfile] {
    // A TaskGroup has a result type for each child task
    return try await withThrowingTaskGroup(of: UserProfile.self) { group in
        for userID in userIDs {
            // Spawns a task for each userID that needs to be resolved
            group.addTask {
                // The `fetchUserProfile` function returns UserProfile
                // This matches the result type of the TaskGroup
                return try await fetchUserProfile(forUserID: userID)
            }
        }
        
        // Now we can process the results of the tasks
        // You have various operations like `reduce` and `map` available
        // You can also the group's AsyncSequence capabilities to process the results
        var profiles = [UserProfile]()
        for try await profile in group {
            profiles.append(profile)
        }
        return profiles
    }
}
```

## Resources

1. [Introduction to Structured Concurrency](https://swiftonserver.com/getting-started-with-structured-concurrency-in-swift/)
2. [Shared Mutable State](https://swiftonserver.com/structured-concurrency-and-shared-state-in-swift/)
3. [Async Sequences](https://swiftonserver.com/advanced-async-sequences/)
4. [Talk by Franz Busch](https://www.youtube.com/watch?v=JmrnE7HUaDE), one of the lead engineers at Apple's SwiftNIO team.

