---
layout: post
title: "java concurrency"
date: 2024-03-20 19:29:39 +0700
categories: [Software Development]
tags: [java, software-development, concurrency, best-practices, vietnamese]
---

Trong bối cảnh các hệ thống backend hiện đại luôn đòi hỏi khả năng xử lý đồng thời (concurrency) với hiệu năng cao
và độ trễ thấp, Java 21 kết hợp cùng Spring Boot 3.x đã mang đến những bước tiến đột phá về mặt kiến trúc.

Bài viết này là một "knowledge guide" chuyên sâu, đúc kết các pattern, best practices và cả những "hố bom" (pitfalls) cần tránh khi làm việc với hệ sinh thái concurrency thế hệ mới của Java.

### # virtual threads (project loom) — java 21

#### # khái niệm cốt lõi

Virtual Threads là lightweight threads do JVM quản lý, mount/unmount trên carrier (platform) threads khi gặp blocking I/O. Khác platform threads (1:1 với OS thread), virtual threads có thể tạo hàng triệu mà không hết memory.

```java
// Tạo virtual thread trực tiếp
Thread.startVirtualThread(() -> doWork());

// Factory pattern — có naming cho debug/logging
ThreadFactory factory = Thread.ofVirtual()
       .name("my-vt-", 0)  // tên prefix + counter
       .factory();

// Executor pattern — mỗi task 1 virtual thread
ExecutorService executor = Executors.newVirtualThreadPerTaskExecutor();

// Scheduled executor với virtual threads
ScheduledExecutorService scheduler = Executors.newSingleThreadScheduledExecutor(
       Thread.ofVirtual().name("cache-cleanup").factory()
);
```

#### # khi nào dùng virtual threads

| Phù hợp                                     | Không phù hợp                                 |
| ------------------------------------------- | --------------------------------------------- |
| I/O-bound: HTTP calls, DB queries, file I/O | CPU-bound: số học nặng, image processing      |
| Fan-out nhiều request song song             | Tasks cần thread affinity (ThreadLocal heavy) |
| Event listeners, message consumers          | Synchronized blocks dài (pin carrier thread)  |
| Async fire-and-forget operations            | Real-time latency-critical paths              |

#### # pitfalls

- **Pinning**: Khối lệnh `synchronized` hoặc các native method (JNI) sẽ "khóa" (pin) carrier thread bên dưới, làm mất tác dụng của Virtual Threads. Giải pháp: Thay thế bằng `ReentrantLock`.
- **ThreadLocal**: Dù vẫn được hỗ trợ, nhưng nếu bạn tạo hàng triệu virtual threads có chứa ThreadLocal, memory footprint sẽ phình to nhanh chóng. Giải pháp: Ưu tiên `ScopedValue`.
- **Pool sizing vô nghĩa**: Đối với Virtual Threads, khái niệm "Pool" là vô nghĩa. newVirtualThreadPerTaskExecutor() tạo một thread độc lập cho mỗi task và không giới hạn size.
- **Connection pool exhaustion**: Ảo hóa thread không có nghĩa là ảo hóa tài nguyên vật lý. Hàng triệu virtual threads có thể đánh sập Database Connection Pool hoặc giới hạn I/O. Giải pháp: Bắt buộc dùng cơ chế Throttling (như Semaphore).

#### # spring boot integration

```yaml
# application.yml — enable globally
spring:
  threads:
    virtual:
      enabled: true
```

Khi enabled, Spring Boot 3.2+ tự động:

- Tomcat sử dụng virtual threads cho request handling
- `@Async` methods chạy trên virtual threads
- RabbitMQ listener threads là virtual

### # ScopedValue (java 21 preview) — thay thế ThreadLocal

#### # vấn đề với ThreadLocal

- Tính khả biến (Mutable): Dễ gây race conditions nếu chia sẻ trạng thái giữa luồng cha và con.
- Rò rỉ bộ nhớ (Memory Leak): Đòi hỏi vòng đời dọn dẹp thủ công (manual cleanup).
- Chi phí kế thừa: Kế thừa ngữ cảnh xuống luồng con bằng InheritableThreadLocal là một thao tác cực kỳ đắt đỏ, đặc biệt là khi đi kèm với Virtual Threads.

#### # ScopedValue pattern

