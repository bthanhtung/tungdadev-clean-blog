---
layout: post
title: "solid principles"
date: 2025-07-25 19:29:39 +0700
categories: [Software Development]
tags: [java, solid, software-development, vietnamese]
---

> _"Any fool can write code that a computer can understand. Good programmers write code that humans can understand."_ — Martin Fowler

Nếu bạn đã từng review code và cảm thấy "cái service này nó làm quá nhiều thứ" hoặc thêm một feature mới mà phải sửa 15 file — thì bạn đang đối mặt với hậu quả của việc vi phạm SOLID.

Bài viết này không chỉ giải thích SOLID là gì, mà sẽ đi sâu vào **tại sao** từng nguyên tắc tồn tại, **khi nào** nên áp dụng và **như thế nào** trong thực tế với Java & Spring Boot.

---

### # tổng quan về solid

SOLID là tập hợp 5 nguyên tắc thiết kế hướng đối tượng (OOP) được giới thiệu bởi Robert C. Martin (Uncle Bob). Mục tiêu cốt lõi:

- **Dễ đọc** — Code nói lên ý đồ của người viết
- **Dễ mở rộng** — Thêm feature mới không phá vỡ feature cũ
- **Dễ test** — Mỗi thành phần có thể test độc lập
- **Dễ bảo trì** — Sửa bug ở một chỗ, không lan sang chỗ khác

Hãy nghĩ SOLID như "building code" cho phần mềm — giống như quy chuẩn xây dựng đảm bảo tòa nhà không sập, SOLID đảm bảo codebase của bạn không trở thành "legacy nightmare" sau 6 tháng.

| Chữ cái | Nguyên tắc            | Một câu tóm tắt                                               |
| ------- | --------------------- | ------------------------------------------------------------- |
| **S**   | Single Responsibility | Một class chỉ có một lý do để thay đổi                        |
| **O**   | Open/Closed           | Mở để mở rộng, đóng để sửa đổi                                |
| **L**   | Liskov Substitution   | Subclass phải thay thế được parent class                      |
| **I**   | Interface Segregation | Nhiều interface nhỏ tốt hơn một interface lớn                 |
| **D**   | Dependency Inversion  | Phụ thuộc vào abstraction, không phụ thuộc vào implementation |

---

### # s — single responsibility principle

> _"A class should have one, and only one, reason to change."_ — Robert C. Martin

Bạn có bao giờ thấy một `UserService` vừa xử lý business logic, vừa gửi email, vừa validate input, vừa format response không? Đó là "God Class" — class biết tất cả, làm tất cả và khi sửa một thứ thì mọi thứ vỡ.

SRP **không** có nghĩa là "mỗi class chỉ có một method". SRP nói về **reason to change** — lý do để thay đổi. Nếu business rule thay đổi và bạn phải sửa cùng class với khi email template thay đổi, thì class đó vi phạm SRP.

#### # vi phạm SRP

```java
@Service
public class OrderService {

    @Autowired
    private OrderRepository orderRepository;

    @Autowired
    private JavaMailSender mailSender;

    public Order createOrder(OrderRequest request) {
        // Validate input
        if (request.getItems().isEmpty()) {
            throw new IllegalArgumentException("Order must have at least one item");
        }
        if (request.getItems().stream().anyMatch(i -> i.getQuantity() <= 0)) {
            throw new IllegalArgumentException("Quantity must be positive");
        }

        // Calculate total
        BigDecimal total = request.getItems().stream()
                .map(i -> i.getPrice().multiply(BigDecimal.valueOf(i.getQuantity())))
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        // Apply discount
        if (total.compareTo(BigDecimal.valueOf(1000)) > 0) {
            total = total.multiply(BigDecimal.valueOf(0.9)); // 10% discount
        }

        // Save order
        Order order = new Order();
        order.setItems(request.getItems());
        order.setTotal(total);
        order.setStatus(OrderStatus.CREATED);
        Order saved = orderRepository.save(order);

        // Send confirmation email
        SimpleMailMessage message = new SimpleMailMessage();
        message.setTo(request.getCustomerEmail());
        message.setSubject("Order Confirmation #" + saved.getId());
        message.setText("Your order total: " + total);
        mailSender.send(message);

        // Log for analytics
        log.info("ORDER_CREATED: id={}, total={}, items={}",
                saved.getId(), total, request.getItems().size());

        return saved;
    }
}
```

