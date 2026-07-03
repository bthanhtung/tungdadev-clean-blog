---
layout: post
title: "java 21 feature"
date: 2024-03-05 19:29:39 +0700
categories: [Software Development]
tags: [java, software-development, best-practices, vietnamese]
---

Java đã trải qua một chặng đường dài gọt giũa. Từ những phiên bản nặng nề boilerplate, Java 17 đến Java 21 mang theo một hơi thở hoàn toàn mới: hướng tới sự tối giản, rành mạch và an toàn. Đối với những kỹ sư theo đuổi sự hoàn mỹ trong từng dòng code hay kiến trúc hệ thống (như Clean Architecture hay Event Sourcing), bộ tính năng mới này không chỉ là công cụ, mà là triết lý để lọc bỏ những "tiếng ồn" rườm rà, giữ lại giá trị cốt lõi nhất của Domain.

Dưới đây là bức tranh toàn cảnh về các tính năng ngôn ngữ quan trọng trong Java 17-21 và cách thực chiến chúng, đặc biệt là trong hệ sinh thái Spring Boot.

### # records (java 16+, finalized)

Lâu nay, chúng ta thường phải dựa vào Lombok (@Data, @Value) để giảm tải các thao tác khai báo rập khuôn. Tuy nhiên, record ra đời như một cấu trúc dữ liệu nguyên bản mang theo đặc tính Immutable (bất biến) — một yếu tố sống còn để đảm bảo tính toàn vẹn của dữ liệu trong các hệ thống phân tán và xử lý đồng thời.

```java
// Trình biên dịch tự động lo liệu: constructor, getters, equals, hashCode, toString
public record UserDTO(UUID id, String name, String email) {}

// Tích hợp Validation ngay từ vòng gửi xe với Compact Constructor
public record CreateOrderRequest(
   @NotNull UUID productId,
   @Positive int quantity,
   @NotBlank String shippingAddress
) {
   // Compact constructor — validation logic
   public CreateOrderRequest {
       if (quantity > 1000) throw new IllegalArgumentException("Max 1000 per order");
   }
}

// Biến Record thành một Value Object trong DDD
public record Money(BigDecimal amount, String currency) {
   public Money add(Money other) {
       if (!this.currency.equals(other.currency)) throw new IllegalArgumentException("Currency mismatch");
       return new Money(this.amount.add(other.amount), this.currency);
   }

   public boolean isPositive() {
       return amount.compareTo(BigDecimal.ZERO) > 0;
   }
}

// Spring integration
@RestController
public class UserController {
   @GetMapping("/users/{id}")
   public UserDTO getUser(@PathVariable UUID id) {
       return new UserDTO(id, "John", "john@example.com");
   }
}
```

**Khi nào dùng Records vs Lombok @Data**:
| Records | Lombok @Data |
|---------|-------------|
| Immutable (no setters) | Mutable (setters) |
| Simple DTOs, responses, events | JPA entities (cần no-arg constructor) |
| Cực kỳ phù hợp cho Value Objects trong DDD | Dành cho các object cần Builder rườm rà (dù Record vẫn có thể custom Builder) |
| Không hỗ trợ extends (chỉ implements) | Hỗ trợ kế thừa hoàn toàn |

### # sealed classes (java 17+)

Kiểm soát chặt chẽ hệ thống phân cấp class là nền tảng để Domain của bạn không bị phá vỡ bởi các implementations không mong muốn. Trình biên dịch giờ đây biết chính xác có bao nhiêu subtypes tồn tại, giúp việc rẽ nhánh logic trở nên tuyệt đối an toàn.

```java
// Khai báo rõ ràng: Chỉ Circle, Rectangle, Triangle mới được phép kế thừa Shape
public sealed interface Shape permits Circle, Rectangle, Triangle {}

public record Circle(double radius) implements Shape {}
public record Rectangle(double width, double height) implements Shape {}
public record Triangle(double base, double height) implements Shape {}

// Exhaustive Switch: Không cần "default" vì Compiler đã nắm rõ mọi ngả đường
public double area(Shape shape) {
   return switch (shape) {
       case Circle c -> Math.PI * c.radius() * c.radius();
       case Rectangle r -> r.width() * r.height();
       case Triangle t -> 0.5 * t.base() * t.height();
   };
}

// Domain modeling
public sealed interface PaymentResult permits PaymentSuccess, PaymentFailed, PaymentPending {}
public record PaymentSuccess(String transactionId, Instant timestamp) implements PaymentResult {}
public record PaymentFailed(String errorCode, String message) implements PaymentResult {}
public record PaymentPending(String referenceId) implements PaymentResult {}

// Usage
public ResponseEntity<?> handleResult(PaymentResult result) {
   return switch (result) {
       case PaymentSuccess s -> ResponseEntity.ok(s);
       case PaymentFailed f -> ResponseEntity.badRequest().body(f);
       case PaymentPending p -> ResponseEntity.accepted().body(p);
   };
}
```

