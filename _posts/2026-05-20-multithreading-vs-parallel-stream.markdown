---
layout: post
title: "multithreading vs parallel stream"
date: 2026-05-20 19:29:39 +0700
categories: [Software Development]
tags: [java, software-development, best-practices, vietnamese]
---

Trong Java, có hai cách phổ biến để xử lý tác vụ song song: **Multithreading truyền thống** (dùng `Thread`, `ExecutorService`, `CompletableFuture`) và **Parallel Stream** (từ Java 8). Tuy cùng mục đích tận dụng nhiều CPU core, nhưng chúng khác nhau về mô hình, kiểm soát, và use case phù hợp.

### # multithreading truyền thống

#### # khái niệm

Multithreading là việc tạo và quản lý nhiều thread thực thi đồng thời. Developer kiểm soát trực tiếp vòng đời thread, đồng bộ hóa, và chia sẻ tài nguyên.

#### # các api chính

```java
// 1. Thread thuần
Thread thread = new Thread(() -> processOrder(orderId));
thread.start();

// 2. ExecutorService — thread pool có quản lý
ExecutorService executor = Executors.newFixedThreadPool(10);
Future<OrderResult> future = executor.submit(() -> processOrder(orderId));
OrderResult result = future.get(); // blocking

// 3. CompletableFuture — non-blocking composition
CompletableFuture<OrderResult> cf = CompletableFuture
    .supplyAsync(() -> fetchOrder(orderId), executor)
    .thenApplyAsync(order -> enrichOrder(order), executor)
    .thenApplyAsync(order -> calculateTotal(order), executor);
```

#### # đặc điểm

| Khía cạnh      | Chi tiết                                                                 |
| -------------- | ------------------------------------------------------------------------ |
| Kiểm soát      | Toàn quyền: pool size, queue strategy, rejection policy                  |
| Thread pool    | Tự chọn: fixed, cached, scheduled, work-stealing                         |
| Error handling | Try-catch trong mỗi task, hoặc `CompletableFuture.exceptionally()`       |
| Shared state   | Phải tự đồng bộ (`synchronized`, `Lock`, `Atomic*`, `ConcurrentHashMap`) |
| Phù hợp        | I/O-bound tasks, long-running tasks, complex orchestration               |

#### # ví dụ thực tế: gọi nhiều service song song

```java
@Service
@RequiredArgsConstructor
public class OrderEnrichmentService {

    private final ExecutorService executor = Executors.newFixedThreadPool(5);
    private final CustomerClient customerClient;
    private final InventoryClient inventoryClient;
    private final PricingClient pricingClient;

    public EnrichedOrder enrich(UUID orderId) {
        CompletableFuture<Customer> customerFuture = CompletableFuture
            .supplyAsync(() -> customerClient.getCustomer(orderId), executor);

        CompletableFuture<Inventory> inventoryFuture = CompletableFuture
            .supplyAsync(() -> inventoryClient.checkStock(orderId), executor);

        CompletableFuture<Pricing> pricingFuture = CompletableFuture
            .supplyAsync(() -> pricingClient.getPrice(orderId), executor);

        // Chờ tất cả hoàn thành
        CompletableFuture.allOf(customerFuture, inventoryFuture, pricingFuture).join();

        return EnrichedOrder.builder()
            .customer(customerFuture.join())
            .inventory(inventoryFuture.join())
            .pricing(pricingFuture.join())
            .build();
    }
}
```

### # parallel stream

#### # khái niệm

Parallel Stream chia collection thành nhiều phần (split), xử lý song song trên **ForkJoinPool.commonPool()**, rồi merge kết quả. Đây là mô hình data parallelism — cùng một operation áp dụng lên nhiều phần dữ liệu.

#### # cách sử dụng

```java
// Chuyển từ sequential sang parallel
List<OrderDTO> results = orders.parallelStream()
    .filter(order -> order.getStatus() == OrderStatus.PENDING)
    .map(this::enrichOrder)
    .collect(Collectors.toList());

// Hoặc từ array
int sum = Arrays.stream(numbers).parallel().sum();
```

#### # đặc điểm

| Khía cạnh      | Chi tiết                                                          |
| -------------- | ----------------------------------------------------------------- |
| Kiểm soát      | Hạn chế: dùng common ForkJoinPool (mặc định = CPU cores - 1)      |
| Thread pool    | Common pool chia sẻ toàn JVM, hoặc custom ForkJoinPool            |
| Error handling | Exception propagate lên caller, khó handle từng phần              |
| Shared state   | KHÔNG nên có — thiết kế cho stateless operations                  |
| Phù hợp        | CPU-bound tasks trên large collections, stateless transformations |

#### # custom ForkJoinPool (tránh block common pool)

