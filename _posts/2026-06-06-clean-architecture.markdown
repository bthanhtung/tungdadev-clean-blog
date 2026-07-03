---
layout: post
title: "clean architecture"
date: 2026-06-06 19:29:39 +0700
categories: [Software Development]
tags: [software-development, system-design, best-practices, vietnamese]
---

### # vấn đề clean architecture giải quyết

Bạn đã bao giờ gặp codebase mà:

- Đổi database từ PostgreSQL sang MongoDB = rewrite 60% code?
- Viết unit test cho business logic phải mock 15 dependencies?
- Service class 2000 dòng vì mix business rules, HTTP calls, database queries, validation?
- Không thể test offline vì code depend trực tiếp vào external APIs?

Root cause: **business logic bị coupling với infrastructure details**. Service biết nó dùng PostgreSQL. Controller biết format response. Use case biết cách gọi REST API. Khi infrastructure thay đổi, business logic phải thay đổi theo.

Clean Architecture (Robert C. Martin, 2012) giải quyết bằng **Dependency Rule**: source code dependencies chỉ point inward. Inner layers (business rules) KHÔNG biết outer layers (frameworks, databases, UI) tồn tại.

### # the dependency rule — quy tắc duy nhất

![clean-architecture-rule]({{ site.baseurl }}/assets/img/blog/clean-architecture-rule.png)

4 layers từ trong ra ngoài:

| Layer                | Chứa gì                             | Ví dụ                                   |
| -------------------- | ----------------------------------- | --------------------------------------- |
| Entities             | Core business objects + rules       | Order, Money, CreditScore               |
| Use Cases            | Application-specific business rules | CreateOrderUseCase, ApproveL oanUseCase |
| Interface Adapters   | Convert data format giữa layers     | Controllers, Presenters, Gateways       |
| Frameworks & Drivers | External tools, libs, infra         | Spring Boot, PostgreSQL, RabbitMQ       |

**Key insight**: Entities không import Use Case classes. Use Cases không import Controller classes. Controller không import Spring-specific gì vào Use Case. Interfaces (ports) ở inner layer, implementations (adapters) ở outer layer.

### # ports & adapters (hexagonal architecture)

Clean Architecture và Hexagonal Architecture (Alistair Cockburn) là cùng 1 idea, khác cách trình bày. Hexagonal dùng metaphor "ports" (interfaces inner layer định nghĩa) và "adapters" (implementations outer layer cung cấp).

![hexagonal-architecture]({{ site.baseurl }}/assets/img/blog/hexagonal-architecture.png)

**Inbound Ports** (driving): Use Case interfaces — ai muốn "dùng" application phải qua đây.
**Outbound Ports** (driven): Repository/Gateway interfaces — application cần gì từ bên ngoài khai báo ở đây.
**Adapters**: Implementations cụ thể (REST controller, JPA repository, SMTP email sender).

### # implementation trong spring boot

#### # package structure

```
com.example.order/
├── domain/                          # ← INNER: Zero Spring dependencies
│   ├── model/
│   │   ├── Order.java              # Entity (POJO, business rules bên trong)
│   │   ├── OrderItem.java
│   │   ├── Money.java              # Value Object
│   │   └── OrderStatus.java
│   ├── port/
│   │   ├── in/                     # Inbound Ports (Use Case interfaces)
│   │   │   ├── CreateOrderUseCase.java
│   │   │   ├── GetOrderUseCase.java
│   │   │   └── CancelOrderUseCase.java
│   │   └── out/                    # Outbound Ports (driven interfaces)
│   │       ├── OrderRepository.java       # Persistence port
│   │       ├── PaymentGateway.java        # External service port
│   │       ├── InventoryGateway.java
│   │       └── NotificationPort.java
│   └── service/                    # Use Case implementations
│       ├── CreateOrderService.java
│       ├── GetOrderService.java
│       └── CancelOrderService.java
│
├── adapter/                         # ← OUTER: Spring, JPA, HTTP dependencies OK
│   ├── in/                         # Inbound Adapters (driving)
│   │   ├── web/
│   │   │   ├── OrderController.java       # REST adapter
│   │   │   ├── CreateOrderRequest.java    # Web-specific DTO
│   │   │   └── OrderResponse.java
│   │   └── messaging/
│   │       └── OrderEventListener.java    # RabbitMQ adapter
│   └── out/                        # Outbound Adapters (driven)
│       ├── persistence/
│       │   ├── OrderJpaEntity.java        # JPA entity (≠ domain Order)
│       │   ├── OrderJpaRepository.java    # Spring Data interface
│       │   └── OrderPersistenceAdapter.java  # Implements domain's OrderRepository
│       ├── payment/
│       │   └── StripePaymentAdapter.java  # Implements PaymentGateway
│       └── notification/
│           └── SmtpNotificationAdapter.java
│
└── config/                          # Spring wiring
   └── BeanConfig.java
```

