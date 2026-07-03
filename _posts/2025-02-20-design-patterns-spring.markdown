---
layout: post
title: "design patterns in spring boot"
date: 2025-02-20 19:29:39 +0700
categories: [Software Development]
tags: [java, software-development, design-pattern, best-practices, vietnamese]
---

Trong quá trình phát triển các hệ thống backend phức tạp, việc áp dụng `Design Pattern` không phải là để "khoe kỹ năng" hay làm rườm rà codebase.
Ngược lại, mục đích tối thượng của pattern là sự `**tối giản**` — gạt bỏ những đoạn `if/else` chằng chịt, tinh gọn luồng xử lý và giữ cho cốt lõi của business logic luôn sạch sẽ, độc lập.

`Spring Boot` cung cấp một hệ sinh thái tuyệt vời để hiện thực hóa các design patterns này một cách vô cùng tự nhiên thông qua cơ chế `Dependency Injection (DI)` và `Inversion of Control (IoC)`.
Dưới đây là các `patterns` phổ biến thường được sử dụng nhất, cùng ngữ cảnh áp dụng thường gặp.

### # strategy pattern

Cho phép thay đổi `algorithm/behavior` tại `runtime` thông qua `interface`.

```java
// 1. Định nghĩa Interface chung
public interface PaymentStrategy {
   PaymentResult process(PaymentRequest request);
   String getType(); // Discriminator để phân loại
}

// 2. Các Implementations cụ thể
@Component
public class CreditCardPayment implements PaymentStrategy {
   @Override
   public PaymentResult process(PaymentRequest request) { /* Logic thẻ tín dụng */ }
   @Override
   public String getType() { return "CREDIT_CARD"; }
}

@Component
public class BankTransferPayment implements PaymentStrategy {
   @Override
   public PaymentResult process(PaymentRequest request) { /* Logic chuyển khoản */ }
   @Override
   public String getType() { return "BANK_TRANSFER"; }
}

// 3. Factory - Nơi Spring tự động gom tất cả các bean implement PaymentStrategy
@Component
@RequiredArgsConstructor
public class PaymentStrategyFactory {
   private final List<PaymentStrategy> strategies;

   public PaymentStrategy getStrategy(String type) {
       return strategies.stream()
           .filter(s -> s.getType().equals(type))
           .findFirst()
           .orElseThrow(() -> new UnsupportedPaymentException(type));
   }
}

// 4. Lớp Service sử dụng - Hoàn toàn không biết về các implementation chi tiết
@Service
@RequiredArgsConstructor
public class PaymentService {
   private final PaymentStrategyFactory factory;

   public PaymentResult pay(String type, PaymentRequest request) {
       return factory.getStrategy(type).process(request);
   }
}
```

**Trường hợp sử dụng**: Nhiều variants của cùng `operation`, chọn bởi runtime value (payment type, export format, notification channel).

### # template method pattern

Pattern này giúp định nghĩa bộ khung (skeleton) của một thuật toán trong một class trừu tượng, cho phép các lớp con ghi đè các bước cụ thể mà không làm thay đổi cấu trúc tổng thể.

```java
// Abstract base class quy định luồng thực thi chuẩn
public abstract class AbstractDataImporter<T> {

   // Đánh dấu final để ngăn subclass phá vỡ luồng chuẩn
   public final ImportResult execute(InputStream input) {
       List<T> records = parse(input);
       List<T> validated = records.stream()
           .filter(this::validate)
           .toList();
       int saved = persist(validated);
       postProcess(validated);

       return new ImportResult(records.size(), saved);
   }

   // Các bước bắt buộc subclass phải tự định nghĩa
   protected abstract List<T> parse(InputStream input);
   protected abstract boolean validate(T record);

   // Các bước có sẵn implementation mặc định (Hook methods)
   protected int persist(List<T> records) {
       return repository.saveAll(records).size();
   }

   protected void postProcess(List<T> records) {
       // Default là không làm gì cả
   }
}

// Concrete implementation
@Component
public class CsvUserImporter extends AbstractDataImporter<UserDTO> {
   @Override
   protected List<UserDTO> parse(InputStream input) { /* Logic đọc CSV */ }

   @Override
   protected boolean validate(UserDTO user) {
       return user.getEmail() != null && StringUtils.hasText(user.getName());
   }
}
```

**Trường hợp sử dụng**: Workflow có bước cố định nhưng implementation khác nhau (import/export, report generation, data processing pipelines).

### # observer pattern (spring events)

Đây là "trái tim" của `Event-Driven Architecture` quy mô nhỏ trong một `Monolithic app`. Nó giúp `decouple` hoàn toàn `publisher` khỏi các `subscribers`, bảo vệ tính toàn vẹn của `Domain Logic`.

