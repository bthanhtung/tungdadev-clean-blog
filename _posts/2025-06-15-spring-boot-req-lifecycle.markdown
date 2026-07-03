---
layout: post
title: "spring-boot request lifecycle"
date: 2025-06-15 19:29:39 +0700
categories: [Software Development]
tags: [java, software-development, spring-boot, best-practices, vietnamese]
---

Có bao giờ giữa những đêm dài debug một lỗi `memory leak` hay `tracing` một request bị nghẽn mạng, bạn tự hỏi thực sự điều gì
đang diễn ra bên dưới bề nổi của những annotation `@RestController` hay `@Transactional`?

Spring Boot, với triết lý "convention over configuration", mang lại cho chúng ta một sự rảnh rang đáng kể.
Nhưng sự tiện lợi ấy đôi khi giống như một tấm màn nhung che khuất đi cơ chế vận hành cốt lõi. Để thực sự làm chủ hệ thống,
tối ưu hóa hiệu năng, hay kiến trúc nên những dịch vụ chịu tải cao, chúng ta cần một lần thực hành lối sống tối giản - gạt bỏ
đi những "phép màu" bề ngoài để nhìn rành rọt vào tận cùng bản chất của framework.

Bài viết này là một chuyến hành trình đi dọc theo dòng chảy của một HTTP Request trong Spring Boot.
Từ lúc nó chập chững bước vào cánh cửa `Servlet Container`, len lỏi qua các tầng `Filter`, chạm tới `Controller`,
lặn sâu xuống Database và cuối cùng ngược dòng mang theo Response trở về.

### # overview flow

Một request đi qua hệ thống không phải là một đường thẳng, mà là một vòng cung chữ U xuyên qua các lớp lang kiến trúc,
tuân thủ chặt chẽ nguyên tắc `Separation of Concerns`.
![springboot-req-flow]({{ site.baseurl }}/assets/img/blog/springboot-req-flow.png)

Hãy cùng bóc tách từng lớp (layer) để xem các kỹ sư của Spring đã thiết kế hệ thống rành mạch như thế nào.

### # layer 1: servlet container (tomcat)

Mọi thứ bắt đầu từ web server. Khi một `TCP connection` được thiết lập, `Tomcat` sẽ phân công một thread để xử lý request này.
Trong kỷ nguyên của Java 21, việc cấu hình `Virtual Threads` giúp chúng ta phá vỡ giới hạn của `thread pool` truyền thống,
mang lại khả năng chịu tải đột phá cho các `I/O-bound` application.

```yaml
server:
  port: 8080
  servlet:
    context-path: /console
  tomcat:
    threads:
      max: 200 # max worker threads (ignored if virtual threads enabled)
      min-spare: 10
    max-connections: 8192
    accept-count: 100

# Virtual threads → mỗi request 1 virtual thread, no pool limit
spring:
  threads:
    virtual:
      enabled: true
```

`Tomcat` nhận TCP connection → assign thread → gọi Filter chain.

### # layer 2: servlet filters

`Filter` là khái niệm của Servlet API, không phải của riêng Spring. Nó bao bọc toàn bộ vòng đời của request.
Đây là nơi hoàn hảo để gắn mã định danh `(TraceID)` cho bài toán Distributed Tracing, giúp ta dễ dàng truy vết log sau này.

```java
@Component
@Order(Ordered.HIGHEST_PRECEDENCE)
public class RequestTracingFilter extends OncePerRequestFilter {

    @Override
    protected void doFilterInternal(HttpServletRequest request,
            HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {

        String traceId = Optional.ofNullable(request.getHeader("X-Request-Id"))
                                 .orElseGet(() -> UUID.randomUUID().toString());

        MDC.put("requestId", traceId); // Gắn vào Mapped Diagnostic Context
        response.setHeader("X-Request-Id", traceId);

        long start = System.nanoTime();
        try {
            chain.doFilter(request, response); // Chuyền tay cho Filter tiếp theo
        } finally {
            long duration = (System.nanoTime() - start) / 1_000_000;
            log.info("[traceId={}] {} {} → {} ({}ms)",
                traceId, request.getMethod(), request.getRequestURI(),
                response.getStatus(), duration);
            MDC.clear(); // Bắt buộc phải dọn dẹp để tránh rò rỉ context giữa các Thread
        }
    }
}
```