#### # domain layer — zero framework dependencies

```java
// Domain Entity — pure Java, NO Spring annotations, NO JPA annotations
public class Order {
   private final OrderId id;
   private final CustomerId customerId;
   private final List<OrderItem> items;
   private OrderStatus status;
   private Money totalAmount;
   private LocalDateTime createdAt;

   // Business rules LIVE HERE
   public void confirm() {
       if (this.status != OrderStatus.PENDING) {
           throw new IllegalOrderStateException(
               "Cannot confirm order in status: " + this.status);
       }
       if (this.items.isEmpty()) {
           throw new EmptyOrderException("Order must have at least 1 item");
       }
       this.status = OrderStatus.CONFIRMED;
   }

   public void cancel(String reason) {
       if (this.status == OrderStatus.SHIPPED) {
           throw new IllegalOrderStateException("Cannot cancel shipped order");
       }
       this.status = OrderStatus.CANCELLED;
   }

   public Money calculateTotal() {
       return items.stream()
           .map(item -> item.getPrice().multiply(item.getQuantity()))
           .reduce(Money.ZERO, Money::add);
   }

   // No setters — state changes only through business methods
}

// Value Object — immutable, equality by value
public record Money(BigDecimal amount, String currency) {
   public static final Money ZERO = new Money(BigDecimal.ZERO, "VND");

   public Money {
       if (amount.compareTo(BigDecimal.ZERO) < 0)
           throw new IllegalArgumentException("Amount cannot be negative");
   }

   public Money add(Money other) {
       if (!this.currency.equals(other.currency))
           throw new CurrencyMismatchException(this.currency, other.currency);
       return new Money(this.amount.add(other.amount), this.currency);
   }

   public Money multiply(int quantity) {
       return new Money(this.amount.multiply(BigDecimal.valueOf(quantity)), this.currency);
   }
}
```

#### # ports — interfaces domain cần

```java
// Inbound Port: Use Case interface
public interface CreateOrderUseCase {
   OrderId execute(CreateOrderCommand command);
}

// Command object (input to use case)
public record CreateOrderCommand(
   CustomerId customerId,
   List<OrderItemCommand> items,
   PaymentMethod paymentMethod
) {}

// Outbound Port: persistence
public interface OrderRepository {
   Order save(Order order);
   Optional<Order> findById(OrderId id);
   List<Order> findByCustomerId(CustomerId customerId);
}

// Outbound Port: external service
public interface PaymentGateway {
   PaymentResult charge(OrderId orderId, Money amount, PaymentMethod method);
   void refund(OrderId orderId);
}

public interface NotificationPort {
   void sendOrderConfirmation(CustomerId customerId, OrderId orderId);
}
```

#### # use case implementation

