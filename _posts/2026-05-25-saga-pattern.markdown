---
layout: post
title: "saga pattern — distributed transactions trong microservices"
date: 2026-05-25 19:29:39 +0700
categories: [Software Development]
tags: [java, software-development, saga-pattern, system-design, best-practices, vietnamese]
---

### # vấn đề: tại sao không dùng được acid transaction trong microservices?

Trong monolith, bạn wrap tất cả trong 1 `@Transactional`: tạo order, trừ tiền, giảm inventory — hoặc tất cả thành công, hoặc tất cả rollback. Database đảm bảo ACID. Cuộc sống đẹp.

Nhưng khi tách thành microservices — Order Service dùng PostgreSQL riêng, Payment Service dùng DB riêng, Inventory Service dùng DB riêng — không còn 1 transaction manager nào kiểm soát cả 3 databases. Two-Phase Commit (2PC) tồn tại nhưng trong thực tế:

- Chậm (lock resources cross-service)
- Fragile (coordinator crash = stuck locks)
- Không scale (tight coupling giữa services)
- Nhiều databases/message brokers không support

**Saga Pattern** giải quyết: thay vì 1 big transaction, chia thành chuỗi local transactions. Mỗi service commit local transaction của mình.
Nếu 1 step fail → chạy compensating transactions để undo các steps trước.

### # saga là gì?

Saga = sequence of local transactions, mỗi transaction update 1 service/database. Sau mỗi local transaction thành công,
publish event/message trigger step tiếp theo. Nếu 1 step fail, chạy compensating transactions theo thứ tự ngược.

![saga](/assets/img/blog/saga/saga.png)

**Key insight**: Saga KHÔNG đảm bảo Isolation (chữ I trong ACID). Giữa T2 và T3, inventory đã reserved nhưng payment chưa
charge — state "tạm thời inconsistent" visible cho other transactions. Đây là trade-off chấp nhận được trong distributed systems (BASE > ACID).

### # hai mô hình: choreography vs orchestration

#### # choreography — event-driven, no central coordinator

Mỗi service lắng nghe events và quyết định phản ứng. Không có ai "chỉ huy." Giống nhóm nhạc jazz — mỗi người nghe nhau và improvise.

![saga-models](/assets/img/blog/saga/saga-models.png)

```java
// Order Service — publishes event after creating order
@Service
@RequiredArgsConstructor
public class OrderService {

   private final OrderRepository orderRepository;
   private final ApplicationEventPublisher eventPublisher;
   private final RabbitTemplate rabbitTemplate;

   @Transactional
   public OrderDTO createOrder(CreateOrderRequest request) {
       Order order = Order.builder()
           .customerId(request.getCustomerId())
           .items(request.getItems())
           .status(OrderStatus.PENDING)
           .build();
       order = orderRepository.save(order);

       // Publish event → Inventory Service listens
       rabbitTemplate.convertAndSend("order.exchange", "order.created",
           new OrderCreatedEvent(order.getId(), order.getItems()));

       return toDTO(order);
   }
}

// Inventory Service — listens and reacts
@Component
@RequiredArgsConstructor
@Slf4j
public class InventoryEventListener {

   private final InventoryService inventoryService;
   private final RabbitTemplate rabbitTemplate;

   @RabbitListener(queues = "inventory.order-created")
   public void onOrderCreated(OrderCreatedEvent event) {
       try {
           inventoryService.reserve(event.getOrderId(), event.getItems());

           // Success → notify Payment Service
           rabbitTemplate.convertAndSend("order.exchange", "inventory.reserved",
               new InventoryReservedEvent(event.getOrderId(), event.getTotalAmount()));

       } catch (InsufficientStockException e) {
           // Fail → compensate: cancel order
           rabbitTemplate.convertAndSend("order.exchange", "inventory.failed",
               new InventoryFailedEvent(event.getOrderId(), e.getMessage()));
       }
   }

   // Compensation: release inventory khi payment fails
   @RabbitListener(queues = "inventory.payment-failed")
   public void onPaymentFailed(PaymentFailedEvent event) {
       inventoryService.release(event.getOrderId());
       log.info("Inventory released for order: {}", event.getOrderId());
   }
}
```

**Ưu điểm Choreography:**

- Simple: không cần central component
- Loose coupling: services chỉ biết events, không biết nhau
- Easy to add participants: thêm service mới chỉ cần subscribe event

**Nhược điểm:**

- Hard to understand flow: logic phân tán across services
- Hard to debug: "tại sao order stuck?" → phải trace events qua 5 services
- Cyclic dependencies: service A listen B, B listen A
- Difficult to add cross-cutting logic (timeout, retry cho toàn saga)

