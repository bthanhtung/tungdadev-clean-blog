---
layout: post
title: "microservice communicate pattern"
date: 2026-02-21 19:29:39 +0700
categories: [Software Development]
tags: [java, software-development, microservices, best-practices, vietnamese]
---

Hành trình chuyển đổi từ một khối monolithic khổng lồ sang kiến trúc microservices mang lại sự tự do, nhưng đồng thời cũng mở ra một chiếc hộp Pandora về sự phức tạp. Ở thế giới phân tán, mạng lưới không bao giờ đáng tin cậy. Các node có thể "ngã quỵ" bất cứ lúc nào, độ trễ là kẻ thù giấu mặt, và việc gỡ lỗi có thể biến thành một cuộc mò kim đáy bể.

Sự tinh tế của một hệ thống tốt không nằm ở việc nó sở hữu bao nhiêu công nghệ hào nhoáng, mà ở sự tĩnh tại, trơn tru trong dòng chảy dữ liệu. Việc loại bỏ những kết nối rườm rà (chatty communication) để giữ lại những giao tiếp cốt lõi chính là triết lý tối giản áp dụng vào kiến trúc phần mềm.

Bài viết này sẽ đào sâu vào các pattern giao tiếp giữa các microservices, cách bảo vệ hệ thống trước giông bão, và nghệ thuật giữ cho mọi thứ nằm trong tầm kiểm soát.

### # synchronous communication

Giao tiếp đồng bộ yêu cầu phía gọi (client) phải chờ đợi phản hồi từ phía nhận (server). Lợi điểm là dòng chảy logic rất rõ ràng, dễ theo dõi, nhưng cái giá phải trả là sự phụ thuộc chặt chẽ về mặt thời gian (temporal coupling).

#### # rest (WebClient / RestClient)

Trong hệ sinh thái Spring 6, RestClient cung cấp một cách tiếp cận fluent, hiện đại và chặn (blocking) cho những luồng nghiệp vụ đơn giản. Trong khi đó, WebClient là lựa chọn tối ưu cho các luồng non-blocking.

```java
// Lựa chọn 1: Spring 6 RestClient (Blocking, thiết kế thanh lịch)
@Component
public class UserClient {
   private final RestClient restClient;

   public UserClient(@Value("${service.user.url}") String baseUrl) {
       this.restClient = RestClient.builder()
           .baseUrl(baseUrl)
           .defaultHeader("Content-Type", "application/json")
           .build();
   }

   public UserDTO getUser(UUID id, String token) {
       return restClient.get()
           .uri("/users/{id}", id)
           .header("Authorization", "Bearer " + token)
           .retrieve()
           .onStatus(HttpStatusCode::is4xxClientError, (req, res) -> {
               throw new UserNotFoundException(id);
           })
           .body(UserDTO.class);
   }
}

// Lựa chọn 2: WebClient (Non-blocking, hướng tới hiệu năng cao)
@Component
public class AsyncUserClient {
   private final WebClient webClient;

   public Mono<UserDTO> getUser(UUID id) {
       return webClient.get()
           .uri("/users/{id}", id)
           .retrieve()
           .bodyToMono(UserDTO.class)
           .timeout(Duration.ofSeconds(3))
           .onErrorResume(WebClientResponseException.NotFound.class,
               e -> Mono.empty());
   }
}
```

#### # gRPC

Khi bạn cần giao tiếp nội bộ (service-to-service) với độ trễ cực thấp và payload nhỏ gọn, gRPC là vị vua không ngai. Nó hoạt động dựa trên HTTP/2 và Protobuf, thay vì JSON cồng kềnh.

```java
// High-performance binary protocol
// Proto definition → generated stubs
@GrpcService
public class UserGrpcService extends UserServiceGrpc.UserServiceImplBase {
   @Override
   public void getUser(GetUserRequest request, StreamObserver<UserResponse> observer) {
       User user = userService.findById(request.getId());
       observer.onNext(toProto(user));
       observer.onCompleted();
   }
}

// Client
@Component
public class UserGrpcClient {
   private final UserServiceGrpc.UserServiceBlockingStub stub;

   public UserResponse getUser(String id) {
       return stub.withDeadlineAfter(3, TimeUnit.SECONDS)
           .getUser(GetUserRequest.newBuilder().setId(id).build());
   }
}
```

#### # khi nào dùng

| Protocol | Use Case                               | Trade-off                             |
| -------- | -------------------------------------- | ------------------------------------- |
| REST     | CRUD, public APIs, simple queries      | Human-readable, higher latency        |
| gRPC     | Internal service-to-service, streaming | Fast, binary, requires proto contract |
| GraphQL  | Frontend aggregation, flexible queries | Complexity, N+1 risk                  |