#### # filter vs interceptor

| Feature      | Filter (Servlet)                     | Interceptor (Spring MVC)  |
| ------------ | ------------------------------------ | ------------------------- |
| Level        | Servlet container                    | DispatcherServlet         |
| Access       | Raw request/response                 | Handler method info       |
| Scope        | All requests (including static)      | Only mapped handlers      |
| Spring beans | Cần đăng ký explicit                 | Auto-detected             |
| Use case     | Security, CORS, logging, compression | Auth check, audit, locale |

### # layer 3: spring security filter chain

`Security Filter Chain` thực chất là một chuỗi các `Filter` đặc biệt được Spring nhúng vào Tầng 2.
Nó là một tấm khiên chắn thép, kiểm tra danh tính `(Authentication)` và quyền hạn `(Authorization)` trước khi request kịp chạm tới logic nghiệp vụ.

Với kiến trúc `Stateless` API hiện đại (thường dùng JWT), luồng xác thực tại `BearerTokenAuthenticationFilter` diễn ra mộc mạc mà chặt chẽ:

```
SecurityFilterChain (ordered filters):
 1. DisableEncodeUrlFilter
 2. WebAsyncManagerIntegrationFilter
 3. SecurityContextHolderFilter
 4. HeaderWriterFilter
 5. CorsFilter
 6. CsrfFilter (disabled for stateless)
 7. LogoutFilter
 8. BearerTokenAuthenticationFilter ← JWT validation
 9. RequestCacheAwareFilter
 10. SecurityContextHolderAwareRequestFilter
 11. AnonymousAuthenticationFilter
 12. SessionManagementFilter
 13. ExceptionTranslationFilter
 14. AuthorizationFilter ← URL-based access rules
```

JWT validation tại `BearerTokenAuthenticationFilter`:

1. Extract `Authorization: Bearer <token>` header
2. Decode JWT, validate signature via JWKS endpoint
3. Check expiry, issuer, audience
4. Convert claims → `Authentication` object
5. Store in `SecurityContextHolder`

### # layer 4: DispatcherServlet + handler mapping

Vượt qua Security, request chính thức bước vào lãnh thổ của Spring MVC: `DispatcherServlet`.
Dựa vào `HandlerMapping`, nó tìm ra đúng `Controller Method` để xử lý. Nhưng trước khi `Controller` được gọi, request phải đi qua các `Interceptor`.

```java
// DispatcherServlet pseudocode:
HandlerExecutionChain chain = handlerMapping.getHandler(request);
// chain = controller method + interceptors

// Run interceptors pre-handle
for (HandlerInterceptor interceptor : chain.getInterceptors()) {
   if (!interceptor.preHandle(request, response, handler)) {
       return; // short-circuit
   }
}

// Invoke controller method
ModelAndView mv = handlerAdapter.handle(request, response, handler);

// Run interceptors post-handle
for (HandlerInterceptor interceptor : chain.getInterceptors()) {
   interceptor.postHandle(request, response, handler, mv);
}
```

#### # HandlerInterceptor

```java
@Component
public class AuditInterceptor implements HandlerInterceptor {

   @Override
   public boolean preHandle(HttpServletRequest request, HttpServletResponse response,
                            Object handler) {
       // Runs AFTER security filters, BEFORE controller
       // handler = HandlerMethod (controller method info)
       if (handler instanceof HandlerMethod hm) {
           log.info("Calling {}.{}()", hm.getBeanType().getSimpleName(), hm.getMethod().getName());
       }
       return true; // continue chain
   }

   @Override
   public void postHandle(HttpServletRequest request, HttpServletResponse response,
                          Object handler, ModelAndView modelAndView) {
       // After controller, before response written (only if no exception)
   }

   @Override
   public void afterCompletion(HttpServletRequest request, HttpServletResponse response,
                               Object handler, Exception ex) {
       // Always runs — even if exception thrown
       // Good for cleanup
   }
}

// Register
@Configuration
public class WebConfig implements WebMvcConfigurer {
   @Override
   public void addInterceptors(InterceptorRegistry registry) {
       registry.addInterceptor(auditInterceptor)
           .addPathPatterns("/api/**")
           .excludePathPatterns("/api/public/**");
   }
}
```

### # layer 5: argument resolution & validation

