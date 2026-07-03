---
layout: post
title: "what happens when you call a rest api update?"
date: 2024-06-27 19:29:39 +0700
categories: [Software Development]
tags: [java, software-development, spring-framework, best-practices, vietnamese]
---

Bạn click "Save" trên UI. Một PUT request bay đi. 200ms sau, data đã update. Nhưng trong 200ms đó, hàng chục components tham gia xử lý — từ TCP handshake, qua reverse proxy, security filters, serialization, transaction management, connection pooling, đến physical disk write trên database server.

Bài này trace toàn bộ journey của 1 UPDATE request từ client đến disk, qua từng layer. Mỗi layer mình sẽ giải thích: nó làm gì, tại sao cần nó, và chuyện gì có thể sai.

**Scenario**: `PUT /api/v1/products/550e8400-e29b-41d4-a716-446655440000` update tên và giá sản phẩm, backend Spring Boot, database PostgreSQL (relational) và MongoDB (document).

### # phase 1: client → network → server (0-50ms)

#### # client tạo http request

Browser/mobile app serialize data thành JSON, build HTTP request:

```
PUT /api/v1/products/550e8400-e29b-41d4-a716-446655440000 HTTP/1.1
Host: api.example.com
Content-Type: application/json
Authorization: Bearer eyJhbGciOiJSUzI1NiIs...
X-Request-Id: req-7f3a2b1c-4d5e-6f7a
Content-Length: 89

{"name": "Laptop Pro 2024", "price": 25990000}
```

Tại điểm này, chuyện gì đang xảy ra ở tầng network:

- DNS resolution: `api.example.com` → IP address (cached hoặc query DNS server)
- TCP 3-way handshake: SYN → SYN-ACK → ACK (1 round-trip)
- TLS handshake: ClientHello → ServerHello → Certificate → Key Exchange (1-2 round-trips)
- HTTP request gửi qua encrypted TLS tunnel

**Nếu dùng HTTP/2** (persistent connection): TCP + TLS handshake đã xong từ request trước → request này gửi ngay trên connection sẵn có (0 round-trips overhead). Đây là lý do HTTP/2 nhanh hơn đáng kể cho subsequent requests.

#### # load balancer / reverse proxy (nginx/haproxy)

Request đến IP của load balancer trước, không phải trực tiếp đến app server.

```
Client → [Load Balancer :443] → [App Server :8080]
```

Load balancer làm gì:

1. **TLS Termination**: Decrypt HTTPS → forward HTTP nội bộ (hoặc re-encrypt)
2. **Health check**: Chỉ route đến healthy instances
3. **Load balancing**: Round-robin, least-connections, hoặc weighted
4. **Rate limiting**: Reject nếu client exceed quota (429 Too Many Requests)
5. **Request logging**: Access log cho monitoring

Sau TLS termination, load balancer forward request (plain HTTP) đến 1 instance của Spring Boot app. Header `X-Forwarded-For` chứa client IP gốc, `X-Forwarded-Proto` = "https".

#### # api gateway (optional — kong, spring cloud gateway)

Nếu có API Gateway layer (microservices architecture):

```
Client → LB → [API Gateway] → [Product Service]
```

Gateway thêm:

- **Authentication verification**: Validate JWT token (check signature, expiry, issuer)
- **Route resolution**: `/api/v1/products/**` → product-service instance
- **Request transformation**: Add headers, strip prefixes
- **Circuit breaker**: Reject nếu downstream service unhealthy
- **Distributed tracing**: Inject trace ID header (OpenTelemetry)

### phase 2: spring boot — servlet container (tomcat)

#### # tomcat nhận request

Spring Boot embed Tomcat server (default port 8080). Khi request đến:

1. **Acceptor thread** nhận TCP connection từ NIO connector
2. **Poller thread** detect data available trên connection
3. **Worker thread** (từ thread pool, default max 200) assigned để xử lý request
4. Tomcat parse HTTP: method, URI, headers, body stream

```
Tomcat Thread Pool (default):
├── max-threads: 200 (worker threads)
├── min-spare-threads: 10 (idle threads ready)
├── accept-count: 100 (queue size khi tất cả threads bận)
└── connection-timeout: 20000ms

Nếu 200 threads đang bận + queue đầy 100 → connection refused (503)
```

