---
layout: post
title: "java advanced performance techniques"
date: 2026-05-29 19:29:39 +0700
categories: [Software Development]
tags: [java, software-development, optimization, best-practices, vietnamese]
---

Bài viết này đi sâu vào các kỹ thuật tối ưu **cấp hệ thống** mà senior engineers và framework authors sử dụng. Đây không phải kiến thức để dùng hàng ngày — mà là vũ khí để triển khai khi profiler chỉ ra bottleneck thực sự.

> "Premature optimization is the root of all evil" — Donald Knuth
>
> Nhưng khi bạn đã đo, đã chứng minh, và cần tốc độ — đây là cách đạt được nó.

### # branchless programming — khi cpu đoán sai

#### # tại sao branch prediction quan trọng

CPU hiện đại hoạt động như dây chuyền nhà máy (pipeline) với 14-20 stages. Để giữ pipeline đầy, CPU dùng **Branch Predictor** — đoán trước kết quả `if/else` và thực thi speculative. Khi đoán đúng: zero cost. Khi đoán sai (**branch misprediction**): CPU flush toàn bộ pipeline, mất **12-25 clock cycles** — tương đương hàng chục phép tính bị vứt.

Với data có pattern rõ ràng (sorted, mostly true/false), branch predictor đoán đúng >95%. Nhưng với **random data** (hash values, network packets, game state), misprediction rate lên 30-50%.

#### # branchless trong java — thực tế

Java không cho phép inline assembly, nhưng JIT compiler có thể convert certain patterns thành conditional moves (CMOV) — instruction không tạo branch.

```java
// Branch-heavy: mỗi iteration = 1 branch prediction
// Với random data: ~50% misprediction
public static int conditionalSum(int[] data) {
   int sum = 0;
   for (int val : data) {
       if (val >= 128) {  // Branch: predicted or mispredicted
           sum += val;
       }
   }
   return sum;
}

// ✅ Branchless: arithmetic thay thế branch
// JIT compiler thường convert sang CMOV instruction
public static int branchlessSum(int[] data) {
   int sum = 0;
   for (int val : data) {
       // (val - 128) >> 31 = 0 khi val >= 128, = -1 (all 1s) khi val < 128
       // ~((val - 128) >> 31) = -1 khi val >= 128, = 0 khi val < 128
       // val & mask = val khi mask = -1, = 0 khi mask = 0
       int mask = ~((val - 128) >> 31);
       sum += val & mask;
   }
   return sum;
}
```

#### # math-based branchless patterns

```java
// Branching min/max
public static int branchingMax(int a, int b) {
   return a > b ? a : b;  // Branch — nhưng JIT thường optimize
}

// ✅ Branchless max (khi JIT KHÔNG optimize, hoặc trong interpreted mode)
public static int branchlessMax(int a, int b) {
   // Khi a > b: a - b > 0, sign bit = 0, >> 31 = 0
   // Khi a <= b: a - b < 0, sign bit = 1, >> 31 = -1 (all 1s)
   int diff = a - b;
   int sign = diff >> 31;          // 0 if a >= b, -1 if a < b
   return a - (diff & sign);       // a - 0 = a, hoặc a - (a-b) = b
   // CẢNH BÁO: overflow khi |a - b| > Integer.MAX_VALUE
}

// ✅ Branchless absolute value
public static int branchlessAbs(int n) {
   int mask = n >> 31;        // 0 nếu positive, -1 nếu negative
   return (n ^ mask) - mask;  // flip bits + add 1 cho negative (two's complement)
}

// ✅ Branchless clamp (giới hạn value trong [min, max])
public static int branchlessClamp(int val, int min, int max) {
   // Math.max(min, Math.min(val, max)) — nhưng branchless
   int clamped = val - max;
   clamped &= clamped >> 31;   // 0 nếu val > max, negative value nếu val <= max
   clamped += max;              // clamp trên

   int lower = clamped - min;
   lower &= ~(lower >> 31);    // 0 nếu clamped < min
   return lower + min;          // clamp dưới
}
```

#### # branchless lookup (boolean to int conversion)

```java
// Java boolean comparison → thường tạo branch
// ✅ Convert boolean condition thành 0/1 integer arithmetic

// Tính phí giao dịch: VIP = 0%, Normal = 2%
// Don't
double fee = isVip ? 0.0 : amount * 0.02;

// Do - Branchless (hữu ích khi gọi triệu lần với random isVip)
// Boolean.compare(isVip, false) = 1 khi true, 0 khi false
int notVip = 1 - Boolean.compare(isVip, false);  // 0 khi VIP, 1 khi không
double fee = amount * 0.02 * notVip;
```

#### # khi nào branchless thực sự giúp ích trong java?

| Scenario                                     | Branch OK?                    | Branchless?   |
| -------------------------------------------- | ----------------------------- | ------------- |
| Sorted/predictable data                      | ✅ Branch predictor đúng >95% | Không cần     |
| Random data, hot loop (>1M iterations)       | ❌ Misprediction penalty cao  | ✅ Xem xét    |
| Business logic (if/else rõ ràng)             | ✅ Readability quan trọng hơn | Không bao giờ |
| Inner loop của game engine/signal processing | ❌ Mỗi nanosecond count       | ✅ Benchmark  |
| JIT-compiled code (production, warm JVM)     | ✅ JIT thường tự optimize     | Profile trước |

**Cảnh báo**: JIT compiler của HotSpot cực kỳ thông minh. Nó tự convert `Math.min/max`, ternary, và simple if/else thành CMOV khi detect pattern. Trước khi viết branchless thủ công, **benchmark với JMH** để chắc chắn JIT chưa optimize rồi.

### # autoboxing — thuế ẩn trong java enterprise

#### # chi phí thực sự của autoboxing

Mỗi lần Java auto-convert `int` → `Integer` (autoboxing), một object mới được tạo trên heap (trừ cached range -128..127). Với high-throughput systems, đây là "thuế vô hình" ăn mòn performance.

```java
// Memory layout comparison:
// int:     4 bytes (stack hoặc inline trong array)
// Integer: 16 bytes object header + 4 bytes value + 4 bytes padding = 24 bytes (heap)
// → 6x memory overhead cho MỖI element

// Autoboxing trap #1: Map với primitive keys
Map<Long, String> cache = new HashMap<>();
for (long id = 0; id < 1_000_000; id++) {
   cache.put(id, "value");  // id auto-boxed → 1M Long objects → ~24MB wasted
}

// Autoboxing trap #2: Generic methods
public static <T extends Comparable<T>> T max(T a, T b) {
   return a.compareTo(b) >= 0 ? a : b;
}
int result = max(x, y);  // x, y boxed → Integer, result unboxed → int
// 2 boxing + 1 unboxing PER CALL

// Autoboxing trap #3: Stream operations
long sum = longList.stream()
   .filter(x -> x > 100)     // x unboxed for comparison
   .map(x -> x * 2)          // x unboxed, result RE-BOXED
   .reduce(0L, Long::sum);   // unbox both, sum, RE-BOX accumulator
// MỖIMỖI pipeline stage = unbox + rebox

// Fix: dùng primitive streams
long sum = longList.stream()
   .mapToLong(Long::longValue)  // unbox ONCE
   .filter(x -> x > 100)        // primitive operations from here
   .map(x -> x * 2)
   .sum();                       // primitive sum, no boxing
```

#### # phát hiện autoboxing trong production

