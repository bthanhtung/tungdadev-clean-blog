---
layout: post
title: "java comparison"
date: 2026-05-25 19:29:39 +0700
categories: [Software Development]
tags: [java, software-development, best-practices, vietnamese]
---

Tổng hợp các cặp concepts trong Java/Spring thường bị hỏi trong phỏng vấn Senior và dễ dùng sai trong production.

## 1. == vs equals()

**Khác biệt cốt lõi**: `==` so sánh reference (cùng object trong memory?), `equals()` so sánh value (nội dung giống nhau?).

```java
String a = new String("hello");
String b = new String("hello");

a == b;       // false — 2 objects khác nhau trong heap
a.equals(b);  // true — nội dung giống nhau

// String pool exception
String c = "hello";
String d = "hello";
c == d;       // true — cùng reference trong String pool (compile-time optimization)

// Integer caching (-128 to 127)
Integer x = 127;
Integer y = 127;
x == y;       // true — cached

Integer m = 128;
Integer n = 128;
m == n;       // false — ngoài cache range, different objects
m.equals(n);  // true

// Best practice: LUÔN dùng equals() cho objects, == chỉ cho primitives và null check
Objects.equals(a, b);  // Null-safe equals
```

---

## 2. final vs finally vs finalize

Ba keywords bắt đầu bằng "final" nhưng hoàn toàn khác nhau.

```java
// final — constant/immutable
final int MAX = 100;              // Variable: không reassign được
final class Utility { }           // Class: không extend được
final void process() { }          // Method: không override được

// final trong modern Java: effectively final cho lambdas
String name = "John";  // Effectively final (không reassign)
Runnable r = () -> System.out.println(name);  // OK

// finally — cleanup code (luôn chạy sau try/catch)
try {
   connection = dataSource.getConnection();
   // ... do work
} catch (SQLException e) {
   log.error("DB error", e);
} finally {
   if (connection != null) connection.close();  // LUÔN chạy
}
// Modern: try-with-resources thay thế finally cho AutoCloseable

// finalize — DEPRECATED (Java 9+), DO NOT USE
// Chạy trước GC collect object — unpredictable timing, performance killer
// Thay thế: Cleaner API hoặc try-with-resources
```

---

## 3. abstract class vs interface

Trước Java 8, ranh giới rõ ràng. Sau Java 8+ (default methods), ranh giới mờ hơn nhưng vẫn có semantic khác nhau.

```java
// Interface — contract, "can do" relationship (HAS-A behavior)
public interface Auditable {
   LocalDateTime getCreatedAt();
   String getCreatedBy();

   // Default method (Java 8+): behavior chung, override được
   default String getAuditInfo() {
       return getCreatedBy() + " at " + getCreatedAt();
   }

   // Static method
   static Auditable empty() { return new EmptyAuditable(); }
}

// Abstract class — shared implementation, "is-a" relationship
public abstract class BaseEntity {
   @Id
   private UUID id;
   private LocalDateTime createdAt;

   // Concrete method: shared behavior
   public boolean isNew() { return id == null; }

   // Abstract method: subclass must implement
   public abstract String getEntityType();

   // Constructor (interface KHÔNG có)
   protected BaseEntity() { this.id = UUID.randomUUID(); }

   // State (fields) — interface chỉ có constants
   private int version;
}

// Class implement nhiều interfaces, extend chỉ 1 abstract class
public class Product extends BaseEntity implements Auditable, Serializable { }
```

**Khi nào dùng gì:**
| Criteria | Interface | Abstract Class |
|----------|-----------|----------------|
| Multiple inheritance | ✓ (implements nhiều) | ✗ (extends 1) |
| Has state (fields) | ✗ (chỉ constants) | ✓ |
| Has constructor | ✗ | ✓ |
| Forces "is-a" relationship | ✗ | ✓ |
| Evolving API | ✓ (default methods) | ✓ |
| Template Method pattern | ✗ | ✓ (preferred) |
| Strategy/Capability | ✓ (preferred) | ✗ |