**Điều quan trọng**: Từ đây, toàn bộ request processing xảy ra trên 1 worker thread duy nhất (blocking model). Thread này bị "occupied" cho đến khi response gửi xong. Đây là lý do thread pool size ảnh hưởng trực tiếp đến throughput.

#### # servlet filter chain

Trước khi đến Controller, request đi qua chuỗi Servlet Filters. Mỗi filter có thể: modify request, reject request, hoặc pass forward.

```
Request → [Filter 1] → [Filter 2] → [Filter 3] → ... → [DispatcherServlet]
                                                             ↓
Response ← [Filter 3] ← [Filter 2] ← [Filter 1] ← ... ← [Controller]
```

Filters thường gặp (theo thứ tự):

```java
// 1. CORS Filter — check Origin header, add CORS response headers
// Nếu Origin không allowed → 403 ngay, không đến Controller

// 2. Security Filter Chain (Spring Security)
//    a. SecurityContextPersistenceFilter — load/create SecurityContext
//    b. JwtAuthenticationFilter — extract + validate JWT token
//    c. AuthorizationFilter — check URL-level permissions
//    Nếu token invalid/expired → 401 ngay

// 3. Request Logging Filter — log request in (method, URI, headers)

// 4. ContentCachingRequestWrapper — buffer body cho re-read (logging/audit)
```

##### # spring security — jwt validation chi tiết:

```java
// Bên trong JwtAuthenticationFilter, đây là những gì xảy ra:

// 1. Extract token từ "Authorization: Bearer xxx" header
String token = request.getHeader("Authorization").substring(7);

// 2. Decode JWT (3 parts: header.payload.signature, base64url encoded)
// Header: {"alg":"RS256","kid":"key-id-123"}
// Payload: {"sub":"user-001","roles":["EDITOR"],"exp":1719849600,"iss":"auth.example.com"}

// 3. Verify signature (RSA/ECDSA)
//    - Fetch public key từ JWKS endpoint (cached): auth.example.com/.well-known/jwks.json
//    - Verify: signature matches header+payload using public key
//    - Nếu sai → 401 Unauthorized

// 4. Check claims:
//    - exp > now? (token chưa hết hạn?)
//    - iss == expected issuer?
//    - aud contains expected audience?

// 5. Extract authorities từ token (roles/permissions)
//    → Tạo Authentication object → set vào SecurityContext
//    → SecurityContext attached vào current thread (ThreadLocal)

// 6. Filter chain continues...
```

**Chuyện gì có thể sai ở đây:**

- Token expired → 401 (client cần refresh token)
- Token signature invalid → 401 (token bị tamper hoặc key rotation)
- JWKS endpoint down → 401 hoặc 500 (tùy caching strategy)
- Rate limit exceeded → 429

### # phase 3: spring mvc — request handling

#### # dispatcherservlet — front controller

`DispatcherServlet` là trái tim của Spring MVC. Nó nhận mọi request và dispatch đến đúng handler.

```
DispatcherServlet workflow:
1. HandlerMapping: "PUT /api/v1/products/{id}" → ProductController.update()
2. HandlerAdapter: setup method arguments (path variables, request body, headers)
3. Execute handler method
4. ResultHandler: serialize return value → HTTP response
```

#### # argument resolution — parse request thành java objects

Trước khi gọi controller method, Spring resolve mỗi parameter:

```java
@PutMapping("/{id}")
public ResponseEntity<APIResponse<ProductDTO>> update(
   @PathVariable UUID id,           // ← PathVariableMethodArgumentResolver
   @Valid @RequestBody UpdateProductRequest request,  // ← RequestBodyMethodArgumentResolver
   @RequestHeader("X-Request-Id") String requestId   // ← RequestHeaderMethodArgumentResolver
) { ... }
```

**@RequestBody resolution chi tiết:**

1. Đọc request body bytes từ InputStream
2. Check `Content-Type: application/json` → chọn Jackson `MappingJackson2HttpMessageConverter`
3. Jackson `ObjectMapper.readValue(bytes, UpdateProductRequest.class)`

