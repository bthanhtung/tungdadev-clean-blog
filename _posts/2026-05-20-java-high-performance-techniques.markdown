---
layout: post
title: "high-performance java techniques"
date: 2026-05-20 19:29:39 +0700
categories: [Software Development]
tags: [java, software-development, optimization, best-practices, vietnamese]
---

Ngoài bitwise, Java có rất nhiều techniques ít developer biết mà framework authors và library developers dùng hàng ngày để đạt performance vượt trội. Bài này tổng hợp tất cả — từ memory layout, object pooling, lock-free algorithms đến JVM-level optimizations.

Mỗi technique đi kèm: khi nào dùng, tại sao nhanh, ví dụ thực tế, và cảnh báo khi nào KHÔNG nên dùng.

## 1. Object Pooling — Tránh GC pressure

**Vấn đề**: Tạo object = allocate memory. GC phải scan và collect. Tạo hàng triệu short-lived objects/second → GC pause spikes.

**Giải pháp**: Reuse objects thay vì tạo mới. Pre-allocate pool, borrow/return.

```java
// ❌ Tạo StringBuilder mới mỗi request (GC pressure)
public String buildResponse(List<Item> items) {
   StringBuilder sb = new StringBuilder();  // Allocated on heap, GC later
   for (Item item : items) {
       sb.append(item.getName()).append(",");
   }
   return sb.toString();
}

// ✅ ThreadLocal StringBuilder pool — reuse per thread
private static final ThreadLocal<StringBuilder> SB_POOL =
   ThreadLocal.withInitial(() -> new StringBuilder(1024));

public String buildResponse(List<Item> items) {
   StringBuilder sb = SB_POOL.get();
   sb.setLength(0);  // Reset, không allocate mới
   for (Item item : items) {
       sb.append(item.getName()).append(",");
   }
   return sb.toString();
}
```

**Spring Boot thực tế — Connection Pooling (HikariCP)**:

```yaml
# HikariCP = object pool cho database connections
spring:
  datasource:
    hikari:
      maximum-pool-size: 20 # Pre-create 20 connections
      minimum-idle: 5 # Keep 5 idle, ready to use
      # getConnection() → borrow từ pool (< 1ms)
      # thay vì tạo mới (50-200ms TCP + auth)
```

**Byte array pooling cho I/O intensive:**

```java
// Netty's PooledByteBufAllocator concept — simplified
public class ByteArrayPool {
   private final Queue<byte[]> pool = new ConcurrentLinkedQueue<>();
   private final int bufferSize;

   public ByteArrayPool(int bufferSize, int initialSize) {
       this.bufferSize = bufferSize;
       for (int i = 0; i < initialSize; i++) {
           pool.offer(new byte[bufferSize]);
       }
   }

   public byte[] borrow() {
       byte[] buf = pool.poll();
       return buf != null ? buf : new byte[bufferSize];
   }

   public void returnBuffer(byte[] buf) {
       if (buf.length == bufferSize) {
           pool.offer(buf);  // Return to pool for reuse
       }
   }
}
```

---

## 2. Primitive Arrays > Object Collections — Avoid boxing overhead

**Vấn đề**: `List<Integer>` chứa boxed objects (mỗi Integer = 16 bytes header + 4 bytes value). `int[]` chứa raw 4 bytes/element. 4x memory difference + cache miss do pointer chasing.

```java
// ❌ Boxed (heap allocation mỗi element, GC phải track)
List<Integer> scores = new ArrayList<>();  // ~20 bytes/element (object overhead)
int sum = scores.stream().mapToInt(Integer::intValue).sum();  // Unboxing cost

// ✅ Primitive array (contiguous memory, cache-friendly)
int[] scores = new int[1000];  // 4 bytes/element, contiguous
int sum = 0;
for (int score : scores) sum += score;  // No boxing/unboxing

// Khi CẦN collection behavior + primitives → Eclipse Collections / HPPC
IntArrayList scores = new IntArrayList(1000);  // Primitive int list, no boxing
int sum = scores.sum();  // Direct arithmetic, no auto-boxing
```