---

## 4. Checked vs Unchecked Exceptions

```java
// Checked Exception — compiler FORCE bạn handle (extends Exception)
// "Recoverable errors" — caller có thể xử lý
public class InsufficientFundsException extends Exception {
   private final BigDecimal balance;
   private final BigDecimal amount;
}

// Phải try-catch hoặc throws
public void transfer(BigDecimal amount) throws InsufficientFundsException {
   if (balance.compareTo(amount) < 0) throw new InsufficientFundsException(balance, amount);
}

// Unchecked Exception — compiler KHÔNG force handle (extends RuntimeException)
// "Programming errors" — caller thường không thể recover
public class ProductNotFoundException extends RuntimeException {
   public ProductNotFoundException(UUID id) {
       super("Product not found: " + id);
   }
}

// Không cần try-catch
public ProductDTO getById(UUID id) {
   return repo.findById(id).orElseThrow(() -> new ProductNotFoundException(id));
}
```

**Spring convention**: Dùng UNCHECKED exceptions cho mọi business/application errors. Lý do:

- `@Transactional` mặc định chỉ rollback RuntimeException
- Không pollute method signatures với throws
- Controller advice catch tất cả centrally

---

## 5. HashMap vs ConcurrentHashMap vs LinkedHashMap vs TreeMap

```java
// HashMap — fastest, unordered, NOT thread-safe
Map<String, Product> cache = new HashMap<>();
// O(1) get/put, null keys/values allowed
// ❌ KHÔNG dùng trong multi-threaded context

// ConcurrentHashMap — thread-safe, NO locks on reads
Map<String, Product> concurrentCache = new ConcurrentHashMap<>();
// Thread-safe, null keys/values NOT allowed
// Segment-level locking (Java 8: CAS + synchronized on node)
// ✅ Dùng cho shared state giữa threads

// LinkedHashMap — insertion order preserved
Map<String, Product> orderedMap = new LinkedHashMap<>();
// Access order mode → LRU cache implementation
Map<String, Product> lruCache = new LinkedHashMap<>(16, 0.75f, true) {
   @Override
   protected boolean removeEldestEntry(Map.Entry<String, Product> eldest) {
       return size() > 100;  // Max 100 entries
   }
};

// TreeMap — sorted by key (Red-Black tree)
Map<String, Product> sortedMap = new TreeMap<>();
// O(log n) get/put, keys must be Comparable
// Use case: range queries, "give me all products between A-M"
NavigableMap<LocalDate, BigDecimal> dailyRevenue = new TreeMap<>();
dailyRevenue.subMap(startDate, endDate);  // Range query
```

---

## 6. ArrayList vs LinkedList vs CopyOnWriteArrayList

```java
// ArrayList — dynamic array, default choice 99% of the time
List<Product> products = new ArrayList<>();
// O(1) random access, O(1) amortized add, O(n) insert/remove middle
// Cache-friendly (contiguous memory)

// LinkedList — doubly-linked list, RARELY better choice
List<Product> linkedProducts = new LinkedList<>();
// O(n) random access, O(1) add/remove at head/tail
// ❌ Almost NEVER faster than ArrayList in practice (cache misses)
// Only use case: frequent add/remove at both ends (Deque interface)

// CopyOnWriteArrayList — thread-safe, optimized for reads
List<EventListener> listeners = new CopyOnWriteArrayList<>();
// Every write creates new internal array copy → expensive writes
// Reads never block, never throw ConcurrentModificationException
// ✅ Use for: listener lists, rarely-modified collections read by many threads
```

---

## 7. synchronized vs ReentrantLock vs volatile vs Atomic