Class này có **5 lý do để thay đổi**: validation rules, pricing logic, persistence, email notification và analytics logging. Khi PM nói "đổi cách tính discount", bạn phải mở file chứa cả logic gửi email — nguy hiểm.

#### # áp dụng srp đúng cách

```java
// 1. Validation — thay đổi khi business rules thay đổi
@Component
public class OrderValidator {

    public void validate(OrderRequest request) {
        if (request.getItems().isEmpty()) {
            throw new IllegalArgumentException("Order must have at least one item");
        }
        if (request.getItems().stream().anyMatch(i -> i.getQuantity() <= 0)) {
            throw new IllegalArgumentException("Quantity must be positive");
        }
    }
}

// 2. Pricing — thay đổi khi pricing strategy thay đổi
@Component
public class OrderPricingService {

    public BigDecimal calculateTotal(List<OrderItem> items) {
        BigDecimal total = items.stream()
                .map(i -> i.getPrice().multiply(BigDecimal.valueOf(i.getQuantity())))
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        if (total.compareTo(BigDecimal.valueOf(1000)) > 0) {
            total = total.multiply(BigDecimal.valueOf(0.9));
        }
        return total;
    }
}

// 3. Notification — thay đổi khi cách thông báo thay đổi
@Component
public class OrderNotificationService {

    @Autowired
    private JavaMailSender mailSender;

    public void sendConfirmation(Order order, String customerEmail) {
        SimpleMailMessage message = new SimpleMailMessage();
        message.setTo(customerEmail);
        message.setSubject("Order Confirmation #" + order.getId());
        message.setText("Your order total: " + order.getTotal());
        mailSender.send(message);
    }
}

// 4. Orchestrator — chỉ điều phối, không chứa business logic
@Service
@RequiredArgsConstructor
public class OrderService {

    private final OrderValidator validator;
    private final OrderPricingService pricingService;
    private final OrderRepository orderRepository;
    private final OrderNotificationService notificationService;

    @Transactional
    public Order createOrder(OrderRequest request) {
        validator.validate(request);

        BigDecimal total = pricingService.calculateTotal(request.getItems());

        Order order = new Order();
        order.setItems(request.getItems());
        order.setTotal(total);
        order.setStatus(OrderStatus.CREATED);
        Order saved = orderRepository.save(order);

        notificationService.sendConfirmation(saved, request.getCustomerEmail());

        return saved;
    }
}
```

#### # tại sao cách này tốt hơn?

- **Test dễ hơn**: Test pricing logic không cần mock email sender
- **Thay đổi an toàn**: Đổi discount strategy chỉ sửa `OrderPricingService`
- **Reuse**: `OrderPricingService` có thể dùng cho cả quote, invoice
- **Team work**: 2 dev có thể làm song song — một người sửa pricing, một người sửa notification

---

### # o — open/closed principle

> _"Software entities should be open for extension, but closed for modification."_ — Bertrand Meyer

Mỗi lần PM nói "thêm phương thức thanh toán mới", bạn lại mở `PaymentService` ra, thêm một `else if` vào chuỗi if-else dài 200 dòng. Mỗi lần thêm là một lần có thể break logic cũ.

OCP không có nghĩa là "không bao giờ sửa code". Nó có nghĩa là **thiết kế sao cho behavior mới có thể thêm vào mà không cần sửa code hiện tại**. Công cụ chính: abstraction (interface) + polymorphism.

#### # vi phạm ocp — Chuỗi if-else chết người