**Spring Boot thực tế — Batch processing:**

```java
// ❌ Process 1M records with boxed IDs
List<Long> ids = repository.findAllIds();  // 1M Long objects = ~20MB heap
ids.forEach(id -> process(id));

// ✅ Stream primitives
repository.findAllIds().stream()
   .mapToLong(Long::longValue)  // Unbox once
   .forEach(this::processById);

// ✅✅ Native query returning primitive projection
@Query(value = "SELECT id FROM products WHERE status = 'ACTIVE'", nativeQuery = true)
Stream<Long> streamAllActiveIds();  // Stream processes one at a time, no full list in memory
```

---

## 3. String Interning & Deduplication — Memory savings

**Vấn đề**: Hàng nghìn String objects chứa cùng nội dung ("ACTIVE", "PENDING", "USD"). Mỗi cái là separate heap object.

```java
// ❌ Hàng ngàn duplicate strings từ DB queries
List<Order> orders = orderRepository.findAll();  // 100K orders
// Mỗi order.getCurrency() = new String("VND") → 100K identical String objects

// ✅ String.intern() → share reference từ String Pool
public class Order {
   private String currency;

   public void setCurrency(String currency) {
       this.currency = currency.intern();  // Reuse existing String from pool
       // 100K orders nhưng chỉ 3-5 unique currency Strings in memory
   }
}

// ✅✅ Enum thay vì String (best approach cho fixed set of values)
public enum Currency { VND, USD, EUR, JPY }
// Zero allocation, zero GC, type-safe, comparable, serializable
```

**JVM option — String Deduplication (G1GC):**

```bash
# G1GC tự detect duplicate strings và deduplicate
java -XX:+UseG1GC -XX:+UseStringDeduplication -jar app.jar
# Không cần code change — JVM handles automatically
# Effective khi app có nhiều duplicate strings (parsed from DB/files)
```

---

## 4. Lazy Initialization & Compute-on-demand

**Vấn đề**: Tạo expensive object upfront mà có thể không bao giờ dùng.

```java
// ❌ Eager — always compute, even if never used
@Service
public class ReportService {
   private final Map<String, ReportTemplate> templates;

   public ReportService() {
       this.templates = loadAllTemplates();  // 500ms startup, may never use all
   }
}

// ✅ Lazy with double-checked locking (thread-safe)
@Service
public class ReportService {
   private volatile Map<String, ReportTemplate> templates;

   public Map<String, ReportTemplate> getTemplates() {
       Map<String, ReportTemplate> result = templates;
       if (result == null) {
           synchronized (this) {
               result = templates;
               if (result == null) {
                   templates = result = loadAllTemplates();
               }
           }
       }
       return result;
   }
}

// ✅✅ Java's built-in lazy holders (cleanest pattern)
public class ExpensiveComputation {
   // Inner class NOT loaded until first access → thread-safe lazy init
   private static class Holder {
       static final ExpensiveComputation INSTANCE = new ExpensiveComputation();
   }

   public static ExpensiveComputation getInstance() {
       return Holder.INSTANCE;  // Class loaded lazily by JVM
   }
}

// ✅✅✅ computeIfAbsent — cache computed results
private final Map<UUID, ProductDTO> cache = new ConcurrentHashMap<>();

public ProductDTO getProduct(UUID id) {
   return cache.computeIfAbsent(id, this::loadFromDatabase);
   // First call: compute + cache. Subsequent calls: return cached. Thread-safe.
}
```

---

## 5. Avoid Unnecessary Object Creation — Reuse patterns