```java
// synchronized — implicit lock, simple
public class Counter {
   private int count = 0;

   public synchronized void increment() { count++; }
   public synchronized int get() { return count; }
   // Pros: Simple, auto-release
   // Cons: No tryLock, no timeout, no fairness control
}

// ReentrantLock — explicit lock, more control
public class AdvancedCounter {
   private final ReentrantLock lock = new ReentrantLock(true); // fair
   private int count = 0;

   public void increment() {
       if (lock.tryLock(5, TimeUnit.SECONDS)) {  // Timeout!
           try { count++; }
           finally { lock.unlock(); }  // Manual unlock
       }
   }
   // Pros: tryLock, timeout, fairness, multiple conditions
   // Cons: Verbose, must remember unlock in finally
}

// volatile — visibility guarantee, NO atomicity
public class Flag {
   private volatile boolean running = true;  // Visible across threads immediately

   public void stop() { running = false; }  // Write visible to all readers
   public void run() { while (running) { /* work */ } }
   // Pros: Lightweight, no locking
   // Cons: Only works for single write/read — NOT for compound operations (count++)
}

// AtomicInteger — lock-free atomic operations (CAS)
public class AtomicCounter {
   private final AtomicInteger count = new AtomicInteger(0);

   public void increment() { count.incrementAndGet(); }  // Atomic!
   public int get() { return count.get(); }
   // Pros: Lock-free, high performance under contention
   // Cons: Only single variable, no compound atomicity
}
```

**Decision tree:**

- Chỉ cần visibility (flag, config) → `volatile`
- Single variable atomic ops → `AtomicInteger/AtomicReference`
- Simple mutual exclusion → `synchronized`
- Cần tryLock/timeout/fairness → `ReentrantLock`

---

## 8. @Component vs @Service vs @Repository vs @Controller

Technically tất cả đều là `@Component` — Spring đều scan và đăng ký bean. Khác biệt nằm ở **semantic** và **special behavior**.

```java
@Component          // Generic Spring bean (utility, helper)
@Service            // Business logic layer — KHÔNG có behavior đặc biệt, chỉ semantic
@Repository         // Data access layer — Exception translation (DataAccessException)
@Controller         // Web layer — view resolution
@RestController     // Web layer — = @Controller + @ResponseBody
@Configuration      // Config class — CGLIB proxy, @Bean method interception
```

**@Repository đặc biệt**: Spring tự động translate database-specific exceptions (SQLIntegrityConstraintViolation) thành Spring's `DataAccessException` hierarchy — portable error handling.

---

## 9. PUT vs PATCH — HTTP semantics

```java
// PUT — replace TOÀN BỘ resource (idempotent)
// Client gửi complete representation
@PutMapping("/{id}")
public ProductDTO update(@PathVariable UUID id, @Valid @RequestBody UpdateProductRequest request) {
   // request PHẢI chứa TẤT CẢ fields
   // Fields không gửi = set null/default
   Product product = productRepository.findById(id).orElseThrow();
   product.setName(request.getName());       // Bắt buộc
   product.setPrice(request.getPrice());     // Bắt buộc
   product.setDescription(request.getDescription()); // null nếu không gửi → xóa description
   return toDTO(productRepository.save(product));
}

// PATCH — update MỘT PHẦN resource (chỉ fields gửi lên)
// Client gửi partial representation
@PatchMapping("/{id}")
public ProductDTO patch(@PathVariable UUID id, @RequestBody Map<String, Object> updates) {
   Product product = productRepository.findById(id).orElseThrow();

   // Chỉ update fields có trong request
   updates.forEach((key, value) -> {
       switch (key) {
           case "name" -> product.setName((String) value);
           case "price" -> product.setPrice(new BigDecimal(value.toString()));
           case "description" -> product.setDescription((String) value);
       }
   });

   return toDTO(productRepository.save(product));
}
```

|                | PUT                          | PATCH                     |
| -------------- | ---------------------------- | ------------------------- |
| Semantics      | Replace full resource        | Partial update            |
| Body           | Complete object              | Only changed fields       |
| Missing fields | Set to null/default          | Leave unchanged           |
| Idempotent     | ✓                            | Not guaranteed            |
| Validation     | Validate all required fields | Validate only sent fields |

