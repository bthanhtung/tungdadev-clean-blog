---
layout: post
title: "observability & production monitoring"
date: 2025-06-07 19:29:39 +0700
categories: [Software Development]
tags: [java, software-development, best-practices, vietnamese]
---

Đẩy code lên production chỉ là điểm khởi đầu. Trong các hệ thống phân tán phức tạp - nơi dữ liệu chảy qua hàng loạt service,
event bus (như kafka hay rabbitmq) và database - việc thiếu đi khả năng quan sát `(Observability)` giống như bạn đang lái xe
tốc độ cao trên cao tốc vào ban đêm mà tắt đèn pha.

Là những Engineer, chúng ta không chỉ xây dựng hệ thống, chúng ta phải giữ cho chúng sống sót, ổn định và tự phục hồi
dưới áp lực thực tế. Bài viết này sẽ đi sâu vào nghệ thuật "thấu thị" hệ thống thông qua việc `instrument` các Spring Boot services,
biến những hộp đen (black box) thành những thực thể minh bạch, dễ dàng đo lường và chẩn đoán.

### # three pillars

Observability không phải là một công cụ mà là một thuộc tính của hệ thống. Thuộc tính này được xây dựng trên ba trụ cột chính, bổ trợ chặt chẽ cho nhau:

![observability-structure]({{ site.baseurl }}/assets/img/blog/observability-structure.png)

Quy trình gỡ lỗi tiêu chuẩn: Cảnh báo từ Metrics → Dùng Traces để khoanh vùng service/hàm gặp vấn đề → Đọc Logs tại điểm đó để tìm nguyên nhân gốc rễ (Root Cause).

### # structured logging

Log text thuần túy chỉ dành cho con người đọc `(human-readable)`. Ở scale production, log phải dành cho máy đọc `(machine-parsable)`.

#### # pattern

Hãy từ bỏ thói quen nối chuỗi `(string concatenation)` và bắt đầu tư duy theo hướng `Key-Value`.

```java
// GOOD: structured, traceable, searchable
log.info("[traceId={}] | event=orderCreated | orderId={} | userId={} | amount={}",
   RequestContext.getRequestId(), order.getId(), userId, amount);

// GOOD: separate data fields by |
log.info("[traceId={}] | event=paymentProcessed | transId={} | status={} | duration={}ms",
   traceId, transactionId, status, duration);

// BAD: unstructured, hard to parse
log.info("Order " + order.getId() + " created by user " + userId);

// BAD: logging entire objects (PII risk, noise)
log.info("Processing request: {}", requestDTO); // ← dumps all fields
```

#### # log levels guide

| Level | When                                | Example                                            |
| ----- | ----------------------------------- | -------------------------------------------------- |
| ERROR | System cannot function, needs human | DB connection lost, OOM, critical service down     |
| WARN  | Unexpected but recoverable          | Retry succeeded, fallback used, slow query         |
| INFO  | Business events, state changes      | Order created, user logged in, deployment complete |
| DEBUG | Developer troubleshooting           | Method entry/exit, intermediate values             |
| TRACE | Very detailed flow                  | SQL parameters, full request/response bodies       |

#### # production log rules

- **INFO** level in production (DEBUG only via dynamic level change)
- KHÔNG log full DTO/entity objects (PII, verbose)
- KHÔNG log passwords, tokens, personal data
- Luôn include traceId trong mọi log line
- Separate data bằng `|` cho structured parsing
- Log request IN và response OUT cho mỗi service boundary

#### # mdc (mapped diagnostic context)

Trong một flow xử lý đồng thời (concurrent), làm sao để gom nhóm các log của cùng một user request?

→ Đáp án là `MDC`. Set `MDC` một lần tại `Filter/Interceptor` và mọi `log lines` trong `thread` đó sẽ tự động kế thừa.

