---
layout: post
title: "ioc container & application context"
date: 2023-09-23 19:29:39 +0700
categories: [Software Development]
tags: [java, software-development, spring-framework, best-practices, vietnamese]
---

Nếu bạn đã từng tự hỏi "Spring Boot biết tạo object nào, inject vào đâu, và quản lý lifecycle ra sao?" — câu trả lời nằm ở package này.

`org.springframework.context` là trái tim của Spring Framework. Nó chứa toàn bộ cơ chế **Inversion of Control (IoC)** — nơi bạn không còn `new Object()` thủ công mà khai báo _cần gì_, Spring lo _tạo và nối_ cho bạn.

Trong thực tế, bạn sẽ gặp package này ở mọi nơi: khai báo configuration class, publish/listen events, schedule background jobs, quản lý profiles (dev/staging/prod), và đọc properties từ file config. Hiểu rõ nó là hiểu cách Spring Boot khởi động và vận hành application của bạn.

### # @Configuration — java-based configuration

Trước Spring 3, config bằng XML là chuẩn. Bạn phải viết hàng trăm dòng XML để khai báo beans. Ngày nay, `@Configuration` thay thế hoàn toàn XML bằng Java code — type-safe, IDE-friendly, và refactor được.

Một class đánh `@Configuration` thực chất là một "factory" — Spring quét nó, tìm tất cả methods đánh `@Bean`, gọi chúng, và đưa return value vào IoC container. Từ đó, bất kỳ class nào cần dependency đó đều có thể inject.

Điểm hay là bạn viết logic Java bình thường trong `@Bean` method — conditional creation, default values, dependencies giữa beans — tất cả tường minh và debuggable.

```java
// Thay thế XML config bằng Java class
@Configuration
public class AppConfig {

   @Bean
   public ObjectMapper objectMapper() {
       return new ObjectMapper()
           .registerModule(new JavaTimeModule())
           .disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS);
   }

   @Bean
   public RestTemplate restTemplate(RestTemplateBuilder builder) {
       return builder
           .setConnectTimeout(Duration.ofSeconds(5))
           .setReadTimeout(Duration.ofSeconds(10))
           .build();
   }

   // Bean với dependency
   @Bean
   public ProductService productService(ProductRepository repo, ObjectMapper mapper) {
       return new ProductService(repo, mapper);
   }
}
```

#### # @Configuration(proxyBeanMethods)

```java
// proxyBeanMethods = true (default) — CGLIB proxy, method calls return same instance
@Configuration
public class FullConfig {
   @Bean
   public ServiceA serviceA() { return new ServiceA(commonDep()); }

   @Bean
   public ServiceB serviceB() { return new ServiceB(commonDep()); }

   @Bean
   public CommonDep commonDep() { return new CommonDep(); }
   // serviceA và serviceB dùng CÙNG instance commonDep (proxied)
}

// proxyBeanMethods = false — Lite mode, no proxy, faster startup
@Configuration(proxyBeanMethods = false)
public class LiteConfig {
   @Bean
   public ServiceA serviceA(CommonDep dep) { return new ServiceA(dep); }
   // Inject qua parameter thay vì gọi method → an toàn hơn
}
```

### # @bean — khai báo bean từ method

`@Bean` là cách bạn nói với Spring: "Tôi muốn object này được quản lý bởi container." Method return gì, container lưu cái đó.

Khi nào dùng `@Bean` thay vì `@Component`? Khi bạn không sở hữu class đó (thư viện bên ngoài như `ObjectMapper`, `RestTemplate`), hoặc cần custom logic phức tạp để khởi tạo. Với class bạn tự viết, `@Service`/`@Component` tiện hơn. Nhưng `@Bean` cho bạn full control.

Một điểm quan trọng: Spring mặc định tạo mỗi bean là **singleton** — gọi method `objectMapper()` 10 lần ở 10 chỗ, vẫn nhận cùng 1 instance. Đây là lý do `@Configuration` tạo CGLIB proxy cho class — để intercept method calls và trả singleton.

