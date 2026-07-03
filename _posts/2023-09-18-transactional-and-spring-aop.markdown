---
layout: post
title: "@Transactional & spring aop — transaction management & cross-cutting concerns"
date: 2023-09-18 19:29:39 +0700
categories: [Software Development]
tags: [java, software-development, spring-framework, best-practices, vietnamese]
---

### # giới thiệu

Có 2 thứ mà senior developer phải hiểu sâu trong Spring: **Transactions** và **AOP (Aspect-Oriented Programming)**. Chúng liên quan mật thiết — `@Transactional` bản thân nó hoạt động nhờ AOP proxy.

Transaction đảm bảo ACID: hoặc tất cả thay đổi commit, hoặc tất cả rollback. Không có trạng thái "nửa nọ nửa kia" — order tạo nhưng payment không ghi, inventory giảm nhưng order fail. Trong microservices, transaction management còn phức tạp hơn với distributed transactions và saga patterns.

AOP cho phép tách "cross-cutting concerns" — logging, security, caching, metrics — ra khỏi business logic. Thay vì copy-paste log statements vào mỗi method, viết 1 aspect apply cho tất cả.

### # @Transactional — deep dive

#### # cơ bản: service layer pattern

Trong Spring, transaction boundary đặt ở **service layer** — không phải controller, không phải repository. Lý do: 1 business operation thường involve nhiều repository calls, tất cả phải trong cùng 1 transaction.

```java
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)  // Default: read-only cho toàn class
@Slf4j
public class OrderService {

   private final OrderRepository orderRepository;
   private final InventoryService inventoryService;
   private final PaymentService paymentService;
   private final ApplicationEventPublisher eventPublisher;

   // Read-only: Hibernate skip dirty checking → faster
   public OrderDTO getById(UUID id) {
       return orderRepository.findById(id)
           .map(this::toDTO)
           .orElseThrow(() -> new OrderNotFoundException(id));
   }

   // Write operation: override class-level readOnly
   @Transactional  // readOnly = false
   public OrderDTO create(CreateOrderRequest request) {
       // Tất cả trong 1 transaction:
       Order order = buildOrder(request);
       order = orderRepository.save(order);          // 1. Save order
       inventoryService.reserve(order.getItems());   // 2. Reserve inventory
       paymentService.authorize(order);              // 3. Authorize payment

       // Nếu step 3 throw exception → step 1, 2 đều rollback
       eventPublisher.publishEvent(new OrderCreatedEvent(order));
       return toDTO(order);
   }

   // Explicit rollback rules
   @Transactional(rollbackFor = Exception.class)  // Rollback cho checked exceptions
   public void importOrders(List<CreateOrderRequest> requests) {
       // Mặc định: chỉ rollback RuntimeException + Error
       // rollbackFor = Exception.class: rollback cả checked exceptions
       requests.forEach(this::create);
   }

   // No rollback cho specific exceptions
   @Transactional(noRollbackFor = DuplicateOrderException.class)
   public OrderDTO createIdempotent(CreateOrderRequest request) {
       try {
           return create(request);
       } catch (DuplicateOrderException e) {
           // Không rollback — return existing order
           return getByIdempotencyKey(request.getIdempotencyKey());
       }
   }
}
```

#### # propagation — transaction giữa các methods

```java
@Service
public class OrderService {

   // REQUIRED (default): Join TX hiện có, hoặc tạo mới
   @Transactional(propagation = Propagation.REQUIRED)
   public OrderDTO create(CreateOrderRequest request) {
       // Nếu caller đã có TX → join
       // Nếu không → tạo TX mới
   }

   // REQUIRES_NEW: LUÔN tạo TX mới (suspend TX hiện tại)
   @Transactional(propagation = Propagation.REQUIRES_NEW)
   public void logAudit(AuditEntry entry) {
       // TX riêng: commit ngay cả khi caller TX rollback
       // Use case: audit log phải ghi bất kể business op thành công hay không
       auditRepository.save(entry);
   }

   // NESTED: Tạo savepoint trong TX hiện tại
   @Transactional(propagation = Propagation.NESTED)
   public void processItem(OrderItem item) {
       // Nếu fail → rollback đến savepoint (không rollback cả TX)
       // Caller có thể catch và continue với item tiếp
   }

   // MANDATORY: PHẢI có TX sẵn, exception nếu không
   @Transactional(propagation = Propagation.MANDATORY)
   public void updateInventory(UUID productId, int qty) {
       // Force caller phải gọi trong TX context
       // Tránh vô tình gọi standalone mà quên TX
   }

   // NOT_SUPPORTED: Suspend TX, chạy không TX
   @Transactional(propagation = Propagation.NOT_SUPPORTED)
   public ReportDTO generateReport(ReportRequest request) {
       // Read-heavy, long-running → không cần giữ TX lock
   }
}
```