```java
@Service
public class PaymentService {

    public PaymentResult processPayment(PaymentRequest request) {
        if (request.getMethod() == PaymentMethod.CREDIT_CARD) {
            // 30 dòng xử lý credit card
            return processCreditCard(request);
        } else if (request.getMethod() == PaymentMethod.BANK_TRANSFER) {
            // 25 dòng xử lý bank transfer
            return processBankTransfer(request);
        } else if (request.getMethod() == PaymentMethod.MOMO) {
            // 20 dòng xử lý MoMo
            return processMoMo(request);
        } else if (request.getMethod() == PaymentMethod.VNPAY) {
            // Mới thêm tuần trước, đã gây bug cho credit card...
            return processVnPay(request);
        }
        // Thêm ZaloPay? Lại mở file này ra sửa...
        throw new UnsupportedOperationException("Unknown payment method");
    }
}
```

#### # áp dụng OCP với Strategy Pattern + Spring

```java
// Interface — contract cho mọi payment processor
public interface PaymentProcessor {

    PaymentMethod getSupportedMethod();

    PaymentResult process(PaymentRequest request);
}

// Mỗi implementation là một file riêng, không ai ảnh hưởng ai
@Component
public class CreditCardPaymentProcessor implements PaymentProcessor {

    @Override
    public PaymentMethod getSupportedMethod() {
        return PaymentMethod.CREDIT_CARD;
    }

    @Override
    public PaymentResult process(PaymentRequest request) {
        // Validate card number, expiry, CVV
        // Call payment gateway API
        // Handle 3D Secure if needed
        return PaymentResult.success(transactionId);
    }
}

@Component
public class MoMoPaymentProcessor implements PaymentProcessor {

    @Autowired
    private MoMoApiClient momoClient;

    @Override
    public PaymentMethod getSupportedMethod() {
        return PaymentMethod.MOMO;
    }

    @Override
    public PaymentResult process(PaymentRequest request) {
        // Call MoMo API
        // Handle MoMo-specific flow
        return PaymentResult.success(transactionId);
    }
}
```

```java
// Service sử dụng Spring DI để tự động collect tất cả implementations
@Service
public class PaymentService {

    private final Map<PaymentMethod, PaymentProcessor> processorMap;

    // Spring tự inject tất cả beans implement PaymentProcessor
    public PaymentService(List<PaymentProcessor> processors) {
        this.processorMap = processors.stream()
                .collect(Collectors.toMap(
                        PaymentProcessor::getSupportedMethod,
                        Function.identity()
                ));
    }

    public PaymentResult processPayment(PaymentRequest request) {
        PaymentProcessor processor = processorMap.get(request.getMethod());
        if (processor == null) {
            throw new UnsupportedOperationException(
                    "No processor found for: " + request.getMethod());
        }
        return processor.process(request);
    }
}
```

#### # thêm ZaloPay? Chỉ cần tạo file mới

```java
// Tạo file mới, KHÔNG sửa bất kỳ file nào đã có
@Component
public class ZaloPayPaymentProcessor implements PaymentProcessor {

    @Override
    public PaymentMethod getSupportedMethod() {
        return PaymentMethod.ZALOPAY;
    }

    @Override
    public PaymentResult process(PaymentRequest request) {
        // ZaloPay-specific logic
        return PaymentResult.success(transactionId);
    }
}
// Xong. PaymentService tự động nhận ZaloPay mà không cần sửa gì.
```

#### # điểm mấu chốt

Spring Boot là framework sinh ra để hỗ trợ OCP. Với dependency injection, bạn có thể:

- Thêm implementation mới chỉ bằng cách tạo `@Component` mới
- `PaymentService` **không bao giờ cần sửa** khi thêm payment method
- Mỗi processor test độc lập, deploy độc lập

---

### # l — liskov substitution principle

> _"Objects of a superclass should be replaceable with objects of its subclasses without breaking the application."_ — Barbara Liskov

Đây là nguyên tắc bị hiểu sai nhiều nhất. Nhiều người nghĩ LSP chỉ là "subclass phải override đúng method". Thực tế, LSP nói về **behavioral compatibility** — subclass phải giữ đúng "hợp đồng" (contract) mà parent class đã thiết lập.