#### # orchestration — central coordinator

Một Saga Orchestrator biết toàn bộ flow, gọi từng service theo thứ tự, và handle failures. Giống conductor trong dàn nhạc — 1 người chỉ huy, mọi người follow.

![saga-orchestration](/assets/img/blog/saga/saga-orchestration.png)

```java
/**
* Saga Orchestrator — biết toàn bộ flow, điều phối step-by-step.
*
* Implement dưới dạng state machine hoặc sequential steps.
* Mỗi step: execute → success → next step / fail → compensate previous steps.
*/
@Service
@RequiredArgsConstructor
@Slf4j
public class CreateOrderSagaOrchestrator {

   private final OrderService orderService;
   private final InventoryClient inventoryClient;
   private final PaymentClient paymentClient;
   private final NotificationClient notificationClient;

   /**
    * Execute saga: từng step, rollback nếu fail.
    *
    * Flow: Create Order → Reserve Inventory → Charge Payment → Confirm
    * Compensate: Cancel Order ← Release Inventory ← Refund Payment
    */
   public OrderDTO execute(CreateOrderRequest request) {
       // Step 1: Create order (PENDING status)
       OrderDTO order = orderService.create(request);
       log.info("Saga step 1/4: Order created | orderId={}", order.getId());

       try {
           // Step 2: Reserve inventory
           inventoryClient.reserve(order.getId(), request.getItems());
           log.info("Saga step 2/4: Inventory reserved | orderId={}", order.getId());

           try {
               // Step 3: Charge payment
               paymentClient.charge(order.getId(), order.getTotalAmount(), request.getPaymentMethod());
               log.info("Saga step 3/4: Payment charged | orderId={}", order.getId());

               // Step 4: Confirm order
               orderService.confirm(order.getId());
               notificationClient.sendOrderConfirmation(order.getCustomerId(), order.getId());
               log.info("Saga step 4/4: Order confirmed | orderId={}", order.getId());

               return orderService.getById(order.getId());

           } catch (PaymentException e) {
               // Compensate step 2: release inventory
               log.warn("Saga compensation: payment failed, releasing inventory | orderId={}",
                   order.getId());
               inventoryClient.release(order.getId());
               orderService.cancel(order.getId(), "Payment failed: " + e.getMessage());
               throw new OrderCreationFailedException("Payment failed", e);
           }

       } catch (InsufficientStockException e) {
           // Compensate step 1: cancel order
           log.warn("Saga compensation: insufficient stock, cancelling order | orderId={}",
               order.getId());
           orderService.cancel(order.getId(), "Insufficient stock: " + e.getMessage());
           throw new OrderCreationFailedException("Insufficient stock", e);
       }
   }
}
```

**Ưu điểm Orchestration:**

- Easy to understand: toàn bộ flow visible trong 1 class/diagram
- Easy to debug: orchestrator logs every step
- Central error handling: timeout, retry, compensation logic tập trung
- No cyclic dependencies

**Nhược điểm:**

- Single point of failure (orchestrator service)
- Coupling: orchestrator biết tất cả participants
- Risk of "god class": orchestrator quá lớn

### # khi nào dùng cái nào?

| Tiêu chí              | Choreography           | Orchestration                |
| --------------------- | ---------------------- | ---------------------------- |
| Số services           | 2-3 (simple)           | 4+ (complex)                 |
| Flow complexity       | Linear, ít branches    | Nhiều branches, conditions   |
| Team structure        | Mỗi team own 1 service | 1 team own toàn flow         |
| Debugging needs       | Low (simple flows)     | High (complex flows)         |
| Business visibility   | Low                    | High (flow visible)          |
| Flexibility to change | High (add listener)    | Medium (change orchestrator) |

**Rule of thumb**: Bắt đầu Choreography cho simple flows (2-3 steps). Chuyển sang Orchestration khi flow > 4 steps hoặc có complex branching/compensation logic.

### # handling challenges

#### # idempotency — "charged 2 lần vì retry"

Message broker có thể deliver message nhiều lần (at-least-once). Compensating transaction cũng có thể trigger nhiều lần. Mỗi step PHẢI idempotent.

```java
@Service
public class PaymentService {

   @Transactional
   public PaymentResult charge(UUID orderId, BigDecimal amount) {
       // Check idempotency: đã charge cho order này chưa?
       Optional<Payment> existing = paymentRepository.findByOrderId(orderId);
       if (existing.isPresent()) {
           log.info("Payment already processed for order: {}", orderId);
           return existing.get().toResult();  // Return existing result, don't charge again
       }

       // First time → execute charge
       Payment payment = processCharge(orderId, amount);
       return payment.toResult();
   }
}
```