```java
// JFR (Java Flight Recorder) — monitor allocations
// jcmd <pid> JFR.start name=boxing duration=60s filename=boxing.jfr

// JMH benchmark with -prof gc
// @Benchmark reports gc.alloc.rate — nếu cao bất thường → boxing

// IntelliJ inspection: "Auto-boxing" → highlight tất cả boxing sites
// IDE settings: Inspections → Java → Performance → "Auto-boxing"
```

#### # giải pháp cấp kiến trúc

```java
// ✅ Strategy 1: Primitive-specialized collections
// Eclipse Collections
import org.eclipse.collections.impl.map.mutable.primitive.LongObjectHashMap;
LongObjectHashMap<String> cache = new LongObjectHashMap<>();
cache.put(42L, "value");  // NO boxing — stores raw long

// ✅ Strategy 2: Value-based classes + JIT optimization
// Java records thường được JIT inline (escape analysis)
record PricePoint(long timestamp, double price) {}
// JIT có thể scalarize record fields → zero heap allocation

// ✅ Strategy 3: Redesign API to accept primitives
// ❌
public void processOrder(Long orderId, Integer quantity, Double price) { }
// ✅
public void processOrder(long orderId, int quantity, double price) { }
// Caller không bị boxing penalty

// ✅ Strategy 4: Primitive OptionalLong/OptionalInt thay vì Optional<Long>
// ❌
Optional<Long> findPrice(String product);  // Long boxing
// ✅
OptionalLong findPrice(String product);  // No boxing
```

### # enumset & bit masking — power tool cho feature flags

#### # enumset internals — array of bits

`EnumSet` là Java's built-in bitmask cho enums. Với ≤64 enum constants, internally nó chỉ là **1 long** (64 bits). Mọi operations (add, remove, contains, union, intersection) = bitwise operations = O(1).

```java
public enum Permission {
   VIEW_DASHBOARD,    // bit 0
   EDIT_FORM,         // bit 1
   DELETE_FORM,       // bit 2
   MANAGE_USERS,      // bit 3
   DEPLOY_PROCESS,    // bit 4
   VIEW_AUDIT_LOG,    // bit 5
   EXPORT_DATA,       // bit 6
   MANAGE_ROLES,      // bit 7
   SYSTEM_CONFIG,     // bit 8
   VIEW_REPORTS       // bit 9
}

// Role definitions — compile-time constant bit patterns
public static final EnumSet<Permission> VIEWER = EnumSet.of(
   Permission.VIEW_DASHBOARD, Permission.VIEW_REPORTS
);  // Internal: 0000_0010_0000_0001

public static final EnumSet<Permission> EDITOR = EnumSet.of(
   Permission.VIEW_DASHBOARD, Permission.EDIT_FORM,
   Permission.VIEW_REPORTS, Permission.EXPORT_DATA
);  // Internal: 0000_0010_0100_0011

public static final EnumSet<Permission> ADMIN = EnumSet.allOf(Permission.class);
// Internal: 0000_0011_1111_1111

// Check permission — O(1) bitwise AND
public boolean hasPermission(EnumSet<Permission> userPerms, Permission required) {
   return userPerms.contains(required);  // Internally: (bits & (1L << ordinal)) != 0
}

// Check ALL required permissions — O(1) containsAll
public boolean hasAllPermissions(EnumSet<Permission> userPerms, EnumSet<Permission> required) {
   return userPerms.containsAll(required);  // Internally: (bits & required) == required
}

// Combine permissions — O(1) OR
public EnumSet<Permission> mergeRoles(EnumSet<Permission> role1, EnumSet<Permission> role2) {
   EnumSet<Permission> combined = EnumSet.copyOf(role1);
   combined.addAll(role2);  // Internally: bits |= other.bits
   return combined;
}
```

#### # persist enumset as bitmask in database

```java
// Store permissions as BIGINT in PostgreSQL (single column, no join table)
@Entity
public class UserRole {
   @Id
   private UUID id;
   private String name;

   // Store as long bitmask
   @Column(name = "permissions_mask")
   private long permissionsMask;

   // Convert to/from EnumSet
   @Transient
   public EnumSet<Permission> getPermissions() {
       EnumSet<Permission> set = EnumSet.noneOf(Permission.class);
       for (Permission p : Permission.values()) {
           if ((permissionsMask & (1L << p.ordinal())) != 0) {
               set.add(p);
           }
       }
       return set;
   }

   public void setPermissions(EnumSet<Permission> permissions) {
       this.permissionsMask = 0L;
       for (Permission p : permissions) {
           this.permissionsMask |= (1L << p.ordinal());
       }
   }
}

// Query: find users with DEPLOY_PROCESS permission
// SQL: WHERE permissions_mask & 16 != 0  (bit 4 = 2^4 = 16)
@Query("SELECT u FROM UserRole u WHERE (u.permissionsMask & :mask) = :mask")
List<UserRole> findByPermission(@Param("mask") long mask);
```

#### # so sánh performance vs alternatives

| Approach                         | Memory/User                           | Contains check     | Add/Remove     | DB storage           |
| -------------------------------- | ------------------------------------- | ------------------ | -------------- | -------------------- |
| `EnumSet<Permission>` (10 perms) | 1 long = 8 bytes                      | O(1) bitwise       | O(1) bitwise   | 1 BIGINT column      |
| `Set<String>` (10 perms)         | ~400 bytes (HashSet + String objects) | O(1) hash + equals | O(1) amortized | JOIN table hoặc JSON |
| `List<Permission>` (10 perms)    | ~200 bytes (ArrayList + enum refs)    | O(n) linear scan   | O(n) shift     | JOIN table           |
| Boolean fields (10 perms)        | 10 bytes (padded)                     | O(1) field access  | O(1) field set | 10 columns           |

EnumSet wins on: memory, speed, và DB simplicity. Trade-off: ordinal-dependent persistence (thêm enum constant ở giữa = break data).

### # virtual threads — giải phóng throughput i/o-bound (java 21+)

#### # vấn đề với platform threads

Mỗi platform thread = 1 OS thread ≈ 1MB stack. Server với 200 threads = 200MB stack alone. Khi thread blocked on I/O (DB call, HTTP call), OS thread bị giữ idle — lãng phí.

Hệ quả: Với 200 threads, server chỉ xử lý 200 concurrent requests. Request thứ 201 phải đợi.

#### # virtual threads — lightweight, millions possible

Virtual threads (Java 21) là **user-mode threads** do JVM quản lý. Khi virtual thread blocked on I/O, JVM **unmount** nó khỏi carrier thread (platform thread) và mount virtual thread khác lên. Carrier thread KHÔNG BAO GIỜ bị idle.

```java
// Platform thread: 1 request = 1 OS thread (giới hạn ~200-500 threads)
// Virtual thread: 1 request = 1 virtual thread (có thể 1M+ concurrent)

// ✅ Spring Boot 3.2+ — bật virtual threads (1 dòng config)
// application.yml:
// spring:
//   threads:
//     virtual:
//       enabled: true
// → Tomcat dùng virtual threads cho mỗi request
// → @Async tasks chạy trên virtual threads
// → Scheduler tasks dùng virtual threads

// ✅ Tự tạo virtual thread executor
ExecutorService executor = Executors.newVirtualThreadPerTaskExecutor();

// Xử lý 10,000 concurrent HTTP calls — KHÔNG cần reactive/WebFlux
List<Future<String>> futures = new ArrayList<>();
for (String url : urls) {  // 10,000 URLs
   futures.add(executor.submit(() -> {
       // Mỗi call block 200ms trung bình
       // Platform threads: 200 threads × 200ms = 1000 req/s
       // Virtual threads: 10,000 concurrent = 50,000 req/s (cùng hardware)
       return httpClient.send(
           HttpRequest.newBuilder().uri(URI.create(url)).build(),
           HttpResponse.BodyHandlers.ofString()
       ).body();
   }));
}

// Structured Concurrency (Java 21 preview) — clean error handling
try (var scope = new StructuredTaskScope.ShutdownOnFailure()) {
   Subtask<User> userTask = scope.fork(() -> userService.getUser(id));
   Subtask<List<Order>> ordersTask = scope.fork(() -> orderService.getOrders(id));
   Subtask<Double> balanceTask = scope.fork(() -> accountService.getBalance(id));

   scope.join();           // Wait for all
   scope.throwIfFailed();  // Propagate first failure

   // All completed successfully — combine results
   return new UserProfile(userTask.get(), ordersTask.get(), balanceTask.get());
   // 3 I/O calls chạy song song, tổng latency = max(3 calls) thay vì sum(3 calls)
}
```

