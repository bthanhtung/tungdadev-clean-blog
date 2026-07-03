---
layout: post
title: "rabbitmq pattern"
date: 2025-11-13 19:29:39 +0700
categories: [Software Development]
tags: [java, software-development, rabbitmq, best-practices, vietnamese]
---

Trong thế giới Microservices, việc phân tách các service (decoupling) là nguyên tắc sống còn. Khi hệ thống phát triển, sự kết nối đồng bộ (synchronous) qua REST hay gRPC dần bộc lộ những điểm yếu chí mạng về hiệu suất và khả năng chịu lỗi (fault tolerance). Đó là lúc Event-Driven Architecture (EDA) lên ngôi, và RabbitMQ chính là một trong những "người vận chuyển" đáng tin cậy nhất.

Bài viết này không dừng lại ở mức "Hello World". Chúng ta sẽ cùng mổ xẻ những pattern thực chiến, cách cấu hình Spring AMQP cho môi trường production, và giải quyết những bài toán hóc búa như tính toàn vẹn dữ liệu (Data Consistency), xử lý message trùng lặp, và kiến trúc Saga cho Distributed Transactions.

### # exchange types

Trái tim của RabbitMQ không nằm ở Queue, mà nằm ở Exchange. Việc chọn đúng loại Exchange quyết định trực tiếp đến tính mềm dẻo của kiến trúc routing.

| Type    | Routing Logic                                       | Use Case                                                          |
| ------- | --------------------------------------------------- | ----------------------------------------------------------------- |
| Direct  | Exact routing key match                             | Point-to-point, task queue                                        |
| Topic   | Wildcard routing key (`*` = 1 word, `#` = 0+ words) | Selective subscription (vd: order.\* để nhận mọi event về order). |
| Fanout  | Broadcast to all bound queues                       | Notifications, events                                             |
| Headers | Match on message headers                            | Complex routing rules                                             |

```java
// Direct exchange — route by exact key
@Bean
public DirectExchange orderExchange() {
   return new DirectExchange("order.exchange");
}

@Bean
public Queue orderCreatedQueue() {
   return QueueBuilder.durable("order.created.queue")
       .withArgument("x-dead-letter-exchange", "dlx.exchange")
       .withArgument("x-dead-letter-routing-key", "order.created.dlq")
       .build();
}

@Bean
public Binding orderBinding() {
   return BindingBuilder.bind(orderCreatedQueue())
       .to(orderExchange())
       .with("order.created"); // routing key
}

// Topic exchange — wildcard routing
@Bean
public TopicExchange eventExchange() {
   return new TopicExchange("event.exchange");
}

// Binds to "order.*" → matches order.created, order.cancelled, etc.
@Bean
public Binding auditBinding() {
   return BindingBuilder.bind(auditQueue())
       .to(eventExchange())
       .with("order.*");
}

// Fanout — all consumers receive
@Bean
public FanoutExchange notificationExchange() {
   return new FanoutExchange("notification.exchange");
}
```

### # producer patterns

Một lỗi sơ đẳng khi làm việc với message broker là fire-and-forget (bắn đi và quên mất) mà không có cơ chế xác nhận. Ở môi trường high-load, network chập chờn hoặc broker bị nghẽn có thể khiến message "bốc hơi".

#### # basic publish

```java
@Service
@RequiredArgsConstructor
public class OrderEventProducer {
   private final RabbitTemplate rabbitTemplate;

   public void publishOrderCreated(Order order) {
       OrderCreatedEvent event = OrderCreatedEvent.builder()
           .orderId(order.getId())
           .timestamp(Instant.now())
           .build();

       rabbitTemplate.convertAndSend(
           "order.exchange",      // exchange
           "order.created",       // routing key
           event                  // message (auto-serialized via MessageConverter)
       );
   }
}
```

#### # with correlation and headers

