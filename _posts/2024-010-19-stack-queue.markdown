---
layout: post
title: "stack & queue"
date: 2024-010-19 19:29:39 +0700
categories: [Software Development]
tags: [java, software-development, best-practices, vietnamese]
---

Dẫu hệ thống có đồ sộ nhường nào, kiến trúc có phân tán ra sao, thì ở tầng sâu nhất, dữ liệu vẫn luôn chảy qua
những cấu trúc nguyên thủy nhất: `Stack` và `Queue`.

Sự khác biệt giữa một đoạn code chạy được và một hệ thống đạt chuẩn "công nghiệp" thường nằm ở những quyết định
tưởng chừng nhỏ bé: Tại sao lại dùng `ArrayDeque` thay vì `LinkedList`? Khi nào thì khóa `(block)` một luồng và khi nào
nên để nó trôi chảy tự do (lock-free)`?

Bài viết này không chỉ liệt kê API. Hãy cùng nhau bước vào hành trình tinh gọn hóa
tư duy lập trình, dọn dẹp những "di sản" kỹ thuật cũ kỹ (như `java.util.Stack`) và chọn đúng công cụ cho từng bài toán cụ thể.

### # tổng quan

Trước khi đi sâu vào chi tiết, chúng ta cần thống nhất một góc nhìn tối giản về cách Java tổ chức các cấu trúc dữ liệu này.

- Stack (LIFO - Last In, First Out): giống như một chồng đĩa, cái nào đặt lên sau cùng sẽ được lấy ra đầu tiên.
- Queue (FIFO - First In, First Out): như dòng chảy tự nhiên của vạn vật, ai đến trước phục vụ trước.

Cây gia phả (và những đứa con bị chối bỏ):

![family-tree]({{ site.baseurl }}/assets/img/blog/family-tree.png)

### # stack

#### # concept

```
push(A) → [A]
push(B) → [A, B]
push(C) → [A, B, C]
pop()   → C, stack = [A, B]
peek()  → B (không remove)
```

#### # implementation: ArrayDeque (recommended)

```java
Deque<Integer> stack = new ArrayDeque<>();
stack.push(1);        // addFirst
stack.push(2);        // addFirst
stack.push(3);        // addFirst
stack.peek();         // 3 (top, không remove)
stack.pop();          // 3 (remove top)
stack.isEmpty();      // false
stack.size();         // 2
```

#### # tại sao KHÔNG dùng `java.util.Stack`

```java
// Stack extends Vector → synchronized mọi method (slow, unnecessary)
// Stack cho phép random access (get(index)) → vi phạm Stack abstraction
// Stack là class, không phải interface → tight coupling

Stack<Integer> bad = new Stack<>();  // DON'T
Deque<Integer> good = new ArrayDeque<>();  // DO
```

#### # use cases

- Undo/Redo operations
- Expression evaluation (postfix, infix)
- Balanced parentheses checking
- DFS (Depth-First Search)
- Call stack simulation
- Browser back/forward

#### # classic problems

##### # balanced parentheses

```java
public boolean isValid(String s) {
   Deque<Character> stack = new ArrayDeque<>();
   for (char c : s.toCharArray()) {
       if (c == '(' || c == '{' || c == '[') {
           stack.push(c);
       } else {
           if (stack.isEmpty()) return false;
           char top = stack.pop();
           if (c == ')' && top != '(') return false;
           if (c == '}' && top != '{') return false;
           if (c == ']' && top != '[') return false;
       }
   }
   return stack.isEmpty();
}
```

##### # min stack (o(1) getMin)

```java
class MinStack {
   private Deque<Integer> stack = new ArrayDeque<>();
   private Deque<Integer> minStack = new ArrayDeque<>();

   public void push(int val) {
       stack.push(val);
       if (minStack.isEmpty() || val <= minStack.peek()) {
           minStack.push(val);
       }
   }

   public void pop() {
       int val = stack.pop();
       if (val == minStack.peek()) minStack.pop();
   }

   public int getMin() { return minStack.peek(); }
}
```

### # queue

#### # concept

```
offer(A) → [A]
offer(B) → [A, B]
offer(C) → [A, B, C]
poll()   → A, queue = [B, C]
peek()   → B (không remove)
```

#### # queue interface methods

| Operation | Throws Exception                   | Returns special value |
| --------- | ---------------------------------- | --------------------- |
| Insert    | add(e) → IllegalStateException     | offer(e) → false      |
| Remove    | remove() → NoSuchElementException  | poll() → null         |
| Examine   | element() → NoSuchElementException | peek() → null         |

**Best practice:** Dùng `offer/poll/peek` (graceful handling).

#### # implementation: ArrayDeque

```java
Queue<String> queue = new ArrayDeque<>();
queue.offer("A");     // enqueue
queue.offer("B");
queue.offer("C");
queue.peek();         // "A" (front, không remove)
queue.poll();         // "A" (dequeue)
queue.size();         // 2
```

#### # use cases

- BFS (Breadth-First Search)
- Task scheduling
- Print queue
- Message buffering
- Rate limiting (sliding window)

### # deque (double-ended queue)

Có thể `add/remove` ở CẢ HAI đầu. Dùng được như cả `Stack` và `Queue`.

```java
Deque<String> deque = new ArrayDeque<>();