#### # virtual threads — khi nào dùng, khi nào không

```java
// ✅ DÙNG cho I/O-bound workloads:
// - REST API calls to downstream services
// - Database queries (JDBC)
// - File I/O
// - Message queue operations (RabbitMQ consume/produce)
// - Anything that spends most time WAITING

// ❌ KHÔNG dùng cho CPU-bound workloads:
// - Heavy computation (encryption, compression, ML inference)
// - Image/video processing
// - Complex mathematical calculations
// Lý do: Virtual threads không tăng CPU throughput — vẫn limited by cores
// Dùng ForkJoinPool hoặc parallel streams cho CPU-bound

// ❌ KHÔNG dùng với synchronized blocks giữ lâu (pinning problem)
// synchronized block PIN virtual thread vào carrier — blocking carrier
synchronized (lock) {
   database.query(...);  // ❌ Virtual thread PINNED → carrier thread blocked
}

// ✅ Thay bằng ReentrantLock
private final ReentrantLock lock = new ReentrantLock();
lock.lock();
try {
   database.query(...);  // ✅ Virtual thread can unmount during I/O
} finally {
   lock.unlock();
}
```

#### # đo lường hiệu quả virtual threads

```java
// JFR events cho virtual threads:
// jdk.VirtualThreadStart, jdk.VirtualThreadEnd
// jdk.VirtualThreadPinned — QUAN TRỌNG: detect pinning issues

// System property để detect pinning at runtime:
// -Djdk.tracePinnedThreads=short
// Output warning khi virtual thread bị pinned

// Metric comparison (REST API, 1000 concurrent users, 100ms DB latency):
// Platform threads (200 pool): throughput = 2,000 req/s, p99 = 500ms (queuing)
// Virtual threads: throughput = 9,500 req/s, p99 = 110ms (no queuing)
```

### # hibernate/jpa performance traps — thuế "tiện lợi"

#### # n+1 query problem — kẻ giết performance #1

```java
// ❌ N+1: Load 100 orders → triggers 100 separate queries for items
@Entity
public class Order {
   @OneToMany(mappedBy = "order", fetch = FetchType.LAZY)
   private List<OrderItem> items;  // LAZY = good default, BUT...
}

// Khi access items trong loop:
List<Order> orders = orderRepository.findAll();  // 1 query: SELECT * FROM orders
for (Order order : orders) {
   order.getItems().size();  // 100 queries: SELECT * FROM order_items WHERE order_id = ?
}
// Tổng: 101 queries thay vì 1

// ✅ Fix 1: JOIN FETCH (eager load in JPQL)
@Query("SELECT o FROM Order o JOIN FETCH o.items WHERE o.status = :status")
List<Order> findByStatusWithItems(@Param("status") OrderStatus status);
// 1 query: SELECT ... FROM orders JOIN order_items ...

// ✅ Fix 2: @EntityGraph (declarative fetch plan)
@EntityGraph(attributePaths = {"items", "items.product"})
List<Order> findByStatus(OrderStatus status);
// 1 query with LEFT JOIN

// ✅ Fix 3: @BatchSize (batch lazy loading — best for collections)
@Entity
public class Order {
   @OneToMany(mappedBy = "order")
   @BatchSize(size = 50)  // Load items for 50 orders at once
   private List<OrderItem> items;
}
// 100 orders → 2 queries (batches of 50) thay vì 101 queries
```

#### # dirty checking overhead — hibernate luôn theo dõi

```java
// Hibernate snapshot TOÀN BỘ entity khi load → so sánh khi flush
// 10,000 entities loaded = 10,000 snapshots in memory + O(n) comparison at flush

// ❌ Load nhiều entity chỉ để đọc
@Transactional
public List<ProductDTO> getAllProducts() {
   List<Product> products = productRepository.findAll();  // 10K entities tracked
   return products.stream().map(this::toDTO).toList();
   // Flush time: Hibernate so sánh 10K snapshots (dù không thay đổi gì)
}

// ✅ Fix 1: Read-only transaction (skip dirty checking)
@Transactional(readOnly = true)
public List<ProductDTO> getAllProducts() {
   // Hibernate skip dirty checking for read-only TX
   List<Product> products = productRepository.findAll();
   return products.stream().map(this::toDTO).toList();
}

// ✅ Fix 2: Projection/DTO query (bypass entity tracking entirely)
@Query("SELECT new vn.com.vpbank.internal.csp.product.dto.ProductSummaryDTO(" +
      "p.id, p.name, p.price) FROM Product p WHERE p.status = 'ACTIVE'")
List<ProductSummaryDTO> findActiveSummaries();
// KHÔNG tạo entity, KHÔNG snapshot, KHÔNG dirty check — pure DTO

// ✅ Fix 3: StatelessSession cho bulk reads
Session session = entityManager.unwrap(Session.class);
StatelessSession stateless = session.getSessionFactory().openStatelessSession();
// StatelessSession: no first-level cache, no dirty checking, no cascades
// Perfect for batch processing millions of rows
```

#### # open session in view — anti-pattern ẩn

```java
// spring.jpa.open-in-view=true (DEFAULT in Spring Boot!)
// → Hibernate Session mở suốt HTTP request lifecycle
// → Lazy loading works in Controller/View layer (tiện)
// → Database connection held cho TOÀN BỘ request duration (NGUY HIỂM)

// Vấn đề: Request mất 2s (1.9s render JSON, 0.1s DB query)
// → DB connection bị giữ 2s thay vì 0.1s
// → Connection pool exhausted dưới load

// ✅ Fix: Tắt OSIV, eager fetch những gì cần
# application.yml:
# spring:
#   jpa:
#     open-in-view: false

// Và fetch đầy đủ data trong Service layer (trước khi TX đóng)
@Service
@Transactional(readOnly = true)
public class OrderService {
   public OrderDetailDTO getOrderDetail(UUID id) {
       Order order = orderRepository.findByIdWithItemsAndCustomer(id);
       // JOIN FETCH tất cả cần thiết → không lazy load ngoài TX
       return mapper.toDetailDTO(order);
   }
}
```

### # json serialization — thuế serialization

#### # jackson performance tuning

Mỗi REST API request trong Spring Boot đều trải qua: **Object → JSON (serialize)** và **JSON → Object (deserialize)**. Với hàng ngàn requests/second, Jackson serialization trở thành CPU hotspot đáng kể.