```java
@Configuration
public class SecurityConfig {

   @Bean
   public PasswordEncoder passwordEncoder() {
       return new BCryptPasswordEncoder(12);
   }

   // Bean name (default = method name)
   @Bean("customEncoder")
   public PasswordEncoder anotherEncoder() {
       return new Argon2PasswordEncoder(16, 32, 1, 65536, 3);
   }

   // Init & destroy methods
   @Bean(initMethod = "start", destroyMethod = "shutdown")
   public ConnectionPool connectionPool() {
       return new ConnectionPool();
   }

   // Conditional bean
   @Bean
   @ConditionalOnProperty(name = "cache.enabled", havingValue = "true")
   public CacheManager cacheManager(RedisConnectionFactory factory) {
       return RedisCacheManager.builder(factory).build();
   }

   @Bean
   @ConditionalOnMissingBean(CacheManager.class)
   public CacheManager noOpCacheManager() {
       return new NoOpCacheManager();
   }

   // Profile-specific
   @Bean
   @Profile("dev")
   public DataSource devDataSource() {
       return new EmbeddedDatabaseBuilder().setType(EmbeddedDatabaseType.H2).build();
   }

   @Bean
   @Profile("prod")
   public DataSource prodDataSource(DataSourceProperties props) {
       return props.initializeDataSourceBuilder().build();
   }
}
```

### # @ComponentScan — quét và đăng ký beans

Spring không magic — nó cần biết _scan ở đâu_ để tìm beans. `@ComponentScan` chỉ định package(s) để Spring quét, tìm tất cả class có `@Component`, `@Service`, `@Repository`, `@Controller`, và đăng ký chúng vào container.

Trong Spring Boot, bạn hiếm khi viết `@ComponentScan` explicit vì `@SpringBootApplication` đã include nó với base package = package chứa main class. Nhưng khi bạn cần exclude một số class (test doubles, legacy code) hoặc scan thêm package ngoài, đây là nơi cần đến.

```java
@Configuration
@ComponentScan(
   basePackages = "vn.com.vpbank.internal.csp",
   excludeFilters = {
       @ComponentScan.Filter(type = FilterType.ANNOTATION, classes = Controller.class),
       @ComponentScan.Filter(type = FilterType.REGEX, pattern = ".*Test.*")
   },
   includeFilters = {
       @ComponentScan.Filter(type = FilterType.ASSIGNABLE_TYPE, classes = CustomService.class)
   }
)
public class AppConfig {}

// @SpringBootApplication đã include @ComponentScan với base package = package chứa main class
```

### # @Profile — conditional bean theo environment

Thực tế bạn luôn có nhiều môi trường: dev chạy local, staging test integration, prod serve users thật. Mỗi môi trường cần config khác nhau — database URL, API keys, feature flags, thậm chí implementations khác nhau (mock mail vs real SMTP).

`@Profile` giải quyết vấn đề này elegant: đánh dấu beans/configurations chỉ hoạt động ở profile cụ thể. Spring chỉ tạo bean nếu profile đang active match. Không cần if/else trong code, không cần comment/uncomment — clean separation.

```java
@Configuration
@Profile("dev")
public class DevConfig {
   @Bean
   public MailService mailService() {
       return new MockMailService(); // Không gửi mail thật
   }
}

@Configuration
@Profile("prod")
public class ProdConfig {
   @Bean
   public MailService mailService(MailProperties props) {
       return new SmtpMailService(props);
   }
}

// NOT profile
@Configuration
@Profile("!prod")  // Mọi env trừ prod
public class NonProdConfig { ... }

// Multiple profiles (OR)
@Service
@Profile({"dev", "staging"})
public class DebugService { ... }

// Active profiles
// application.yml: spring.profiles.active=dev,local
// CLI: --spring.profiles.active=prod
// ENV: SPRING_PROFILES_ACTIVE=prod
```

### # @PropertySource & @Value — external configuration

Hard-code config values trong Java code là anti-pattern kinh điển. Mỗi lần đổi timeout, URL, hay feature flag lại phải re-compile và re-deploy? Không chấp nhận được.

