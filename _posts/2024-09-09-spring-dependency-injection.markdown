---
layout: post
title: "dependency injection"
date: 2024-09-09 19:29:39 +0700
categories: [Software Development]
tags: [java, software-development, spring-framework, best-practices, vietnamese]
---

### # giới thiệu

Dependency Injection (DI) là pattern mà bạn không tạo dependencies bên trong class, mà nhận chúng từ bên ngoài. Nghe đơn giản, nhưng nó thay đổi hoàn toàn cách bạn viết và test code.

Không có DI, `OrderService` tự `new OrderRepository()` — tight coupling, không mock được, không swap implementation được. Với DI, Spring "tiêm" repository vào service — loose coupling, testable, configurable.

Package `org.springframework.beans.factory.annotation` chứa tất cả annotations để điều khiển _cách Spring inject_: inject gì (`@Autowired`), chọn bean nào (`@Qualifier`, `@Primary`), lấy config từ đâu (`@Value`). Đây là tool belt hàng ngày của mọi Spring developer.

### # @Autowired — tự động inject dependency

`@Autowired` nói với Spring: "Tìm bean phù hợp trong container và inject vào đây." Spring match theo type trước, theo name nếu ambiguous.

Có 3 cách inject: constructor, field, setter. Nhưng trong production code, **constructor injection** là lựa chọn duy nhất đáng cân nhắc. Lý do:

- Fields là `final` → immutable, thread-safe
- Dependencies tường minh (nhìn constructor biết class cần gì)
- Dễ test (pass mock qua constructor, không cần Spring context)
- Compile-time check (quên inject → compile error, không phải NullPointerException runtime)

Với Lombok `@RequiredArgsConstructor`, bạn thậm chí không cần viết constructor — Lombok generate cho bạn từ các `final` fields.

#### # constructor injection (recommended)

```java
@Service
public class OrderService {

   private final OrderRepository orderRepository;
   private final ProductService productService;
   private final NotificationService notificationService;

   // @Autowired không cần khi chỉ có 1 constructor (Spring Boot 4.3+)
   public OrderService(OrderRepository orderRepository,
                       ProductService productService,
                       NotificationService notificationService) {
       this.orderRepository = orderRepository;
       this.productService = productService;
       this.notificationService = notificationService;
   }
}

// Lombok equivalent (RECOMMENDED trong CSP)
@Service
@RequiredArgsConstructor
public class OrderService {
   private final OrderRepository orderRepository;
   private final ProductService productService;
   private final NotificationService notificationService;
}
```

#### # field injection (avoid — hard to test)

```java
@Service
public class OrderService {

   @Autowired  // Inject trực tiếp vào field
   private OrderRepository orderRepository;

   @Autowired(required = false)  // Optional — null nếu bean không tồn tại
   private CacheService cacheService;
}
```

#### # setter injection (optional dependencies)

```java
@Service
public class OrderService {

   private NotificationService notificationService;

   @Autowired(required = false)
   public void setNotificationService(NotificationService notificationService) {
       this.notificationService = notificationService;
   }

   public void createOrder(OrderRequest request) {
       // ... create order
       if (notificationService != null) {
           notificationService.notify(order);
       }
   }
}
```

#### # collection injection

```java
@Service
public class NotificationDispatcher {

   // Inject TẤT CẢ beans implement NotificationSender
   private final List<NotificationSender> senders;

   @Autowired
   public NotificationDispatcher(List<NotificationSender> senders) {
       this.senders = senders;
       // senders = [EmailSender, SmsSender, PushSender] (tất cả impl)
   }

   public void dispatch(Notification notification) {
       senders.forEach(sender -> sender.send(notification));
   }
}

// Map injection — key = bean name
@Autowired
private Map<String, PaymentProcessor> processors;
// processors = {"stripe": StripeProcessor, "vnpay": VnPayProcessor}
```

### # @Qualifier — chọn bean cụ thể khi có nhiều candidates

Khi container có nhiều beans cùng type (2 DataSource, 3 PaymentProcessor...), Spring không biết inject cái nào → `NoUniqueBeanDefinitionException`. `@Qualifier` giải quyết bằng cách chỉ định tên bean cụ thể.