```java
// ❌ Default ObjectMapper — reflection-based, slow for first calls
// Jackson dùng reflection để inspect fields → tạo serializer/deserializer
// First serialize: ~500μs (reflection + cache build)
// Subsequent: ~5-50μs (cached serializers)

// ✅ Strategy 1: Reuse ObjectMapper (Spring Boot mặc định làm đúng)
// KHÔNG BAO GIỜ tạo new ObjectMapper() trong method — nó thread-safe, share được
@Configuration
public class JacksonConfig {
   @Bean
   public ObjectMapper objectMapper() {
       return JsonMapper.builder()
           .addModule(new JavaTimeModule())
           .disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS)
           .disable(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES)
           // ✅ Afterburner: bytecode generation thay vì reflection
           .addModule(new AfterburnerModule())  // 20-30% faster serialization
           .build();
   }
}
// Dependency: com.fasterxml.jackson.module:jackson-module-afterburner

// ✅ Strategy 2: Blackbird (Java 9+ replacement for Afterburner)
// Dùng java.lang.invoke.LambdaMetafactory thay vì bytecode generation
.addModule(new BlackbirdModule())  // Tương đương Afterburner, cleaner cho modern JVMs
// Dependency: com.fasterxml.jackson.module:jackson-module-blackbird

// ✅ Strategy 3: Avoid serializing unnecessary fields
@JsonInclude(JsonInclude.Include.NON_NULL)  // Skip null fields → smaller JSON, less work
public class ProductDTO {
   private UUID id;
   private String name;
   private BigDecimal price;

   @JsonIgnore  // Never serialize — internal field
   private String internalCode;

   @JsonProperty(access = JsonProperty.Access.WRITE_ONLY)  // Deserialize only
   private String secretToken;
}

// ✅ Strategy 4: Custom serializer cho hot DTOs
// Khi 1 DTO được serialize hàng triệu lần, custom serializer > reflection
public class ProductDTOSerializer extends JsonSerializer<ProductDTO> {
   @Override
   public void serialize(ProductDTO dto, JsonGenerator gen,
                         SerializerProvider provider) throws IOException {
       gen.writeStartObject();
       gen.writeStringField("id", dto.getId().toString());
       gen.writeStringField("name", dto.getName());
       gen.writeNumberField("price", dto.getPrice().doubleValue());
       gen.writeEndObject();
       // Direct field writes — no reflection, no introspection
   }
}
```

#### # streaming json cho large responses

```java
// ❌ Build entire list in memory → serialize all at once
@GetMapping("/products/export")
public List<ProductDTO> exportAll() {
   return productService.findAll();  // 100K objects in memory simultaneously
   // Jackson serializes toàn bộ List → massive heap usage → GC pressure
}

// ✅ Stream + Jackson Streaming API — constant memory
@GetMapping("/products/export")
public ResponseEntity<StreamingResponseBody> exportAll() {
   return ResponseEntity.ok()
       .contentType(MediaType.APPLICATION_JSON)
       .body(outputStream -> {
           try (JsonGenerator gen = objectMapper.getFactory()
                   .createGenerator(outputStream, JsonEncoding.UTF8)) {
               gen.writeStartArray();

               productRepository.streamAll().forEach(product -> {
                   try {
                       gen.writeObject(mapper.toDTO(product));
                       gen.flush();  // Flush periodically — don't buffer everything
                   } catch (IOException e) {
                       throw new UncheckedIOException(e);
                   }
               });

               gen.writeEndArray();
           }
       });
   // Memory: O(1) — only 1 product in memory at a time
}
```

#### # alternative: protocol buffers cho internal service communication

```java
// Jackson JSON: human-readable, ~50μs serialize, ~100 bytes overhead per object
// Protobuf: binary, ~5μs serialize, ~10 bytes overhead per object
// → 10x faster, 10x smaller cho inter-service calls

// Khi CSP services gọi nhau (console → bpm-runtime → repo):
// REST + JSON: đơn giản, debug-friendly, standard
// gRPC + Protobuf: 10x throughput cho high-frequency internal calls

// Trade-off decision:
// External APIs (client-facing): JSON (compatibility, readability)
// Internal hot paths (service-to-service): consider Protobuf/gRPC
```

### # graalvm native image — khởi động trong milliseconds

#### # vấn đề: jvm startup time

Spring Boot app truyền thống: **3-15 giây** khởi động (class loading, annotation scanning, bean creation, JIT warmup). Trong serverless/container environments, mỗi cold start = user-visible latency.

#### # native image giải quyết gì

GraalVM Native Image compile Java bytecode thành **native binary** tại build time (Ahead-of-Time compilation). Kết quả:

- Startup: **50-100ms** (thay vì 3-15s)
- Memory: **50-80MB** (thay vì 200-500MB)
- No JIT warmup — peak performance from first request

```xml
<!-- pom.xml: Spring Boot 3.x native support -->
<plugin>
   <groupId>org.graalvm.buildtools</groupId>
   <artifactId>native-maven-plugin</artifactId>
</plugin>

<!-- Build native image -->
<!-- mvn -Pnative native:compile -->
<!-- Output: target/my-service (single executable binary, ~80MB) -->
```

#### # trade-offs và limitations

```java
// ✅ Hoạt động tốt với Native Image:
// - Standard Spring Boot controllers, services, repositories
// - Spring Data JPA (với proper hints)
// - Spring Security (basic configurations)
// - RestTemplate, WebClient

// ❌ Không hoạt động (hoặc cần config thủ công):
// - Runtime reflection (phải declare trước trong reflect-config.json)
// - Dynamic proxies (JDK proxy cần declare, CGLIB không support)
// - Resource loading từ classpath (cần resource-config.json)
// - Serialization (cần serialization-config.json)

// Spring Boot 3.x generates hints automatically cho most cases
// Nhưng third-party libraries có thể cần manual hints:

// reflect-config.json
[
 {
   "name": "vn.com.vpbank.internal.csp.dto.ProductDTO",
   "allDeclaredConstructors": true,
   "allDeclaredFields": true,
   "allDeclaredMethods": true
 }
]

// ❌ KHÔNG phù hợp cho:
// - Applications dùng heavy reflection (Activiti engine, complex Hibernate mappings)
// - Long-running services hưởng lợi từ JIT optimization (JIT > AOT cho peak throughput)
// - Services cần dynamic class loading

// ✅ PHÙ HỢP cho:
// - Lightweight microservices (config-service, discovery, proxy)
// - Serverless functions (AWS Lambda, Azure Functions)
// - CLI tools
// - Services cần fast startup (auto-scaling, spot instances)
```

#### # so sánh thực tế

| Metric          | JVM (Hotspot)              | Native Image   |
| --------------- | -------------------------- | -------------- |
| Startup time    | 3-15s                      | 50-100ms       |
| Memory (idle)   | 200-500MB                  | 50-80MB        |
| Peak throughput | Higher (JIT optimized)     | 10-20% lower   |
| Build time      | 10-30s                     | 3-10 minutes   |
| Debug-ability   | Full (JFR, JMX, profilers) | Limited        |
| Reflection      | Full support               | Requires hints |

### # caffeine cache — local cache "không rác"

#### # tại sao không chỉ dùng redis?

Redis = network call (~0.5-2ms round-trip). Cho data accessed hàng nghìn lần/second, network overhead > computation cost. **Caffeine** = in-process cache, **O(nanoseconds)** access, zero network.