`@Value` inject giá trị từ properties files vào Java fields — runtime configurable, không cần rebuild. `@PropertySource` cho phép load properties từ nhiều file khác nhau.

Nhưng nếu bạn có nhiều properties liên quan (cùng prefix), `@ConfigurationProperties` là lựa chọn tốt hơn — type-safe, validatable, IDE-autocomplete. Xem nó như upgrade từ "lấy từng giá trị rời rạc" lên "bind cả nhóm config vào 1 object có cấu trúc."

```java
@Configuration
@PropertySource("classpath:custom-config.properties")
@PropertySource(value = "file:/opt/config/override.properties", ignoreResourceNotFound = true)
public class ExternalConfig {

   @Value("${app.name:CSP}")  // Default value
   private String appName;

   @Value("${app.max-upload-size:10485760}")
   private long maxUploadSize;

   @Value("${app.allowed-origins}")  // Bắt buộc phải có
   private String[] allowedOrigins;

   @Value("#{${app.feature-flags}}")  // SpEL → Map
   private Map<String, Boolean> featureFlags;

   @Value("${app.timeout:30}000")  // Expression
   private long timeoutMs;

   @Value("#{systemProperties['user.home']}")
   private String userHome;

   @Value("#{T(java.util.UUID).randomUUID().toString()}")
   private String instanceId;
}
```

#### # @ConfigurationProperties — type-safe config (recommended)

```java
@Data
@ConfigurationProperties(prefix = "app.upload")
@Validated
public class UploadProperties {

   @NotBlank
   private String storagePath;

   @Min(1)
   private long maxFileSize = 10_485_760;

   private List<String> allowedTypes = List.of("pdf", "png", "jpg");

   @DurationUnit(ChronoUnit.SECONDS)
   private Duration timeout = Duration.ofSeconds(30);

   @Valid
   private Retry retry = new Retry();

   @Data
   public static class Retry {
       @Min(1) @Max(10)
       private int maxAttempts = 3;
       private Duration backoff = Duration.ofSeconds(1);
   }
}

// Enable
@Configuration
@EnableConfigurationProperties(UploadProperties.class)
public class AppConfig {}

// Usage
@Service
@RequiredArgsConstructor
public class UploadService {
   private final UploadProperties props;
}
```

### # event system — application events

Đây là một trong những feature bị underrated nhất của Spring. Thay vì service A gọi trực tiếp service B, C, D (tight coupling), A chỉ cần "hét lên" rằng một sự kiện đã xảy ra. Ai quan tâm thì tự lắng nghe.

Pattern này gọi là **Observer** hay **Pub/Sub** — và Spring implement nó elegantly qua `ApplicationEventPublisher` + `@EventListener`. Kết quả: code loosely coupled, dễ test (mock publisher), dễ mở rộng (thêm listener mới mà không sửa publisher).

Trong microservices, events thường đi qua RabbitMQ/Kafka. Nhưng trong cùng 1 service (intra-process), Spring Events là lựa chọn nhẹ nhàng và hiệu quả — không cần infrastructure bên ngoài.

Một tip quan trọng: dùng `@TransactionalEventListener(phase = AFTER_COMMIT)` cho side effects (gửi email, push notification). Nếu transaction rollback, bạn không muốn user nhận email xác nhận đơn hàng mà đơn hàng thực ra không tồn tại.

#### # built-in events

```java
@Component
@Slf4j
public class AppLifecycleListener {

   @EventListener(ApplicationReadyEvent.class)
   public void onReady() {
       log.info("Application started and ready to serve");
   }

   @EventListener(ContextRefreshedEvent.class)
   public void onRefresh() {
       log.info("Context refreshed");
   }

   @EventListener(ContextClosedEvent.class)
   public void onShutdown() {
       log.info("Application shutting down");
   }
}
```

#### # custom events