### # asynchronous communication

Giống như việc bạn gửi một bức thư và tiếp tục làm việc khác thay vì đứng chờ người đưa thư mang hồi đáp về. Kiến trúc Event-Driven giúp các service giải phóng sự phụ thuộc vào nhau. Hệ thống lúc này chỉ giao tiếp qua các Domain Events, bảo toàn trọn vẹn triết lý của Clean Architecture: lớp Application/Domain hoàn toàn không biết đến sự tồn tại của các service khác.

#### # event-driven (rabbitmq/kafka)

Pattern "Fire-and-forget" giúp giảm tải đáng kể cho các tiến trình chịu tải cao.

```java
@Service
public class OrderService {
   public Order createOrder(CreateOrderDTO dto) {
       // 1. Lưu trạng thái vào core domain
       Order order = repo.save(map(dto));

       // 2. Bắn sự kiện ra thế giới bên ngoài (Infrastructure layer)
       // OrderService không cần biết ai sẽ xử lý (Inventory, Notification, etc.)
       rabbitTemplate.convertAndSend(
           "order.exchange",
           "order.created",
           new OrderCreatedEvent(order.getId())
       );

       return order;
   }
}
```

#### # request-reply (async rpc)

Có những lúc bạn vẫn cần câu trả lời, nhưng lại không muốn chịu rủi ro rớt kết nối mạng chặn đứng toàn bộ thread. Request-Reply pattern trên RabbitMQ giải quyết bài toán này.

```java
public PaymentResult requestPayment(PaymentRequest request) {
   Message reply = rabbitTemplate.sendAndReceive(
       "payment.exchange",
       "payment.process",
       MessageBuilder.withBody(serialize(request))
           .setCorrelationId(UUID.randomUUID().toString())
           .build()
   );
   return deserialize(reply.getBody(), PaymentResult.class);
}
```

### # resilience patterns

Mọi lời gọi ra bên ngoài đều tiềm ẩn rủi ro. Nếu không có cơ chế phòng ngự, một service "chết" sẽ kéo theo sự sụp đổ dây chuyền (cascading failure) của toàn bộ hệ thống. Sử dụng Resilience4j là chuẩn mực hiện tại trong thế giới Spring.

#### # circuit breaker (Resilience4j)

Khi một service hạ nguồn bắt đầu ném lỗi liên tục, thay vì tiếp tục "đâm đầu vào đá", Circuit Breaker sẽ ngắt mạch (Open), trả về Fallback ngay lập tức để bảo vệ tài nguyên.

```java
// Dependency
// implementation 'io.github.resilience4j:resilience4j-spring-boot3'

@Service
public class PaymentClient {

   @CircuitBreaker(name = "paymentService", fallbackMethod = "paymentFallback")
   public PaymentResult processPayment(PaymentRequest request) {
       return restClient.post()
           .uri("/payments")
           .body(request)
           .retrieve()
           .body(PaymentResult.class);
   }

   // Lưới an toàn: hứng lỗi khi cầu dao mở hoặc mạng đứt
   private PaymentResult paymentFallback(PaymentRequest request, Throwable t) {
       log.warn("Payment service gián đoạn. Chuyển vào hàng đợi: {}", t.getMessage());
       rabbitTemplate.convertAndSend("payment.retry.queue", request);
       return PaymentResult.pending("Đang chờ xử lý");
   }
}
```

Configuration:

```yaml
resilience4j:
  circuitbreaker:
    instances:
      paymentService:
        sliding-window-size: 10
        failure-rate-threshold: 50 # open after 50% failures
        wait-duration-in-open-state: 30s # wait before half-open
        permitted-number-of-calls-in-half-open-state: 3
        slow-call-duration-threshold: 2s
        slow-call-rate-threshold: 80
```

#### # retry

Thử lại những lỗi thoáng qua (transient errors) như rớt mạng tức thời. Lưu ý: Luôn đi kèm Exponential Backoff (thời gian chờ tăng dần) và thao tác gọi phải đảm bảo tính Idempotent (gọi nhiều lần không thay đổi kết quả).

```java
@Retry(name = "externalApi", fallbackMethod = "retryFallback")
public DataDTO fetchData(String id) {
   return restClient.get().uri("/data/{id}", id).retrieve().body(DataDTO.class);
}
```

```yaml
resilience4j:
  retry:
    instances:
      externalApi:
        max-attempts: 3
        wait-duration: 1s
        exponential-backoff-multiplier: 2
        retry-exceptions:
          - java.io.IOException
          - java.util.concurrent.TimeoutException
        ignore-exceptions:
          - com.example.BusinessException
```