```java
// Use Case: orchestrate domain objects + ports
// NO Spring annotations here (optional: can add @Service for convenience)
public class CreateOrderService implements CreateOrderUseCase {

   private final OrderRepository orderRepository;
   private final PaymentGateway paymentGateway;
   private final InventoryGateway inventoryGateway;
   private final NotificationPort notificationPort;

   public CreateOrderService(OrderRepository orderRepository,
                             PaymentGateway paymentGateway,
                             InventoryGateway inventoryGateway,
                             NotificationPort notificationPort) {
       this.orderRepository = orderRepository;
       this.paymentGateway = paymentGateway;
       this.inventoryGateway = inventoryGateway;
       this.notificationPort = notificationPort;
   }

   @Override
   public OrderId execute(CreateOrderCommand command) {
       // 1. Create domain object (business rules validated in constructor)
       Order order = Order.create(command.customerId(), command.items());

       // 2. Check inventory (through port — doesn't know HOW it's checked)
       inventoryGateway.checkAvailability(order.getItems());

       // 3. Charge payment (through port — doesn't know it's Stripe/VnPay)
       PaymentResult payment = paymentGateway.charge(
           order.getId(), order.calculateTotal(), command.paymentMethod());

       if (!payment.isSuccess()) {
           throw new PaymentFailedException(payment.getErrorMessage());
       }

       // 4. Confirm order (domain business rule)
       order.confirm();

       // 5. Persist (through port — doesn't know it's PostgreSQL/MongoDB)
       orderRepository.save(order);

       // 6. Notify (through port — doesn't know it's email/push/SMS)
       notificationPort.sendOrderConfirmation(command.customerId(), order.getId());

       return order.getId();
   }
}
```

#### # adapter layer — framework-specific implementations

```java
// Inbound Adapter: REST Controller
@RestController
@RequestMapping("/api/v1/orders")
@RequiredArgsConstructor
public class OrderController {

   private final CreateOrderUseCase createOrderUseCase;  // Depend on PORT, not implementation
   private final GetOrderUseCase getOrderUseCase;

   @PostMapping
   @ResponseStatus(HttpStatus.CREATED)
   public OrderResponse create(@Valid @RequestBody CreateOrderRequest request) {
       // Convert web DTO → domain command
       CreateOrderCommand command = new CreateOrderCommand(
           new CustomerId(request.getCustomerId()),
           request.getItems().stream().map(this::toItemCommand).toList(),
           request.getPaymentMethod()
       );

       // Call use case (doesn't know about HTTP, JSON, Spring)
       OrderId orderId = createOrderUseCase.execute(command);

       // Convert domain result → web response
       return new OrderResponse(orderId.value(), "Order created successfully");
   }
}

// Outbound Adapter: JPA persistence
@Component
@RequiredArgsConstructor
public class OrderPersistenceAdapter implements OrderRepository {

   private final OrderJpaRepository jpaRepository;  // Spring Data
   private final OrderMapper mapper;                // Domain ↔ JPA entity

   @Override
   public Order save(Order order) {
       OrderJpaEntity entity = mapper.toJpaEntity(order);
       OrderJpaEntity saved = jpaRepository.save(entity);
       return mapper.toDomain(saved);
   }

   @Override
   public Optional<Order> findById(OrderId id) {
       return jpaRepository.findById(id.value())
           .map(mapper::toDomain);
   }
}

// Outbound Adapter: Payment gateway (Stripe)
@Component
@RequiredArgsConstructor
public class StripePaymentAdapter implements PaymentGateway {

   private final StripeClient stripeClient;

   @Override
   public PaymentResult charge(OrderId orderId, Money amount, PaymentMethod method) {
       StripeChargeRequest stripeRequest = StripeChargeRequest.builder()
           .amount(amount.amount().movePointRight(2).longValue())  // cents
           .currency(amount.currency().toLowerCase())
           .idempotencyKey(orderId.value().toString())
           .build();

       StripeChargeResponse response = stripeClient.createCharge(stripeRequest);
       return new PaymentResult(response.isSucceeded(), response.getErrorMessage());
   }
}
```

#### # wiring — spring config

```java
@Configuration
public class OrderBeanConfig {

   @Bean
   public CreateOrderUseCase createOrderUseCase(
           OrderRepository orderRepository,
           PaymentGateway paymentGateway,
           InventoryGateway inventoryGateway,
           NotificationPort notificationPort) {
       return new CreateOrderService(
           orderRepository, paymentGateway, inventoryGateway, notificationPort);
   }
}
```