- Parse JSON string → JsonNode tree
- Map fields theo tên (hoặc @JsonProperty)
- Call constructor/setters để tạo Java object
- Nếu JSON malformed → `HttpMessageNotReadableException` → 400

**@Valid — Bean Validation trigger:** 4. Hibernate Validator scan annotations trên `UpdateProductRequest` 5. Validate từng field: `@NotBlank`, `@Positive`, `@Size`... 6. Nếu violations → `MethodArgumentNotValidException` → 400 (handled by @RestControllerAdvice) 7. Nếu pass → object sẵn sàng dùng

```java
@Data
public class UpdateProductRequest {
   @NotBlank(message = "Name is required")
   @Size(max = 255)
   private String name;

   @NotNull @Positive(message = "Price must be positive")
   private BigDecimal price;
}
```

#### # controller method execution

```java
@RestController
@RequestMapping("/api/v1/products")
@RequiredArgsConstructor
public class ProductController {

   private final ProductService productService;

   @PutMapping("/{id}")
   public ResponseEntity<APIResponse<ProductDTO>> update(
           @PathVariable UUID id,
           @Valid @RequestBody UpdateProductRequest request,
           @RequestHeader("X-Request-Id") String requestId) {

       // Tại đây: chỉ delegate — không có business logic trong controller
       ProductDTO updated = productService.update(id, request);
       return ResponseEntity.ok(APIResponse.success(updated));
   }
}
```

Controller chỉ là "adapter" — convert HTTP world (request/response) sang application world (service call). Zero business logic here.

### # phase 4: service layer — business logic & transaction

#### # @Transactional — transaction bắt đầu

Khi thread enter method đánh `@Transactional`, Spring AOP proxy intercept:

```java
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class ProductService {

   private final ProductRepository productRepository;  // JPA
   private final ProductDocumentRepository documentRepository;  // MongoDB

   @Transactional  // readOnly = false → write transaction
   public ProductDTO update(UUID id, UpdateProductRequest request) {
       // ← TẠI ĐÂY: Spring TransactionInterceptor bắt đầu transaction
       // 1. TransactionManager.getTransaction() called
       // 2. DataSource.getConnection() → lấy connection từ HikariCP pool
       // 3. connection.setAutoCommit(false) → bắt đầu DB transaction
       // 4. Connection bind vào ThreadLocal (TransactionSynchronizationManager)

       Product product = productRepository.findById(id)
           .orElseThrow(() -> new ProductNotFoundException(id));

       // Business logic
       product.setName(request.getName());
       product.setPrice(request.getPrice());
       product.setUpdatedAt(LocalDateTime.now());

       // Save to PostgreSQL
       Product saved = productRepository.save(product);

       // Save metadata to MongoDB
       documentRepository.updateMetadata(id, Map.of(
           "lastModified", LocalDateTime.now(),
           "modifiedBy", SecurityUtils.getCurrentUserId()
       ));

       return toDTO(saved);
       // ← KHI METHOD RETURN THÀNH CÔNG:
       // 1. TransactionInterceptor calls commit()
       // 2. connection.commit() → PostgreSQL commit
       // 3. Connection return về HikariCP pool
       // 4. ThreadLocal cleanup

       // ← NẾU EXCEPTION THROW:
       // 1. TransactionInterceptor calls rollback()
       // 2. connection.rollback() → PostgreSQL rollback
       // 3. Connection return pool
       // 4. Exception propagate lên controller → error response
   }
}
```

#### # connection pool (hikaricp) — behind the scenes

Khi `DataSource.getConnection()` được gọi, HikariCP không tạo connection mới — nó lấy từ pool:

```
HikariCP Pool State:
├── Total connections: 20 (maximum-pool-size)
├── Active (đang dùng): 8
├── Idle (sẵn sàng): 12
└── Waiting threads: 0

Khi getConnection():
1. Kiểm pool có idle connection không?
  ├── CÓ → return ngay (< 1ms)
  └── KHÔNG + pool chưa full → tạo connection mới (~50-200ms cho PostgreSQL)
  └── KHÔNG + pool đã full → thread WAIT (block) cho đến connectionTimeout (30s default)
      └── Timeout → ConnectionTimeoutException → 500

Connection lifecycle:
- Được tạo bởi pool (TCP connect to PostgreSQL: 3-way handshake + auth)
- Reused across transactions (dozens/hundreds of times)
- Health-checked bởi pool (SELECT 1, hoặc JDBC isValid())
- Evicted khi idle quá lâu (idleTimeout) hoặc sống quá lâu (maxLifetime)
```