```java
// Event class
public class OrderCompletedEvent extends ApplicationEvent {
   @Getter
   private final Order order;

   public OrderCompletedEvent(Object source, Order order) {
       super(source);
       this.order = order;
   }
}

// Publisher - Tập trung vào core business, không quan tâm ai lắng nghe
@Service
@RequiredArgsConstructor
public class OrderService {
   private final ApplicationEventPublisher publisher;

   @Transactional
   public Order complete(UUID orderId) {
       Order order = findAndComplete(orderId);
       // Bắn event ra ngoài
       publisher.publishEvent(new OrderCompletedEvent(this, order));
       return order;
   }
}

// Listeners - Xử lý các side-effects độc lập
@Component
public class InventoryListener {
   @EventListener
   public void onOrderCompleted(OrderCompletedEvent event) {
       decrementStock(event.getOrder().getItems());
   }
}

// Đảm bảo tính nhất quán dữ liệu: Chỉ trigger khi Transaction gốc đã commit thành công
@Component
public class AnalyticsListener {
   @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
   public void onOrderCompleted(OrderCompletedEvent event) {
       trackConversion(event.getOrder());
   }
}
```

**Trường hợp sử dụng**: Khi cần xử lý các tác vụ phụ `(side-effects)` sau một hành động chính như gửi email, ghi audit log, cập nhật thống kê mà không muốn làm phình to code ở Service chính.

### # factory pattern

Mục đích của `Factory` là tập trung hóa logic khởi tạo các đối tượng phức tạp. Thay vì dùng từ khóa `new` rải rác khắp nơi, chúng ta giao việc đó cho một `Factory` chuyên trách.

```java
// Abstract Factory - Phù hợp cho việc khởi tạo một "họ" các đối tượng liên quan
public interface StorageFactory {
   FileWriter createWriter();
   FileReader createReader();
   FileDeleter createDeleter();
}

// Khởi tạo bean dựa trên cấu hình môi trường
@Component
@ConditionalOnProperty(name = "storage.type", havingValue = "s3")
public class S3StorageFactory implements StorageFactory {
   public FileWriter createWriter() { return new S3Writer(); }
   public FileReader createReader() { return new S3Reader(); }
   public FileDeleter createDeleter() { return new S3Deleter(); }
}
```

### # decorator pattern (filters & interceptors)

Decorator cho phép "bọc" thêm các hành vi (behavior) mới cho một object mà không cần phải thay đổi source code của class gốc. Trong Spring, `@Primary` hoặc các `Filter chain` là đại diện tiêu biểu.

```java
// HTTP Filter chain — mỗi filter decorate request/response
@Component
@Order(1)
public class RequestTracingFilter extends OncePerRequestFilter {
   @Override
   protected void doFilterInternal(HttpServletRequest request,
           HttpServletResponse response, FilterChain chain) throws IOException, ServletException {
       String traceId = extractOrGenerate(request);
       MDC.put("traceId", traceId);
       try {
           chain.doFilter(request, response); // delegate to next
       } finally {
           MDC.clear();
       }
   }
}

// Service decorator — add caching/logging/retry around existing service
@Component
@Primary
@RequiredArgsConstructor
public class CachedUserService implements UserService {
   private final UserService delegate; // original implementation
   private final Cache cache;

   @Override
   public User findById(UUID id) {
       return cache.get(id, () -> delegate.findById(id));
   }
}
```

**Trường hợp sử dụng**: Cross-cutting concerns (logging, tracing, caching, rate limiting), filter chains.

### # chain of responsibility

Request sẽ được đi qua một chuỗi các "mắt xích" (handlers). Mỗi `handler` sẽ tự đánh giá xem nó có nên xử lý request hay đẩy tiếp cho mắt xích phía sau. Thường dùng `@Order` để quy định thứ tự ưu tiên.

```java
// Handler interface
public interface ValidationHandler {
   ValidationResult validate(Document document);
   int getOrder();
}

// Các Validator cụ thể
@Component
@Order(1)
public class SizeValidator implements ValidationHandler {
   public ValidationResult validate(Document doc) {
       if (doc.getSize() > MAX_SIZE) return ValidationResult.fail("File quá lớn");
       return ValidationResult.ok();
   }
   public int getOrder() { return 1; }
}

@Component
@Order(2)
public class MimeTypeValidator implements ValidationHandler {
   public ValidationResult validate(Document doc) {
       if (!ALLOWED_TYPES.contains(doc.getMimeType())) return ValidationResult.fail("Định dạng không hợp lệ");
       return ValidationResult.ok();
   }
   public int getOrder() { return 2; }
}

// Executor quản lý chuỗi
@Component
public class ValidationChain {
   private final List<ValidationHandler> handlers;

   public ValidationChain(List<ValidationHandler> handlers) {
       this.handlers = handlers.stream()
           .sorted(Comparator.comparingInt(ValidationHandler::getOrder))
           .toList();
   }

   public ValidationResult validate(Document document) {
       for (ValidationHandler handler : handlers) {
           ValidationResult result = handler.validate(document);
           // Dừng chuỗi ngay lập tức nếu có một handler báo lỗi (Short-circuit)
           if (result.isFailed()) return result;
       }
       return ValidationResult.ok();
   }
}
```