```java
public void publishWithHeaders(Object payload, String traceId) {
   rabbitTemplate.convertAndSend("exchange", "routing.key", payload, message -> {
       MessageProperties props = message.getMessageProperties();
       props.setCorrelationId(traceId);
       props.setHeader("X-Source-Service", "order-service");
       props.setContentType("application/json");
       props.setDeliveryMode(MessageDeliveryMode.PERSISTENT);
       return message;
   });
}
```

#### # publisher confirms (reliability)

Để đảm bảo reliability, chúng ta cần kích hoạt cơ chế Publisher Confirms (Broker xác nhận đã nhận được message) và Publisher Returns (Message không thể route đến bất kỳ queue nào).

```java
// Kích hoạt trong application.yml
// spring.rabbitmq.publisher-confirm-type: correlated
// spring.rabbitmq.publisher-returns: true

@Bean
public RabbitTemplate rabbitTemplate(ConnectionFactory factory) {
   RabbitTemplate template = new RabbitTemplate(factory);

   // Xác nhận từ Broker
   template.setConfirmCallback((correlationData, ack, cause) -> {
       if (!ack) {
           log.error("Cảnh báo: Message chưa được confirm bởi Broker. Lý do: {}", cause);
           // Thực thi logic Retry hoặc lưu vào Database (Outbox/Failed Events table)
       }
   });

   // Bắt lỗi Unroutable messages
   template.setReturnsCallback(returned -> {
       log.error("Message bị trả về: routingKey={}, replyText={}",
           returned.getRoutingKey(), returned.getReplyText());
   });
   return template;
}
```

### # consumer patterns

Việc config consumer quyết định hệ thống của bạn xử lý nhanh đến đâu và có làm mất message khi app crash đột ngột hay không.

#### # @RabbitListener

```java
@Component
@Slf4j
public class OrderConsumer {

   // Simple consumer
   @RabbitListener(queues = "order.created.queue")
   public void handleOrderCreated(OrderCreatedEvent event) {
       log.info("Processing order: {}", event.getOrderId());
       processOrder(event);
   }

   // With message metadata
   @RabbitListener(queues = "order.created.queue")
   public void handleWithMetadata(OrderCreatedEvent event,
                                  @Header(AmqpHeaders.DELIVERY_TAG) long tag,
                                  @Header(AmqpHeaders.CORRELATION_ID) String correlationId,
                                  Channel channel) {
       log.info("[traceId={}] Processing order: {}", correlationId, event.getOrderId());
       processOrder(event);
   }

   // Batch consumer
   @RabbitListener(queues = "batch.queue", containerFactory = "batchListenerFactory")
   public void handleBatch(List<OrderCreatedEvent> events) {
       log.info("Processing batch of {} events", events.size());
       events.forEach(this::processOrder);
   }
}
```

#### # manual acknowledgment

Thay vì để Spring tự động ACK ngay khi method được gọi (rất nguy hiểm nếu có Exception xảy ra giữa chừng), hãy dùng Manual ACK.

```java
@Bean
public SimpleRabbitListenerContainerFactory manualAckFactory(ConnectionFactory factory) {
   SimpleRabbitListenerContainerFactory f = new SimpleRabbitListenerContainerFactory();
   f.setConnectionFactory(factory);
   f.setAcknowledgeMode(AcknowledgeMode.MANUAL); // Kiểm soát hoàn toàn vòng đời message
   f.setPrefetchCount(10); // Không lấy quá 10 messages cùng lúc để tránh ngộp memory
   return f;
}

@RabbitListener(queues = "critical.queue", containerFactory = "manualAckFactory", concurrency = "5-20")
public void handleCriticalTask(Message message, Channel channel) throws IOException {
   long deliveryTag = message.getMessageProperties().getDeliveryTag();
   try {
       // Thực thi Business Logic
       processData(message);

       // Xác nhận thành công
       channel.basicAck(deliveryTag, false);
   } catch (RetryableBusinessException e) {
       // Lỗi có thể thử lại -> Requeue
       channel.basicNack(deliveryTag, false, true);
   } catch (Exception e) {
       // Lỗi nghiêm trọng (NPE, Invalid Data) -> Reject, đẩy thẳng xuống DLQ
       channel.basicNack(deliveryTag, false, false);
   }
}
```