#### # rate limiter

Giới hạn tốc độ gọi API để không làm quá tải đối tác thứ 3.

```java
@RateLimiter(name = "thirdPartyApi")
public Response callThirdParty(Request request) {
   return externalClient.call(request);
}
```

```yaml
resilience4j:
  ratelimiter:
    instances:
      thirdPartyApi:
        limit-for-period: 100
        limit-refresh-period: 1s
        timeout-duration: 500ms
```

#### # bulkhead (isolation)

Cô lập tài nguyên. Giới hạn số lượng thread pool cho một chức năng nặng để nó không "ăn" hết tài nguyên của toàn bộ ứng dụng.

```java
@Bulkhead(name = "heavyOperation", type = Bulkhead.Type.THREADPOOL)
public Result processHeavy(Request request) {
   return heavyService.process(request);
}
```

```yaml
resilience4j:
  bulkhead:
    instances:
      heavyOperation:
        max-concurrent-calls: 10
        max-wait-duration: 500ms
  thread-pool-bulkhead:
    instances:
      heavyOperation:
        max-thread-pool-size: 5
        core-thread-pool-size: 3
        queue-capacity: 20
```

#### # combining patterns

Khi kết hợp, thứ tự thực thi luôn là: `Retry → CircuitBreaker → RateLimiter → Bulkhead`.

```java
// Order matters: Retry → CircuitBreaker → RateLimiter → Bulkhead
@CircuitBreaker(name = "backend")
@Retry(name = "backend")
@RateLimiter(name = "backend")
public Response callBackend(Request request) {
   return client.call(request);
}
```

### # timeout chains

Một vấn đề cực kỳ tinh vi trong microservices là quản lý thời gian chờ. Giả sử: Service A gọi B, B gọi C. Nếu mỗi service tự định nghĩa timeout là 5s, Client gọi Service A có thể phải đợi đến 15s chỉ để nhận về một lỗi báo timeout từ C.

#### # Solution: Cascading timeouts

```yaml
# Service A (gateway) — total budget: 5s
service-b:
  timeout: 3s # leaves 2s for own processing

# Service B — budget from A: 3s
service-c:
  timeout: 1.5s # leaves 1.5s for own processing
```

```java
@GetMapping("/aggregate")
public AggregateDTO aggregate(@RequestHeader("X-Request-Deadline") Optional<Instant> deadline) {
   // Nếu không có, gán ngân sách tổng là 5 giây
   Instant myDeadline = deadline.orElse(Instant.now().plusSeconds(5));
   Duration remaining = Duration.between(Instant.now(), myDeadline);

   if (remaining.isNegative()) {
       throw new TimeoutException("Ngân sách thời gian đã cạn kiệt, hủy luồng.");
   }

   // Chỉ cấp cho các lời gọi hạ nguồn phần thời gian còn lại
   Duration downstreamBudget = remaining.dividedBy(2);
   return client.getData(downstreamBudget);
}
```

### # service discovery

Trong một cụm hàng chục services luôn thay đổi IP (do scale up/down), việc hardcode URL là tối kỵ. Service Discovery (như Eureka) giúp các service tự tìm thấy nhau thông qua những tên miền ảo.

#### # eureka (client-side discovery)

```yaml
# Service registers itself
eureka:
  client:
    service-url:
      defaultZone: http://localhost:8087/eureka/
  instance:
    prefer-ip-address: true
    instance-id: ${spring.application.name}:${server.port}
```

```java
// Load-balanced RestClient via service name
@Bean
@LoadBalanced
public RestTemplate restTemplate() {
   return new RestTemplate();
}

// Call by service name (Eureka resolves to IP:port)
restTemplate.getForObject("http://user-service/users/{id}", UserDTO.class, id);
```

#### # fallback discovery (mongodb-based)

```java
// When Eureka is unavailable — query MongoDB for registered services
public String resolveServiceUrl(String serviceName) {
   try {
       return eurekaClient.getNextServerFromEureka(serviceName, false).getHomePageUrl();
   } catch (Exception e) {
       // Fallback to MongoDB registry
       ServiceRegistration reg = mongoTemplate.findOne(
           Query.query(Criteria.where("serviceName").is(serviceName).and("status").is("UP")),
           ServiceRegistration.class);
       return reg != null ? reg.getUrl() : null;
   }
}
```

### # distributed tracing

Để kiểm soát dòng chảy logic, Distributed Tracing (OpenTelemetry + Micrometer) là hệ thần kinh trung ương của hệ thống. Dấu vết (Trace ID) sẽ truyền qua tất cả các lời gọi HTTP và Message Broker, giúp chúng ta dựng lại bức tranh toàn cảnh khi có sự cố.