```java
// ❌ Pattern compilation mỗi lần gọi (regex compile = expensive)
public boolean isValidEmail(String email) {
   return email.matches("^[A-Za-z0-9+_.-]+@(.+)$");  // Compiles Pattern EVERY CALL
}

// ✅ Pre-compile once, reuse forever
private static final Pattern EMAIL_PATTERN =
   Pattern.compile("^[A-Za-z0-9+_.-]+@(.+)$");

public boolean isValidEmail(String email) {
   return EMAIL_PATTERN.matcher(email).matches();  // Reuse compiled pattern
}

// ❌ DateTimeFormatter mới mỗi lần
public String format(LocalDateTime dt) {
   return dt.format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss"));  // Parse pattern each time
}

// ✅ Static formatter (thread-safe since Java 8)
private static final DateTimeFormatter FORMATTER =
   DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");

public String format(LocalDateTime dt) {
   return dt.format(FORMATTER);
}

// ❌ Autoboxing in loop
Long sum = 0L;  // Boxed Long!
for (long val : values) {
   sum += val;  // Unbox, add, RE-BOX → millions of Long objects created!
}

// ✅ Primitive in loop
long sum = 0L;
for (long val : values) {
   sum += val;  // Pure arithmetic, zero allocation
}
```

---

## 6. Data Locality & Cache-Friendly Structures

**Vấn đề**: CPU cache line = 64 bytes. Array of objects = array of POINTERS → each access = cache miss (pointer chasing). Array of primitives = contiguous data → sequential access = cache hits.

```java
// ❌ Array of objects (pointer chasing → cache misses)
class Point { double x, y; }
Point[] points = new Point[1_000_000];
// Memory: [ptr1, ptr2, ptr3, ...] → [Point@heap1] → [Point@heap2] → scattered!

double sumX = 0;
for (Point p : points) sumX += p.x;  // Each p.x = random memory access

// ✅ Struct of Arrays (SoA) — contiguous per field
double[] xs = new double[1_000_000];  // All X values contiguous
double[] ys = new double[1_000_000];  // All Y values contiguous

double sumX = 0;
for (int i = 0; i < xs.length; i++) sumX += xs[i];
// Sequential memory access → CPU prefetcher happy → 5-10x faster

// ✅ Spring Boot application: Batch processing with arrays
@Service
public class BulkPriceCalculator {

   // Instead of List<Product> → process price arrays
   public double[] calculateDiscounts(double[] prices, double discountRate) {
       double[] results = new double[prices.length];
       for (int i = 0; i < prices.length; i++) {
           results[i] = prices[i] * (1 - discountRate);
       }
       return results;  // Vectorizable by JIT compiler (SIMD instructions)
   }
}
```

---

## 7. Lock-Free & Wait-Free Algorithms (Atomic operations)

**Vấn đề**: `synchronized` blocks serialize access → threads wait → throughput drops under contention.

**Giải pháp**: Compare-And-Swap (CAS) — atomic CPU instruction, no locking.

```java
// ❌ Synchronized counter (threads block each other)
public class SyncCounter {
   private int count = 0;
   public synchronized void increment() { count++; }  // Lock acquire + release
   public synchronized int get() { return count; }
}

// ✅ AtomicInteger (CAS-based, lock-free)
public class AtomicCounter {
   private final AtomicInteger count = new AtomicInteger(0);
   public void increment() { count.incrementAndGet(); }  // CAS loop, no lock
   public int get() { return count.get(); }
}

// ✅ LongAdder — even faster under HIGH contention
// Internally: multiple cells, each thread updates its own cell, sum on read
public class HighThroughputCounter {
   private final LongAdder counter = new LongAdder();
   public void increment() { counter.increment(); }  // Striped, minimal contention
   public long get() { return counter.sum(); }        // Sum all cells
}

// Benchmark comparison (16 threads, 10M increments):
// synchronized:   ~3500ms (heavy lock contention)
// AtomicLong:     ~1200ms (CAS retries under contention)
// LongAdder:      ~180ms  (striped, almost zero contention)
```

**Spring Boot thực tế — Rate limiter lock-free:**