Thuộc tính concurrency = "5-20" giúp Consumer tự động scale số lượng thread từ 5 lên tối đa 20 tùy thuộc vào lượng message đang chờ trong queue, tối ưu hóa tài nguyên hệ thống.

#### # concurrency

```java
// Multiple threads consuming from same queue
@RabbitListener(queues = "high-volume.queue", concurrency = "5-20")
public void handleConcurrent(Event event) {
   // 5 consumers min, scale up to 20 under load
}
```

### # dead letter queue (dlq)

Không có hệ thống nào hoàn hảo. Khi một message thất bại quá số lần quy định, nó cần được cách ly vào Dead Letter Queue để không làm block các message khác, đồng thời cho phép kỹ sư phân tích sau đó.

#### # configuration

```java
@Bean
public Queue mainQueue() {
   return QueueBuilder.durable("order.queue")
       .withArgument("x-dead-letter-exchange", "dlx.exchange")
       .withArgument("x-dead-letter-routing-key", "order.dlq")
       .withArgument("x-message-ttl", 60000) // optional: message TTL
       .build();
}

@Bean
public DirectExchange dlxExchange() {
   return new DirectExchange("dlx.exchange");
}

@Bean
public Queue dlq() {
   return QueueBuilder.durable("order.dlq").build();
}

@Bean
public Binding dlqBinding() {
   return BindingBuilder.bind(dlq()).to(dlxExchange()).with("order.dlq");
}
```

#### # retry with backoff

Cấu hình Spring Retry kết hợp cùng Recoverer:

```java
@Bean
public SimpleRabbitListenerContainerFactory retryFactory(ConnectionFactory factory) {
   SimpleRabbitListenerContainerFactory f = new SimpleRabbitListenerContainerFactory();
   f.setConnectionFactory(factory);
   f.setAdviceChain(RetryInterceptorBuilder.stateless()
       .maxAttempts(3)
       .backOffOptions(1000, 2.0, 10000) // Backoff chiến lược: 1s, 2s, 4s...
       .recoverer(new RejectAndDontRequeueRecoverer()) // Hết 3 lần -> Bắn xuống DLQ
       .build());
   return f;
}
```

#### # dlq reprocessing

Bạn có thể xây dựng một CronJob để tự động reprocess các message trong DLQ sau khi hệ thống đã ổn định lại:

```java
@Scheduled(fixedDelay = 300000) // Chạy mỗi 5 phút
public void reprocessDlq() {
   Message msg;
   int count = 0;
   // Lấy tối đa 100 messages mỗi lần chạy để tránh thắt nút cổ chai
   while ((msg = rabbitTemplate.receive("order.dlq")) != null && count < 100) {
       try {
           rabbitTemplate.send("order.exchange", "order.created", msg);
           count++;
       } catch (Exception e) {
           log.error("Reprocess thất bại", e);
           break;
       }
   }
   if (count > 0) log.info("Đã khôi phục thành công {} messages từ DLQ", count);
}
```

### # idempotent consumer

RabbitMQ (và hầu hết các Message Broker) chỉ đảm bảo "At-least-once delivery" (giao ít nhất một lần). Nghĩa là Consumer CÓ THỂ nhận một message 2 lần (do network chập chờn, app crash trước khi kịp gửi ACK).

Giải pháp bắt buộc là biến Consumer thành Idempotent (Xử lý 1 hay N lần đều ra cùng một kết quả).

#### # sử dụng redis (hiệu năng cao, độ trễ thấp)