```java
// Event class
@Getter
public class OrderCreatedEvent extends ApplicationEvent {
   private final UUID orderId;
   private final UUID customerId;
   private final BigDecimal amount;

   public OrderCreatedEvent(Object source, UUID orderId, UUID customerId, BigDecimal amount) {
       super(source);
       this.orderId = orderId;
       this.customerId = customerId;
       this.amount = amount;
   }
}

// Publisher
@Service
@RequiredArgsConstructor
public class OrderService {
   private final ApplicationEventPublisher eventPublisher;

   @Transactional
   public OrderDTO create(CreateOrderRequest request) {
       Order order = orderRepository.save(buildOrder(request));

       // Publish event
       eventPublisher.publishEvent(new OrderCreatedEvent(
           this, order.getId(), order.getCustomerId(), order.getTotalAmount()));

       return toDTO(order);
   }
}

// Listeners
@Component
@Slf4j
public class OrderEventListeners {

   // Sync listener (same thread, same TX)
   @EventListener
   public void onOrderCreated(OrderCreatedEvent event) {
       log.info("Order created: {} | amount={}", event.getOrderId(), event.getAmount());
   }

   // Async listener (different thread)
   @Async
   @EventListener
   public void sendNotification(OrderCreatedEvent event) {
       notificationService.notifyCustomer(event.getCustomerId(), "Order placed");
   }

   // Transactional listener (after TX commits)
   @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
   public void afterOrderCommitted(OrderCreatedEvent event) {
       // Chỉ chạy khi TX commit thành công
       analyticsService.trackOrder(event.getOrderId(), event.getAmount());
   }

   // Conditional listener
   @EventListener(condition = "#event.amount.compareTo(T(java.math.BigDecimal).valueOf(1000000)) > 0")
   public void onHighValueOrder(OrderCreatedEvent event) {
       alertService.alertHighValueOrder(event.getOrderId());
   }

   // Return value → publish as new event
   @EventListener
   public NotificationSentEvent handleOrder(OrderCreatedEvent event) {
       sendEmail(event);
       return new NotificationSentEvent(this, event.getOrderId());
   }
}
```

#### # generic events (spring 4.2+)

```java
// Generic event — no need to extend ApplicationEvent
@Getter
@AllArgsConstructor
public class EntityChangedEvent<T> {
   private final T entity;
   private final ChangeType changeType;

   public enum ChangeType { CREATED, UPDATED, DELETED }
}

// Publish
eventPublisher.publishEvent(new EntityChangedEvent<>(product, ChangeType.CREATED));

// Listen (match by generic type)
@EventListener
public void onProductChanged(EntityChangedEvent<Product> event) { ... }

@EventListener
public void onOrderChanged(EntityChangedEvent<Order> event) { ... }
```

### # @Scheduled — task scheduling

Mọi ứng dụng production đều có background jobs: xóa temp files, gửi daily reports, sync data, health check. Thay vì setup cron job trên server hoặc dùng Quartz phức tạp, Spring cung cấp `@Scheduled` — đơn giản như đánh annotation lên method.

`fixedDelay` vs `fixedRate` là câu hỏi phỏng vấn kinh điển: delay = "chờ task xong rồi mới đếm interval", rate = "chạy đều đặn bất kể task trước mất bao lâu." Chọn sai có thể gây overlap hoặc drift.

Lưu ý: `@Scheduled` mặc định chạy trên 1 thread. Nếu bạn có 5 scheduled tasks, chúng phải xếp hàng. Configure `TaskScheduler` với pool size > 1 nếu tasks cần chạy song song.