---

## 10. @RequestParam vs @PathVariable vs @RequestBody

```java
// @PathVariable — resource identifier, part of URL path
// GET /api/products/550e8400-e29b-41d4-a716-446655440000
@GetMapping("/{id}")
public ProductDTO get(@PathVariable UUID id) { ... }
// Khi nào: identifying specific resource

// @RequestParam — filtering, pagination, search criteria
// GET /api/products?status=ACTIVE&page=0&size=20&keyword=laptop
@GetMapping
public Page<ProductDTO> list(
   @RequestParam(required = false) ProductStatus status,
   @RequestParam(defaultValue = "0") int page) { ... }
// Khi nào: optional filters, query parameters

// @RequestBody — JSON payload (POST/PUT/PATCH body)
// POST /api/products  with JSON body
@PostMapping
public ProductDTO create(@Valid @RequestBody CreateProductRequest request) { ... }
// Khi nào: sending complex object, create/update operations
```

---

## 11. Comparator vs Comparable

```java
// Comparable — "natural ordering" (defined IN the class)
public class Product implements Comparable<Product> {
   private String name;
   private BigDecimal price;

   @Override
   public int compareTo(Product other) {
       return this.name.compareTo(other.name);  // Natural order: by name
   }
}
Collections.sort(products);  // Uses compareTo

// Comparator — "custom ordering" (defined OUTSIDE the class)
// Nhiều cách sort khác nhau cho cùng 1 class
Comparator<Product> byPrice = Comparator.comparing(Product::getPrice);
Comparator<Product> byPriceDesc = Comparator.comparing(Product::getPrice).reversed();
Comparator<Product> byNameThenPrice = Comparator.comparing(Product::getName)
   .thenComparing(Product::getPrice);

// Null-safe
Comparator<Product> nullSafe = Comparator.comparing(
   Product::getCategory, Comparator.nullsLast(Comparator.naturalOrder()));

products.sort(byPrice);
products.stream().sorted(byNameThenPrice).toList();
```

**Rule**: Implement `Comparable` cho 1 obvious natural order (String → alphabetical, Date → chronological). Dùng `Comparator` cho alternative/custom orderings.

---

## 12. StringBuilder vs StringBuffer vs String concatenation

```java
// String concatenation (+) — compiler optimizes simple cases
String result = "Hello " + name + "!";
// Java 9+: compiler uses invokedynamic → efficient cho simple cases
// ❌ KHÔNG dùng trong loops

// ❌ Anti-pattern: concatenation in loop
String csv = "";
for (Product p : products) {
   csv += p.getName() + ",";  // Tạo new String object mỗi iteration → O(n²)
}

// ✅ StringBuilder — NOT thread-safe, fast (single-threaded)
StringBuilder sb = new StringBuilder();
for (Product p : products) {
   sb.append(p.getName()).append(",");
}
String csv = sb.toString();

// StringBuffer — thread-safe (synchronized), slower
StringBuffer buffer = new StringBuffer();  // Legacy, HIẾM KHI cần
// Chỉ khi nhiều threads cùng build 1 string (rất rare)

// ✅ Modern approach: String.join / Collectors
String csv = products.stream()
   .map(Product::getName)
   .collect(Collectors.joining(","));

String csv = String.join(",", names);
```

**Decision**: Dùng `+` cho simple expressions. `StringBuilder` cho loops/complex building. `String.join`/`Collectors.joining` cho collections. `StringBuffer` → almost never.

> Chỉ là những ghi chép cá nhân với hy vọng mang lại chút giá trị. Nếu thấy hữu ích, đừng ngại chia sẻ cho bạn bè & đồng nghiệp nhé!

Happy coding <Twemoji emoji="clinking-beer-mugs" /> 😎 👍🏻 🚀 🔥.