```java
ForkJoinPool customPool = new ForkJoinPool(4);
List<OrderDTO> results = customPool.submit(() ->
    orders.parallelStream()
        .map(this::cpuIntensiveTransform)
        .collect(Collectors.toList())
).get();
customPool.shutdown();
```

### # so sánh chi tiết

| Tiêu chí         | Multithreading                            | Parallel Stream                                |
| ---------------- | ----------------------------------------- | ---------------------------------------------- |
| Mô hình          | Task parallelism (nhiều task khác nhau)   | Data parallelism (cùng task, nhiều data)       |
| Kiểm soát thread | Toàn quyền (pool size, policy, lifecycle) | Hạn chế (common pool hoặc custom ForkJoinPool) |
| Use case chính   | I/O-bound, orchestration, long-running    | CPU-bound, batch processing, transformations   |
| Shared state     | Hỗ trợ (với synchronization)              | Tránh hoàn toàn                                |
| Error handling   | Linh hoạt (per-task, retry, fallback)     | Đơn giản (all-or-nothing)                      |
| Overhead         | Cao hơn (quản lý thread, context switch)  | Thấp hơn (ForkJoin tối ưu cho split/merge)     |
| Code complexity  | Cao (sync, deadlock, race condition)      | Thấp (declarative, functional)                 |
| Debugging        | Khó (non-deterministic)                   | Dễ hơn (chuyển về sequential để debug)         |
| Collection size  | Không phụ thuộc                           | Cần large collection mới hiệu quả              |

### # khi nào dùng gì?

#### # dùng multithreading khi:

- **I/O-bound tasks**: gọi HTTP, query database, đọc file
- **Cần kiểm soát thread pool**: giới hạn connection, backpressure
- **Long-running background tasks**: scheduled jobs, polling
- **Complex orchestration**: task A xong mới chạy B, C chạy song song với D
- **Cần retry/timeout/fallback**: circuit breaker pattern
- **Shared mutable state**: cần đồng bộ hóa giữa các task

```java
// Ví dụ: Gửi notification cho 1000 users với rate limiting
ExecutorService executor = new ThreadPoolExecutor(
    5, 10, 60L, TimeUnit.SECONDS,
    new LinkedBlockingQueue<>(100),
    new ThreadPoolExecutor.CallerRunsPolicy() // backpressure
);

for (User user : users) {
    executor.submit(() -> notificationService.send(user));
}
```

#### # dùng parallel stream khi:

- **CPU-bound transformations**: tính toán, mapping, filtering trên large dataset
- **Stateless operations**: không side effects, không shared state
- **Large collections**: > 10,000 elements (dưới mức này overhead > benefit)
- **Splitable data source**: ArrayList, array tốt; LinkedList, Stream.iterate() kém
- **Không có I/O trong pipeline**: tránh block ForkJoinPool threads

```java
// Ví dụ: Tính toán thống kê trên 100K records
BigDecimal totalRevenue = transactions.parallelStream()
    .filter(tx -> tx.getYear() == 2024)
    .map(Transaction::getAmount)
    .reduce(BigDecimal.ZERO, BigDecimal::add);
```

#### # không dùng parallel stream khi:

```java
// ❌ Collection nhỏ — overhead > benefit
List<String> names = List.of("A", "B", "C");
names.parallelStream().map(String::toLowerCase).toList(); // slower than sequential

// ❌ I/O operations — block common pool threads
users.parallelStream()
    .map(user -> httpClient.fetchProfile(user.getId())) // ĐỪNG
    .toList();

// ❌ Shared mutable state — race condition
List<String> results = new ArrayList<>(); // NOT thread-safe
items.parallelStream().forEach(item -> results.add(transform(item))); // BUG

// ❌ Order-dependent operations
stream.parallelStream().forEachOrdered(this::process); // negates parallelism

// ❌ LinkedList source — poor split performance
LinkedList<Item> items = ...;
items.parallelStream(); // splits poorly → unbalanced work
```

### # performance: benchmark thực tế

```java
// Setup: 1 triệu integers, CPU-bound operation (tính sqrt rồi filter)
List<Integer> numbers = IntStream.rangeClosed(1, 1_000_000).boxed().toList();

// Sequential: ~120ms
numbers.stream()
    .map(Math::sqrt)
    .filter(n -> n > 500)
    .toList();

// Parallel: ~35ms (trên 8-core machine)
numbers.parallelStream()
    .map(Math::sqrt)
    .filter(n -> n > 500)
    .toList();

// Nhưng với I/O (HTTP call):
// Sequential: 1000 calls × 100ms = 100s
// Parallel Stream (7 threads): ~14s nhưng BLOCK common pool
// ExecutorService(20 threads): ~5s và isolated
```

### # pitfalls thường gặp

#### # parallel stream pitfalls