```java
// Khai báo — Bất biến (Immutable) và gắn chặt với một Scope nhất định
public static final ScopedValue<String> REQUEST_ID = ScopedValue.newInstance();

// Ràng buộc (Bind) và Thực thi
ScopedValue.where(REQUEST_ID, "trace-123").run(() -> {
   // REQUEST_ID.get() = "trace-123" trong scope này
   doWork();
});

// Read — throws NoSuchElementException nếu chưa bound
String id = REQUEST_ID.get();

// Truy xuất linh hoạt (Kiểm tra kỹ trước khi đọc để tránh NoSuchElementException)
if (REQUEST_ID.isBound()) {
   String id = REQUEST_ID.get();
}
```

#### # so sánh

| Feature                 | ThreadLocal          | ScopedValue                |
| ----------------------- | -------------------- | -------------------------- |
| Mutability              | Mutable (set/get)    | Immutable trong scope      |
| Inheritance             | Manual (Inheritable) | Tự động trong scope        |
| Memory                  | Mỗi thread 1 copy    | Shared, rebind per scope   |
| Virtual Thread friendly | Không (heavy)        | Có (lightweight)           |
| Cleanup                 | Manual `.remove()`   | Tự động khi scope kết thúc |

### # context propagation across threads

Khi khởi tạo luồng mới (bất kể là Platform hay Virtual), toàn bộ ngữ cảnh từ luồng cha như TraceId, MDC (Logging), Security Context hay Locale sẽ biến mất. Trong các hệ thống phân tán, mất dấu vết (trace) là một thảm họa.

#### # TaskDecorator pattern

```java
public class ContextPropagatingDecorator implements TaskDecorator {
   @Override
   public Runnable decorate(Runnable runnable) {
       // 1. Chụp lại (Capture) toàn bộ context từ luồng gọi (Caller Thread)
       String traceId = RequestContext.getRequestId();
       Map<String, String> mdc = MDC.getCopyOfContextMap();
       Locale locale = LocaleContextHolder.getLocale();

       // 2. Đóng gói vào một Runnable mới
       return () -> {
           // 3. Phục hồi (Restore) context tại luồng thực thi (Worker Thread)
           if (mdc != null) MDC.setContextMap(mdc);
           LocaleContextHolder.setLocale(locale);
           try {
               ScopedValue.where(RequestContext.REQUEST_ID, traceId)
                   .run(runnable);
           } finally {
                // 4. Dọn dẹp sạch sẽ
               MDC.clear();
               LocaleContextHolder.resetLocaleContext();
           }
       };
   }
}
```

#### # BeanPostProcessor cho auto-decoration

Inject TaskDecorator vào tất cả executor beans tự động, để không phải cấu hình thủ công cho từng Executor::

```java
@Component
public class ExecutorContextInjector implements BeanPostProcessor {
   @Override
   public Object postProcessAfterInitialization(Object bean, String beanName) {
       if (bean instanceof ThreadPoolTaskExecutor executor) {
           // Compose với existing decorator, không override
           executor.setTaskDecorator(new ContextPropagatingDecorator());
       }
       if (bean instanceof AsyncTaskExecutor asyncExecutor) {
           return new TracePropagatingWrapper(asyncExecutor);
       }
       return bean;
   }
}
```

**Note**: KHÔNG thay thế bean bằng lambda/wrapper khác type → gây `BeanNotOfRequiredTypeException`. Phải preserve original bean type.

### # @Async pattern

Cú pháp đơn giản nhất để chạy bất đồng bộ trong Spring, nhưng cần tuân thủ một số quy tắc để tránh "bẫy" phổ biến.

```java
@Service
public class NotificationService {

   // Fire-and-forget
   @Async
   public void sendEmail(String to, String body) {
       // runs on async executor
   }

   // Return result
   @Async
   public CompletableFuture<Report> generateReport(String id) {
       Report report = heavyComputation(id);
       return CompletableFuture.completedFuture(report);
   }

   // Chỉ định executor cụ thể
   @Async("auditExecutor")
   public void audit(AuditEvent event) {
       // runs on named executor
   }
}
```

#### # luật bất thành văn @async