### # pattern matching

#### # instanceof pattern (java 16+)

Tạm biệt việc ép kiểu (casting) dư thừa. Code giờ đây đọc thuận miệng như một câu văn.

```java
// Ngày xưa: Khai báo rồi ép kiểu
if (obj instanceof String) {
    String s = (String) obj;
    return s.length();
}

// Java 16+: Binding biến ngay lập tức
if (obj instanceof String s && s.length() > 5) {
    return s.substring(0, 5);
}
```

#### # switch pattern matching (java 21)

Sự kết hợp hoàn hảo giữa switch và instanceof, mở ra khả năng phân tách dữ liệu (destructuring) mạnh mẽ.

```java
// Phân loại kết hợp Guard Clauses (when)
public String classify(Shape shape) {
    return switch (shape) {
        case Circle c when c.radius() > 100 -> "Vòng tròn cỡ lớn";
        case Circle c -> "Vòng tròn tiêu chuẩn";
        case Rectangle r when r.width() == r.height() -> "Hình vuông";
        case Rectangle r -> "Hình chữ nhật";
        case Triangle t -> "Hình tam giác";
    };
}

// Phân rã Record (Destructuring) - Trực tiếp lấy biến từ bên trong Record
public double calculateArea(Shape shape) {
    return switch (shape) {
        case Circle(var radius) -> Math.PI * radius * radius;
        case Rectangle(var w, var h) -> w * h;
        case Triangle(var b, var h) -> 0.5 * b * h;
    };
}
```

#### # practical: exception handling

```java
public APIResponse<?> handleException(Exception ex) {
   return switch (ex) {
       case NotFoundException e -> APIResponse.error("NOT_FOUND", e.getMessage());
       case ValidationException e -> APIResponse.error("VALIDATION", e.getErrors());
       case AccessDeniedException e -> APIResponse.error("FORBIDDEN", "Access denied");
       case TimeoutException e -> APIResponse.error("TIMEOUT", "Service unavailable");
       default -> APIResponse.error("INTERNAL", "Unexpected error");
   };
}
```

### # text blocks (java 15+)

Đừng để những dấu nối chuỗi + và ký tự escape \n làm hỏng cấu trúc đoạn code của bạn. Text Blocks giữ nguyên định dạng trực quan.

```java
// Multi-line strings
String sql = """
   SELECT u.id, u.name, u.email
   FROM users u
   WHERE u.status = :status
     AND u.created_date > :since
   ORDER BY u.name
   """;

// JSON template
String json = """
   {
       "name": "%s",
       "email": "%s",
       "role": "USER"
   }
   """.formatted(name, email);

// SQL in @Query
@Query(value = """
   SELECT p.* FROM products p
   JOIN categories c ON c.id = p.category_id
   WHERE c.name = :category
     AND p.price BETWEEN :min AND :max
   ORDER BY p.created_at DESC
   """, nativeQuery = true)
List<Product> findByCategoryAndPrice(String category, BigDecimal min, BigDecimal max);
```

### # sequenced collections (java 21)

Nhiều năm qua, việc lấy phần tử cuối cùng của một danh sách thường yêu cầu cú pháp lủng củng list.get(list.size() - 1). Interface mới này mang lại các phương thức nhất quán.

```java
// Interface hierarchy: SequencedCollection, SequencedSet, SequencedMap
List<String> list = List.of("a", "b", "c");

// First/Last access (no more list.get(0), list.get(list.size()-1))
String first = list.getFirst();  // "a"
String last = list.getLast();    // "c"

// Reversed view
List<String> reversed = list.reversed(); // ["c", "b", "a"]

// Works with LinkedHashSet, TreeSet, LinkedHashMap
SequencedMap<String, Integer> map = new LinkedHashMap<>();
map.putFirst("key1", 1);
map.putLast("key2", 2);
Map.Entry<String, Integer> firstEntry = map.firstEntry();
Map.Entry<String, Integer> lastEntry = map.lastEntry();
```

### # enhanced switch expressions (java 14+)

```java
// Arrow syntax — no fall-through
String label = switch (status) {
   case ACTIVE -> "Active";
   case INACTIVE -> "Inactive";
   case SUSPENDED -> "Suspended";
};

// Multiple values per case
int numDays = switch (month) {
   case JANUARY, MARCH, MAY, JULY, AUGUST, OCTOBER, DECEMBER -> 31;
   case APRIL, JUNE, SEPTEMBER, NOVEMBER -> 30;
   case FEBRUARY -> isLeapYear ? 29 : 28;
};

// Block with yield
String description = switch (errorCode) {
   case 404 -> "Not Found";
   case 500 -> {
       log.error("Internal server error");
       yield "Internal Error";
   }
   default -> "Unknown Error (%d)".formatted(errorCode);
};
```

### # unnamed patterns & variables (java 22 preview, but useful concept)