```java
@Component
public class IdempotentConsumer {
   private final StringRedisTemplate redis;
   private static final Duration DEDUP_TTL = Duration.ofHours(24);

   @RabbitListener(queues = "payment.queue")
   public void handle(PaymentEvent event) {
       String dedupKey = "processed:payment:" + event.getEventId();

       // Atomic operation: Chỉ set thành công nếu key chưa tồn tại
       Boolean isNew = redis.opsForValue().setIfAbsent(dedupKey, "1", DEDUP_TTL);
       if (Boolean.FALSE.equals(isNew)) {
           log.warn("Bỏ qua duplicate message: {}", event.getEventId());
           return;
       }

       try {
           processPayment(event);
       } catch (Exception e) {
           redis.delete(dedupKey); // Xóa key để có thể retry nếu thực sự xảy ra lỗi hệ thống
           throw e;
       }
   }
}
```

#### # sử dụng database unique constraint

Phù hợp khi cần tính nhất quán tuyệt đối, thường đi kèm với việc cập nhật trạng thái Entity.

```java
@Transactional
public void handleIdempotent(PaymentEvent event) {
   if (processedEventRepo.existsByEventId(event.getEventId())) {
       return; // already processed
   }

   processPayment(event);

   processedEventRepo.save(new ProcessedEvent(event.getEventId(), Instant.now()));
}
```

### # message ordering

Nếu bạn có nhiều hơn 1 consumer lắng nghe trên 1 queue (concurrency > 1), RabbitMQ không đảm bảo thứ tự xử lý.
Để giải quyết việc các message của cùng một Entity phải được xử lý tuần tự (ví dụ: OrderCreated phải chạy trước OrderUpdated), ta sử dụng Consistent Hashing Exchange.

Bằng cách này, mọi event có chung một tham số (ví dụ: orderId) sẽ luôn được hash và đẩy về chính xác một queue/consumer cố định.

1. **Single consumer**: `concurrency = "1"` — simple but no parallelism
2. **Consistent hashing exchange**: Route same entity to same queue
3. **Sequence number**: Consumer reorders or rejects out-of-order messages

```java
// Consistent hash — same orderId always goes to same queue/consumer
@Bean
public CustomExchange consistentHashExchange() {
   return new CustomExchange("order.hash.exchange", "x-consistent-hash", true, false);
}

// Binding with weight
@Bean
public Binding hashBinding1() {
   return BindingBuilder.bind(queue1())
       .to(consistentHashExchange())
       .with("1") // weight
       .noargs();
}
```

### # transactional messaging

Vấn đề lớn nhất của EDA (Dual-Write Problem): Bạn lưu Data vào Database thành công, nhưng tiến trình chết ngay trước khi kịp bắn Event vào RabbitMQ. Hệ quả: Hệ thống xung quanh không hề biết Data đã được tạo.

#### # outbox pattern

Gắn chặt việc lưu Data và lưu Event vào chung một Database Transaction.

```java
// 1. Core Logic (Write Side)
@Transactional
public Order handleCreateOrderCommand(CreateOrderCommand cmd) {
   // Lưu Aggregate Root
   Order order = orderRepo.save(new Order(cmd));

   // Lưu Event vào Outbox table trong CÙNG MỘT transaction
   outboxRepo.save(OutboxEvent.builder()
       .aggregateId(order.getId().toString())
       .eventType("ORDER_CREATED")
       .payload(objectMapper.writeValueAsString(order))
       .status(OutboxStatus.PENDING)
       .build());

   return order;
}

// 2. Message Relay Worker
@Scheduled(fixedDelay = 1000)
@Transactional
public void publishPendingEvents() {
   List<OutboxEvent> events = outboxRepo.findTop100ByStatus(OutboxStatus.PENDING);
   for (OutboxEvent event : events) {
       try {
           rabbitTemplate.convertAndSend("domain.events.exchange", event.getEventType(), event.getPayload());
           event.setStatus(OutboxStatus.PUBLISHED);
       } catch (Exception e) {
           log.error("Không thể publish event: {}", event.getId());
       }
   }
   outboxRepo.saveAll(events);
}
```

Đây là nền tảng vững chắc để triển khai Event Sourcing và cập nhật Query-side Model trong kiến trúc CQRS.

### # saga pattern (distributed transactions)