```java
// Set once in filter → available in all logs within request
MDC.put("traceId", requestId);
MDC.put("userId", jwt.getSubject());
MDC.put("service", "order-service");

// Log4j2 pattern includes MDC automatically
// %X{traceId} %X{userId} trong log pattern
```

#### # log4j2 configuration

```xml
<Configuration>
   <Properties>
       <Property name="LOG_PATTERN">
           %d{yyyy-MM-dd HH:mm:ss.SSS} [%pid] [%t] %-5level %logger{36}.%M(%L) - %msg%n
       </Property>
   </Properties>

   <Appenders>
       <!-- Async appender for performance -->
       <RollingFile name="File" fileName="logs/application.log"
                    filePattern="logs/application-%d{yyyy-MM-dd}-%i.log">
           <PatternLayout pattern="${LOG_PATTERN}"/>
           <Policies>
               <TimeBasedTriggeringPolicy interval="1"/>
               <SizeBasedTriggeringPolicy size="100MB"/>
           </Policies>
           <DefaultRolloverStrategy max="30"/>
       </RollingFile>
   </Appenders>

   <Loggers>
       <AsyncRoot level="info">
           <AppenderRef ref="File"/>
       </AsyncRoot>

       <!-- Reduce noise from frameworks -->
       <Logger name="org.hibernate.SQL" level="debug"/> <!-- show SQL in dev -->
       <Logger name="org.springframework.web" level="warn"/>
       <Logger name="com.netflix.eureka" level="warn"/>
   </Loggers>
</Configuration>
```

### # metrics (micrometer + prometheus)

Nếu `Logs` cung cấp góc nhìn vi mô (micro), thì `Metrics` cung cấp góc nhìn vĩ mô (macro).
Chúng ta sử dụng `Micrometer` (như SLF4J dành cho metrics) kết hợp với `Prometheus`.

#### # spring boot actuator setup

`Spring Boot Actuator` đã cung cấp sẵn các metrics nền tảng (JVM, HTTP, HikariCP). Nhưng để thực sự thấu hiểu ứng dụng, bạn cần đo lường Business Logic:

```yaml
management:
  endpoints:
    web:
      exposure:
        include: health, info, prometheus, metrics
  endpoint:
    health:
      show-details: when-authorized
  metrics:
    tags:
      application: ${spring.application.name}
      environment: ${spring.profiles.active:dev}
    export:
      prometheus:
        enabled: true
```

#### # built-in metrics (auto-collected)

```
# JVM
jvm_memory_used_bytes{area="heap"}
jvm_threads_live_threads
jvm_gc_pause_seconds

# HTTP
http_server_requests_seconds_count{method="GET", uri="/api/orders", status="200"}
http_server_requests_seconds_sum
http_server_requests_seconds_max

# Database
hikaricp_connections_active
hikaricp_connections_idle
hikaricp_connections_pending

# Cache
cache_gets_total{cache="users", result="hit"}
cache_gets_total{cache="users", result="miss"}
```

#### # custom business metrics

```java
@Service
@RequiredArgsConstructor
public class OrderService {
   private final MeterRegistry meterRegistry;
   private final Counter orderCreatedCounter;
   private final Timer orderProcessingTimer;

   public OrderService(MeterRegistry registry) {
       this.meterRegistry = registry;
       this.orderCreatedCounter = Counter.builder("orders.created")
           .description("Total orders created")
           .tag("service", "order-service")
           .register(registry);
       this.orderProcessingTimer = Timer.builder("orders.processing.duration")
           .description("Order processing time")
           .publishPercentiles(0.5, 0.95, 0.99)
           .register(registry);
   }

   public Order createOrder(CreateOrderDTO dto) {
       return orderProcessingTimer.record(() -> {
           Order order = processOrder(dto);
           orderCreatedCounter.increment();
           meterRegistry.counter("orders.created.by_type",
               "type", order.getType().name()).increment();
           return order;
       });
   }
}
```

#### # metric types