```java
@Configuration
@EnableScheduling
public class SchedulingConfig {}

@Component
@Slf4j
public class ScheduledTasks {

   // Fixed delay — chờ xong rồi mới đếm tiếp
   @Scheduled(fixedDelay = 60_000)  // 60s SAU KHI method trước hoàn thành
   public void cleanExpiredSessions() {
       sessionService.cleanExpired();
   }

   // Fixed rate — chạy đều đặn bất kể execution time
   @Scheduled(fixedRate = 30_000)  // Mỗi 30s
   public void sendHeartbeat() {
       healthService.sendHeartbeat();
   }

   // Cron expression
   @Scheduled(cron = "0 0 2 * * *")  // Mỗi ngày lúc 2:00 AM
   public void dailyCleanup() {
       fileService.purgeOldFiles(30);
   }

   @Scheduled(cron = "0 */5 * * * *")  // Mỗi 5 phút
   public void syncData() {
       syncService.sync();
   }

   // Initial delay
   @Scheduled(initialDelay = 10_000, fixedDelay = 60_000)
   public void afterStartup() {
       // Chờ 10s sau khi app start, rồi chạy mỗi 60s
   }

   // Cron timezone
   @Scheduled(cron = "0 0 9 * * MON-FRI", zone = "Asia/Ho_Chi_Minh")
   public void weekdayMorningReport() {
       reportService.generateDaily();
   }
}
```

#### # @Async — non-blocking method execution

```java
@Configuration
@EnableAsync
public class AsyncConfig {

   @Bean("taskExecutor")
   public Executor taskExecutor() {
       ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
       executor.setCorePoolSize(5);
       executor.setMaxPoolSize(20);
       executor.setQueueCapacity(500);
       executor.setThreadNamePrefix("async-");
       executor.setRejectedExecutionHandler(new ThreadPoolExecutor.CallerRunsPolicy());
       executor.setWaitForTasksToCompleteOnShutdown(true);
       executor.setAwaitTerminationSeconds(30);
       executor.initialize();
       return executor;
   }
}

@Service
@Slf4j
public class NotificationService {

   @Async("taskExecutor")
   public void sendEmail(String to, String subject, String body) {
       // Chạy trên thread khác, method return ngay lập tức
       emailClient.send(to, subject, body);
   }

   @Async("taskExecutor")
   public CompletableFuture<NotificationResult> sendAsync(NotificationRequest request) {
       // Caller có thể await result
       NotificationResult result = process(request);
       return CompletableFuture.completedFuture(result);
   }
}

// Usage
CompletableFuture<NotificationResult> future = notificationService.sendAsync(request);
NotificationResult result = future.get(10, TimeUnit.SECONDS); // Optional wait
```

### # @Scope — bean scope control

Mặc định mọi bean trong Spring là **singleton** — 1 instance duy nhất shared across toàn bộ application. Đây là lý do bạn KHÔNG nên giữ mutable state trong `@Service` beans (race condition khi nhiều threads cùng access).

Nhưng đôi khi bạn cần mỗi lần inject là 1 instance mới (prototype), hoặc 1 instance per HTTP request. `@Scope` cho bạn kiểm soát lifecycle này.

Trong thực tế, 95% beans là singleton. Bạn chỉ cần prototype khi bean giữ state (report builder accumulating data) hoặc request scope cho request-specific context (current user, workspace ID).

```java
@Component
@Scope("prototype")  // New instance mỗi lần inject
public class ReportGenerator {
   private final List<String> lines = new ArrayList<>();

   public void addLine(String line) { lines.add(line); }
   public String generate() { return String.join("\n", lines); }
}

// Request scope (1 instance per HTTP request)
@Component
@Scope(value = WebApplicationContext.SCOPE_REQUEST, proxyMode = ScopedProxyMode.TARGET_CLASS)
public class RequestContext {
   private UUID requestId;
   private UUID workspaceId;
   private String userId;
}

// Custom scope
@Bean
@Scope("refresh")  // Spring Cloud — refresh without restart
public ExternalServiceConfig externalConfig() { ... }
```

### # @Lazy — lazy initialization

Spring mặc định tạo TẤT CẢ singleton beans khi application start — gọi là **eager initialization**. Ưu điểm: fail fast (lỗi config phát hiện ngay lúc start). Nhược điểm: startup time chậm nếu có nhiều beans heavy (load large dataset, connect external services).

`@Lazy` trì hoãn việc tạo bean đến lần đầu tiên nó được sử dụng. Hữu ích cho beans ít khi dùng hoặc expensive to create. Nhưng cẩn thận: lỗi sẽ chỉ xuất hiện khi runtime gọi đến bean đó — không còn fail-fast nữa.