#### # ví dụ kinh điển: Hình chữ nhật và Hình vuông

Trước khi vào Spring Boot, hãy hiểu bản chất qua ví dụ kinh điển:

```java
// Tưởng đúng nhưng SAI
public class Rectangle {
    protected int width;
    protected int height;

    public void setWidth(int width) { this.width = width; }
    public void setHeight(int height) { this.height = height; }
    public int getArea() { return width * height; }
}

public class Square extends Rectangle {
    // "Hình vuông là hình chữ nhật đặc biệt" — đúng trong toán, SAI trong code
    @Override
    public void setWidth(int width) {
        this.width = width;
        this.height = width; // Buộc height = width
    }

    @Override
    public void setHeight(int height) {
        this.width = height; // Buộc width = height
        this.height = height;
    }
}

// Code client — hoạt động đúng với Rectangle, SAI với Square
public void resize(Rectangle rect) {
    rect.setWidth(5);
    rect.setHeight(10);
    assert rect.getArea() == 50; // FAIL nếu rect là Square! Area = 100
}
```

#### # vi phạm LSP trong Spring Boot

```java
public interface NotificationSender {
    /**
     * Gửi notification đến user.
     * Contract: luôn gửi được, throw exception nếu có lỗi kỹ thuật.
     */
    void send(String userId, String message);
}

@Component
public class EmailNotificationSender implements NotificationSender {

    @Override
    public void send(String userId, String message) {
        // Gửi email — OK, đúng contract
        emailClient.send(userId, message);
    }
}

@Component
public class SmsNotificationSender implements NotificationSender {

    @Override
    public void send(String userId, String message) {
        // Vi phạm LSP: thêm điều kiện mà contract không đề cập
        if (message.length() > 160) {
            throw new IllegalArgumentException("SMS cannot exceed 160 chars");
            // Client code không expect exception này!
        }
        smsClient.send(userId, message);
    }
}

@Component
public class PushNotificationSender implements NotificationSender {

    @Override
    public void send(String userId, String message) {
        // Vi phạm LSP: âm thầm không làm gì
        if (!userHasApp(userId)) {
            return; // Swallow silently — caller nghĩ đã gửi thành công!
        }
        pushClient.send(userId, message);
    }
}
```

#### # áp dụng LSP đúng cách

```java
public interface NotificationSender {

    /**
     * Kiểm tra xem sender này có thể gửi cho user này không.
     * Caller PHẢI gọi method này trước khi gọi send().
     */
    boolean canSend(String userId, String message);

    /**
     * Gửi notification. Chỉ gọi khi canSend() trả về true.
     * @throws NotificationException nếu có lỗi kỹ thuật (network, server down)
     */
    void send(String userId, String message) throws NotificationException;
}

@Component
public class SmsNotificationSender implements NotificationSender {

    @Override
    public boolean canSend(String userId, String message) {
        // Rõ ràng: SMS có giới hạn, caller biết trước
        return message.length() <= 160 && phoneNumberExists(userId);
    }

    @Override
    public void send(String userId, String message) throws NotificationException {
        // Nếu đã qua canSend(), đảm bảo gửi được
        try {
            smsClient.send(userId, message);
        } catch (SmsApiException e) {
            throw new NotificationException("SMS sending failed", e);
        }
    }
}

@Component
public class PushNotificationSender implements NotificationSender {

    @Override
    public boolean canSend(String userId, String message) {
        return userHasApp(userId) && deviceTokenExists(userId);
    }

    @Override
    public void send(String userId, String message) throws NotificationException {
        try {
            pushClient.send(userId, message);
        } catch (PushApiException e) {
            throw new NotificationException("Push sending failed", e);
        }
    }
}

// Service sử dụng — hoạt động đúng với BẤT KỲ implementation nào
@Service
@RequiredArgsConstructor
public class NotificationService {

    private final List<NotificationSender> senders;

    public void notifyUser(String userId, String message) {
        List<NotificationSender> availableSenders = senders.stream()
                .filter(s -> s.canSend(userId, message))
                .toList();

        if (availableSenders.isEmpty()) {
            throw new NoAvailableSenderException(userId);
        }

        for (NotificationSender sender : availableSenders) {
            try {
                sender.send(userId, message);
                return; // Gửi thành công qua channel đầu tiên
            } catch (NotificationException e) {
                log.warn("Failed to send via {}: {}", sender.getClass().getSimpleName(), e.getMessage());
            }
        }
        throw new AllSendersFailedException(userId);
    }
}
```