- Method PHẢI public (bản chất Spring sử dụng proxy-based AOP)
- Tuyệt đối không gọi hàm @Async từ một hàm khác trong cùng một class (Self-invocation sẽ đi xuyên qua lớp Proxy, chạy đồng bộ như hàm bình thường).
- Exception sinh ra trong hàm void sẽ bị "nuốt" mất — Hãy chủ động thiết lập Error Logging hoặc ExceptionHandler.
- Exception trong CompletableFuture → propagate khi `.join()` / `.get()`
- Cần đánh dấu @EnableAsync ở tầng cấu hình một (và chỉ một) lần.

#### # custom Executor

```java
@Configuration
public class AsyncConfig {

   @Bean(name = "auditExecutor")
   public AsyncTaskExecutor auditExecutor() {
       ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
       executor.setCorePoolSize(2);
       executor.setMaxPoolSize(5);
       executor.setQueueCapacity(100);
       executor.setThreadNamePrefix("audit-");
       executor.setRejectionHandler(new CallerRunsPolicy());
       executor.initialize();
       return executor;
   }
}
```

### # CompletableFuture patterns

#### # fan-out / fan-in - phân tán & gom tụ

```java
// Chạy nhiều tasks song song, đợi tất cả
CompletableFuture<List<Label>> labelsFuture = CompletableFuture.supplyAsync(
   () -> labelService.verify(metadata), executor);
CompletableFuture<Boolean> mimeFuture = CompletableFuture.supplyAsync(
   () -> mimeService.check(file), executor);

// Đợi tất cả hoàn thành
CompletableFuture.allOf(labelsFuture, mimeFuture).join();

// Lấy kết quả (đã complete)
List<Label> labels = labelsFuture.join();
Boolean mimeOk = mimeFuture.join();
```

#### # chaining - xử lý lỗi định tuyến

```java
CompletableFuture.supplyAsync(() -> fetchData(), executor)
   .thenApply(data -> transform(data))
   .thenAccept(result -> save(result))
   .exceptionally(ex -> {
       log.error("Pipeline failed", ex);
       return null;
   });
```

#### # timeout handling

```java
CompletableFuture<Result> future = CompletableFuture.supplyAsync(() -> slowOp());
Result result = future.orTimeout(5, TimeUnit.SECONDS)  // Java 9+
   .exceptionally(ex -> fallback());
```

#### # gotchas

- `.join()` ném `CompletionException` (unchecked) — `.get()` ném `ExecutionException` (checked)
- Không truyền executor → dùng ForkJoinPool.commonPool() (platform threads, limited)
- `allOf().join()` nếu 1 task fail → exception. Dùng `handle()` nếu muốn partial results
- Virtual thread + CompletableFuture: luôn truyền explicit executor

### # semaphore-based concurrency control

Như đã đề cập, Virtual Threads sinh ra vô hạn có thể đánh gục các External API hoặc Database. Sử dụng Semaphore là chốt chặn phòng ngự hiệu quả.

```java
@Component
public class ThrottledExecutor {
   private final ExecutorService executor;
   private final Semaphore semaphore;

   public ThrottledExecutor(
       @Value("${max.concurrent:50}") int maxConcurrent,
       @Value("${use.virtual:true}") boolean useVirtual
   ) {
       this.executor = useVirtual
           ? Executors.newVirtualThreadPerTaskExecutor()
           : new ThreadPoolExecutor(4, 50, 60, SECONDS, new LinkedBlockingQueue<>(500));

       // Semaphore = null nếu unlimited
       this.semaphore = maxConcurrent > 0 ? new Semaphore(maxConcurrent) : null;
   }

   public <T> CompletableFuture<T> submit(Callable<T> task) {
       return CompletableFuture.supplyAsync(() -> {
           acquire();
           try {
               return task.call();
           } catch (Exception e) {
               throw new RuntimeException(e);
           } finally {
               release();
           }
       }, executor);
   }

   private void acquire() {
       if (semaphore != null) {
           try { semaphore.acquire(); }
           catch (InterruptedException e) {
               Thread.currentThread().interrupt();
               throw new RuntimeException("Interrupted waiting for permit", e);
           }
       }
   }

   private void release() {
       if (semaphore != null) semaphore.release();
   }
}
```

### # ApplicationEvent + async multicaster