#### # timeout — "saga stuck forever"

Mỗi step cần timeout. Nếu service không respond trong X seconds → consider failed → compensate.

```java
// Orchestrator với timeout per step
CompletableFuture<InventoryResult> inventoryFuture = CompletableFuture
   .supplyAsync(() -> inventoryClient.reserve(orderId, items))
   .orTimeout(10, TimeUnit.SECONDS);  // 10s timeout

try {
   InventoryResult result = inventoryFuture.get();
} catch (TimeoutException e) {
   // Timeout = treat as failure → compensate
   orderService.cancel(orderId, "Inventory service timeout");
   throw new SagaTimeoutException("Inventory reservation timed out");
}
```

#### # semantic lock — tránh "dirty reads" giữa saga steps

Khi order đang PENDING (giữa steps), user khác không nên thấy nó ở trạng thái final. Dùng status field: `PENDING → CONFIRMED` hoặc `PENDING → CANCELLED`.

```java
public enum OrderStatus {
   PENDING,              // Saga đang chạy — chưa final
   INVENTORY_RESERVED,   // Step 2 done
   PAYMENT_CHARGED,      // Step 3 done
   CONFIRMED,            // Saga complete — happy path
   CANCELLED,            // Saga compensated — sad path
   COMPENSATION_FAILED   // Compensation cũng fail — cần manual intervention
}
```

### # saga + bpmn — process engine as orchestrator

BPMN engines (Activiti, Camunda) là natural Saga Orchestrators. Mỗi service task = 1 saga step. Error boundary events = compensation triggers. Compensation handlers = undo logic.

```xml
<!-- BPMN as Saga Orchestrator -->
<process id="createOrderSaga">
   <startEvent id="start"/>

   <!-- Step 1: Create Order -->
   <serviceTask id="createOrder" activiti:delegateExpression="${createOrderDelegate}"/>
   <boundaryEvent id="createOrderCompensation" attachedToRef="createOrder">
       <compensateEventDefinition/>
   </boundaryEvent>
   <serviceTask id="cancelOrder" isForCompensation="true"
                activiti:delegateExpression="${cancelOrderDelegate}"/>

   <!-- Step 2: Reserve Inventory -->
   <serviceTask id="reserveInventory" activiti:delegateExpression="${reserveInventoryDelegate}"/>
   <boundaryEvent id="reserveCompensation" attachedToRef="reserveInventory">
       <compensateEventDefinition/>
   </boundaryEvent>
   <serviceTask id="releaseInventory" isForCompensation="true"
                activiti:delegateExpression="${releaseInventoryDelegate}"/>

   <!-- Step 3: Charge Payment (may fail) -->
   <serviceTask id="chargePayment" activiti:delegateExpression="${chargePaymentDelegate}"/>
   <boundaryEvent id="paymentError" attachedToRef="chargePayment">
       <errorEventDefinition errorRef="PAYMENT_FAILED"/>
   </boundaryEvent>

   <!-- Happy path end -->
   <endEvent id="success"/>

   <!-- Error path: trigger compensation for all completed steps -->
   <sequenceFlow sourceRef="paymentError" targetRef="compensateAll"/>
   <intermediateThrowEvent id="compensateAll">
       <compensateEventDefinition/>
   </intermediateThrowEvent>
   <endEvent id="sagaFailed"/>
</process>
```

Lợi ích: flow visualizable trên diagram, version control, monitoring built-in, retry/timeout native. Đây là cách nhiều enterprise systems implement Saga mà không cần build orchestrator framework từ đầu.

### # tổng kết

| Aspect       | Saga                        | Distributed Transaction (2PC) |
| ------------ | --------------------------- | ----------------------------- |
| Consistency  | Eventual (BASE)             | Strong (ACID)                 |
| Availability | High                        | Low (blocking)                |
| Performance  | Good (async)                | Poor (locks)                  |
| Complexity   | Higher (compensation logic) | Lower (framework handles)     |
| Scalability  | High                        | Limited                       |
| Use case     | Microservices               | Monolith/tightly-coupled      |

**Saga là trade-off**: bạn đổi strong consistency lấy availability và scalability. Compensation logic phức tạp hơn rollback, nhưng system resilient hơn nhiều. Trong microservices world, đây là accepted standard — không phải workaround.

> Chỉ là những ghi chép cá nhân với hy vọng mang lại chút giá trị. Nếu thấy hữu ích, đừng ngại chia sẻ cho bạn bè & đồng nghiệp nhé!

Happy coding <Twemoji emoji="clinking-beer-mugs" /> 😎 👍🏻 🚀 🔥.