```java
// Architecture: Request → Caffeine (L1, in-process) → Redis (L2, distributed) → DB (L3)
// Cache hit L1: ~50ns
// Cache hit L2: ~1-2ms (network)
// Cache miss (DB): ~5-50ms

// ✅ Spring Boot + Caffeine configuration
// Dependency: com.github.ben-manes.caffeine:caffeine

@Configuration
@EnableCaching
public class CacheConfig {

   @Bean
   public CacheManager cacheManager() {
       CaffeineCacheManager manager = new CaffeineCacheManager();
       manager.setCaffeine(Caffeine.newBuilder()
           .maximumSize(10_000)              // Max 10K entries
           .expireAfterWrite(Duration.ofMinutes(5))  // TTL 5 minutes
           .recordStats()                    // Enable metrics
       );
       return manager;
   }

   // Hoặc per-cache configuration
   @Bean
   public CacheManager cacheManager() {
       SimpleCacheManager manager = new SimpleCacheManager();
       manager.setCaches(List.of(
           buildCache("products", 5000, Duration.ofMinutes(10)),
           buildCache("users", 1000, Duration.ofMinutes(30)),
           buildCache("permissions", 2000, Duration.ofMinutes(5))
       ));
       return manager;
   }

   private CaffeineCache buildCache(String name, int maxSize, Duration ttl) {
       return new CaffeineCache(name, Caffeine.newBuilder()
           .maximumSize(maxSize)
           .expireAfterWrite(ttl)
           .recordStats()
           .build());
   }
}
```

#### # sử dụng với spring @cacheable

```java
@Service
@RequiredArgsConstructor
public class ProductService {

   private final ProductRepository productRepository;

   // ✅ Cache kết quả — subsequent calls skip DB entirely
   @Cacheable(value = "products", key = "#id")
   public ProductDTO getProduct(UUID id) {
       return productRepository.findById(id)
           .map(this::toDTO)
           .orElseThrow(() -> new EntityNotFoundException("Product not found"));
       // First call: DB query + cache result
       // Subsequent calls: return from Caffeine (~50ns)
   }

   // ✅ Invalidate khi data thay đổi
   @CacheEvict(value = "products", key = "#id")
   public ProductDTO updateProduct(UUID id, UpdateProductDTO dto) {
       Product product = productRepository.findById(id).orElseThrow();
       product.setName(dto.getName());
       product.setPrice(dto.getPrice());
       return toDTO(productRepository.save(product));
   }

   // ✅ Invalidate toàn bộ cache
   @CacheEvict(value = "products", allEntries = true)
   public void refreshCache() {
       log.info("Products cache invalidated");
   }

   // ✅ Conditional caching — chỉ cache khi result != null
   @Cacheable(value = "products", key = "#code", unless = "#result == null")
   public ProductDTO findByCode(String code) {
       return productRepository.findByCode(code)
           .map(this::toDTO)
           .orElse(null);
   }
}
```

#### # caffeine advanced: async loading + multi-level cache

```java
// ✅ AsyncLoadingCache — non-blocking cache population
@Component
public class ProductCacheService {

   private final AsyncLoadingCache<UUID, ProductDTO> cache;

   public ProductCacheService(ProductRepository repo, ProductMapper mapper) {
       this.cache = Caffeine.newBuilder()
           .maximumSize(10_000)
           .expireAfterWrite(Duration.ofMinutes(5))
           .refreshAfterWrite(Duration.ofMinutes(1))  // Background refresh
           .buildAsync((key, executor) -> CompletableFuture.supplyAsync(() ->
               repo.findById(key).map(mapper::toDTO).orElse(null), executor
           ));
       // refreshAfterWrite: sau 1 phút, lần access tiếp → return stale value
       // + trigger async refresh in background → next access gets fresh value
       // → User KHÔNG BAO GIỜ thấy latency spike từ cache miss
   }

   public CompletableFuture<ProductDTO> getProduct(UUID id) {
       return cache.get(id);  // Non-blocking, returns CompletableFuture
   }
}

// ✅ Two-level cache: Caffeine (L1) + Redis (L2)
@Service
@RequiredArgsConstructor
public class TwoLevelCacheService {

   private final Cache<String, ProductDTO> localCache = Caffeine.newBuilder()
       .maximumSize(5000)
       .expireAfterWrite(Duration.ofSeconds(30))  // Short TTL for consistency
       .build();

   private final RedisTemplate<String, ProductDTO> redisTemplate;
   private final ProductRepository repository;

   public ProductDTO getProduct(String id) {
       // L1: Local cache (nanoseconds)
       ProductDTO cached = localCache.getIfPresent(id);
       if (cached != null) return cached;

       // L2: Redis (milliseconds)
       cached = redisTemplate.opsForValue().get("product:" + id);
       if (cached != null) {
           localCache.put(id, cached);  // Populate L1
           return cached;
       }

       // L3: Database (tens of milliseconds)
       ProductDTO fresh = repository.findById(UUID.fromString(id))
           .map(this::toDTO)
           .orElseThrow();

       // Populate both levels
       redisTemplate.opsForValue().set("product:" + id, fresh, Duration.ofMinutes(10));
       localCache.put(id, fresh);
       return fresh;
   }
}
```

#### # caffeine eviction strategies

| Strategy            | Config                            | Use Case                              |
| ------------------- | --------------------------------- | ------------------------------------- |
| Size-based          | `.maximumSize(N)`                 | Bounded memory, LRU-like eviction     |
| Weight-based        | `.maximumWeight(N).weigher(...)`  | Heterogeneous entry sizes             |
| Time-based (write)  | `.expireAfterWrite(duration)`     | Data có known TTL                     |
| Time-based (access) | `.expireAfterAccess(duration)`    | Session-like data                     |
| Reference-based     | `.weakValues()` / `.softValues()` | GC-friendly, memory-pressure eviction |

### # data locality trong java — SoA pattern thực chiến

#### # vấn đề: java object layout

Mỗi Java object trên heap có **16 bytes header** (mark word + klass pointer, compressed oops). Một `Point { double x; double y; }` = 16 header + 8 + 8 = **32 bytes**. Array of 1M Points = 1M pointers (8 bytes each) + 1M objects (32 bytes each, scattered across heap) = **~40MB**, non-contiguous.

CPU cache line = 64 bytes. Khi iterate array of objects, mỗi `points[i].x` = **pointer chase** → random memory access → cache miss → **~100 clock cycles** penalty (vs 4 cycles cho cache hit).

#### # struct of arrays (SoA) — cache-friendly alternative

```java
// ❌ Array of Structs (AoS) — default Java style
// Memory layout: [ptr0][ptr1][ptr2]... → [hdr|x0|y0|vx0|vy0] [hdr|x1|y1|vx1|vy1]...
// Khi chỉ cần x,y → load cả vx,vy vào cache line = waste 50% bandwidth
class Particle {
   double x, y;    // position
   double vx, vy;  // velocity
   int color;      // rendering only
   boolean active; // logic only
}
Particle[] particles = new Particle[1_000_000];  // 1M pointers + 1M scattered objects

// Tính toán physics (chỉ cần x, y, vx, vy — không cần color, active):
for (Particle p : particles) {
   p.x += p.vx * dt;  // Cache miss: load toàn bộ object (48+ bytes) cho 2 fields
   p.y += p.vy * dt;
}

// ✅ Struct of Arrays (SoA) — group by access pattern
// Memory layout: [x0|x1|x2|x3|...] [y0|y1|y2|y3|...] [vx0|vx1|...] [vy0|vy1|...]
// Khi cần x → CPU prefetcher load sequential doubles → cache hit mọi access
class ParticleSystem {
   int count;
   double[] xs;     // All X positions contiguous
   double[] ys;     // All Y positions contiguous
   double[] vxs;    // All X velocities contiguous
   double[] vys;    // All Y velocities contiguous
   int[] colors;    // Separate — not loaded during physics
   boolean[] active; // Separate — not loaded during physics

   public ParticleSystem(int capacity) {
       this.count = 0;
       this.xs = new double[capacity];
       this.ys = new double[capacity];
       this.vxs = new double[capacity];
       this.vys = new double[capacity];
       this.colors = new int[capacity];
       this.active = new boolean[capacity];
   }

   // Physics update: CPU prefetcher LOVES this pattern
   // Sequential access → every cache line fully utilized
   public void updatePositions(double dt) {
       for (int i = 0; i < count; i++) {
           xs[i] += vxs[i] * dt;   // xs[] contiguous → prefetch works perfectly
           ys[i] += vys[i] * dt;   // ys[] contiguous → same
       }
       // JIT compiler có thể AUTO-VECTORIZE loop này (SIMD)
       // → Process 4 doubles per instruction (AVX2)
   }

   // Rendering: chỉ load positions + colors (skip velocities)
   public void render(Graphics g) {
       for (int i = 0; i < count; i++) {
           g.setColor(colors[i]);
           g.drawCircle(xs[i], ys[i], 3);
           // colors[], xs[], ys[] contiguous — 3 cache-friendly arrays
           // vxs[], vys[] KHÔNG bị load vào cache → more room for useful data
       }
   }
}
```