| Type                 | Use Case                  | Example                                             |
| -------------------- | ------------------------- | --------------------------------------------------- |
| Counter              | Events that only increase | Requests received, errors occurred, orders created  |
| Gauge                | Current value (up/down)   | Active connections, queue size, memory used         |
| Timer                | Duration of events        | Request latency, DB query time, processing duration |
| Distribution Summary | Distribution of values    | Request sizes, payload sizes                        |

```java
// Counter — only goes up
Counter.builder("emails.sent")
   .tag("type", "confirmation")
   .register(registry)
   .increment();

// Gauge — current state
Gauge.builder("queue.size", queue, Queue::size)
   .register(registry);

// Timer — measure duration
Timer.builder("db.query.duration")
   .tag("query", "findByStatus")
   .publishPercentiles(0.5, 0.95, 0.99)
   .register(registry);

// Distribution Summary — value distribution
DistributionSummary.builder("http.request.size")
   .baseUnit("bytes")
   .publishPercentiles(0.5, 0.95)
   .register(registry)
   .record(requestBody.length);
```

#### # custom health indicators

```java
@Component
public class ExternalServiceHealthIndicator implements HealthIndicator {

   @Override
   public Health health() {
       try {
           boolean reachable = checkExternalService();
           if (reachable) {
               return Health.up()
                   .withDetail("service", "payment-gateway")
                   .withDetail("responseTime", "45ms")
                   .build();
           }
           return Health.down()
               .withDetail("service", "payment-gateway")
               .withDetail("error", "Connection refused")
               .build();
       } catch (Exception e) {
           return Health.down(e).build();
       }
   }
}
```

### # distributed tracing (opentelemetry)

Khi hệ thống áp dụng kiến trúc Microservices, một request từ `Client` có thể đi qua API Gateway → Service A → RabbitMQ → Service B.
Việc truy vết thủ công là bất khả thi.

`OpenTelemetry (OTel)` và chuẩn `W3C Trace Context` sinh ra để giải quyết việc này.
Hệ thống sẽ gán một `TraceId` duy nhất cho toàn bộ vòng đời request và các `SpanId` cho từng nấc xử lý (hop).

#### # configuration

```yaml
management:
  tracing:
    sampling:
      probability: 0.1 # 10% in prod, 1.0 in dev
    propagation:
      type: w3c # W3C TraceContext headers

# Export to collector
otel:
  exporter:
    otlp:
      endpoint: http://otel-collector:4318
  resource:
    attributes:
      service.name: ${spring.application.name}
      deployment.environment: ${spring.profiles.active:dev}
```

Với cấu hình này, Spring Boot tự động "cấy" context vào HTTP Headers, Kafka/RabbitMQ headers, JDBC queries và cả các hàm đánh `@Async`.
Việc của bạn là đảm bảo truyền đúng `TraceContext` nếu có gọi các giao thức custom nằm ngoài hỗ trợ mặc định của framework.

#### # auto-instrumentation (zero-code)

Spring Boot 3.2 + Micrometer Tracing auto-instruments:

- HTTP requests (inbound + outbound)
- JDBC queries
- Redis commands
- RabbitMQ publish/consume
- gRPC calls
- `@Async` methods
- `@Scheduled` tasks

#### # manual span creation

```java
@Service
@RequiredArgsConstructor
public class PaymentService {
   private final ObservationRegistry observationRegistry;

   public PaymentResult processPayment(PaymentRequest request) {
       return Observation.createNotStarted("payment.process", observationRegistry)
           .lowCardinalityKeyValue("payment.type", request.getType().name())
           .highCardinalityKeyValue("payment.id", request.getId().toString())
           .observe(() -> {
               // Auto-creates span with timing
               validate(request);
               PaymentResult result = callGateway(request);
               persistResult(result);
               return result;
           });
   }
}

// Or with Tracer directly
@Service
@RequiredArgsConstructor
public class ImportService {
   private final Tracer tracer;

   public void importBatch(List<Record> records) {
       Span span = tracer.nextSpan().name("import.batch").start();
       try (Tracer.SpanInScope ws = tracer.withSpan(span)) {
           span.tag("batch.size", String.valueOf(records.size()));
           records.forEach(this::importRecord);
           span.tag("batch.result", "success");
       } catch (Exception e) {
           span.error(e);
           throw e;
       } finally {
           span.end();
       }
   }
}
```