### # testing benefits — the payoff

Clean Architecture shines khi testing: domain logic test với ZERO infrastructure.

```java
// Unit test Use Case — mock ports, test business logic
class CreateOrderServiceTest {

   private final OrderRepository orderRepository = mock(OrderRepository.class);
   private final PaymentGateway paymentGateway = mock(PaymentGateway.class);
   private final InventoryGateway inventoryGateway = mock(InventoryGateway.class);
   private final NotificationPort notificationPort = mock(NotificationPort.class);

   private final CreateOrderUseCase useCase = new CreateOrderService(
       orderRepository, paymentGateway, inventoryGateway, notificationPort);

   @Test
   void createOrder_success() {
       when(paymentGateway.charge(any(), any(), any()))
           .thenReturn(PaymentResult.success());
       when(orderRepository.save(any())).thenAnswer(i -> i.getArgument(0));

       OrderId result = useCase.execute(validCommand());

       assertThat(result).isNotNull();
       verify(orderRepository).save(argThat(order ->
           order.getStatus() == OrderStatus.CONFIRMED));
       verify(notificationPort).sendOrderConfirmation(any(), any());
   }

   @Test
   void createOrder_paymentFailed_throwsException() {
       when(paymentGateway.charge(any(), any(), any()))
           .thenReturn(PaymentResult.failed("Insufficient funds"));

       assertThatThrownBy(() -> useCase.execute(validCommand()))
           .isInstanceOf(PaymentFailedException.class);

       verify(orderRepository, never()).save(any());  // Order NOT persisted
   }
}

// Domain entity unit test — ZERO mocking
class OrderTest {

   @Test
   void confirm_pendingOrder_changesStatusToConfirmed() {
       Order order = Order.create(customerId, List.of(item1, item2));
       order.confirm();
       assertThat(order.getStatus()).isEqualTo(OrderStatus.CONFIRMED);
   }

   @Test
   void confirm_emptyOrder_throwsException() {
       Order order = Order.create(customerId, List.of());
       assertThatThrownBy(order::confirm)
           .isInstanceOf(EmptyOrderException.class);
   }

   @Test
   void cancel_shippedOrder_throwsException() {
       Order order = createShippedOrder();
       assertThatThrownBy(() -> order.cancel("Changed mind"))
           .isInstanceOf(IllegalOrderStateException.class);
   }
}
```

### # pragmatic clean architecture — đừng over-engineer

Clean Architecture là guideline, không phải religion. Trong thực tế:

**Khi nào FULL Clean Architecture:**

- Core domain phức tạp (fintech, insurance, healthcare)
- Nhiều inbound channels (REST, gRPC, messaging, scheduled)
- Khả năng swap infrastructure (đổi DB, payment provider)
- Team lớn, cần clear boundaries

**Khi nào SIMPLIFIED (3-layer đủ rồi):**

- CRUD apps đơn giản
- Prototypes, MVPs
- Team nhỏ (1-3 devs)
- Ít business logic (pass-through APIs)

**Common simplifications:**

- Domain entities CÓ THỂ dùng JPA annotations (pragmatic trade-off)
- Use Cases CÓ THỂ là `@Service` classes (Spring convenient)
- Skip mapper layer nếu domain model ≈ persistence model
- Combine inbound port + use case (interface + impl cùng class)

Mục tiêu không phải "pure Clean Architecture" — mà là **business logic testable mà không cần infrastructure**. Nếu bạn đạt được điều đó với ít layers hơn, đó cũng là thành công.

> Chỉ là những ghi chép cá nhân với hy vọng mang lại chút giá trị. Nếu thấy hữu ích, đừng ngại chia sẻ cho bạn bè & đồng nghiệp nhé!

Happy coding <Twemoji emoji="clinking-beer-mugs" /> 😎 👍🏻 🚀 🔥.