Từ những chuỗi `JSON` vô tri hay các `path variable` thô cứng, Spring sử dụng `HttpMessageConverter` (thường là Jackson)
và cơ chế `Reflection` để nhào nặn chúng thành các `DTO` (Data Transfer Object) vuông vức. Kèm theo đó là lưới
lọc `@Valid` (Jakarta Bean Validation)chặn đứng các dữ liệu rác.

```java
@RestController
@RequestMapping("/api/orders")
@RequiredArgsConstructor
public class OrderController {

   @PostMapping
   public ResponseEntity<APIResponse<OrderDTO>> createOrder(
           @Valid @RequestBody CreateOrderRequest request,  // ← Jackson deserialize + validate
           @AuthenticationPrincipal Jwt jwt,                // ← extract from SecurityContext
           @RequestHeader("X-Workspace-Id") UUID workspaceId // ← header extraction
   ) {
       // If @Valid fails → MethodArgumentNotValidException → @ExceptionHandler
       // If type conversion fails → TypeMismatchException
       // If body missing → HttpMessageNotReadableException
   }
}
```

#### # validation flow

```
@Valid @RequestBody CreateOrderRequest
 → Jackson ObjectMapper.readValue(body, CreateOrderRequest.class)
 → Jakarta Bean Validation
   → @NotNull, @NotBlank, @Size, @Pattern...
   → Custom @ValidXxx → XxxValidator.isValid()
 → If violations → MethodArgumentNotValidException
 → Else → pass to controller method
```

### # layer 6: controller → service (aop proxies)

```java
@RestController
@RequiredArgsConstructor
public class OrderController {
   private final OrderService orderService; // ← injected PROXY, not real instance

   @PostMapping("/api/orders")
   public ResponseEntity<?> create(@Valid @RequestBody CreateOrderRequest req,
                                   @AuthenticationPrincipal Jwt jwt) {
       OrderDTO result = orderService.createOrder(req, jwt.getSubject());
       return ResponseEntity.status(201).body(APIResponse.success(result));
   }
}
```

#### # aop proxy chain

Khi gọi `orderService.createOrder()`, thực tế gọi qua `CGLIB proxy`:

```
Proxy.createOrder()
 → @PreAuthorize check (if present)
 → @Transactional interceptor (begin TX)
 → @LogExecutionTime aspect (if present)
 → Real OrderService.createOrder()
 → @Transactional interceptor (commit or rollback)
```

### # layer 7: service layer

```java
@Service
@RequiredArgsConstructor
@Slf4j
public class OrderService {
   private final OrderRepository orderRepo;
   private final ProductService productService;
   private final ApplicationEventPublisher eventPublisher;

   @Transactional
   public OrderDTO createOrder(CreateOrderRequest req, String userId) {
       // 1. Business validation
       Product product = productService.getById(req.getProductId());
       if (!product.isAvailable()) {
           throw new BusinessException("PRODUCT_UNAVAILABLE");
       }

       // 2. Create entity
       Order order = Order.builder()
           .customerId(userId)
           .productId(product.getId())
           .quantity(req.getQuantity())
           .status(OrderStatus.PENDING)
           .build();

       // 3. Persist (Hibernate dirty checking → INSERT SQL)
       Order saved = orderRepo.save(order);

       // 4. Publish event (async via multicaster)
       eventPublisher.publishEvent(new OrderCreatedEvent(this, saved));

       // 5. Map to DTO
       return OrderMapper.INSTANCE.toDTO(saved);
   }
   // If exception → @Transactional proxy rollbacks
   // If success → @Transactional proxy commits
}
```

### # layer 8: repository / data access

```java
public interface OrderRepository extends JpaRepository<Order, UUID> {
   // Spring Data generates implementation at runtime
}
```

#### # jpa persistence flow

```
repo.save(order)
 → EntityManager.persist(order)  [if new]
 → EntityManager.merge(order)    [if detached]
 → Hibernate:
   → First-level cache check (persistence context)
   → Generate SQL INSERT/UPDATE
   → Get JDBC connection from HikariCP pool
   → Execute PreparedStatement
   → Return generated ID
   → Entity enters "managed" state
 → At TX commit:
   → Flush persistence context (dirty checking)
   → Execute pending SQLs in batch
   → JDBC connection.commit()
   → Return connection to pool
```

#### # connection pool (HikariCP)