Trong CSP, ví dụ điển hình là primary database (write) vs replica database (read). Service cần read-heavy dùng replica, service cần write dùng primary. `@Qualifier` cho phép cùng type `DataSource` nhưng inject đúng instance.

Nâng cao hơn: tạo custom qualifier annotations (`@PrimaryDatabase`, `@ReplicaDatabase`) — readable hơn string-based qualifier, compiler check được typo.

```java
// Nhiều beans cùng type
@Configuration
public class DataSourceConfig {

   @Bean("primaryDs")
   public DataSource primaryDataSource() {
       return DataSourceBuilder.create().url("jdbc:postgresql://primary:5432/db").build();
   }

   @Bean("replicaDs")
   public DataSource replicaDataSource() {
       return DataSourceBuilder.create().url("jdbc:postgresql://replica:5432/db").build();
   }
}

// Inject với @Qualifier
@Service
@RequiredArgsConstructor
public class ReportService {

   @Qualifier("replicaDs")  // Chọn replica cho read-heavy operations
   private final DataSource dataSource;
}

// Hoặc với constructor
@Service
public class ReportService {
   private final DataSource readDataSource;

   public ReportService(@Qualifier("replicaDs") DataSource readDataSource) {
       this.readDataSource = readDataSource;
   }
}
```

#### # custom qualifier annotation

```java
// Tạo custom qualifier
@Target({ElementType.FIELD, ElementType.PARAMETER, ElementType.TYPE})
@Retention(RetentionPolicy.RUNTIME)
@Qualifier
public @interface PrimaryDatabase {}

@Target({ElementType.FIELD, ElementType.PARAMETER, ElementType.TYPE})
@Retention(RetentionPolicy.RUNTIME)
@Qualifier
public @interface ReplicaDatabase {}

// Đánh dấu beans
@Bean
@PrimaryDatabase
public DataSource primaryDs() { ... }

@Bean
@ReplicaDatabase
public DataSource replicaDs() { ... }

// Inject
@Service
public class OrderService {
   public OrderService(@PrimaryDatabase DataSource ds) { ... }
}

@Service
public class ReportService {
   public ReportService(@ReplicaDatabase DataSource ds) { ... }
}
```

### # @Value — inject property values

`@Value` là cách nhanh nhất để đưa config values vào code. Kết hợp với Spring Cloud Config Server (như CSP đang dùng), bạn thay đổi config centrally mà không cần redeploy.

Syntax `${property.name:defaultValue}` — phần sau dấu `:` là fallback nếu property không tồn tại. Luôn đặt default value cho optional configs để tránh startup failures.

Với SpEL (Spring Expression Language) trong `@Value`, bạn có thể làm nhiều hơn inject string — gọi method, tính toán, access system properties. Nhưng đừng lạm dụng: logic phức tạp nên ở trong code, không phải trong annotation.

```java
@Service
public class FileService {

   @Value("${app.upload.max-size:10485760}")
   private long maxFileSize;

   @Value("${app.upload.path}")
   private String uploadPath;

   @Value("${app.upload.allowed-types:pdf,png,jpg}")
   private List<String> allowedTypes;

   @Value("#{${app.feature-flags:{}}}")  // SpEL → Map
   private Map<String, Boolean> featureFlags;

   @Value("${app.name:#{null}}")  // null default
   private String appName;

   // SpEL expressions
   @Value("#{systemEnvironment['JAVA_HOME']}")
   private String javaHome;

   @Value("#{T(java.time.LocalDate).now()}")
   private LocalDate today;

   @Value("#{@someBean.computeValue()}")  // Call another bean's method
   private String computedValue;

   // Constructor injection with @Value
   public FileService(
           @Value("${app.upload.max-size:10485760}") long maxFileSize,
           @Value("${app.upload.path}") String uploadPath) {
       this.maxFileSize = maxFileSize;
       this.uploadPath = uploadPath;
   }
}
```

### # @Lookup — method injection cho prototype beans

Đây là giải pháp cho bài toán ít người biết: **singleton bean cần prototype bean mới mỗi lần gọi**.

Nếu inject prototype vào singleton qua constructor, prototype chỉ được tạo 1 lần (lúc singleton init) → mất ý nghĩa prototype. `@Lookup` giải quyết bằng cách Spring override method mỗi lần gọi → trả về fresh instance.