```java
@Component
public class SlidingWindowRateLimiter {

   private final AtomicLong[] windows;  // Circular buffer of counters
   private final AtomicLong windowStart = new AtomicLong(0);
   private final int maxRequests;
   private final long windowSizeMs;

   public boolean tryAcquire() {
       long now = System.currentTimeMillis();
       int slot = (int) ((now / 1000) % windows.length);

       // CAS-based increment — no lock, no blocking
       long count = windows[slot].incrementAndGet();
       return count <= maxRequests;
   }
}
```

---

## 8. Bulk Operations & Batch Processing

**Vấn đề**: N database calls = N network round-trips. Mỗi round-trip ~1-5ms = chậm.

```java
// ❌ N+1 problem — 1000 individual saves
for (Product product : products) {
   productRepository.save(product);  // 1000 INSERT statements, 1000 round-trips
}

// ✅ Batch insert (1 round-trip, batched statements)
@Transactional
public void batchInsert(List<Product> products) {
   // JPA batch: spring.jpa.properties.hibernate.jdbc.batch_size=50
   productRepository.saveAll(products);  // Hibernate batches 50 INSERTs per flush
}

// ✅✅ Native batch (fastest — bypass Hibernate overhead)
@Transactional
public void nativeBatchInsert(List<Product> products) {
   String sql = "INSERT INTO products (id, name, price, status) VALUES (?, ?, ?, ?)";
   jdbcTemplate.batchUpdate(sql, new BatchPreparedStatementSetter() {
       @Override
       public void setValues(PreparedStatement ps, int i) throws SQLException {
           Product p = products.get(i);
           ps.setObject(1, p.getId());
           ps.setString(2, p.getName());
           ps.setBigDecimal(3, p.getPrice());
           ps.setString(4, p.getStatus().name());
       }
       @Override
       public int getBatchSize() { return products.size(); }
   });
   // 1 round-trip, all rows in single batch command
}

// ✅ MongoDB bulk operations
public void bulkUpdate(List<ProductUpdate> updates) {
   BulkOperations bulkOps = mongoTemplate.bulkOps(BulkOperations.BulkMode.UNORDERED, "products");
   for (ProductUpdate update : updates) {
       Query query = Query.query(Criteria.where("_id").is(update.getId()));
       Update mongoUpdate = new Update().set("price", update.getNewPrice());
       bulkOps.updateOne(query, mongoUpdate);
   }
   BulkWriteResult result = bulkOps.execute();  // 1 round-trip for all updates
}
```

---

## 9. Zero-Copy & Buffer Reuse — I/O Performance

**Vấn đề**: File read → copy to user buffer → copy to socket buffer → send. Multiple memory copies = slow.

```java
// ❌ Traditional I/O (multiple copies)
byte[] data = Files.readAllBytes(path);  // Copy 1: disk → kernel buffer → user buffer
response.getOutputStream().write(data);   // Copy 2: user buffer → kernel socket buffer

// ✅ Zero-copy with NIO (kernel handles transfer directly)
@GetMapping("/files/{id}")
public ResponseEntity<Resource> downloadFile(@PathVariable UUID id) {
   Path filePath = storageService.getPath(id);
   Resource resource = new FileSystemResource(filePath);

   return ResponseEntity.ok()
       .contentType(MediaType.APPLICATION_OCTET_STREAM)
       .body(resource);
   // Spring uses FileChannel.transferTo() internally → OS-level zero-copy
   // Data goes: disk → kernel buffer → network card (skips user space)
}

// ✅ StreamingResponseBody — no full file in memory
@GetMapping("/export")
public ResponseEntity<StreamingResponseBody> export() {
   StreamingResponseBody body = outputStream -> {
       try (var cursor = mongoTemplate.stream(query, Document.class)) {
           while (cursor.hasNext()) {
               Document doc = cursor.next();
               outputStream.write(toCsvLine(doc).getBytes());
               // Stream line by line — never hold full dataset in memory
           }
       }
   };
   return ResponseEntity.ok().body(body);
}
```

---