#### # SoA trong spring boot — batch processing thực tế

```java
// Scenario: Tính discount cho 100K products mỗi đêm
// Input: product prices + categories + stock levels
// Logic: discount phụ thuộc price + category (KHÔNG cần name, description, images...)

// ❌ AoS: Load full Product entities
@Scheduled(cron = "0 0 2 * * *")
public void calculateNightlyDiscounts() {
   List<Product> products = productRepository.findAll();  // 100K full objects
   // Mỗi Product: id, name, description, price, category, stock, images, metadata...
   // Memory: ~500 bytes/product × 100K = 50MB (chỉ cần ~20 bytes/product)
   for (Product p : products) {
       double discount = computeDiscount(p.getPrice(), p.getCategory(), p.getStock());
       p.setDiscount(discount);
   }
   productRepository.saveAll(products);
}

// ✅ SoA: Query chỉ columns cần thiết, process in parallel arrays
@Scheduled(cron = "0 0 2 * * *")
public void calculateNightlyDiscounts() {
   // Projection query — chỉ lấy 4 fields
   List<Object[]> rows = entityManager.createNativeQuery(
       "SELECT id, price, category, stock_level FROM products WHERE status = 'ACTIVE'"
   ).getResultList();

   int size = rows.size();
   UUID[] ids = new UUID[size];
   double[] prices = new double[size];
   int[] categories = new int[size];
   int[] stocks = new int[size];

   // Unpack into parallel arrays (SoA layout)
   for (int i = 0; i < size; i++) {
       Object[] row = rows.get(i);
       ids[i] = (UUID) row[0];
       prices[i] = ((Number) row[1]).doubleValue();
       categories[i] = ((Number) row[2]).intValue();
       stocks[i] = ((Number) row[3]).intValue();
   }

   // Compute discounts — cache-friendly sequential access
   double[] discounts = new double[size];
   for (int i = 0; i < size; i++) {
       discounts[i] = computeDiscount(prices[i], categories[i], stocks[i]);
   }

   // Batch update
   jdbcTemplate.batchUpdate(
       "UPDATE products SET discount = ? WHERE id = ?",
       new BatchPreparedStatementSetter() { /* ... */ }
   );
}
```

### # lookup tables (LUTs) — precomputation strategy

#### # nguyên lý: đánh đổi memory lấy cpu cycles

Thay vì tính toán runtime, **tính trước mọi kết quả** và lưu trong array. Truy xuất = `array[index]` = O(1), 1 memory access.

```java
// ❌ Runtime computation: sin() mỗi frame (floating point = expensive)
// Giả sử game loop 60fps, 10K particles mỗi frame = 600K sin() calls/second
public double getAngle(int degreeTenths) {
   return Math.sin(Math.toRadians(degreeTenths / 10.0));
}

// ✅ Precomputed sine table — 1 memory read thay vì floating point computation
public class SineLUT {
   // 3600 entries = 0.0° to 359.9° (precision 0.1°)
   private static final double[] SIN_TABLE = new double[3600];
   private static final double[] COS_TABLE = new double[3600];

   static {
       for (int i = 0; i < 3600; i++) {
           double radians = Math.toRadians(i / 10.0);
           SIN_TABLE[i] = Math.sin(radians);
           COS_TABLE[i] = Math.cos(radians);
       }
   }

   // O(1) lookup — ~4 clock cycles (cache hit) vs ~20-50 cycles (Math.sin)
   public static double sin(int degreeTenths) {
       return SIN_TABLE[((degreeTenths % 3600) + 3600) % 3600];
   }

   public static double cos(int degreeTenths) {
       return COS_TABLE[((degreeTenths % 3600) + 3600) % 3600];
   }
}
```

#### # LUT cho business logic — status/fee calculation

```java
// Scenario: Tính phí giao dịch dựa trên (loại giao dịch × hạng khách hàng × kênh)
// 5 loại × 4 hạng × 3 kênh = 60 combinations
// ❌ Nested if/else hoặc switch: O(branches), hard to maintain, error-prone

// ✅ 3D Lookup Table — O(1) access, dễ cập nhật
public class FeeCalculator {
   // Dimensions: [transactionType][customerTier][channel]
   private static final double[][][] FEE_TABLE = new double[5][4][3];

   static {
       // Load from config/database at startup
       // Hoặc hardcode:
       // FEE_TABLE[TRANSFER][VIP][MOBILE] = 0.001;
       // FEE_TABLE[TRANSFER][NORMAL][COUNTER] = 0.005;
       initFromConfig();
   }

   // O(1) fee lookup — zero branching, zero computation
   public static double getFeeRate(TransactionType type, CustomerTier tier, Channel channel) {
       return FEE_TABLE[type.ordinal()][tier.ordinal()][channel.ordinal()];
   }

   // Hot-reload từ database (runtime config change)
   @Scheduled(fixedRate = 60_000)  // Refresh mỗi phút
   public void refreshFeeTable() {
       List<FeeConfig> configs = feeConfigRepository.findAll();
       for (FeeConfig config : configs) {
           FEE_TABLE[config.getType().ordinal()]
                    [config.getTier().ordinal()]
                    [config.getChannel().ordinal()] = config.getRate();
       }
   }
}
```

#### # LUT cho validation — character classification

```java
// ❌ String-based validation (tạo strings, regex, multiple comparisons)
public boolean isValidIdentifier(String s) {
   return s.matches("[a-zA-Z_][a-zA-Z0-9_]*");  // Regex = expensive per call
}

// ✅ Lookup table: O(1) per character check
public class CharClassifier {
   // 128 ASCII entries — boolean array indexed by char value
   private static final boolean[] IS_IDENTIFIER_START = new boolean[128];
   private static final boolean[] IS_IDENTIFIER_PART = new boolean[128];

   static {
       for (char c = 'a'; c <= 'z'; c++) { IS_IDENTIFIER_START[c] = true; IS_IDENTIFIER_PART[c] = true; }
       for (char c = 'A'; c <= 'Z'; c++) { IS_IDENTIFIER_START[c] = true; IS_IDENTIFIER_PART[c] = true; }
       for (char c = '0'; c <= '9'; c++) { IS_IDENTIFIER_PART[c] = true; }
       IS_IDENTIFIER_START['_'] = true;
       IS_IDENTIFIER_PART['_'] = true;
   }

   public static boolean isValidIdentifier(String s) {
       if (s == null || s.isEmpty()) return false;
       char first = s.charAt(0);
       if (first >= 128 || !IS_IDENTIFIER_START[first]) return false;
       for (int i = 1; i < s.length(); i++) {
           char c = s.charAt(i);
           if (c >= 128 || !IS_IDENTIFIER_PART[c]) return false;
       }
       return true;
       // O(n) scan nhưng mỗi check = 1 array access (vs regex backtracking)
   }
}
```