**Performance insight**: Mỗi connection = 1 TCP socket + 1 PostgreSQL backend process (~10MB RAM on DB server). Pool 20 connections = 20 backend processes. Đây là lý do `maximum-pool-size` không nên quá lớn — tốn RAM DB server và context-switch overhead.

#### # aop proxying — cách @Transactional thực sự hoạt động

Spring không modify bytecode. Nó tạo **proxy object** wrap real service:

```
Khi inject ProductService:
 Controller nhận → CGLIB Proxy (subclass of ProductService)
 KHÔNG phải real ProductService instance

Call flow:
 controller.update(id, request)
     → proxy.update(id, request)              // Proxy intercept
         → TransactionInterceptor.invoke()    // Begin TX
             → realService.update(id, request) // Actual business logic
         → TransactionInterceptor.commit()    // Commit TX (nếu success)
     ← return result to controller
```

**Đây là lý do self-invocation bypass @Transactional**: khi method A gọi `this.methodB()` trong cùng class, nó gọi trực tiếp (không qua proxy) → không có transaction cho methodB.

### # phase 5: jpa/hibernate — object-relational mapping

#### # findbyid — select query

```java
Product product = productRepository.findById(id).orElseThrow();
```

Bên dưới, Hibernate:

1. Check **1st Level Cache** (Persistence Context / EntityManager): entity với id này đã load trong session chưa?

- CÓ → return cached entity (0 SQL queries!)
- KHÔNG → tiếp bước 2

2. Check **2nd Level Cache** (nếu enabled): entity có trong shared cache không?

- CÓ → hydrate entity từ cache
- KHÔNG → tiếp bước 3

3. Generate SQL: `SELECT * FROM products WHERE id = $1`
4. Get PreparedStatement từ connection
5. Set parameter: `ps.setObject(1, uuid)`
6. Execute query → ResultSet
7. **Hydration**: Map ResultSet columns → Java object fields
8. Đặt entity vào Persistence Context (1st level cache)
9. Set entity state = `MANAGED` (Hibernate track changes từ đây)

```sql
-- SQL thực tế được generate (với format_sql=true):
SELECT
   p.id, p.name, p.price, p.code, p.status,
   p.category_id, p.created_at, p.updated_at, p.version
FROM products p
WHERE p.id = '550e8400-e29b-41d4-a716-446655440000'
```

#### # dirty checking — detect changes

Sau khi `product.setName("Laptop Pro 2024")` và `product.setPrice(25990000)`:

Hibernate KHÔNG gửi UPDATE ngay. Nó chỉ modify Java object trong memory. Entity vẫn MANAGED trong Persistence Context.

**Khi nào UPDATE thực sự xảy ra?**

- Khi `flush()` được gọi (explicit hoặc auto)
- Auto-flush triggers:
- Trước khi execute query (đảm bảo query thấy data mới nhất)
- Trước khi transaction commit
- Khi gọi `repository.save()` (optional, Spring Data JPA trigger flush)

#### # repository.save() — persist changes

```java
Product saved = productRepository.save(product);
```

Spring Data JPA's `save()` implementation:

```java
// SimpleJpaRepository.save() — source code simplified
public <S extends T> S save(S entity) {
   if (entityInformation.isNew(entity)) {
       em.persist(entity);  // INSERT (new entity, no ID)
   } else {
       return em.merge(entity);  // UPDATE (existing entity, has ID)
   }
}
```

Vì entity đã MANAGED (loaded bởi findById) và đã có ID → `merge()` called.
Thực tế với MANAGED entity, `save()` không bắt buộc — Hibernate dirty checking tự detect changes và flush khi commit. Nhưng `save()` explicit hơn và trigger flush sớm hơn.

#### # flush — generate & execute update sql