#### # isolation levels — concurrent access control

```java
// READ_COMMITTED (default PostgreSQL): Không đọc uncommitted data
@Transactional(isolation = Isolation.READ_COMMITTED)
public OrderDTO getOrder(UUID id) { ... }

// REPEATABLE_READ: Cùng query trong TX luôn trả cùng kết quả
@Transactional(isolation = Isolation.REPEATABLE_READ)
public void transferFunds(UUID from, UUID to, BigDecimal amount) {
   // Đảm bảo balance không thay đổi giữa đọc và ghi
}

// SERIALIZABLE: Cao nhất — sequential execution
@Transactional(isolation = Isolation.SERIALIZABLE)
public void processPayment(PaymentRequest request) {
   // Critical financial operation — no concurrency issues
   // Trade-off: throughput giảm đáng kể
}
```

#### # @Transactional pitfalls — senior must know

```java
// ❌ PITFALL 1: Self-invocation bypass proxy
@Service
public class OrderService {
   @Transactional
   public void processAll() {
       for (Order order : orders) {
           this.processOne(order); // GỌI TRỰC TIẾP → KHÔNG qua proxy → KHÔNG có TX
       }
   }

   @Transactional(propagation = Propagation.REQUIRES_NEW)
   public void processOne(Order order) { ... }
}

// ✅ FIX: Inject self hoặc tách service
@Service
@RequiredArgsConstructor
public class OrderService {
   private final OrderItemProcessor itemProcessor; // Separate bean

   @Transactional
   public void processAll() {
       for (Order order : orders) {
           itemProcessor.processOne(order); // Qua proxy → có TX
       }
   }
}

// ❌ PITFALL 2: @Transactional trên private/final method
@Transactional
private void internalMethod() { }  // CGLIB cannot proxy private/final

// ❌ PITFALL 3: Catch exception trong TX method
@Transactional
public void riskyOperation() {
   try {
       riskyCall(); // throws RuntimeException
   } catch (Exception e) {
       log.error("Failed", e);
       // TX đã bị mark rollback-only!
       // Khi method return, Spring throw UnexpectedRollbackException
   }
}

// ✅ FIX: Programmatic TX control khi cần partial commit
@Transactional
public void batchProcess(List<Item> items) {
   for (Item item : items) {
       try {
           itemProcessor.process(item); // REQUIRES_NEW → isolated TX
       } catch (Exception e) {
           log.warn("Item {} failed, continuing", item.getId());
           // item's TX rolls back, outer TX continues
       }
   }
}
```

### # spring aop — cross-cutting concerns

AOP cho phép "cắt ngang" nhiều classes với cùng 1 logic mà không sửa code gốc. Spring implement AOP qua proxy pattern (giống @Transactional).

#### # concepts

| Term       | Nghĩa                                        | Ví dụ                           |
| ---------- | -------------------------------------------- | ------------------------------- |
| Aspect     | Module chứa cross-cutting logic              | LoggingAspect                   |
| Advice     | Code chạy tại join point                     | @Around, @Before, @After        |
| Pointcut   | Expression xác định methods nào bị intercept | "execution(_ ..service.._(..))" |
| Join Point | Điểm execution bị intercept                  | Method call                     |
| Target     | Object gốc (không proxy)                     | ProductService instance         |

#### # logging aspect

```java
@Aspect
@Component
@Slf4j
public class ServiceLoggingAspect {

   // Pointcut: mọi public method trong package service
   @Around("execution(public * vn.com.vpbank.internal.csp..service..*(..))")
   public Object logServiceMethod(ProceedingJoinPoint joinPoint) throws Throwable {
       String method = joinPoint.getSignature().toShortString();
       String traceId = RequestContext.getRequestId();
       long start = System.nanoTime();

       log.info("[traceId={}] → {}", traceId, method);
       try {
           Object result = joinPoint.proceed();
           long duration = (System.nanoTime() - start) / 1_000_000;
           log.info("[traceId={}] ← {} | {}ms", traceId, method, duration);
           return result;
       } catch (Exception e) {
           long duration = (System.nanoTime() - start) / 1_000_000;
           log.error("[traceId={}] ✗ {} | {}ms | {}", traceId, method, duration, e.getMessage());
           throw e;
       }
   }
}
```