### # builder pattern (lombok)

Sử dụng triệt để thư viện `Lombok` để tạo các đối tượng `Immutable` (bất biến), giúp code an toàn trong môi trường `multithreading`.

```java
// Standard builder
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class SearchCriteria {
   private String keyword;
   @Builder.Default
   private int page = 0;
   @Builder.Default
   private int size = 20;
   private String sortBy;
   private SortDirection direction;
}

// Usage
SearchCriteria criteria = SearchCriteria.builder()
   .keyword("report")
   .page(2)
   .sortBy("createdDate")
   .build();

// Builder with inheritance
@SuperBuilder
public abstract class BaseEntity {
   private UUID id;
   private LocalDateTime createdAt;
}

@SuperBuilder
@Data
public class Product extends BaseEntity {
   private String name;
   private BigDecimal price;
}
```

### # specification pattern (dynamic queries)

Kết hợp với JPA, `Specification pattern` là giải pháp hoàn hảo để xây dựng các câu query tìm kiếm động phức tạp mà không làm dơ bẩn tầng `Domain/Entity`.

```java
// JPA Specification — composable query predicates
public class ProductSpecifications {

   public static Specification<Product> hasName(String name) {
       return (root, query, cb) ->
           name == null ? null : cb.like(cb.lower(root.get("name")), "%" + name.toLowerCase() + "%");
   }

   public static Specification<Product> hasCategory(String category) {
       return (root, query, cb) ->
           category == null ? null : cb.equal(root.get("category"), category);
   }

   public static Specification<Product> priceBetween(BigDecimal min, BigDecimal max) {
       return (root, query, cb) -> {
           if (min == null && max == null) return null;
           if (min != null && max != null) return cb.between(root.get("price"), min, max);
           if (min != null) return cb.greaterThanOrEqualTo(root.get("price"), min);
           return cb.lessThanOrEqualTo(root.get("price"), max);
       };
   }
}

// Usage — compose dynamically
public Page<Product> search(ProductSearchRequest req, Pageable pageable) {
   Specification<Product> spec = Specification
       .where(ProductSpecifications.hasName(req.getName()))
       .and(ProductSpecifications.hasCategory(req.getCategory()))
       .and(ProductSpecifications.priceBetween(req.getMinPrice(), req.getMaxPrice()));

   return productRepo.findAll(spec, pageable);
}
```

### # null object pattern

Thay vì viết hàng tá dòng if (obj != null), hãy tiêm (inject) một đối tượng mang hành vi mặc định (thường là không làm gì cả).

```java
// Interface
public interface NotificationSender {
   void send(String message, String recipient);
}

// Null object — does nothing, safe to call
@Component("noOpNotification")
public class NoOpNotificationSender implements NotificationSender {
   @Override
   public void send(String message, String recipient) {
       // intentionally empty — silent no-op
   }
}

// Usage — inject default khi channel không configured
@Service
public class AlertService {
   private final NotificationSender sender;

   public AlertService(@Value("${alert.channel:noop}") String channel,
                       Map<String, NotificationSender> senders) {
       this.sender = senders.getOrDefault(channel, senders.get("noOpNotification"));
   }
}
```

### # pattern selection guide

| Vấn đề                           | Pattern                 | Spring Mechanism            |
| -------------------------------- | ----------------------- | --------------------------- |
| Nhiều variants cùng interface    | Strategy                | `List<Interface>` injection |
| Workflow cố định, steps khác     | Template Method         | Abstract class              |
| Decouple side effects            | Observer                | `ApplicationEvent`          |
| Complex object creation          | Factory                 | `@Component` + Map          |
| Add behavior without modifying   | Decorator               | `@Primary` + delegate       |
| Sequential validation/processing | Chain of Responsibility | Ordered `List<Handler>`     |
| Dynamic query composition        | Specification           | JPA `Specification<T>`      |
| Avoid null checks                | Null Object             | Default `@Component`        |
| Immutable object construction    | Builder                 | Lombok `@Builder`           |

> Chỉ là những ghi chép cá nhân với hy vọng mang lại chút giá trị. Nếu thấy hữu ích, đừng ngại chia sẻ cho bạn bè & đồng nghiệp nhé!

Happy coding <Twemoji emoji="clinking-beer-mugs" /> 😎 👍🏻 🚀 🔥.