```java
// 1. Blocking common ForkJoinPool ảnh hưởng toàn JVM
// Nếu parallel stream chứa I/O, TẤT CẢ parallel streams khác trong JVM bị chậm

// 2. Autoboxing overhead
IntStream.range(0, 1_000_000).parallel().sum(); // tốt — primitive
List<Integer> list = ...;
list.parallelStream().mapToInt(i -> i).sum(); // kém hơn — unboxing

// 3. Encounter order preservation
list.parallelStream()
    .filter(...)
    .findFirst(); // bắt buộc giữ order → giảm parallelism
// Thay bằng findAny() nếu không cần thứ tự

// 4. Collector không phù hợp
// groupingBy() với downstream không concurrent → bottleneck
list.parallelStream()
    .collect(Collectors.groupingByConcurrent(Item::getCategory)); // dùng concurrent version
```

#### # multithreading pitfalls

```java
// 1. Thread leak — quên shutdown executor
ExecutorService executor = Executors.newFixedThreadPool(10);
// ... dùng xong không shutdown → thread sống mãi

// 2. Deadlock
synchronized(lockA) {
    synchronized(lockB) { ... } // Thread 1
}
synchronized(lockB) {
    synchronized(lockA) { ... } // Thread 2 → DEADLOCK
}

// 3. Unbounded queue → OOM
Executors.newFixedThreadPool(10); // dùng LinkedBlockingQueue(Integer.MAX_VALUE)
// Nếu task produce nhanh hơn consume → queue vô hạn → OutOfMemoryError

// Fix: dùng bounded queue + rejection policy
new ThreadPoolExecutor(5, 10, 60L, TimeUnit.SECONDS,
    new LinkedBlockingQueue<>(1000),
    new ThreadPoolExecutor.CallerRunsPolicy());
```

### # virtual threads (java 21+)

Java 21 giới thiệu Virtual Threads — thay đổi cuộc chơi cho I/O-bound tasks:

```java
// Tạo 100K virtual threads — gần như không tốn memory
try (var executor = Executors.newVirtualThreadPerTaskExecutor()) {
    List<Future<Response>> futures = users.stream()
        .map(user -> executor.submit(() -> httpClient.fetch(user.getId())))
        .toList();

    List<Response> results = futures.stream()
        .map(f -> f.get())
        .toList();
}
```

| Khi nào                  | Platform Threads    | Virtual Threads | Parallel Stream |
| ------------------------ | ------------------- | --------------- | --------------- |
| I/O-bound, nhiều tasks   | ✓ (cần tuning pool) | ✓✓ (preferred)  | ✗               |
| CPU-bound, data parallel | ✗                   | ✗               | ✓✓              |
| Mixed workload           | ✓                   | ✓               | ✗               |

### # tóm tắt quyết định

```
Bạn cần xử lý song song?
│
├── Task khác nhau, cần orchestrate? → Multithreading (CompletableFuture / ExecutorService)
│   ├── I/O-bound (HTTP, DB, File)? → Virtual Threads (Java 21+) hoặc fixed thread pool
│   └── Cần retry/timeout/fallback? → CompletableFuture + custom executor
│
└── Cùng operation trên large dataset? → Parallel Stream
    ├── Collection > 10K elements? → ✓ Parallel Stream
    ├── CPU-bound (no I/O)? → ✓ Parallel Stream
    ├── Stateless, no side effects? → ✓ Parallel Stream
    └── Bất kỳ điều kiện nào = NO? → Sequential Stream hoặc Multithreading
```

### # best practices

1. **Measure before parallelizing** — dùng JMH benchmark, đừng đoán
2. **Parallel Stream**: chỉ dùng cho CPU-bound + large collection + stateless
3. **I/O tasks**: dùng `ExecutorService` hoặc Virtual Threads, KHÔNG dùng parallel stream
4. **Luôn dùng bounded queue** cho thread pool trong production
5. **Shutdown executor** trong `@PreDestroy` hoặc try-with-resources
6. **Tránh shared mutable state** — nếu bắt buộc, dùng `ConcurrentHashMap`, `AtomicReference`
7. **Debug bằng sequential trước** — chuyển `.parallelStream()` thành `.stream()` để isolate bug
8. **Monitor common pool** — nếu dùng parallel stream, monitor `ForkJoinPool.commonPool().getActiveThreadCount()`

### # kết luận

Multithreading và Parallel Stream không thay thế nhau — chúng giải quyết hai loại bài toán khác nhau. Hiểu rõ bản chất (task parallelism vs data parallelism), đặc tính workload (I/O-bound vs CPU-bound), và trade-off (control vs simplicity) sẽ giúp bạn chọn đúng công cụ cho đúng bài toán.

> Chỉ là những ghi chép cá nhân với hy vọng mang lại chút giá trị. Nếu thấy hữu ích, đừng ngại chia sẻ cho bạn bè & đồng nghiệp nhé!

Happy coding <Twemoji emoji="clinking-beer-mugs" /> 😎 👍🏻 🚀 🔥.