#### # quy tắc vàng của LSP

1. **Preconditions**: Subclass không được yêu cầu nhiều hơn parent (không thêm validation mà contract không có)
2. **Postconditions**: Subclass không được trả về ít hơn parent (không swallow kết quả)
3. **Invariants**: Subclass phải giữ nguyên các bất biến của parent
4. **Exception behavior**: Subclass chỉ throw exception types mà parent đã declare

---

### # i — interface segregation principle

> _"No client should be forced to depend on methods it does not use."_ — Robert C. Martin

Bạn có một interface `UserService` với 20 methods. Controller chỉ cần `findById()` và `findAll()`, nhưng phải depend vào cả `deleteUser()`, `exportToExcel()`, `syncToLdap()`. Khi `syncToLdap()` thay đổi signature, controller phải recompile dù không dùng method đó.

#### # vi phạm ISP — "Fat Interface"

```java
// Interface "béo phì" — ép mọi implementation phải implement tất cả
public interface UserRepository {
    User findById(Long id);
    List<User> findAll();
    User save(User user);
    void delete(Long id);
    List<User> findByDepartment(String dept);
    void exportToCsv(OutputStream out);
    void importFromCsv(InputStream in);
    UserStatistics calculateStatistics();
    void syncToExternalSystem(String systemId);
    List<User> searchFullText(String query);
}

// Admin module cần tất cả — OK
@Repository
public class AdminUserRepository implements UserRepository {
    // Implement tất cả 10 methods — hợp lý
}

// Public API chỉ cần đọc — nhưng bị ép implement hết
@Repository
public class PublicUserRepository implements UserRepository {

    @Override
    public void delete(Long id) {
        throw new UnsupportedOperationException("Public API cannot delete users");
        // Vi phạm cả LSP!
    }

    @Override
    public void syncToExternalSystem(String systemId) {
        throw new UnsupportedOperationException("Not supported");
        // Vô nghĩa, nhưng bắt buộc phải có
    }

    // ... nhiều method throw UnsupportedOperationException
}
```

#### # áp dụng ISP — tách interface theo role

```java
// Interface cho việc đọc data
public interface UserReader {
    User findById(Long id);
    List<User> findAll();
    List<User> findByDepartment(String dept);
}

// Interface cho việc ghi data
public interface UserWriter {
    User save(User user);
    void delete(Long id);
}

// Interface cho search
public interface UserSearchable {
    List<User> searchFullText(String query);
}

// Interface cho import/export
public interface UserDataTransfer {
    void exportToCsv(OutputStream out);
    void importFromCsv(InputStream in);
}

// Interface cho external sync
public interface UserExternalSync {
    void syncToExternalSystem(String systemId);
}

// Admin repository — implement những gì cần
@Repository
public class AdminUserRepository implements UserReader, UserWriter,
        UserSearchable, UserDataTransfer, UserExternalSync {
    // Implement tất cả — hợp lý vì admin cần tất cả
}

// Public API — chỉ implement đọc và search
@Repository
public class PublicUserRepository implements UserReader, UserSearchable {
    // Chỉ implement 4 methods cần thiết
    // Không có method thừa, không có UnsupportedOperationException
}
```

#### # áp dụng ISP trong Spring Boot Controller