```java
// Lazy bean — chỉ tạo khi lần đầu được inject/sử dụng
@Service
@Lazy
public class HeavyReportService {
   // Constructor chỉ chạy khi service lần đầu được gọi
   public HeavyReportService() {
       loadLargeDataset(); // Expensive
   }
}

// Lazy injection
@Service
@RequiredArgsConstructor
public class OrderService {
   @Lazy
   private final HeavyReportService reportService; // Không tạo cho đến khi gọi method
}

// Global lazy initialization
// application.yml: spring.main.lazy-initialization=true
```

### # @Import & @ImportResource

Khi project lớn, bạn tách config thành nhiều `@Configuration` classes. `@Import` cho phép 1 config class "include" nhiều config khác — tạo modular configuration.

`@ImportResource` là cầu nối cho legacy XML configs. Nếu bạn đang migration dần từ XML sang Java config, đây là cách để cả hai cùng tồn tại.

```java
// Import config classes
@Configuration
@Import({SecurityConfig.class, CacheConfig.class, AsyncConfig.class})
public class AppConfig {}

// Import XML config (legacy)
@Configuration
@ImportResource("classpath:legacy-beans.xml")
public class LegacyConfig {}
```

### # MessageSource — Internationalization (i18n)

Khi ứng dụng serve nhiều locale (Việt Nam, English, Japan...), bạn không hardcode messages trong code. Thay vào đó, dùng `MessageSource` để load messages từ properties files theo locale hiện tại.

Trong CSP, mỗi service có error codes dạng `CATEGORY.INDEX.ID` (12 digits). MessageSource map error code → user-friendly message theo ngôn ngữ — đảm bảo API luôn trả về message đúng ngữ cảnh.

```java
@Configuration
public class I18nConfig {

   @Bean
   public MessageSource messageSource() {
       ReloadableResourceBundleMessageSource source = new ReloadableResourceBundleMessageSource();
       source.setBasename("classpath:messages");
       source.setDefaultEncoding("UTF-8");
       source.setCacheSeconds(3600);
       return source;
   }

   @Bean
   public LocaleResolver localeResolver() {
       AcceptHeaderLocaleResolver resolver = new AcceptHeaderLocaleResolver();
       resolver.setDefaultLocale(Locale.forLanguageTag("vi"));
       return resolver;
   }
}

// Usage
@Service
@RequiredArgsConstructor
public class ValidationMessageService {
   private final MessageSource messageSource;

   public String getMessage(String code, Object... args) {
       return messageSource.getMessage(code, args, LocaleContextHolder.getLocale());
   }
}
```

### # quick reference

| Annotation/Interface        | Mục đích                   |
| --------------------------- | -------------------------- |
| @Configuration              | Java-based config class    |
| @Bean                       | Khai báo bean từ method    |
| @ComponentScan              | Quét package đăng ký beans |
| @Profile                    | Bean theo environment      |
| @PropertySource             | Load external properties   |
| @Value                      | Inject property value      |
| @ConfigurationProperties    | Type-safe config binding   |
| @EventListener              | Listen application events  |
| @TransactionalEventListener | Listen after TX commit     |
| @Scheduled                  | Cron/fixed-rate scheduling |
| @EnableScheduling           | Bật scheduling             |
| @Async                      | Non-blocking execution     |
| @EnableAsync                | Bật async support          |
| @Scope                      | Bean lifecycle scope       |
| @Lazy                       | Deferred initialization    |
| @Import                     | Import config classes      |
| @Conditional\*              | Conditional bean creation  |
| ApplicationEventPublisher   | Publish events             |
| MessageSource               | i18n messages              |
| Environment                 | Access properties/profiles |

> Chỉ là những ghi chép cá nhân với hy vọng mang lại chút giá trị. Nếu thấy hữu ích, đừng ngại chia sẻ cho bạn bè & đồng nghiệp nhé!

Happy coding <Twemoji emoji="clinking-beer-mugs" /> 😎 👍🏻 🚀 🔥.