#### # performance monitoring aspect

```java
@Aspect
@Component
@Slf4j
public class PerformanceAspect {

   private final MeterRegistry meterRegistry;

   // Custom annotation
   @Around("@annotation(monitored)")
   public Object monitorPerformance(ProceedingJoinPoint pjp, Monitored monitored) throws Throwable {
       String metricName = monitored.value().isEmpty()
           ? pjp.getSignature().toShortString()
           : monitored.value();

       Timer.Sample sample = Timer.start(meterRegistry);
       try {
           Object result = pjp.proceed();
           sample.stop(Timer.builder(metricName).tag("status", "success").register(meterRegistry));
           return result;
       } catch (Exception e) {
           sample.stop(Timer.builder(metricName).tag("status", "error").register(meterRegistry));
           throw e;
       }
   }
}

// Custom annotation
@Target(ElementType.METHOD)
@Retention(RetentionPolicy.RUNTIME)
public @interface Monitored {
   String value() default "";
}

// Usage
@Monitored("order.creation")
public OrderDTO createOrder(CreateOrderRequest request) { ... }
```

#### # retry aspect

```java
@Aspect
@Component
@Slf4j
public class RetryAspect {

   @Around("@annotation(retryable)")
   public Object retry(ProceedingJoinPoint pjp, Retryable retryable) throws Throwable {
       int maxAttempts = retryable.maxAttempts();
       long delay = retryable.delay();
       Exception lastException = null;

       for (int attempt = 1; attempt <= maxAttempts; attempt++) {
           try {
               return pjp.proceed();
           } catch (Exception e) {
               lastException = e;
               if (attempt < maxAttempts) {
                   log.warn("Attempt {}/{} failed for {}: {}. Retrying in {}ms",
                       attempt, maxAttempts, pjp.getSignature().toShortString(),
                       e.getMessage(), delay);
                   Thread.sleep(delay);
                   delay *= 2; // Exponential backoff
               }
           }
       }
       throw lastException;
   }
}

@Target(ElementType.METHOD)
@Retention(RetentionPolicy.RUNTIME)
public @interface Retryable {
   int maxAttempts() default 3;
   long delay() default 1000;
}

// Usage
@Retryable(maxAttempts = 3, delay = 500)
public ExternalResponse callExternalService(Request request) { ... }
```

#### # pointcut expressions cheat sheet

```java
// Mọi method trong service package
@Pointcut("execution(* vn.com.vpbank.internal.csp..service..*(..))")

// Mọi public method
@Pointcut("execution(public * *(..))")

// Method có annotation cụ thể
@Pointcut("@annotation(vn.com.vpbank.internal.csp.common.annotation.Monitored)")

// Class có annotation cụ thể
@Pointcut("@within(org.springframework.stereotype.Service)")

// Method nhận tham số cụ thể
@Pointcut("execution(* *..*(UUID, ..))")  // First param is UUID

// Combine pointcuts
@Pointcut("serviceLayer() && !getter()")
public void serviceMethodsExcludeGetters() {}
```

### # quick reference

| Annotation                  | Mục đích                       |
| --------------------------- | ------------------------------ |
| @Transactional              | Transaction boundary           |
| @Transactional(readOnly)    | Optimize read operations       |
| @Transactional(propagation) | TX interaction between methods |
| @Transactional(isolation)   | Concurrent access control      |
| @Transactional(rollbackFor) | Specify rollback exceptions    |
| @Transactional(timeout)     | TX timeout in seconds          |
| @Aspect                     | Declare AOP aspect class       |
| @Around                     | Wrap method execution          |
| @Before                     | Run before method              |
| @After                      | Run after method (always)      |
| @AfterReturning             | Run after successful return    |
| @AfterThrowing              | Run after exception            |
| @Pointcut                   | Reusable pointcut expression   |
| @EnableAspectJAutoProxy     | Enable AOP proxy               |
| @Order                      | Aspect execution order         |

> Chỉ là những ghi chép cá nhân với hy vọng mang lại chút giá trị. Nếu thấy hữu ích, đừng ngại chia sẻ cho bạn bè & đồng nghiệp nhé!

Happy coding <Twemoji emoji="clinking-beer-mugs" /> 😎 👍🏻 🚀 🔥.