```java
// Controller cho public API — chỉ inject những gì cần
@RestController
@RequestMapping("/api/public/users")
@RequiredArgsConstructor
public class PublicUserController {

    // Chỉ depend vào UserReader, không biết gì về delete, sync, export
    private final UserReader userReader;
    private final UserSearchable userSearch;

    @GetMapping("/{id}")
    public ResponseEntity<UserDto> getUser(@PathVariable Long id) {
        return ResponseEntity.ok(toDto(userReader.findById(id)));
    }

    @GetMapping("/search")
    public ResponseEntity<List<UserDto>> search(@RequestParam String q) {
        return ResponseEntity.ok(
                userSearch.searchFullText(q).stream().map(this::toDto).toList()
        );
    }
}

// Controller cho admin — inject thêm write capabilities
@RestController
@RequestMapping("/api/admin/users")
@RequiredArgsConstructor
public class AdminUserController {

    private final UserReader userReader;
    private final UserWriter userWriter;
    private final UserDataTransfer dataTransfer;

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteUser(@PathVariable Long id) {
        userWriter.delete(id);
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/export")
    public void exportCsv(HttpServletResponse response) throws IOException {
        response.setContentType("text/csv");
        dataTransfer.exportToCsv(response.getOutputStream());
    }
}
```

#### # ISP + Spring Boot

Spring Boot hỗ trợ ISP rất tự nhiên:

- Một class có thể implement nhiều interface
- `@Autowired` inject theo type — controller chỉ thấy interface nó cần
- Khi test, chỉ cần mock interface nhỏ thay vì mock 20 methods

---

### # d — dependency inversion principle

> _"High-level modules should not depend on low-level modules. Both should depend on abstractions."_ — Robert C. Martin

#### # vấn đề thực tế

`OrderService` gọi trực tiếp `MySqlOrderRepository`. Một ngày, team quyết định chuyển sang MongoDB. Bạn phải sửa `OrderService` — một high-level module chứa business logic — chỉ vì thay đổi ở tầng infrastructure. Đó là coupling sai hướng.

#### # hiểu đúng DIP

DIP có 2 phần:

1. **High-level modules** (business logic) không depend vào **low-level modules** (database, API, file system)
2. Cả hai đều depend vào **abstractions** (interfaces)

Hướng dependency phải **đảo ngược**: thay vì business logic phụ thuộc vào database, database phụ thuộc vào interface mà business logic định nghĩa.

#### # vi phạm DIP — Coupling trực tiếp

```java
// High-level module phụ thuộc trực tiếp vào low-level module
@Service
public class ReportService {

    // Depend trực tiếp vào MySQL implementation
    private final MySqlReportRepository mysqlRepo;

    // Depend trực tiếp vào cách gửi email cụ thể
    private final SmtpEmailClient smtpClient;

    // Depend trực tiếp vào AWS S3
    private final AmazonS3Client s3Client;

    public ReportService(MySqlReportRepository mysqlRepo,
                         SmtpEmailClient smtpClient,
                         AmazonS3Client s3Client) {
        this.mysqlRepo = mysqlRepo;
        this.smtpClient = smtpClient;
        this.s3Client = s3Client;
    }

    public void generateAndSendReport(Long reportId) {
        // Business logic bị trộn lẫn với infrastructure details
        Report report = mysqlRepo.findById(reportId); // MySQL-specific
        byte[] pdf = generatePdf(report);

        // Upload to S3 — nếu đổi sang GCS phải sửa class này
        s3Client.putObject("reports-bucket", report.getName() + ".pdf",
                new ByteArrayInputStream(pdf), new ObjectMetadata());

        // Send email — nếu đổi sang SendGrid phải sửa class này
        MimeMessage message = smtpClient.createMimeMessage();
        // ... 20 dòng SMTP-specific code
        smtpClient.send(message);
    }
}
```

#### # áp dụng DIP — Depend vào abstraction