Khi flush (trước commit hoặc explicit):

1. Hibernate compare current entity state vs **snapshot** (state lúc load)
2. Detect **dirty fields**: name changed, price changed
3. Generate UPDATE SQL (chỉ update dirty columns nếu `@DynamicUpdate`, hoặc tất cả columns mặc định)

```sql
-- Generated UPDATE (default: all columns)
UPDATE products
SET name = 'Laptop Pro 2024',
   price = 25990000,
   code = 'LP-2024',           -- unchanged nhưng vẫn trong SET (default behavior)
   status = 'ACTIVE',          -- unchanged
   updated_at = '2024-06-19T10:30:00',
   version = 3                  -- optimistic lock: version + 1
WHERE id = '550e8400-e29b-41d4-a716-446655440000'
 AND version = 2               -- optimistic lock: check old version

-- Với @DynamicUpdate (chỉ dirty columns):
UPDATE products
SET name = 'Laptop Pro 2024',
   price = 25990000,
   updated_at = '2024-06-19T10:30:00',
   version = 3
WHERE id = '550e8400-e29b-41d4-a716-446655440000'
 AND version = 2
```

4. Execute PreparedStatement
5. Check `affected rows`:

- `1` → success
- `0` → `OptimisticLockException` (someone else updated between our read and write)

### # phase 6: postgresql — từ sql đến disk

#### # query processing pipeline

Khi PostgreSQL server nhận UPDATE statement

![query-processing-pipeline](/assets/img/blog/query-processing-pipeline.png)

Cho UPDATE cụ thể:

1. **Index Scan** trên `products_pkey` (B-tree index trên id column) → tìm row location (page + offset)
2. **Heap access**: Read page chứa row từ shared buffers (RAM) hoặc disk
3. **Row-level lock**: Acquire `FOR UPDATE` lock trên row (block concurrent UPDATEs trên cùng row)
4. **MVCC check**: Verify row version phù hợp (`AND version = 2`)

#### # mvcc (multi-version concurrency control) — postgresql's magic

PostgreSQL KHÔNG overwrite data cũ. Nó tạo **version mới** của row:

![postgresql-mvcc](/assets/img/blog/postgresql-mvcc.png)

UPDATE tạo:

- Old tuple: set xmax = current transaction ID (mark as "expired")
- New tuple: INSERT với xmin = current transaction ID
- Old tuple KHÔNG bị xóa ngay — VACUUM cleanup sau

Đây là MVCC: readers đọc old version (không bị block bởi writer) writers tạo new version (không block readers)

#### # wal (write-ahead log) — durability guarantee

TRƯỚC KHI modify data page, PostgreSQL ghi **WAL record** (write-ahead log):

```
Thứ tự write:
1. Ghi WAL record vào WAL buffer (memory)
2. Modify data page trong shared buffers (memory)
3. Khi COMMIT: flush WAL buffer → WAL file trên disk (fsync)
4. Data pages flush ra disk SAU (async, bởi background writer/checkpointer)

Tại sao WAL trước data?
- WAL sequential write (fast: ~1-2ms fsync)
- Data pages random write (slow: phụ thuộc vị trí trên disk)
- Nếu crash sau WAL write nhưng trước data write → recovery replay WAL → data consistent
- Nếu crash trước WAL write → transaction chưa commit → data stays old version → consistent
```

```
WAL Record cho UPDATE:
├── Transaction ID: 12345
├── Table: products (OID: 16384)
├── Block: 42 (page number)
├── Offset: 3 (tuple index within page)
├── Old tuple: (header + "Laptop Pro", 19990000, ...)
├── New tuple: (header + "Laptop Pro 2024", 25990000, ...)
└── Timestamp: 2024-06-19 10:30:00.123
```

#### # index update

Khi row data thay đổi, indexes cũng cần update:

- **Primary key index** (B-tree on `id`): ID không đổi → index entry point to new tuple location (HOT update nếu cùng page)
- **Secondary indexes** (nếu có index trên `name` hoặc `price`): Insert new entry + mark old entry dead
- **GIN/GiST indexes** (full-text search): Rebuild affected entries