#### # opentelemetry + micrometer

```yaml
management:
  tracing:
    sampling:
      probability: 1.0 # 100% in dev, lower in prod
  otlp:
    tracing:
      endpoint: http://localhost:4318/v1/traces
```

```java
// Auto-propagated via Micrometer Tracing
// HTTP headers: traceparent, tracestate (W3C format)
// RabbitMQ: message headers

// Manual span creation
@Component
@RequiredArgsConstructor
public class CustomTracing {
   private final Tracer tracer;

   public void tracedOperation() {
       Span span = tracer.nextSpan().name("custom-operation").start();
       try (Tracer.SpanInScope ws = tracer.withSpan(span)) {
           doWork();
           span.tag("result", "success");
       } catch (Exception e) {
           span.error(e);
           throw e;
       } finally {
           span.end();
       }
   }
}
```

### # api gateway patterns

#### # request routing

Thay vì để ứng dụng Frontend/Mobile phải gọi gộp từ 5-7 services khác nhau, tạo ra các "chatty communication", chúng ta nên thiết lập một mặt tiền duy nhất.

Pattern BFF (Backend for Frontend) cho phép Gateway hoặc một service chuyên biệt đứng ra tổng hợp dữ liệu, tận dụng tối đa sức mạnh của xử lý song song (Concurrency).

```yaml
# Spring Cloud Gateway (or custom proxy)
spring:
  cloud:
    gateway:
      routes:
        - id: user-service
          uri: lb://user-service
          predicates:
            - Path=/api/users/**
          filters:
            - StripPrefix=1
            - AddRequestHeader=X-Internal, true
```

#### # backend for frontend (bff)

```java
@GetMapping("/dashboard")
public DashboardDTO getDashboard(@AuthenticationPrincipal JwtPayload user) {
   CompletableFuture<UserProfile> profile = CompletableFuture.supplyAsync(
       () -> userClient.getProfile(user.getSub()), executor);

   CompletableFuture<List<Order>> orders = CompletableFuture.supplyAsync(
       () -> orderClient.getRecent(user.getSub(), 5), executor);

   CompletableFuture<Notifications> notifications = CompletableFuture.supplyAsync(
       () -> notifClient.getUnread(user.getSub()), executor);

   // Chờ tất cả cùng hoàn thành
   CompletableFuture.allOf(profile, orders, notifications).join();

   return new DashboardDTO(profile.join(), orders.join(), notifications.join());
}
```

### # communication anti-patterns

| Anti-Pattern                 | Problem                                    | Fix                                   |
| ---------------------------- | ------------------------------------------ | ------------------------------------- |
| Synchronous chain (A→B→C→D)  | Latency compounds, single point of failure | Event-driven, async where possible    |
| No timeout                   | Thread blocked forever                     | Always set timeout < caller's timeout |
| Chatty communication         | N+1 calls, high latency                    | Batch API, BFF aggregation            |
| Shared database              | Tight coupling, schema conflicts           | Each service owns its data            |
| No circuit breaker           | Cascading failure                          | Resilience4j circuit breaker          |
| Hardcoded URLs               | Fragile, no scaling                        | Service discovery (Eureka)            |
| No retry on transient errors | Unnecessary failures                       | Retry with exponential backoff        |
| Retry without idempotency    | Duplicate side effects                     | Idempotency key in requests           |

### # decision matrix

| Requirement                  | Pattern                              |
| ---------------------------- | ------------------------------------ |
| Need immediate response      | Sync (REST/gRPC) + Circuit Breaker   |
| Fire-and-forget              | Async (RabbitMQ event)               |
| Need guaranteed delivery     | Outbox + Async messaging             |
| High throughput, low latency | gRPC + connection pooling            |
| Cross-service transaction    | Saga (choreography or orchestration) |
| Aggregate for frontend       | BFF + parallel async calls           |
| External unreliable API      | Circuit Breaker + Retry + Fallback   |

Thiết kế một hệ thống microservices vững chãi không phải là việc đắp lên thật nhiều công nghệ. Đó là quá trình dọn dẹp, khơi thông những luồng giao tiếp, lường trước sự đổ vỡ và ứng xử với nó một cách thanh lịch nhất.

> Chỉ là những ghi chép cá nhân với hy vọng mang lại chút giá trị. Nếu thấy hữu ích, đừng ngại chia sẻ cho bạn bè & đồng nghiệp nhé!

Happy coding <Twemoji emoji="clinking-beer-mugs" /> 😎 👍🏻 🚀 🔥.