Thực tế ít gặp, nhưng hữu ích cho: report builders accumulating state, request-scoped operations trong singleton service, hoặc command pattern objects.

```java
// Problem: Singleton service cần mỗi lần 1 prototype bean mới
@Service
public abstract class ReportService {

   // Spring override method này → trả về new prototype instance mỗi lần gọi
   @Lookup
   protected abstract ReportGenerator createGenerator();

   public String generateReport(ReportRequest request) {
       ReportGenerator generator = createGenerator(); // New instance mỗi lần
       generator.addHeader(request.getTitle());
       generator.addData(request.getData());
       return generator.generate();
   }
}

@Component
@Scope("prototype")
public class ReportGenerator {
   private final StringBuilder content = new StringBuilder();

   public void addHeader(String title) { content.append("# ").append(title).append("\n"); }
   public void addData(Object data) { content.append(data.toString()); }
   public String generate() { return content.toString(); }
}
```

### # @Primary — default bean khi có nhiều candidates

`@Primary` là "soft default" — khi không chỉ định `@Qualifier`, Spring chọn bean đánh `@Primary`. Nhưng `@Qualifier` luôn override `@Primary` khi cần bean khác.

Pattern thường gặp: Redis cache là `@Primary` (dùng mặt định), local cache là alternative (dùng khi cần test hoặc fallback). Hoặc: production DataSource là `@Primary`, test DataSource dùng `@Qualifier("testDb")`.

```java
@Configuration
public class CacheConfig {

   @Bean
   @Primary  // Default khi inject CacheManager không chỉ định @Qualifier
   public CacheManager redisCacheManager(RedisConnectionFactory factory) {
       return RedisCacheManager.builder(factory).build();
   }

   @Bean("localCache")
   public CacheManager localCacheManager() {
       return new ConcurrentMapCacheManager("products", "users");
   }
}

// Inject — không cần @Qualifier, tự động chọn @Primary
@Service
@RequiredArgsConstructor
public class ProductService {
   private final CacheManager cacheManager; // → redisCacheManager
}

// Override khi cần
@Service
public class TestService {
   public TestService(@Qualifier("localCache") CacheManager cache) { ... }
}
```

### # @Required (deprecated) & alternatives

`@Required` từng dùng trên setter methods để đánh dấu "property này bắt buộc phải inject." Nhưng từ Spring 5.1, nó deprecated vì constructor injection giải quyết triệt để hơn: nếu dependency thiếu, application không compile/start được.

Bài học: constructor injection không chỉ là "best practice" — nó giải quyết cả class annotations khác trở thành không cần thiết.

```java
// @Required deprecated từ Spring 5.1 — dùng constructor injection thay thế

// ❌ Old way
@Component
public class OldService {
   private Repository repo;

   @Required  // Deprecated
   public void setRepo(Repository repo) { this.repo = repo; }
}

// ✅ Modern way — constructor injection (required by default)
@Service
@RequiredArgsConstructor
public class ModernService {
   private final Repository repo;  // Bắt buộc phải inject
}
```

### # objectprovider & lazy resolution

`ObjectProvider<T>` là cách "an toàn" để inject bean có thể không tồn tại. Thay vì `@Autowired(required=false)` trả null (NPE risk), `ObjectProvider` cho bạn API rõ ràng: `getIfAvailable()`, `getIfUnique()`, `stream()`.

Use cases thực tế:

- Plugin architecture: scan tất cả implementations, xử lý dynamic
- Optional features: service hoạt động bình thường kể cả khi bean vắng mặt
- Circular dependency breaking: lazy resolution tránh circular inject