**HOT (Heap-Only Tuple) Update**: Nếu new tuple fit trong cùng page VÀ indexed columns không đổi → PostgreSQL dùng HOT update (chỉ update heap, không update index). Significant performance win.

#### # commit — durability moment

Khi Hibernate call `connection.commit()`:

```
PostgreSQL COMMIT sequence:
1. Write COMMIT WAL record to WAL buffer
2. Flush WAL buffer to disk (fsync) ← ĐÂY là "durability point"
  - Sau fsync thành công: dù server crash, data recoverable từ WAL
  - Trước fsync: data có thể mất nếu crash
3. Mark transaction as committed in CLOG (commit log)
4. Release row-level locks
5. Return success to client (JDBC driver)

fsync latency:
- SSD: ~0.1-1ms
- HDD: ~5-15ms (disk rotation)
- Battery-backed write cache: <0.1ms

Đây là lý do SSD quan trọng cho database: COMMIT speed = fsync speed
```

### # phase 7: mongodb — document update

Nếu service cũng update metadata trong MongoDB (common pattern: relational cho structured data, MongoDB cho flexible/nested metadata):

#### # mongodb wire protocol

Spring Data MongoDB serialize operation thành BSON (Binary JSON) và gửi qua MongoDB Wire Protocol:

```java
// Spring Data MongoDB operation
documentRepository.updateMetadata(productId, metadata);

// Translated to MongoDB command:
db.product_metadata.updateOne(
   { _id: "550e8400-e29b-41d4-a716-446655440000" },
   { $set: {
       "metadata.lastModified": ISODate("2024-06-19T10:30:00Z"),
       "metadata.modifiedBy": "user-001",
       "metadata.version": 3
   }},
   { upsert: false }
)
```

#### # mongodb server processing

```
MongoDB Update Pipeline:
1. Router (mongos) hoặc Primary nhận command
2. Parse BSON command
3. Acquire document-level lock (WiredTiger: document-level, không page-level)
4. Find document: query _id index (B-tree)
5. Read document từ WiredTiger cache (in-memory) hoặc disk
6. Apply $set operations (modify in-place nếu size không đổi)
7. Write updated document
8. Update indexes (nếu indexed fields thay đổi)
9. Write to journal (WAL equivalent)
10. Return success
```

#### # wiredtiger storage engine — behind mongodb

WiredTiger (default storage engine từ MongoDB 3.2) khác PostgreSQL:

```
WiredTiger vs PostgreSQL:
├── Concurrency: Document-level lock (WiredTiger) vs Row-level lock (PG)
├── MVCC: Cả 2 đều có, nhưng WiredTiger dùng in-place update + journaling
├── Compression: Snappy/zlib/zstd (WiredTiger) vs Toast (PG)
├── Cache: WiredTiger internal cache (50% RAM default) vs Shared Buffers (PG, 25% RAM)
└── Journal: Checkpoint every 60s + journal mỗi 100ms (WiredTiger) vs WAL continuous (PG)
```

**Update in WiredTiger:**

1. Đọc document vào WiredTiger cache (decompressed)
2. Modify document trong cache
3. Ghi journal record (durability — mỗi 100ms hoặc mỗi commit nếu `j:true`)
4. Document stays trong cache (dirty page)
5. Checkpoint (mỗi 60s): flush dirty pages ra disk (compressed)

#### # write concern — durability trade-off

MongoDB cho phép tuning durability vs speed:

```java
// Spring Data MongoDB — configure write concern
@Configuration
public class MongoConfig {
   @Bean
   public MongoClientSettings mongoSettings() {
       return MongoClientSettings.builder()
           .writeConcern(WriteConcern.MAJORITY  // Wait majority replicas acknowledge
               .withJournal(true)                // Wait journal flush
               .withWTimeout(5000, TimeUnit.MILLISECONDS))
           .build();
   }
}
```

| Write Concern        | Durability         | Speed   | Risk                                          |
| -------------------- | ------------------ | ------- | --------------------------------------------- |
| w:0 (unacknowledged) | None               | Fastest | Data loss on any failure                      |
| w:1 (default)        | Primary only       | Fast    | Data loss if primary crash before replication |
| w:majority           | Majority replicas  | Medium  | Safe (tolerates minority failures)            |
| w:1 + j:true         | Primary + journal  | Medium  | Safe on single node (journal recovery)        |
| w:majority + j:true  | Majority + journal | Slowest | Safest                                        |