```java
// Abstractions — định nghĩa ở tầng domain/business
public interface ReportRepository {
    Report findById(Long id);
    Report save(Report report);
}

public interface FileStorage {
    String upload(String path, byte[] content);
    byte[] download(String path);
}

public interface NotificationSender {
    void send(String recipient, String subject, String body, byte[] attachment);
}

// High-level module — chỉ biết abstractions
@Service
@RequiredArgsConstructor
public class ReportService {

    private final ReportRepository reportRepository;  // Không biết là MySQL hay MongoDB
    private final FileStorage fileStorage;             // Không biết là S3 hay GCS
    private final NotificationSender notificationSender; // Không biết là SMTP hay SendGrid

    public void generateAndSendReport(Long reportId) {
        Report report = reportRepository.findById(reportId);
        byte[] pdf = generatePdf(report);

        String fileUrl = fileStorage.upload(
                "reports/" + report.getName() + ".pdf", pdf);

        notificationSender.send(
                report.getOwnerEmail(),
                "Report Ready: " + report.getName(),
                "Your report is available at: " + fileUrl,
                pdf
        );
    }
}
```

```java
// Low-level modules — implement abstractions, có thể swap tự do

@Repository
public class JpaReportRepository implements ReportRepository {

    @Autowired
    private SpringDataReportRepository springDataRepo;

    @Override
    public Report findById(Long id) {
        return springDataRepo.findById(id)
                .orElseThrow(() -> new ReportNotFoundException(id));
    }

    @Override
    public Report save(Report report) {
        return springDataRepo.save(report);
    }
}

@Component
@Profile("aws")
public class S3FileStorage implements FileStorage {

    @Autowired
    private AmazonS3Client s3Client;

    @Value("${storage.bucket}")
    private String bucket;

    @Override
    public String upload(String path, byte[] content) {
        s3Client.putObject(bucket, path,
                new ByteArrayInputStream(content), new ObjectMetadata());
        return s3Client.getUrl(bucket, path).toString();
    }

    @Override
    public byte[] download(String path) {
        S3Object object = s3Client.getObject(bucket, path);
        return object.getObjectContent().readAllBytes();
    }
}

@Component
@Profile("gcp")
public class GcsFileStorage implements FileStorage {

    @Autowired
    private Storage gcsStorage;

    @Value("${storage.bucket}")
    private String bucket;

    @Override
    public String upload(String path, byte[] content) {
        BlobInfo blobInfo = BlobInfo.newBuilder(bucket, path).build();
        gcsStorage.create(blobInfo, content);
        return String.format("https://storage.googleapis.com/%s/%s", bucket, path);
    }

    @Override
    public byte[] download(String path) {
        return gcsStorage.readAllBytes(bucket, path);
    }
}
```

#### # DIP + Spring Profiles

```yaml
# application-aws.yml
spring:
  profiles:
    active: aws
storage:
  bucket: my-reports-bucket

# application-gcp.yml
spring:
  profiles:
    active: gcp
storage:
  bucket: my-reports-bucket
```

Chuyển từ AWS sang GCP? Đổi profile, không sửa một dòng business logic nào.

#### # DIP trong Testing

```java
@ExtendWith(MockitoExtension.class)
class ReportServiceTest {

    @Mock
    private ReportRepository reportRepository;

    @Mock
    private FileStorage fileStorage;

    @Mock
    private NotificationSender notificationSender;

    @InjectMocks
    private ReportService reportService;

    @Test
    void shouldGenerateAndSendReport() {
        // Arrange
        Report report = new Report(1L, "Q4 Report", "[email]");
        when(reportRepository.findById(1L)).thenReturn(report);
        when(fileStorage.upload(anyString(), any())).thenReturn("https://example.com/report.pdf");

        // Act
        reportService.generateAndSendReport(1L);

        // Assert
        verify(fileStorage).upload(contains("Q4 Report"), any());
        verify(notificationSender).send(
                eq("[email]"),
                contains("Q4 Report"),
                contains("https://example.com/report.pdf"),
                any()
        );
    }
}
```

Test business logic mà không cần database, không cần S3, không cần email server. Chạy trong milliseconds.

---

### # SOLID trong thực tế: Khi nào KHÔNG nên áp dụng