Tách rời logic nghiệp vụ (Decoupling) bằng mô hình Publisher - Listener.

#### # pattern: async event handling

```java
// Event class
public class OrderCreatedEvent extends ApplicationEvent {
   private final Order order;
   public OrderCreatedEvent(Object source, Order order) {
       super(source);
       this.order = order;
   }
}

// Publisher
@Service
public class OrderService {
   private final ApplicationEventPublisher publisher;

   public void createOrder(OrderRequest req) {
       Order order = save(req);
       publisher.publishEvent(new OrderCreatedEvent(this, order));
   }
}

// Listener — runs async nhờ multicaster config
@Component
public class NotificationListener {
   @EventListener
   public void onOrderCreated(OrderCreatedEvent event) {
       // chạy trên virtual thread (nếu multicaster dùng VT executor)
       sendNotification(event.getOrder());
   }
}
```

#### # multicaster config cho virtual threads

Để các Listener thực sự chạy Async bằng Virtual Threads, hãy tinh chỉnh Multicaster:

```java
@Configuration
public class EventConfig {
   @Bean(name = "applicationEventMulticaster")
   public ApplicationEventMulticaster multicaster() {
       SimpleApplicationEventMulticaster m = new SimpleApplicationEventMulticaster();

       ExecutorService vtExecutor = Executors.newThreadPerTaskExecutor(
           Thread.ofVirtual().name("event-vt-", 0).factory()
       );

       // Wrap với context propagation
       TaskExecutorAdapter adapter = new TaskExecutorAdapter(vtExecutor);
       TaskDecorator decorator = new ContextPropagatingDecorator();
       m.setTaskExecutor(task -> adapter.execute(decorator.decorate(task)));

       return m;
   }
}
```

**Lưu ý**: Multicaster async = tất cả @EventListener chạy async. Nếu cần sync cho một số event → dùng `@TransactionalEventListener` hoặc handle riêng.

### # deferredresult — non-blocking controller response

#### # pattern

```java
@RestController
public class ReportController {

   @GetMapping("/reports/{id}")
   public DeferredResult<ResponseEntity<?>> getReport(@PathVariable String id) {
       DeferredResult<ResponseEntity<?>> result = new DeferredResult<>(5000L);

       // Capture context từ request thread
       String traceId = RequestContext.getRequestId();
       Map<String, String> mdc = MDC.getCopyOfContextMap();

       Thread.startVirtualThread(() -> {
           if (mdc != null) MDC.setContextMap(mdc);
           RequestContext.runWith(traceId, () -> {
               try {
                   Report report = reportService.generate(id);
                   result.setResult(ResponseEntity.ok(report));
               } catch (Exception e) {
                   result.setErrorResult(e);
               } finally {
                   MDC.clear();
               }
           });
       });

       result.onTimeout(() ->
           result.setResult(ResponseEntity.status(408).body("Timeout")));

       return result;
   }
}
```

#### # khi nào dùng DeferredResult

- Request cần xử lý lâu hơn Tomcat thread timeout
- Muốn free Tomcat thread sớm cho request khác
- Response phụ thuộc vào external event (callback, message)

#### # so sánh với virtual threads trên tomcat

Nếu `spring.threads.virtual.enabled=true`, Tomcat đã dùng virtual threads → DeferredResult ít cần thiết hơn vì blocking trên virtual thread không tốn OS thread. Vẫn hữu ích khi cần explicit timeout control hoặc event-driven response.

### # thread safety trong spring beans

#### # singleton scope (default)

Mặc định các Spring Beans mang vòng đời Singleton (được chia sẻ bởi tất cả các request threads).

```java
@Service
public class UserService {
   // SAFE: final, immutable reference
   private final UserRepository repo;

   // UNSAFE: mutable shared state
   private int counter = 0; // ← race condition

   // SAFE: thread-safe collection
   private final AtomicInteger safeCounter = new AtomicInteger(0);

   // UNSAFE: non-thread-safe collection
   private final List<String> cache = new ArrayList<>(); // ← concurrent modification

   // SAFE: thread-safe collection
   private final List<String> safeCache = new CopyOnWriteArrayList<>();
}
```

#### # quy tắc