## 10. Efficient Collections — Right tool for the job

```java
// HashMap vs EnumMap — when keys are enum
// ❌ HashMap with Enum keys (hash computation, boxing, node objects)
Map<OrderStatus, List<Order>> grouped = new HashMap<>();

// ✅ EnumMap (array-based internally, O(1) access, no hashing)
Map<OrderStatus, List<Order>> grouped = new EnumMap<>(OrderStatus.class);
// 2-3x faster than HashMap for enum keys, less memory

// ArrayList vs LinkedList (almost ALWAYS ArrayList wins)
// LinkedList only wins for: frequent add/remove at HEAD (use as Deque)

// HashSet.contains() vs sorted array + binary search
// Small set (<20 elements): array scan can be faster (no hashing overhead)
// Large set: HashSet O(1) amortized

// ✅ Specialized collections for high-performance
// Agrona (used by Aeron messaging): Int2ObjectHashMap, MutableLong
// Eclipse Collections: IntArrayList, LongHashSet, UnifiedMap
// HPPC: IntIntHashMap (primitive-to-primitive, zero boxing)

// ✅ Pre-size collections
// ❌
List<ProductDTO> results = new ArrayList<>();  // Default capacity 10, grows via arraycopy
// ✅
List<ProductDTO> results = new ArrayList<>(expectedSize);  // No resize needed
Map<String, Object> map = HashMap.newHashMap(expectedSize);  // Java 19+, or capacity = size/0.75+1
```

---

## 11. JIT-Friendly Code — Help the compiler help you

JVM JIT compiler optimizes code at runtime. Certain patterns enable/block optimizations:

```java
// ✅ Small methods → JIT can INLINE (eliminate method call overhead)
// Methods < ~35 bytecodes are auto-inlined
public boolean isActive(Product p) { return p.getStatus() == ProductStatus.ACTIVE; }
// JIT inlines this → zero method call overhead at call sites

// ❌ Megamorphic dispatch (>2 implementations) blocks inlining
interface Processor { void process(Data d); }
// If 5+ implementations → JIT can't inline → virtual dispatch every call
// Fix: limit implementations, or restructure to avoid hot polymorphic calls

// ✅ Final classes/methods → enable devirtualization
public final class FastCalculator {  // JIT knows no subclass exists → can inline
   public final double compute(double x) { return x * x + 1; }
}

// ✅ Loop-invariant code motion — JIT does this, but help it:
// ❌
for (int i = 0; i < list.size(); i++) { ... }  // list.size() called each iteration
// ✅
int size = list.size();
for (int i = 0; i < size; i++) { ... }  // Hoisted out of loop

// ✅ Avoid megamorphic calls in hot loops
// JIT optimizes monomorphic (1 type) and bimorphic (2 types) call sites
// 3+ types at same call site → megamorphic → slow virtual dispatch
```

---

## 12. Concurrent Data Structures — Beyond synchronized

```java
// ConcurrentHashMap — segmented locking (Java 8: CAS + sync on node)
ConcurrentHashMap<UUID, ProductDTO> cache = new ConcurrentHashMap<>();
cache.computeIfAbsent(id, k -> loadProduct(k));  // Atomic compute, no external lock

// CopyOnWriteArrayList — reads never block (copy on write)
// Perfect for: rarely-modified, frequently-read lists (event listeners, config)
List<EventHandler> handlers = new CopyOnWriteArrayList<>();
// Reads: zero synchronization. Writes: copy entire array (expensive but rare)

// ConcurrentLinkedQueue — lock-free FIFO queue (Michael-Scott algorithm)
Queue<Task> taskQueue = new ConcurrentLinkedQueue<>();
// Non-blocking add/poll — ideal for producer-consumer without locks

// Disruptor pattern (LMAX) — mechanical sympathy, ring buffer
// 25M+ messages/second with predictable latency
// Used in: trading systems, high-throughput event processing
```

---

## 13. Memory-Mapped Files — OS-level caching