Đây là phần mà nhiều bài viết bỏ qua. SOLID là guidelines, không phải laws. Áp dụng mù quáng có thể gây hại nhiều hơn lợi.

#### # over-engineering cho code đơn giản

```java
// ĐỪNG làm thế này cho một util method đơn giản
public interface StringFormatter { ... }
public interface StringValidator { ... }
public interface StringTransformer { ... }
public class UpperCaseStringFormatter implements StringFormatter { ... }
public class DefaultStringValidator implements StringValidator { ... }

// Chỉ cần thế này
public class StringUtils {
    public static String formatName(String name) {
        return name.trim().toUpperCase();
    }
}
```

#### # premature Abstraction

Đừng tạo interface khi chỉ có một implementation. Tạo interface khi bạn thực sự cần polymorphism hoặc khi bạn cần mock trong test.

```java
// Nếu chỉ có MySQL và không có kế hoạch đổi — YAGNI
// Đừng tạo interface chỉ vì "SOLID nói phải có interface"

// Nhưng NÊN tạo interface khi:
// - Có 2+ implementations (payment processors)
// - Cần mock trong unit test (external API calls)
// - Team đã biết sẽ có thêm implementation (notification channels)
```

#### # quy tắc "Rule of Three"

> Lần đầu: viết trực tiếp.
> Lần hai: nhận ra sự trùng lặp, chấp nhận.
> Lần ba: refactor, áp dụng SOLID.

#### # context matters

- **Startup MVP**: Ship fast, refactor later. Đừng over-engineer.
- **Enterprise system**: SOLID từ đầu, technical debt ở đây rất đắt.
- **Microservice nhỏ**: Một service 200 dòng không cần 15 interfaces.
- **Shared library**: SOLID rất quan trọng vì nhiều team depend vào.

---

### # kết luận

SOLID không phải là checklist để áp dụng 100% mọi lúc. Nó là một mindset để hướng đến code chất lượng hơn. Đôi khi, vi phạm một nguyên tắc có thể chấp nhận được nếu nó làm code đơn giản hơn trong trường hợp cụ thể. Nhưng nếu bạn thấy mình thường xuyên phải sửa cùng một file khi thêm feature mới hoặc phải mock quá nhiều thứ trong test, đó là dấu hiệu bạn đang vi phạm SOLID và nên refactor.

| Khi bạn thấy...                     | Có thể vi phạm... | Hỏi...                                             |
| ----------------------------------- | ----------------- | -------------------------------------------------- |
| Class > 300 dòng                    | SRP               | "Class này có bao nhiêu lý do để thay đổi?"        |
| Switch/if-else trên type            | OCP               | "Thêm type mới có phải sửa file này không?"        |
| `instanceof` checks                 | LSP               | "Subclass có giữ đúng contract không?"             |
| `UnsupportedOperationException`     | ISP (+ LSP)       | "Interface có ép implement method thừa không?"     |
| `new ConcreteClass()` trong service | DIP               | "High-level module có depend vào low-level không?" |

#### # vậy nên:

1. **Bắt đầu đơn giản**, refactor khi complexity tăng
2. **SRP và DIP** là hai nguyên tắc có impact lớn nhất — ưu tiên áp dụng trước
3. **Code review** là nơi tốt nhất để catch SOLID violations
4. **Đừng dogmatic** — SOLID phục vụ bạn, không phải ngược lại
5. **Spring Boot** là framework hỗ trợ SOLID tốt nhất trong Java ecosystem — tận dụng DI, Profiles, và component scanning

> _"The goal of software architecture is to minimize the human resources required to build and maintain the required system."_ — Robert C. Martin, Clean Architecture

> Chỉ là những ghi chép cá nhân với hy vọng mang lại chút giá trị. Nếu thấy hữu ích, đừng ngại chia sẻ cho bạn bè & đồng nghiệp nhé!

Happy coding <Twemoji emoji="clinking-beer-mugs" /> 😎 👍🏻 🚀 🔥.