- KHÔNG lưu mutable state trong singleton bean
- Request-scoped data → dùng method parameters, ScopedValue, hoặc RequestScope bean
- Nếu cần shared mutable state → dùng `Atomic*`, `ConcurrentHashMap`, hoặc explicit locking
- `@Scope("prototype")` tạo instance mới mỗi lần inject — KHÔNG phải mỗi request

### # structured concurrency (preview — java 21+)

#### # concept

Một mô hình xử lý đa luồng có tính tổ chức chặt chẽ: Gom nhóm các task có quan hệ logic, hủy toàn bộ nếu một nhánh thất bại, và quy hoạch vòng đời rõ ràng.

```java
// Requires: --enable-preview
try (var scope = new StructuredTaskScope.ShutdownOnFailure()) {
   Subtask<User> userTask = scope.fork(() -> fetchUser(id));
   Subtask<List<Order>> ordersTask = scope.fork(() -> fetchOrders(id));

   scope.join();           // Block chờ toàn bộ nhánh con
   scope.throwIfFailed();  // Quăng exception ngay nếu có bất kỳ nhánh nào ngã ngựa

   User user = userTask.get();
   List<Order> orders = ordersTask.get();
   return new UserProfile(user, orders);
}
// Nếu fetchUser() fail → fetchOrders() bị cancel tự động
```

Vẻ đẹp của kiến trúc này: Nếu fetchProfile() sập, fetchOrders() sẽ tự động nhận tín hiệu CANCEL.

#### # khi nào dùng

- Fan-out tasks có quan hệ (tất cả thành công hoặc tất cả fail)
- Thay thế `CompletableFuture.allOf()` khi cần proper cancellation
- Task hierarchy có parent-child relationship

#### # lưu ý

- Vẫn preview trong Java 21 — cần `--enable-preview`
- Spring chưa integrate native — dùng manual trong service layer

### # common anti-patterns

| Anti-Pattern                         | Vấn đề                     | Fix                                    |
| ------------------------------------ | -------------------------- | -------------------------------------- |
| `synchronized` với virtual threads   | Pin carrier thread         | Dùng `ReentrantLock`                   |
| ThreadLocal cho request context      | Memory leak với VT         | Dùng `ScopedValue`                     |
| Unbounded virtual thread spawn       | Exhaust DB connections     | Semaphore throttling                   |
| `.get()` không timeout               | Thread block vĩnh viễn     | `.orTimeout()` hoặc `.get(5, SECONDS)` |
| Shared mutable state trong singleton | Race condition             | Atomic types hoặc immutable            |
| `@Async` self-invocation             | Method không chạy async    | Tách ra service khác                   |
| `new Thread()` trong Spring          | Không context propagation  | Dùng executor bean                     |
| `CompletableFuture` không executor   | Dùng common pool (limited) | Luôn truyền explicit executor          |

### # configuration properties

```yaml
# Virtual threads
spring:
  threads:
    virtual:
      enabled: true

# Custom executor tuning
app:
  executor:
    use-virtual-thread: true
    max-concurrent-tasks: 50 # Semaphore permits (0 = unlimited)
    pool-size: 4 # fallback platform thread pool
    max-pool-size: 50
    queue-capacity: 500
    ttl: 60 # keep-alive seconds
```

### # decision matrix

| Scenario                          | Approach                                |
| --------------------------------- | --------------------------------------- |
| Simple fire-and-forget            | `@Async` void method                    |
| Need result from async            | `@Async` + `CompletableFuture<T>`       |
| Multiple parallel calls, wait all | `CompletableFuture.allOf()`             |
| Event-driven decoupling           | `ApplicationEvent` + async multicaster  |
| Non-blocking controller           | `DeferredResult` + virtual thread       |
| I/O heavy batch processing        | Virtual thread executor + Semaphore     |
| CPU-bound computation             | Platform thread pool (bounded)          |
| Related tasks, cancel-on-failure  | Structured Concurrency (preview)        |
| Scheduled periodic tasks          | `ScheduledExecutorService` + VT factory |

> Chỉ là những ghi chép cá nhân với hy vọng mang lại chút giá trị. Nếu thấy hữu ích, đừng ngại chia sẻ cho bạn bè & đồng nghiệp nhé!

Happy coding <Twemoji emoji="clinking-beer-mugs" /> 😎 👍🏻 🚀 🔥.