```java
// Underscore for unused variables (preview)
try {
   process();
} catch (IOException _) {
   // don't need the exception variable
   return fallback();
}

// In enhanced for
for (var _ : collection) {
   count++;
}

// In lambda
map.forEach((_, value) -> process(value));
```

### # string templates (preview — java 21)

```java
// STR processor (preview, requires --enable-preview)
String name = "World";
String greeting = STR."Hello, \{name}!";

// Expression interpolation
String info = STR."User \{user.getName()} has \{user.getOrders().size()} orders";

// Multi-line
String html = STR."""
   <div class="user">
       <span>\{user.getName()}</span>
       <span>\{user.getEmail()}</span>
   </div>
   """;

// Note: Removed in Java 23+, replaced by simpler approach
// For now, use String.formatted() or MessageFormat
String safe = "User %s has %d orders".formatted(name, count);
```

### # practical combinations

Tính năng ngôn ngữ chỉ thực sự tỏa sáng khi được đặt vào đúng hoa tiêu kiến trúc. Hãy xem cách kết hợp Records + Sealed Interfaces + Pattern Matching để giải quyết bài toán phức tạp.

#### # domain modeling with records + sealed + pattern matching

```java
// Giới hạn rạch ròi các Event có thể xảy ra trong Domain Order
public sealed interface DomainEvent permits
   OrderPlaced, OrderConfirmed, OrderShipped, OrderCancelled {}

public record OrderPlaced(UUID orderId, UUID customerId, List<LineItem> items, Instant at)
   implements DomainEvent {}
public record OrderConfirmed(UUID orderId, String paymentRef, Instant at)
   implements DomainEvent {}
public record OrderShipped(UUID orderId, String trackingNumber, Instant at)
   implements DomainEvent {}
public record OrderCancelled(UUID orderId, String reason, Instant at)
   implements DomainEvent {}

// Event handler
public Order apply(Order current, DomainEvent event) {
   return switch (event) {
       case OrderPlaced e -> Order.create(e.orderId(), e.customerId(), e.items());
       case OrderConfirmed e -> current.confirm(e.paymentRef());
       case OrderShipped e -> current.ship(e.trackingNumber());
       case OrderCancelled e -> current.cancel(e.reason());
   };
}
```

#### # result type (railway-oriented)

Thay vì ném Exception bừa bãi khắp mọi layer, ta bọc kết quả trả về bằng một kiểu Result, làm rõ luồng xử lý Thành công/Thất bại ngay từ chữ ký của hàm (method signature).

```java
public sealed interface Result<T> permits Result.Success, Result.Failure {
   record Success<T>(T value) implements Result<T> {}
   record Failure<T>(String error, String code) implements Result<T> {}

   static <T> Result<T> ok(T value) { return new Success<>(value); }
   static <T> Result<T> fail(String error, String code) { return new Failure<>(error, code); }
}

// Usage
public Result<User> findUser(UUID id) {
   return userRepo.findById(id)
       .<Result<User>>map(Result::ok)
       .orElse(Result.fail("User not found", "USER_404"));
}

// Handle in controller
public ResponseEntity<?> getUser(UUID id) {
   return switch (userService.findUser(id)) {
       case Result.Success<User>(var user) -> ResponseEntity.ok(user);
       case Result.Failure<User>(var msg, var code) -> ResponseEntity.status(404).body(msg);
   };
}
```

### # migration tips

| Old Pattern                          | Java 21 Replacement              |
| ------------------------------------ | -------------------------------- |
| Lombok @Value DTO                    | `record`                         |
| Visitor pattern                      | Sealed + switch pattern matching |
| `instanceof` + cast                  | Pattern binding variable         |
| String concatenation                 | Text blocks + `.formatted()`     |
| `Collections.unmodifiableList(list)` | `List.copyOf(list)`              |
| `list.get(list.size()-1)`            | `list.getLast()`                 |
| Enum with abstract method            | Sealed interface + records       |

### # lời kết

Sự chuyển mình từ Java 8, Java 11 lên thẳng Java 21 không đơn thuần là việc nâng cấp version hay chạy theo công nghệ mới. Nó là quá trình loại bỏ những thứ thừa thãi, mài giũa cú pháp để lập trình viên có thể tập trung toàn bộ chất xám vào Nghiệp Vụ (Business Logic) thay vì loay hoay với những đoạn code boilerplate vô hồn.

Việc chuyển đổi tư duy sử dụng Class thông thường sang Record, hay áp dụng triệt để Sealed Interface sẽ giúp những dự án backend trở nên bền bỉ, dễ bảo trì và mở rộng hơn rất nhiều.

> Chỉ là những ghi chép cá nhân với hy vọng mang lại chút giá trị. Nếu thấy hữu ích, đừng ngại chia sẻ cho bạn bè & đồng nghiệp nhé!

Happy coding <Twemoji emoji="clinking-beer-mugs" /> 😎 👍🏻 🚀 🔥.