// As Stack (LIFO)
deque.push("A");      // addFirst
deque.pop();          // removeFirst

// As Queue (FIFO)
deque.offer("A");     // addLast
deque.poll();         // removeFirst

// Double-ended operations
deque.addFirst("A");
deque.addLast("B");
deque.peekFirst();    // "A"
deque.peekLast();     // "B"
deque.pollFirst();    // "A"
deque.pollLast();     // "B"
```

### # ArrayDeque internal

Dưới đây là hình ảnh minh họa chi tiết quá trình hoạt động của hai phép toán `addFirst` (thêm vào đầu)
và `addLast` (thêm vào cuối) trên mảng vòng đã cung cấp.

![array-deque]({{ site.baseurl }}/assets/img/blog/array-deque.png)

Hình ảnh được chia làm hai phần:

- Phần trên: Hiển thị mảng vật lý ban đầu với `Head=5` và `Tail=2`, cùng với các phần tử `[A, B, C, D, E]` được phân bố trong mảng vòng.

- Phần dưới: Chia làm hai cột để so sánh:
  - Cột trái `(addFirst)`: Minh họa chi tiết 3 bước:
    1. Dịch Head: Sử dụng công thức `head = (5 - 1) & 7 = 4`.
    2. hèn dữ liệu: Chèn phần tử mới vào ô số 4.
    3. Kết quả: Head mới ở 4, Tail vẫn ở 2.

  - Cột phải `(addLast)`: Minh họa chi tiết 3 bước:
    1. Chèn dữ liệu: Chèn phần tử mới vào ô số 2 (vị trí Tail cũ).
    2. Dịch Tail: Sử dụng công thức `tail = (2 + 1) & 7 = 3`.
    3. Kết quả: Head vẫn ở 5, Tail mới ở 3.

- Capacity luôn là power of 2 (cho bitwise AND thay vì modulo)
- Grow: double capacity khi full, copy elements
- No null elements allowed

#### # ArrayDeque vs LinkedList (as Deque)

| Tiêu chí         | ArrayDeque             | LinkedList       |
| ---------------- | ---------------------- | ---------------- |
| Memory           | Compact (array)        | 40 bytes/node    |
| Cache            | Excellent (contiguous) | Poor (scattered) |
| addFirst/addLast | O(1) amortized         | O(1)             |
| Null elements    | Not allowed            | Allowed          |
| As List          | Not a List             | Implements List  |
| Thread-safe      | No                     | No               |

→ **Kết luận:** `ArrayDeque` nhanh hơn `LinkedList` cho hầu hết `Deque/Stack/Queue` operations.

### # PriorityQueue (min-heap)

`Elements` được dequeue theo priority (smallest first by default).

```java
// Min-heap (default)
PriorityQueue<Integer> minHeap = new PriorityQueue<>();
minHeap.offer(5); minHeap.offer(1); minHeap.offer(3);
minHeap.poll(); // 1 (smallest)
minHeap.poll(); // 3
minHeap.poll(); // 5

// Max-heap
PriorityQueue<Integer> maxHeap = new PriorityQueue<>(Comparator.reverseOrder());
maxHeap.offer(5); maxHeap.offer(1); maxHeap.offer(3);
maxHeap.poll(); // 5 (largest)

// Custom priority
PriorityQueue<Task> taskQueue = new PriorityQueue<>(
   Comparator.comparingInt(Task::getPriority)
);
```

#### internal: binary heap (array-based)

```
Array: [1, 3, 5, 7, 4, 8, 6]

Tree representation:
       1
     /   \
    3     5
   / \   / \
  7   4 8   6

Parent of i: (i - 1) / 2
Left child of i: 2*i + 1
Right child of i: 2*i + 2
```

#### # complexity

| Operation        | Complexity                  |
| ---------------- | --------------------------- |
| offer(e)         | O(log n) — sift up          |
| poll()           | O(log n) — sift down        |
| peek()           | O(1)                        |
| remove(Object)   | O(n) — linear search + sift |
| contains(Object) | O(n)                        |

#### # use cases

- Dijkstra's shortest path
- Task scheduling by priority
- Merge K sorted lists
- Top-K elements
- Median finding (2 heaps)

#### top-k pattern

```java
// Find K largest elements → use min-heap of size K
public List<Integer> topK(int[] nums, int k) {
   PriorityQueue<Integer> minHeap = new PriorityQueue<>();
   for (int num : nums) {
       minHeap.offer(num);
       if (minHeap.size() > k) minHeap.poll(); // remove smallest
   }
   return new ArrayList<>(minHeap); // K largest remain
}
```

### # blockingqueue (thread-safe, producer-consumer)

Blocking operations: wait khi queue empty (take) hoặc full (put).

```java
BlockingQueue<Task> queue = new ArrayBlockingQueue<>(100); // bounded