#### # trace propagation across services

![observability-trace-propagation]({{ site.baseurl }}/assets/img/blog/observability-trace-propagation.png)

```java
// HTTP client — auto-propagated via WebClient/RestClient instrumentation
// RabbitMQ — propagated via message headers
// Manual propagation (e.g., custom protocol):
String traceParent = tracer.currentSpan().context().traceId();
// Include in outgoing request header
```

### # alerting strategy

Có `Metrics` tốt mà `Alert` tồi (báo động giả liên tục) sẽ dẫn đến hội chứng "Alert Fatigue" (chai lỳ với cảnh báo).

#### # alert severity levels

| Severity      | Response Time     | Example                                                       |
| ------------- | ----------------- | ------------------------------------------------------------- |
| P1 (Critical) | < 5 min           | Service down, data loss, auth broken                          |
| P2 (High)     | < 30 min          | High error rate (>5%), latency spike, DB connection exhausted |
| P3 (Medium)   | < 4 hours         | Elevated error rate (>1%), queue growing, memory trending up  |
| P4 (Low)      | Next business day | Disk usage >70%, deprecated API still in use                  |

#### # key alerts (prometheus/grafana)

```yaml
# Error rate > 5% for 5 minutes
- alert: HighErrorRate
 expr: |
   sum(rate(http_server_requests_seconds_count{status=~"5.."}[5m]))
   / sum(rate(http_server_requests_seconds_count[5m])) > 0.05
 for: 5m
 labels:
   severity: P2

# P95 latency > 2 seconds
- alert: HighLatency
 expr: |
   histogram_quantile(0.95, rate(http_server_requests_seconds_bucket[5m])) > 2
 for: 5m
 labels:
   severity: P2

# DB connection pool exhausted
- alert: DbPoolExhausted
 expr: hikaricp_connections_pending > 0
 for: 2m
 labels:
   severity: P1

# Service health check down
- alert: ServiceDown
 expr: up{job="order-service"} == 0
 for: 1m
 labels:
   severity: P1

# JVM heap > 85%
- alert: HighMemoryUsage
 expr: |
   jvm_memory_used_bytes{area="heap"}
   / jvm_memory_max_bytes{area="heap"} > 0.85
 for: 10m
 labels:
   severity: P3

# Queue growing (messages not consumed)
- alert: QueueBacklog
 expr: rabbitmq_queue_messages > 10000
 for: 10m
 labels:
   severity: P3
```

### # production dashboards (grafana)

#### # red method (request-focused)

| Metric   | Query                                                                     | Purpose         |
| -------- | ------------------------------------------------------------------------- | --------------- |
| Rate     | `sum(rate(http_server_requests_seconds_count[5m]))`                       | Traffic volume  |
| Errors   | `sum(rate(http_server_requests_seconds_count{status=~"5.."}[5m]))`        | Error detection |
| Duration | `histogram_quantile(0.95, rate(http_server_requests_seconds_bucket[5m]))` | Latency         |

#### # use method (resource-focused)

| Resource | Utilization             | Saturation        | Errors              |
| -------- | ----------------------- | ----------------- | ------------------- |
| CPU      | `process_cpu_usage`     | Load average      | —                   |
| Memory   | `jvm_memory_used / max` | GC frequency      | OOM events          |
| DB Pool  | `active / max`          | `pending > 0`     | Connection timeouts |
| Threads  | `live_threads / max`    | Thread pool queue | Rejected tasks      |
| Disk     | `disk_used / total`     | I/O wait          | I/O errors          |