### # memory pooling nâng cao — arena allocation (java 22+)

#### # vấn đề sâu hơn object pooling

Object pooling (đã cover ở high-performance-java-techniques) giải quyết reuse. Nhưng với **off-heap memory** (native memory, direct ByteBuffers), vấn đề phức tạp hơn:

- `ByteBuffer.allocateDirect()` = system call, expensive (~microseconds)
- Native memory leaks nếu quên `Cleaner`/`free()`
- GC không quản lý off-heap → manual lifecycle

#### # MemorySegment arena (java 22+ foreign function & memory api)

```java
// ✅ Arena-based allocation — deterministic deallocation, no GC pressure
import java.lang.foreign.*;

// Confined arena: memory freed khi close(), scoped to 1 thread
try (Arena arena = Arena.ofConfined()) {
   // Allocate 1MB off-heap buffer — no GC involvement
   MemorySegment buffer = arena.allocate(1024 * 1024);

   // Allocate structured data (like C struct)
   MemorySegment point = arena.allocate(ValueLayout.JAVA_DOUBLE, 2);
   point.setAtIndex(ValueLayout.JAVA_DOUBLE, 0, 3.14);  // x
   point.setAtIndex(ValueLayout.JAVA_DOUBLE, 1, 2.71);  // y

   // Allocate array of 10,000 doubles (contiguous, off-heap)
   MemorySegment prices = arena.allocateArray(ValueLayout.JAVA_DOUBLE, 10_000);
   for (int i = 0; i < 10_000; i++) {
       prices.setAtIndex(ValueLayout.JAVA_DOUBLE, i, computePrice(i));
   }
   // Process prices — data is contiguous, cache-friendly
   processContiguous(prices, 10_000);

}  // ALL memory freed instantly here — no GC, no finalizers, deterministic

// Shared arena: accessible from multiple threads
Arena shared = Arena.ofShared();
MemorySegment sharedBuffer = shared.allocate(4096);
// ... pass to multiple threads ...
shared.close();  // Free when done — thread-safe close

// Auto arena: memory freed by GC (like DirectByteBuffer, but safer API)
Arena auto = Arena.ofAuto();
MemorySegment managed = auto.allocate(1024);
// Freed when arena is garbage collected — no explicit close needed
```

#### # practical use: high-throughput network buffer pool

```java
// Scenario: Server xử lý 100K connections, mỗi connection cần read/write buffer
// Allocate/free ByteBuffer liên tục = expensive, fragmented

public class DirectBufferPool {
   private final int bufferSize;
   private final Queue<MemorySegment> pool;
   private final Arena arena;  // Long-lived arena for pool buffers

   public DirectBufferPool(int bufferSize, int poolSize) {
       this.bufferSize = bufferSize;
       this.pool = new ConcurrentLinkedQueue<>();
       this.arena = Arena.ofShared();

       // Pre-allocate all buffers in one large allocation (contiguous)
       MemorySegment bulk = arena.allocate((long) bufferSize * poolSize);
       for (int i = 0; i < poolSize; i++) {
           pool.offer(bulk.asSlice((long) i * bufferSize, bufferSize));
       }
   }

   public MemorySegment acquire() {
       MemorySegment seg = pool.poll();
       if (seg != null) return seg;
       // Pool exhausted — allocate new (should be rare if pool sized correctly)
       return arena.allocate(bufferSize);
   }

   public void release(MemorySegment seg) {
       // Zero-out for security, then return to pool
       seg.fill((byte) 0);
       pool.offer(seg);
   }

   public void shutdown() {
       arena.close();  // Free ALL pooled memory at once
   }
}
```

### # lock-free nâng cao — beyond AtomicInteger

#### # compare-and-swap (cas) — cơ chế phần cứng

CAS là **single CPU instruction** (x86: `CMPXCHG`). Nó atomically: đọc value → so sánh với expected → nếu bằng, ghi new value. Không cần OS lock, không context switch.

```java
// CAS pseudo-code (thực tế là 1 CPU instruction):
// boolean CAS(address, expectedValue, newValue) {
//     if (*address == expectedValue) {
//         *address = newValue;
//         return true;   // Success
//     }
//     return false;      // Someone else changed it — retry
// }

// ✅ CAS-based stack (lock-free, obstruction-free)
public class LockFreeStack<E> {
   private final AtomicReference<Node<E>> top = new AtomicReference<>(null);

   private static class Node<E> {
       final E item;
       Node<E> next;
       Node(E item, Node<E> next) { this.item = item; this.next = next; }
   }

   public void push(E item) {
       Node<E> newNode = new Node<>(item, null);
       Node<E> currentTop;
       do {
           currentTop = top.get();
           newNode.next = currentTop;
       } while (!top.compareAndSet(currentTop, newNode));
       // CAS loop: retry nếu another thread modified top giữa get() và compareAndSet()
       // Trong practice: retry rất ít lần (1-3) trừ extreme contention
   }

   public E pop() {
       Node<E> currentTop;
       Node<E> newTop;
       do {
           currentTop = top.get();
           if (currentTop == null) return null;  // Empty stack
           newTop = currentTop.next;
       } while (!top.compareAndSet(currentTop, newTop));
       return currentTop.item;
   }
}
```

#### # varhandle — modern cas api (java 9+)

```java
// VarHandle: type-safe, performance-equivalent to Unsafe, legal API
// Thay thế sun.misc.Unsafe cho CAS operations

public class LockFreeCounter {
   private volatile long value;

   private static final VarHandle VALUE_HANDLE;
   static {
       try {
           VALUE_HANDLE = MethodHandles.lookup()
               .findVarHandle(LockFreeCounter.class, "value", long.class);
       } catch (Exception e) {
           throw new ExceptionInInitializerError(e);
       }
   }

   public long incrementAndGet() {
       long current;
       long next;
       do {
           current = (long) VALUE_HANDLE.getVolatile(this);
           next = current + 1;
       } while (!VALUE_HANDLE.compareAndSet(this, current, next));
       return next;
   }

   // Memory ordering options (từ weak → strong):
   // getOpaque()    — no ordering guarantees (fastest)
   // getAcquire()   — acquire semantics (reads after this see updates)
   // getVolatile()  — full volatile (sequential consistency)

   // setOpaque()    — no ordering
   // setRelease()   — release semantics (writes before this visible)
   // setVolatile()  — full volatile

   // weakCompareAndSet() — may spuriously fail (dùng trong loops anyway)
   // compareAndSet()     — strong, never spuriously fails
}
```

#### # false sharing — cache line contention ẩn