// Producer thread
queue.put(task);  // blocks if full

// Consumer thread
Task task = queue.take();  // blocks if empty
```

#### # implementations

| Implementation        | Bounded     | Ordering   | Use case                          |
| --------------------- | ----------- | ---------- | --------------------------------- |
| ArrayBlockingQueue    | Yes (fixed) | FIFO       | Bounded producer-consumer         |
| LinkedBlockingQueue   | Optional    | FIFO       | Unbounded (careful!) or bounded   |
| PriorityBlockingQueue | No          | Priority   | Priority-based processing         |
| DelayQueue            | No          | Delay time | Scheduled tasks, retry with delay |
| SynchronousQueue      | 0 capacity  | N/A        | Direct handoff (no buffering)     |

#### # producer-consumer pattern

```java
// Shared queue
BlockingQueue<Order> orderQueue = new ArrayBlockingQueue<>(1000);

// Producer
class OrderProducer implements Runnable {
   public void run() {
       while (true) {
           Order order = receiveOrder();
           orderQueue.put(order); // blocks if queue full
       }
   }
}

// Consumer
class OrderProcessor implements Runnable {
   public void run() {
       while (true) {
           Order order = orderQueue.take(); // blocks if queue empty
           processOrder(order);
       }
   }
}

// Start multiple consumers
ExecutorService executor = Executors.newFixedThreadPool(5);
executor.submit(new OrderProducer());
for (int i = 0; i < 4; i++) {
   executor.submit(new OrderProcessor());
}
```

#### # DelayQueue

```java
class DelayedTask implements Delayed {
   private final long executeAt;
   private final Runnable task;

   public DelayedTask(Runnable task, long delayMs) {
       this.task = task;
       this.executeAt = System.currentTimeMillis() + delayMs;
   }

   @Override
   public long getDelay(TimeUnit unit) {
       return unit.convert(executeAt - System.currentTimeMillis(), TimeUnit.MILLISECONDS);
   }

   @Override
   public int compareTo(Delayed other) {
       return Long.compare(this.getDelay(TimeUnit.MILLISECONDS),
                          other.getDelay(TimeUnit.MILLISECONDS));
   }
}

DelayQueue<DelayedTask> delayQueue = new DelayQueue<>();
delayQueue.put(new DelayedTask(() -> retry(), 5000)); // execute after 5s
DelayedTask task = delayQueue.take(); // blocks until delay expires
```

### # ConcurrentLinkedQueue (lock-free)

Non-blocking, thread-safe queue dùng CAS (Compare-And-Swap).

```java
ConcurrentLinkedQueue<String> queue = new ConcurrentLinkedQueue<>();
queue.offer("A"); // never blocks, never fails
queue.poll();     // null if empty (never blocks)
```

- Không bounded (unbounded)
- Không blocking (offer/poll luôn return immediately)
- Lock-free (CAS-based, no mutex)
- size() là O(n) — phải traverse!

**Use case:** High-throughput, non-blocking scenarios. Khi không cần blocking semantics.

### # so sánh tổng hợp

| Implementation        | Thread-safe | Bounded    | Blocking | Null | Best for                     |
| --------------------- | ----------- | ---------- | -------- | ---- | ---------------------------- |
| ArrayDeque            | No          | No (grows) | No       | No   | Stack/Queue single-thread    |
| LinkedList            | No          | No         | No       | Yes  | Deque + List combo           |
| PriorityQueue         | No          | No         | No       | No   | Priority ordering            |
| ArrayBlockingQueue    | Yes         | Yes        | Yes      | No   | Bounded producer-consumer    |
| LinkedBlockingQueue   | Yes         | Optional   | Yes      | No   | Flexible producer-consumer   |
| ConcurrentLinkedQueue | Yes         | No         | No       | No   | High-throughput non-blocking |
| SynchronousQueue      | Yes         | 0          | Yes      | No   | Direct handoff               |

### # interview tips

- Stack: dùng ArrayDeque, KHÔNG dùng java.util.Stack (legacy, synchronized)
- Queue: dùng ArrayDeque (single-thread) hoặc BlockingQueue (multi-thread)
- ArrayDeque: circular array, O(1) amortized, no null, faster than LinkedList
- PriorityQueue: binary heap, O(log n) offer/poll, NOT thread-safe
- BlockingQueue: put() blocks when full, take() blocks when empty
- ConcurrentLinkedQueue: CAS-based, non-blocking, size() is O(n)
- Producer-Consumer: BlockingQueue là standard pattern
- DelayQueue: scheduled retry, delayed execution
- SynchronousQueue: zero capacity, direct handoff between threads

> Chỉ là những ghi chép cá nhân với hy vọng mang lại chút giá trị. Nếu thấy hữu ích, đừng ngại chia sẻ cho bạn bè & đồng nghiệp nhé!

Happy coding <Twemoji emoji="clinking-beer-mugs" /> 😎 👍🏻 🚀 🔥.