#### # essential dashboard panels

![observability-essential-dashboard]({{ site.baseurl }}/assets/img/blog/observability-essential-dashboard.png)

### # production debugging

#### # troubleshooting workflow

![observability-troubleshooting-workflow]({{ site.baseurl }}/assets/img/blog/observability-troubleshooting-workflow.png)

#### # dynamic log level (runtime change)

```bash
# Change log level without restart via Actuator
curl -X POST http://service:8080/actuator/loggers/com.vpbank.internal \
 -H 'Content-Type: application/json' \
 -d '{"configuredLevel": "DEBUG"}'

# Revert
curl -X POST http://service:8080/actuator/loggers/com.vpbank.internal \
 -H 'Content-Type: application/json' \
 -d '{"configuredLevel": "INFO"}'
```

#### # thread dump (deadlock/hang detection)

```bash
# Via Actuator
curl http://service:8080/actuator/threaddump

# Look for:
# - BLOCKED threads (deadlock)
# - WAITING on same lock (contention)
# - Many threads in same stack (bottleneck)
```

#### # heap dump (memory leak)

```bash
# Via Actuator
curl -o heapdump.hprof http://service:8080/actuator/heapdump

# Analyze with Eclipse MAT or VisualVM
# Look for:
# - Largest retained objects
# - Objects growing over time
# - Unclosed resources (connections, streams)
```

### # performance baselines

#### # establish per service

```
Baseline metrics (measure during normal load):
- P50 latency: 15ms
- P95 latency: 45ms
- P99 latency: 120ms
- Error rate: < 0.1%
- Throughput: 500 req/s
- DB pool utilization: 30%
- Heap usage: 60%
- GC pause: < 50ms

Alert when:
- P95 > 2x baseline (45ms → alert at 90ms)
- Error rate > 50x baseline (0.1% → alert at 5%)
- Pool utilization > 80%
- Heap > 85%
```

### # sli/slo framework

#### # service level indicators (sli)

```
Availability SLI = successful requests / total requests
Latency SLI = requests < threshold / total requests
Throughput SLI = requests served within capacity / total requests
```

#### # service level objectives (slo)

Thay vì cố gắng đạt `100% Uptime` (điều phi thực tế và tốn kém), các team kỹ thuật hàng đầu sử dụng `Service Level Objectives (SLO)`.
| Service | Availability | Latency (P95) | Error Budget |
| --------------- | ------------ | ------------- | --------------------- |
| API Gateway | 99.9% | < 200ms | 43 min/month downtime |
| Order Service | 99.95% | < 500ms | 21 min/month |
| Payment Service | 99.99% | < 1s | 4 min/month |
| Report Engine | 99.5% | < 30s | 3.6 hours/month |

#### # error budget policy

```
Error budget remaining > 50%: Ship freely, experiment
Error budget remaining 20-50%: Normal development, careful with risky changes
Error budget remaining < 20%: Focus on reliability, no risky deployments
Error budget exhausted: Freeze features, fix reliability issues only
```

### # checklist: instrumenting a new service

- [ ] Log4j2 configured with structured pattern
- [ ] MDC populated in request filter (traceId, userId)
- [ ] Actuator endpoints exposed (health, prometheus, info)
- [ ] Custom business metrics added (counters, timers)
- [ ] Health indicators for external dependencies
- [ ] Tracing configured (sampling rate appropriate for env)
- [ ] Grafana dashboard created (RED + USE panels)
- [ ] Alerts configured (P1, P2 at minimum)
- [ ] Baseline metrics documented
- [ ] Runbook created for common alerts

> Chỉ là những ghi chép cá nhân với hy vọng mang lại chút giá trị. Nếu thấy hữu ích, đừng ngại chia sẻ cho bạn bè & đồng nghiệp nhé!

Happy coding <Twemoji emoji="clinking-beer-mugs" /> 😎 👍🏻 🚀 🔥.