```java
@Service
public class FlexibleService {

   private final ObjectProvider<ExpensiveService> expensiveServiceProvider;
   private final ObjectProvider<List<Plugin>> pluginsProvider;

   @Autowired
   public FlexibleService(
           ObjectProvider<ExpensiveService> expensiveServiceProvider,
           ObjectProvider<List<Plugin>> pluginsProvider) {
       this.expensiveServiceProvider = expensiveServiceProvider;
       this.pluginsProvider = pluginsProvider;
   }

   public void doWork() {
       // Lazy resolution — chỉ tạo khi cần
       ExpensiveService service = expensiveServiceProvider.getIfAvailable();
       if (service != null) {
           service.process();
       }

       // Với default fallback
       ExpensiveService serviceOrDefault = expensiveServiceProvider
           .getIfAvailable(NoOpExpensiveService::new);

       // Stream tất cả beans
       expensiveServiceProvider.stream().forEach(s -> s.process());

       // Ordered
       expensiveServiceProvider.orderedStream().forEach(s -> s.process());
   }
}
```

### # injection patterns — best practices

Phần này là nơi DI annotations trở thành design patterns. Bạn không chỉ inject dependencies — bạn _thiết kế_ cách components interact thông qua DI.

Strategy Pattern qua DI là ví dụ kinh điển: khai báo interface, tạo nhiều implementations, inject `List<Interface>` → runtime dispatch. Không cần factory class, không cần switch/case — Spring collect tất cả implementations cho bạn.

#### # pattern 1: strategy pattern via di

```java
public interface PaymentProcessor {
   boolean supports(PaymentMethod method);
   PaymentResult process(PaymentRequest request);
}

@Component
public class StripeProcessor implements PaymentProcessor {
   public boolean supports(PaymentMethod m) { return m == PaymentMethod.CREDIT_CARD; }
   public PaymentResult process(PaymentRequest req) { ... }
}

@Component
public class VnPayProcessor implements PaymentProcessor {
   public boolean supports(PaymentMethod m) { return m == PaymentMethod.BANK_TRANSFER; }
   public PaymentResult process(PaymentRequest req) { ... }
}

@Service
@RequiredArgsConstructor
public class PaymentService {
   private final List<PaymentProcessor> processors; // Auto-inject all implementations

   public PaymentResult pay(PaymentRequest request) {
       return processors.stream()
           .filter(p -> p.supports(request.getMethod()))
           .findFirst()
           .orElseThrow(() -> new UnsupportedPaymentException(request.getMethod()))
           .process(request);
   }
}
```

#### # pattern 2: conditional dependencies

```java
@Service
public class NotificationService {

   private final Optional<SmsGateway> smsGateway;       // May not exist
   private final Optional<PushService> pushService;     // May not exist
   private final EmailService emailService;             // Always exists

   public NotificationService(
           EmailService emailService,
           Optional<SmsGateway> smsGateway,
           Optional<PushService> pushService) {
       this.emailService = emailService;
       this.smsGateway = smsGateway;
       this.pushService = pushService;
   }

   public void notify(User user, String message) {
       emailService.send(user.getEmail(), message);
       smsGateway.ifPresent(gw -> gw.send(user.getPhone(), message));
       pushService.ifPresent(ps -> ps.send(user.getDeviceToken(), message));
   }
}
```

### # quick reference

| Annotation | Mục đích                     | Khi nào dùng                                |
| ---------- | ---------------------------- | ------------------------------------------- |
| @Autowired | Auto inject dependency       | Setter/field injection (prefer constructor) |
| @Qualifier | Chọn bean cụ thể             | Nhiều beans cùng type                       |
| @Primary   | Default bean                 | 1 bean ưu tiên hơn                          |
| @Value     | Inject property              | Config values, SpEL                         |
| @Lookup    | Method injection             | Singleton cần prototype                     |
| @Required  | Bắt buộc inject (deprecated) | Dùng constructor thay thế                   |

#### # so sánh injection types

| Type        | Pros                               | Cons                        | Khi nào                  |
| ----------- | ---------------------------------- | --------------------------- | ------------------------ |
| Constructor | Immutable, testable, required deps | Verbose (Lombok fix)        | DEFAULT — luôn dùng      |
| Setter      | Optional deps                      | Mutable, hidden             | Optional dependencies    |
| Field       | Concise                            | Untestable, hidden, mutable | TRÁNH — chỉ test classes |

> Chỉ là những ghi chép cá nhân với hy vọng mang lại chút giá trị. Nếu thấy hữu ích, đừng ngại chia sẻ cho bạn bè & đồng nghiệp nhé!

Happy coding <Twemoji emoji="clinking-beer-mugs" /> 😎 👍🏻 🚀 🔥.