```java
// Vấn đề: 2 threads write vào 2 biến khác nhau
// NHƯNG 2 biến nằm trên CÙNG cache line (64 bytes)
// → CPU phải invalidate cache line liên tục giữa cores = performance collapse

// ❌ False sharing: counters cạnh nhau trong memory
public class Counters {
   volatile long counter1;  // Core 0 writes
   volatile long counter2;  // Core 1 writes
   // Cả 2 fit trong 1 cache line (16 bytes << 64 bytes)
   // → Core 0 write invalidates Core 1's cache line (and vice versa)
   // → Performance giảm 10-50x so với single-threaded!
}

// ✅ @Contended: JVM chèn padding để tách cache lines
// Cần: -XX:-RestrictContended (hoặc trong java.base module)
@jdk.internal.vm.annotation.Contended  // hoặc dùng manual padding:
public class PaddedCounters {
   volatile long counter1;
   // Manual padding: 7 longs = 56 bytes → đẩy counter2 sang cache line khác
   long p1, p2, p3, p4, p5, p6, p7;
   volatile long counter2;
}

// LongAdder đã solve false sharing internally — dùng nó thay vì tự padding
// Internally: Cell[] array với @Contended annotation trên mỗi Cell
```

### # SIMD vectorization — khi JIT tự tối ưu

#### # auto-vectorization trong hotspot jit

JIT compiler của HotSpot có thể tự động convert simple loops thành **SIMD instructions** (SSE/AVX trên x86). Một instruction xử lý 4 doubles (AVX2) hoặc 8 floats cùng lúc.

```java
// ✅ Loop mà JIT CÓ THỂ auto-vectorize:
// - Simple array operations
// - No method calls trong loop body
// - No branches (hoặc branch rất đơn giản)
// - Predictable loop bounds

// ✅ Vectorizable: element-wise addition
public static void addArrays(double[] a, double[] b, double[] result) {
   for (int i = 0; i < a.length; i++) {
       result[i] = a[i] + b[i];  // JIT: 4 additions per AVX2 instruction
   }
}

// ✅ Vectorizable: scalar multiplication
public static void scale(double[] arr, double factor) {
   for (int i = 0; i < arr.length; i++) {
       arr[i] *= factor;  // JIT: 4 multiplications per instruction
   }
}

// ❌ NOT vectorizable: method call in loop
public static void transform(double[] arr) {
   for (int i = 0; i < arr.length; i++) {
       arr[i] = customTransform(arr[i]);  // Method call blocks vectorization
   }
}

// ❌ NOT vectorizable: data-dependent branch
public static void conditional(double[] arr) {
   for (int i = 0; i < arr.length; i++) {
       if (arr[i] > 0) arr[i] = Math.sqrt(arr[i]);  // Branch blocks SIMD
       else arr[i] = 0;
   }
}
```

#### # vector api (java 22+ incubator) — explicit SIMD control

```java
// Khi auto-vectorization không đủ: Vector API cho explicit SIMD programming
import jdk.incubator.vector.*;

public class VectorMath {
   // Process 4 doubles at once (AVX2: 256-bit = 4 × 64-bit double)
   private static final VectorSpecies<Double> SPECIES = DoubleVector.SPECIES_256;

   // ✅ Explicit vectorized dot product
   public static double dotProduct(double[] a, double[] b) {
       int upperBound = SPECIES.loopBound(a.length);
       double[] sum = new double[1];
       DoubleVector vsum = DoubleVector.zero(SPECIES);

       // Main loop: process 4 elements per iteration
       int i = 0;
       for (; i < upperBound; i += SPECIES.length()) {
           DoubleVector va = DoubleVector.fromArray(SPECIES, a, i);
           DoubleVector vb = DoubleVector.fromArray(SPECIES, b, i);
           vsum = va.fma(vb, vsum);  // Fused Multiply-Add: vsum += va * vb
           // 1 instruction = 4 multiplications + 4 additions
       }

       double result = vsum.reduceLanes(VectorOperators.ADD);

       // Tail loop: remaining elements (< 4)
       for (; i < a.length; i++) {
           result += a[i] * b[i];
       }
       return result;
   }

   // Speedup: 3-4x vs scalar loop (4 operations per instruction)
   // Với AVX-512 (SPECIES_512): 7-8x (8 doubles per instruction)
}
```

#### # khi nào simd matters trong enterprise java?

| Use Case                            | Frequency          | SIMD benefit                   |
| ----------------------------------- | ------------------ | ------------------------------ |
| JSON parsing (character scanning)   | Every request      | Moderate (JIT auto-vectorizes) |
| Batch price calculations            | Nightly batch      | High (explicit Vector API)     |
| Image/PDF processing                | On-demand          | Very high                      |
| Encryption/hashing                  | Every request      | Built-in (JDK uses intrinsics) |
| String operations (equals, indexOf) | Frequent           | Already optimized by JDK       |
| ML inference                        | Rare in enterprise | Extreme (use native libs)      |

Trong enterprise Java, bạn **hiếm khi** cần explicit SIMD. JIT compiler và JDK intrinsics đã handle hầu hết cases. Vector API relevant cho: custom signal processing, scientific computing, hoặc khi JIT fails to vectorize.

### # decision matrix

| Technique                            | Complexity | Risk   | Reward    | Dùng khi                                   |
| ------------------------------------ | ---------- | ------ | --------- | ------------------------------------------ |
| Tránh Autoboxing                     | Low        | None   | Medium    | Luôn luôn (habit tốt)                      |
| EnumSet bitmask                      | Low        | None   | Medium    | Permission/flag systems                    |
| Virtual Threads                      | Low        | Low    | High      | I/O-bound services (Java 21+)              |
| Caffeine L1 cache                    | Medium     | Low    | High      | Hot data, >1000 reads/sec                  |
| Hibernate tuning (OSIV, projections) | Medium     | Low    | High      | Mọi JPA project                            |
| Jackson optimization                 | Medium     | None   | Medium    | High-throughput APIs                       |
| Branchless programming               | High       | Medium | Medium    | Inner loops + random data (profile first!) |
| SoA data layout                      | High       | Medium | High      | Batch processing >100K items               |
| Lookup Tables                        | Low        | None   | High      | Repeated computation, bounded input        |
| Lock-free (CAS)                      | Very High  | High   | High      | Extreme contention, framework-level        |
| Arena allocation                     | High       | Medium | High      | Off-heap, native interop                   |
| GraalVM Native                       | High       | High   | High      | Serverless, startup-critical               |
| Explicit SIMD (Vector API)           | Very High  | Medium | Very High | Scientific/batch computation               |

#### # nguyên tắc vàng

1. **Profile trước** — Dùng JFR/async-profiler xác định bottleneck thực sự. 90% thời gian, bottleneck không phải ở chỗ bạn nghĩ.

2. **Low-hanging fruit trước** — Autoboxing, Hibernate N+1, missing cache, wrong collection type. Những thứ này fix trong 5 phút, gain 10x.

3. **Readability mặc định** — Clean code + correct algorithm > micro-optimization. Team phải đọc và maintain code này 5 năm tới.

4. **Benchmark, không đoán** — JMH cho micro-benchmarks, Gatling/k6 cho load tests. Số liệu thực > trực giác.

5. **JIT compiler thông minh hơn bạn nghĩ** — HotSpot JIT tự inline, escape analyze, vectorize, và eliminate dead code. Đừng "optimize" thứ JIT đã handle.

6. **Tối ưu đúng level** — Architecture fix (caching layer, async processing, batching) thường gain 100x. Micro-optimization (branchless, SIMD) gain 2-5x. Đầu tư đúng chỗ.

> Chỉ là những ghi chép cá nhân với hy vọng mang lại chút giá trị. Nếu thấy hữu ích, đừng ngại chia sẻ cho bạn bè & đồng nghiệp nhé!

Happy coding <Twemoji emoji="clinking-beer-mugs" /> 😎 👍🏻 🚀 🔥.