```java
// Cho large files (GB+): mmap = OS manages caching, zero explicit I/O
// File acts like byte array in memory — OS pages in/out automatically

try (FileChannel channel = FileChannel.open(path, StandardOpenOption.READ)) {
   MappedByteBuffer buffer = channel.map(FileChannel.MapMode.READ_ONLY, 0, channel.size());
   // 'buffer' is now backed by OS page cache
   // Random access = O(1), OS handles prefetching
   // No explicit read() calls needed — access like array

   while (buffer.hasRemaining()) {
       byte b = buffer.get();  // Reads from page cache, not disk I/O call
   }
}

// Use case: Log file processing, large CSV parsing, database file access
// SharedMemory between processes (IPC)
```

---

## 14. Escape Analysis & Stack Allocation

JIT compiler's escape analysis determines if object can stay on stack (no GC) vs must go to heap (GC tracked).

```java
// ✅ Object that DOESN'T escape method → JIT allocates on STACK (no GC!)
public double calculateDistance(double x1, double y1, double x2, double y2) {
   Point p1 = new Point(x1, y1);  // JIT: p1 doesn't escape → stack allocated
   Point p2 = new Point(x2, y2);  // JIT: p2 doesn't escape → stack allocated
   return p1.distanceTo(p2);
   // When method returns: stack frame popped, objects gone. Zero GC work.
}

// ❌ Object ESCAPES method → must heap allocate
public Point createPoint(double x, double y) {
   return new Point(x, y);  // Returned to caller → escapes → heap allocated → GC tracks
}

// Help escape analysis:
// - Keep methods small (easier for JIT to analyze)
// - Avoid storing local objects into fields/collections
// - Avoid passing local objects to methods that might store them
// - Use records/value types for small temporary data
```

---

## 15. Quick Reference — When to Use What

| Technique                    | Speedup                           | When to use                  | Complexity |
| ---------------------------- | --------------------------------- | ---------------------------- | ---------- |
| Primitive arrays             | 2-5x memory, 2-3x speed           | Bulk numeric processing      | Low        |
| Object pooling               | Reduce GC pauses 50%+             | High-allocation hot paths    | Medium     |
| String.intern() / Enum       | 5-10x memory for repeated strings | Fixed-set string values      | Low        |
| Pre-compile regex/formatter  | 10-100x per call                  | Any repeated pattern usage   | Low        |
| Batch DB operations          | 10-100x throughput                | Bulk inserts/updates         | Low        |
| Lock-free (Atomic/LongAdder) | 5-20x under contention            | Shared counters, hot metrics | Medium     |
| EnumMap/EnumSet              | 2-3x vs HashMap/HashSet           | Enum keys/values             | Low        |
| Pre-size collections         | 1.5-2x (avoid resizing)           | Known-size collections       | Low        |
| Zero-copy I/O                | 2-3x file transfer                | Large file serving           | Medium     |
| Memory-mapped files          | 10x random access on large files  | GB+ file processing          | Medium     |
| Cache-friendly layout (SoA)  | 5-10x for sequential access       | Numeric batch processing     | High       |
| JIT-friendly patterns        | 2-5x in hot paths                 | Inner loops, framework code  | Medium     |

**Golden rules:**

1. **Measure first** — JMH benchmark before and after. Don't guess.
2. **Readability by default** — optimize only proven bottlenecks.
3. **Know your GC** — Many "optimizations" become unnecessary with modern GCs (ZGC, Shenandoah).
4. **JIT is smart** — Often your "optimization" is something JIT already does.
5. **Profile, don't speculate** — Use JFR, async-profiler to find actual hot spots.

> Chỉ là những ghi chép cá nhân với hy vọng mang lại chút giá trị. Nếu thấy hữu ích, đừng ngại chia sẻ cho bạn bè & đồng nghiệp nhé!

Happy coding <Twemoji emoji="clinking-beer-mugs" /> 😎 👍🏻 🚀 🔥.