Khi một process trải dài qua nhiều service, ta không thể dùng ACID transaction. Saga Pattern giúp quản lý luồng bằng việc chia nhỏ thành các local transaction, đi kèm với hành động "bù đắp" (Compensation) nếu có bước thất bại.

#### # choreography-based

```java
// Service A: Thanh toán thành công -> Phát tín hiệu xác nhận đơn
@RabbitListener(queues = "payment.confirmed.queue")
public void onPaymentConfirmed(PaymentConfirmedEvent event) {
   orderService.confirmOrder(event.getOrderId());
   rabbitTemplate.convertAndSend("saga.exchange", "order.confirmed",
       new OrderConfirmedEvent(event.getOrderId()));
}

// Service A: Thanh toán thất bại -> Kích hoạt Compensating Transaction (Hoàn tác)
@RabbitListener(queues = "payment.failed.queue")
public void onPaymentFailed(PaymentFailedEvent event) {
   orderService.cancelOrder(event.getOrderId());
   rabbitTemplate.convertAndSend("saga.exchange", "order.cancelled",
       new OrderCancelledEvent(event.getOrderId()));
}
```

Choreography rất dễ cài đặt ở giai đoạn đầu. Tuy nhiên, khi luồng nghiệp vụ trở nên phức tạp với hàng chục node, việc theo dõi (trace) sẽ trở thành ác mộng. Ở quy mô lớn, Orchestration-based Saga (Sử dụng một điều phối viên trung tâm - Orchestrator quản lý state machine) sẽ là tiêu chuẩn của các hệ thống hạng nặng.

### # messageConverter configuration

```java
@Bean
public Jackson2JsonMessageConverter messageConverter() {
   ObjectMapper mapper = new ObjectMapper();
   mapper.registerModule(new JavaTimeModule());
   mapper.configure(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES, false);
   return new Jackson2JsonMessageConverter(mapper);
}

@Bean
public RabbitTemplate rabbitTemplate(ConnectionFactory factory, MessageConverter converter) {
   RabbitTemplate template = new RabbitTemplate(factory);
   template.setMessageConverter(converter);
   return template;
}
```

### # configuration (application.yml)

```yaml
spring:
  rabbitmq:
    host: localhost
    port: 5672
    username: guest
    password: guest
    virtual-host: /
    publisher-confirm-type: correlated
    publisher-returns: true
    listener:
      simple:
        acknowledge-mode: auto
        prefetch: 10
        retry:
          enabled: true
          max-attempts: 3
          initial-interval: 1000ms
          multiplier: 2.0
          max-interval: 10000ms
```

### # decision matrix

| Scenario               | Exchange | Ack Mode     | Retry     | Idempotent       |
| ---------------------- | -------- | ------------ | --------- | ---------------- |
| Task queue (workers)   | Direct   | Auto + retry | Yes (3x)  | Yes              |
| Event broadcast        | Fanout   | Auto         | No        | Optional         |
| Selective subscription | Topic    | Auto         | Yes       | Yes              |
| Critical payment       | Direct   | Manual       | Yes (DLQ) | Mandatory        |
| Audit logging          | Fanout   | Auto         | Yes       | No (append-only) |
| Saga orchestration     | Direct   | Manual       | Yes (DLQ) | Mandatory        |

Việc làm chủ RabbitMQ và các Messaging Patterns không chỉ là hiểu về API của nó, mà là hiểu về cách thiết kế một hệ thống chịu lỗi (Resilient System). Khi kết hợp nhuần nhuyễn Outbox Pattern, DLQ và Idempotency, bạn có thể tự tin vận hành một hệ thống kiến trúc sạch, nhất quán dữ liệu mà không lo lắng về tính toàn vẹn ngay cả khi hạ tầng gặp sự cố.

> Chỉ là những ghi chép cá nhân với hy vọng mang lại chút giá trị. Nếu thấy hữu ích, đừng ngại chia sẻ cho bạn bè & đồng nghiệp nhé!

Happy coding <Twemoji emoji="clinking-beer-mugs" /> 😎 👍🏻 🚀 🔥.