### # phase 8: response journey — back to client

#### # service → controller → response serialization

```java
// Service returns DTO
ProductDTO updated = toDTO(saved);

// Controller wraps in APIResponse
return ResponseEntity.ok(APIResponse.success(updated));

// Spring MVC response handling:
// 1. HandlerMethodReturnValueHandler detect return type = ResponseEntity
// 2. Extract status (200), headers, body (APIResponse<ProductDTO>)
// 3. Content negotiation: Accept header = "application/json" → Jackson
// 4. Jackson ObjectMapper.writeValueAsString(apiResponse) → JSON string
// 5. Write JSON bytes to HttpServletResponse OutputStream
```

**Jackson serialization:**

```java
// ObjectMapper traverses object graph:
APIResponse
 ├── statusCode: 200 → "status_code": 200
 ├── data: ProductDTO
 │     ├── id: UUID → "id": "550e8400-..."
 │     ├── name: "Laptop Pro 2024" → "name": "Laptop Pro 2024"
 │     ├── price: BigDecimal → "price": 25990000
 │     ├── updatedAt: LocalDateTime → "updated_at": "2024-06-19T10:30:00" (via JavaTimeModule)
 │     └── null fields → SKIPPED (JsonInclude.NON_NULL)
 └── timestamp: Instant → "timestamp": "2024-06-19T03:30:00.123Z"

// Output ~200 bytes JSON
```

#### # response filters (outbound)

Response đi ngược qua filter chain:

1. **Response logging filter**: log response status, size, duration
2. **Metrics filter**: record request duration → Prometheus `http_server_requests_seconds`
3. **Security headers**: add `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`
4. **Compression**: nếu client Accept-Encoding: gzip → compress response body

#### # tomcat → network → client

```
1. Tomcat write response to socket buffer
2. TCP send: split into segments (MSS ~1460 bytes), send with ACK
3. TLS encrypt (nếu không termination ở LB)
4. Load Balancer forward to client
5. Client receive → parse JSON → update UI

HTTP Response:
HTTP/1.1 200 OK
Content-Type: application/json
Content-Length: 287
X-Request-Id: req-7f3a2b1c-4d5e-6f7a
X-Response-Time: 142ms

{"status_code":200,"data":{"id":"550e8400-...","name":"Laptop Pro 2024","price":25990000,"updated_at":"2024-06-19T10:30:00"},"timestamp":"2024-06-19T03:30:00.123Z"}
```

### # phase 9: after response — async & background

Sau khi response đã gửi, nhiều thứ vẫn xảy ra:

#### # event publishing (spring events)

```java
// Trong service, event đã được publish:
eventPublisher.publishEvent(new ProductUpdatedEvent(product.getId(), oldName, newName));

// @TransactionalEventListener chạy SAU commit:
@TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
public void onProductUpdated(ProductUpdatedEvent event) {
   // Chạy async — không block response
   cacheService.evict("product:" + event.getProductId());
   searchIndexService.reindex(event.getProductId());
   auditService.logChange(event);
   webhookService.notify(event);
}
```

#### # postgresql background processes

```
Sau COMMIT, PostgreSQL background workers:
├── WAL Sender: replicate WAL records to standby servers (streaming replication)
├── Background Writer: periodically flush dirty pages from shared buffers to disk
├── Checkpointer: every 5 min (default), write all dirty pages + WAL checkpoint
├── Autovacuum: later, clean dead tuples left by UPDATE (MVCC)
│   - Remove old row version (xmax set)
│   - Update visibility map
│   - Update statistics for query planner
└── Stats Collector: update pg_stat_user_tables (seq_scan, idx_scan, n_tup_upd)
```

#### # connection return to pool

```
Sau transaction commit:
1. connection.setAutoCommit(true) — restore default
2. Reset connection state (warnings, savepoints)
3. Return connection to HikariCP pool → available for next request
4. Worker thread return to Tomcat pool → available for next request

Timeline of thread/connection usage:
├── Thread occupied: ~142ms (entire request lifecycle)
├── Connection occupied: ~50ms (from TX begin to TX commit)
└── Actual DB processing: ~5ms (query + update + commit)
```