```yaml
spring:
  datasource:
    hikari:
      maximum-pool-size: 20
      minimum-idle: 5
      idle-timeout: 300000
      connection-timeout: 20000
      max-lifetime: 1200000
```

Nếu `Pool` cạn kiệt, `Thread` sẽ phải chờ đợi trong mỏi mòn (connection-timeout). Nếu quá thời gian,
`ConnectionTimeoutException` sẽ ném ra, kéo sập cả chuỗi xử lý bên trên. Cấu hình `HikariCP` chuẩn xác là nghệ thuật của sự cân bằng.

```
Thread requests connection
 → Pool has idle connection? → Return immediately
 → Pool at max? → Wait (up to connection-timeout)
 → Timeout exceeded? → ConnectionTimeoutException
```

### # layer 9: exception handling

Trên chặng đường quay về, nếu bất kỳ tầng nào (từ `Service`, `DB` đến `Controller`) ném ra `Exception`, chuỗi proxy sẽ
lập tức cuộn trào lên trên. `@Transactional` đánh dấu `rollback`. Lỗi được đẩy ra ngoài cho `DispatcherServlet` và bị tóm gọn bởi `@RestControllerAdvice`.

Lúc này, một `Exception` lạnh lùng được gói gém lại thành một `Error Response` có cấu trúc chuẩn chỉnh, thân thiện với người dùng (client-friendly).

```java
@RestControllerAdvice
@Slf4j
public class GlobalExceptionHandler {

   // Validation errors
   @ExceptionHandler(MethodArgumentNotValidException.class)
   public ResponseEntity<APIResponse<?>> handleValidation(MethodArgumentNotValidException ex) {
       List<String> errors = ex.getBindingResult().getFieldErrors().stream()
           .map(e -> e.getField() + ": " + e.getDefaultMessage())
           .toList();
       return ResponseEntity.badRequest()
           .body(APIResponse.error("VALIDATION_ERROR", errors));
   }

   // Business exceptions
   @ExceptionHandler(BusinessException.class)
   public ResponseEntity<APIResponse<?>> handleBusiness(BusinessException ex) {
       log.warn("[traceId={}] Business error: {}", RequestContext.getRequestId(), ex.getMessage());
       return ResponseEntity.badRequest()
           .body(APIResponse.error(ex.getCode(), ex.getMessage()));
   }

   // Not found
   @ExceptionHandler(EntityNotFoundException.class)
   public ResponseEntity<APIResponse<?>> handleNotFound(EntityNotFoundException ex) {
       return ResponseEntity.status(404)
           .body(APIResponse.error("NOT_FOUND", ex.getMessage()));
   }

   // Catch-all
   @ExceptionHandler(Exception.class)
   public ResponseEntity<APIResponse<?>> handleUnexpected(Exception ex) {
       log.error("[traceId={}] Unexpected error", RequestContext.getRequestId(), ex);
       return ResponseEntity.status(500)
           .body(APIResponse.error("INTERNAL_ERROR", "An unexpected error occurred"));
   }
}
```

#### # exception propagation path

```
Exception thrown in Service/Repository
 → Bubbles up through AOP proxies
   → @Transactional catches → rollback TX
 → Reaches DispatcherServlet
 → DispatcherServlet delegates to HandlerExceptionResolver
 → @RestControllerAdvice @ExceptionHandler matched
 → Error response serialized → returned to client
 → HandlerInterceptor.afterCompletion(ex) called
 → Filter chain unwinds (finally blocks)
```

### # layer 10: response serialization

`Jackson` lại một lần nữa vào việc (tại `MappingJackson2HttpMessageConverter`), chuyển đổi `Object` (DTO hoặc Error Response) thành chuỗi `JSON`.
Dòng chảy đi ngược qua các `Filter`, trả dọn dẹp các Context Map (như `MDC.clear()`) và an tọa dưới dạng một `HTTP Response `hoàn chỉnh.

```java
// Controller returns object → Jackson serializes to JSON
@GetMapping("/orders/{id}")
public OrderDTO getOrder(@PathVariable UUID id) {
   return orderService.getById(id); // ← Jackson calls getters, serializes
}
```

#### # HttpMessageConverter chain

```
Return value (OrderDTO)
 → ContentNegotiation (Accept header → application/json)
 → MappingJackson2HttpMessageConverter
   → ObjectMapper.writeValueAsString(dto)
   → Custom serializers (@JsonSerialize)
   → @JsonIgnore, @JsonProperty handling
 → Write to response body
 → Set Content-Type: application/json
```