### # timeline summary — 142ms breakdown

```
0ms    ─── Client sends request
2ms    ─── TLS/TCP (reused connection)
5ms    ─── Load Balancer → App Server
8ms    ─── Servlet Filters (JWT validation: ~3ms)
12ms   ─── Argument resolution + validation
15ms   ─── Service method enter, TX begin, get connection from pool
18ms   ─── SELECT (findById): index scan + return (~3ms)
20ms   ─── Business logic (set fields): ~0.1ms
22ms   ─── Dirty checking + flush: generate UPDATE SQL
25ms   ─── PostgreSQL UPDATE execution: index scan + row lock + write + WAL
30ms   ─── MongoDB update: find + modify + journal
35ms   ─── COMMIT PostgreSQL: WAL fsync (~1-2ms SSD)
40ms   ─── Release connection, TX complete
42ms   ─── DTO mapping + Jackson serialization
45ms   ─── Response filters (logging, metrics)
47ms   ─── Tomcat write to socket
50ms   ─── Network transit back to client
52ms   ─── Client receives response

After response (async):
60ms   ─── Cache eviction
70ms   ─── Search re-index
80ms   ─── Audit log
100ms  ─── Webhook notification
...    ─── PostgreSQL autovacuum (minutes later)
```

### # điều gì có thể sai? (failure modes)

| Layer              | Failure                       | Impact                            | Mitigation                      |
| ------------------ | ----------------------------- | --------------------------------- | ------------------------------- |
| Network            | Timeout, packet loss          | Client gets timeout error         | Retry with idempotency key      |
| Load Balancer      | All backends unhealthy        | 503 Service Unavailable           | Health checks, auto-scaling     |
| Tomcat             | Thread pool exhausted         | Connection queue full → rejected  | Monitor threads, tune pool      |
| Security           | Token expired                 | 401 Unauthorized                  | Client refresh token flow       |
| Validation         | Invalid input                 | 400 Bad Request                   | Clear error messages            |
| Connection Pool    | Pool exhausted                | Thread waits → timeout            | Monitor pool, tune max size     |
| Database           | Deadlock                      | Transaction rollback → retry      | Consistent lock ordering        |
| Database           | Optimistic Lock               | Update rejected (concurrent edit) | Retry or notify user            |
| PostgreSQL         | Disk full                     | All writes fail                   | Monitoring, auto-extend, alerts |
| MongoDB            | Primary election              | Brief write unavailability        | retryWrites=true, write concern |
| Network (internal) | Service-to-DB connection lost | Transaction rollback              | Connection validation, retry    |

### # key takeaways

1. **1 HTTP request touches 10+ components** — mỗi cái có thể fail independently
2. **Thread is precious** — mỗi request "chiếm" 1 thread suốt lifecycle. Connection cũng vậy. Pool sizes = throughput limit.
3. **Flush ≠ Commit** — Hibernate flush gửi SQL đến DB nhưng chưa durable. Commit + WAL fsync = durable.
4. **PostgreSQL MVCC**: UPDATE = INSERT new + mark old dead. VACUUM cleanup sau. Đây là lý do table bloat nếu VACUUM không chạy đủ.
5. **MongoDB document-level lock** > PostgreSQL row-level lock cho concurrent writes trên different documents, nhưng cùng document vẫn serialized.
6. **Connection pool size = bottleneck thường gặp nhất**. Formula: pool size = ((core_count \* 2) + effective_spindle_count). Thường 10-30 là sweet spot.
7. **Hầu hết latency nằm ở I/O**: network round-trips, disk fsync, connection establishment. CPU processing thường < 5% total time.

> Chỉ là những ghi chép cá nhân với hy vọng mang lại chút giá trị. Nếu thấy hữu ích, đừng ngại chia sẻ cho bạn bè & đồng nghiệp nhé!

Happy coding <Twemoji emoji="clinking-beer-mugs" /> 😎 👍🏻 🚀 🔥.