#### # jackson customization

```java
@Configuration
public class JacksonConfig {
   @Bean
   public ObjectMapper objectMapper() {
       return JsonMapper.builder()
           .addModule(new JavaTimeModule())
           .disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS)
           .disable(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES)
           .serializationInclusion(JsonInclude.Include.NON_NULL)
           .build();
   }
}
```

### # complete timing example

Để hình dung sự mượt mà của hệ thống, hãy nhìn vào thang đo thời gian của một "Happy Path":

```
[0ms]    Request arrives at Tomcat
[1ms]    Filter: RequestTracingFilter (assign traceId)
[2ms]    Filter: SecurityFilterChain (JWT validation, JWKS cache hit)
[3ms]    DispatcherServlet: resolve handler
[3ms]    Interceptor: preHandle
[4ms]    Argument resolution: deserialize JSON body
[5ms]    Bean Validation: @Valid check
[5ms]    Controller method invoked
[6ms]    AOP: @Transactional begin
[7ms]    Service: business logic
[8ms]    Repository: get connection from pool
[9ms]    Execute SQL query (DB round-trip)
[12ms]   Repository: return entity
[13ms]   Service: map to DTO, publish event
[14ms]   AOP: @Transactional commit
[15ms]   Controller: return ResponseEntity
[16ms]   Jackson: serialize DTO → JSON
[16ms]   Interceptor: postHandle, afterCompletion
[17ms]   Filter chain: cleanup MDC
[17ms]   Response sent to client
```

### # key concepts

#### # request scope

```
Tomcat Thread (or Virtual Thread)
 ├── SecurityContext (Authentication object)
 ├── MDC (traceId, userId for logging)
 ├── ScopedValue (RequestContext.REQUEST_ID)
 ├── LocaleContext (i18n)
 └── Transaction (bound to thread via TransactionSynchronizationManager)
```

Tất cả đều thread-bound → mất khi spawn async thread (cần propagation).

#### # filter vs interceptor vs aop

| Layer             | When                          | Use Case                             |
| ----------------- | ----------------------------- | ------------------------------------ |
| Filter            | Before/after entire servlet   | Security, CORS, compression, tracing |
| Interceptor       | Before/after controller       | Audit, locale, permission check      |
| AOP (@Aspect)     | Around any Spring bean method | Logging, transaction, caching, retry |
| @ControllerAdvice | On exception                  | Error response mapping               |

#### # order of execution (happy path)

```
1. Filter.doFilter (before)
2. Security filters (authentication + authorization)
3. Interceptor.preHandle
4. Argument resolution + validation
5. AOP around advice (before)
6. Controller method
7. Service method (within TX)
8. Repository → DB
9. Service returns
10. AOP around advice (after)
11. Controller returns
12. Interceptor.postHandle
13. Response serialization
14. Interceptor.afterCompletion
15. Filter.doFilter (after/finally)
```

#### # order of execution (exception path)

```
1-7.  Same as happy path until exception
8.    Exception thrown
9.    @Transactional rollback
10.   AOP after-throwing advice
11.   Exception bubbles to DispatcherServlet
12.   @ExceptionHandler resolves error response
13.   Interceptor.afterCompletion(ex)
14.   Filter finally blocks (MDC cleanup)
15.   Error response sent
```

Bức tranh kiến trúc của Spring Boot dẫu có phức tạp và đồ sộ, nhưng khi bóc tách từng lớp lang, ta thấy được vẻ đẹp của
sự trật tự, của những Design Pattern (như Chain of Responsibility, Proxy, Observer) được áp dụng ở mức độ bậc thầy.

Hiểu sâu về Lifecycle không chỉ để viết code cho chạy, mà là để biết đặt đúng thứ vào đúng chỗ: Security phải nằm ở
Filter, Business Logic không được tràn ra Controller, và Connection Pool thì luôn cần sự giám sát gắt gao.

> Chỉ là những ghi chép cá nhân với hy vọng mang lại chút giá trị. Nếu thấy hữu ích, đừng ngại chia sẻ cho bạn bè & đồng nghiệp nhé!

Happy coding <Twemoji emoji="clinking-beer-mugs" /> 😎 👍🏻 🚀 🔥.
