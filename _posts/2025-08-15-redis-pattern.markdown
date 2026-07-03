---
layout: post
title: "redis pattern"
date: 2025-08-15 19:29:39 +0700
categories: [Software Development]
tags: [java, software-development, redis, best-practices, vietnamese]
---

Trong các hệ thống phân tán và kiến trúc microservices hiện đại, Redis thường bị đóng khung trong một vai trò duy nhất: Caching. Tuy nhiên, khi đào sâu vào tầng application và infrastructure, Redis là một chiếc "dao găm Thụy Sĩ" đích thực. Từ việc điều phối các distributed lock, quản lý state cho đến ngăn chặn các "cơn bão" request đánh gục cơ sở dữ liệu, việc sử dụng Redis đúng pattern sẽ quyết định ranh giới giữa một hệ thống chạy được và một hệ thống chịu tải hoàn hảo.

Dưới đây là cẩm nang thực chiến, tổng hợp các design pattern, chiến lược caching và những "cú ngã" thường gặp khi làm việc với Redis trong hệ sinh thái Java/Spring Boot.

### # caching strategies

Việc chọn đúng chiến lược đồng bộ giữa Cache và Database (Source of Truth) quyết định tính nhất quán của dữ liệu.

#### # cache-aside (lazy loading)

Đây là pattern kinh điển và an toàn nhất. Ứng dụng sẽ chủ động quản lý việc đọc/ghi. Cache chỉ chứa những dữ liệu thực sự được user yêu cầu (lazy), giúp tiết kiệm memory.

Lưu ý kiến trúc: Khi có thay đổi dữ liệu, nguyên tắc sống còn là xóa cache (invalidate) chứ không phải cập nhật lại cache. Việc cập nhật lại cache ngay lập tức có thể dẫn đến race condition trong môi trường multi-thread.

```java
// Application quản lý cache manually
@Service
@RequiredArgsConstructor
public class ProductService {
   private final ProductRepository repo;
   private final RedisTemplate<String, Product> redis;
   private static final Duration TTL = Duration.ofMinutes(30);

   public Product getById(UUID id) {
       String key = "product:" + id;
       Product cached = redis.opsForValue().get(key);
       if (cached != null) return cached;

       Product product = repo.findById(id).orElseThrow();
       redis.opsForValue().set(key, product, TTL);
       return product;
   }

   public void update(UUID id, ProductUpdateDTO dto) {
       Product product = repo.findById(id).orElseThrow();
       product.apply(dto);
       repo.save(product);
       redis.delete("product:" + id); // invalidate
   }
}
```

#### # write-through

Phù hợp với các hệ thống yêu cầu read-heavy nhưng data bắt buộc phải nhất quán ngay lập tức. Ta ghi song song vào cả DB và Cache trong cùng một transaction.

```java
// Write to cache và DB cùng lúc
public Product save(Product product) {
   Product saved = repo.save(product);
   redis.opsForValue().set("product:" + saved.getId(), saved, TTL);
   return saved;
}
```

#### # write-behind (async)

Đây "Vũ khí hạng nặng" cho các hệ thống write-heavy. Request ghi trực tiếp vào Redis để phản hồi siêu tốc cho user, sau đó đẩy event đi (ví dụ qua Event Bus/Message Broker) để hệ thống bất đồng bộ lưu xuống Database.

```java
// Write to cache immediately, persist to DB async
public void updateScore(UUID userId, int score) {
   redis.opsForValue().set("score:" + userId, score);
   publisher.publishEvent(new ScorePersistEvent(userId, score)); // async persist later
}
```

### # spring cache annotations

Spring cung cấp bộ annotation mạnh mẽ, che giấu đi boilerplate code. Tuy nhiên, vì hoạt động dựa trên cơ chế AOP Proxy, chúng sẽ không hoạt động nếu bạn gọi hàm nội bộ (internal method call) trong cùng một class.

#### # @Cacheable

Caching kết quả trả về. Hỗ trợ SpEL (Spring Expression Language) để tạo key động và điều kiện caching phức tạp.

```java
@Service
public class UserService {

   // Cache result — subsequent calls with same id skip method execution
   @Cacheable(value = "users", key = "#id")
   public User findById(UUID id) {
       return repo.findById(id).orElseThrow();
   }

   // Conditional caching — only cache non-null results
   @Cacheable(value = "users", key = "#email", unless = "#result == null")
   public User findByEmail(String email) {
       return repo.findByEmail(email).orElse(null);
   }

   // SpEL expression for complex keys
   @Cacheable(value = "search", key = "#criteria.keyword + ':' + #pageable.pageNumber")
   public Page<User> search(SearchCriteria criteria, Pageable pageable) {
       return repo.findAll(toSpec(criteria), pageable);
   }
}
```

#### # @CacheEvict

Dọn dẹp bộ nhớ đệm. Rất hữu ích khi kết hợp với tham số allEntries = true để clear toàn bộ dictionary khi cấu hình hệ thống thay đổi.

```java
@CacheEvict(value = "users", key = "#id")
public void delete(UUID id) {
   repo.deleteById(id);
}

// Evict all entries in cache
@CacheEvict(value = "users", allEntries = true)
public void refreshAll() { }

// Evict before method execution
@CacheEvict(value = "users", key = "#user.id", beforeInvocation = true)
public void update(User user) {
   repo.save(user);
}
```

#### # @CachePut

```java
// Always execute method, update cache with result
@CachePut(value = "users", key = "#user.id")
public User save(User user) {
   return repo.save(user);
}
```

#### # @Caching (multiple operations)

Gom nhóm nhiều thao tác cùng lúc (vừa update cache này, vừa xóa cache kia).

```java
@Caching(
   put = @CachePut(value = "users", key = "#result.id"),
   evict = @CacheEvict(value = "userList", allEntries = true)
)
public User create(CreateUserDTO dto) {
   return repo.save(mapToEntity(dto));
}
```

### # RedisTemplate configuration

Mặc định, Spring Data Redis sử dụng cơ chế serialization của JDK. Đây là một thảm họa trong môi trường microservices vì dữ liệu lưu dưới dạng byte code không thể đọc được bằng mắt thường và sẽ gây lỗi ClassCastException nếu các service khác ngôn ngữ cùng truy cập.

Best Practice: Luôn cấu hình GenericJackson2JsonRedisSerializer.

#### # json serialization (recommended)

```java
@Configuration
public class RedisConfig {

   @Bean
   public RedisTemplate<String, Object> redisTemplate(RedisConnectionFactory factory) {
       RedisTemplate<String, Object> template = new RedisTemplate<>();
       template.setConnectionFactory(factory);

       // Key chuẩn hóa bằng String để tối ưu indexing trong Redis
       template.setKeySerializer(new StringRedisSerializer());

       // Value chuẩn hóa bằng JSON (Human-readable, cross-language)
       ObjectMapper mapper = new ObjectMapper();
       mapper.registerModule(new JavaTimeModule());
       mapper.activateDefaultTyping(mapper.getPolymorphicTypeValidator(),
           ObjectMapper.DefaultTyping.NON_FINAL);

       GenericJackson2JsonRedisSerializer jsonSerializer =
           new GenericJackson2JsonRedisSerializer(mapper);

       template.setValueSerializer(jsonSerializer);
       template.afterPropertiesSet();

       return template;
   }
}
```

#### # ttl strategies

```java
// Per-cache TTL via CacheManager
@Bean
public RedisCacheManager cacheManager(RedisConnectionFactory factory) {
   RedisCacheConfiguration defaultConfig = RedisCacheConfiguration.defaultCacheConfig()
       .entryTtl(Duration.ofMinutes(10))
       .serializeValuesWith(SerializationPair.fromSerializer(new GenericJackson2JsonRedisSerializer()));

   Map<String, RedisCacheConfiguration> cacheConfigs = Map.of(
       "users", defaultConfig.entryTtl(Duration.ofHours(1)),
       "sessions", defaultConfig.entryTtl(Duration.ofMinutes(30)),
       "lookups", defaultConfig.entryTtl(Duration.ofHours(24))
   );

   return RedisCacheManager.builder(factory)
       .cacheDefaults(defaultConfig)
       .withInitialCacheConfigurations(cacheConfigs)
       .build();
}
```

### # distributed lock

Khi hệ thống scale ngang (horizontal scaling) ra nhiều node, cơ chế @Scheduled truyền thống hoặc block thread (như synchronized) sẽ hoàn toàn vô dụng. Để đảm bảo một task (ví dụ: batch job chốt đơn cuối ngày) chỉ được chạy bởi một instance duy nhất, ta cần Distributed Lock.

#### # shedlock (scheduled tasks)

Shedlock là thư viện sinh ra để giải quyết chính xác bài toán này một cách thanh lịch.

```java
// Prevent concurrent execution of scheduled tasks across instances
@Scheduled(cron = "0 0 * * * *")
@SchedulerLock(name = "hourlyReport", lockAtMostFor = "50m", lockAtLeastFor = "5m")
public void generateHourlyReport() {
   // Only ONE instance executes this across cluster
}
```

#### # manual distributed lock - lua script

Để lock an toàn, thao tác kiểm tra lock và nhả lock phải mang tính Nguyên tử (Atomic). Ta bắt buộc phải dùng Lua Script để tránh việc node A vô tình giải phóng lock của node B.

```java
@Component
@RequiredArgsConstructor
public class RedisLock {
   private final StringRedisTemplate redis;

   public boolean tryLock(String key, String owner, Duration ttl) {
       Boolean acquired = redis.opsForValue()
           .setIfAbsent("lock:" + key, owner, ttl);
       return Boolean.TRUE.equals(acquired);
   }

   public void unlock(String key, String owner) {
       // Lua script: atomic check-and-delete (only owner can unlock)
       String script = """
           if redis.call('get', KEYS[1]) == ARGV[1] then
               return redis.call('del', KEYS[1])
           else
               return 0
           end
           """;
       redis.execute(new DefaultRedisScript<>(script, Long.class),
           List.of("lock:" + key), owner);
   }
}

// Usage
public void processExclusive(String resourceId) {
   String owner = UUID.randomUUID().toString();
   if (!redisLock.tryLock(resourceId, owner, Duration.ofSeconds(30))) {
       throw new ConflictException("Resource locked");
   }
   try {
       doWork(resourceId);
   } finally {
       redisLock.unlock(resourceId, owner);
   }
}
```

### # cache stampede prevention

Điều gì xảy ra khi một key rất quan trọng (ví dụ: Flash Sale data) hết hạn TTL? Ngay trong mili-giây đó, hàng ngàn request cùng "cache miss" và lao thẳng vào Database. Database quá tải, connection pool cạn kiệt, hệ thống sập.

#### # giải pháp: mutex lock

Chỉ cho phép 1 thread đi xuống DB để lấy data và fill lại cache. Các thread khác phải đợi hoặc retry.

```java
// 1. Lock-based (only one thread refreshes)
public Product getWithLock(UUID id) {
   String key = "product:" + id;
   Product cached = redis.opsForValue().get(key);
   if (cached != null) return cached;

   String lockKey = "lock:product:" + id;
   if (redisLock.tryLock(lockKey, "refresh", Duration.ofSeconds(5))) {
       try {
           // Double-check locking (Cực kỳ quan trọng)
           cached = redis.opsForValue().get(key);
           if (cached != null) return cached;

           Product product = repo.findById(id).orElseThrow();
           redis.opsForValue().set(key, product, Duration.ofMinutes(30));
           return product;
       } finally {
           redisLock.unlock(lockKey, "refresh");
       }
   }
   // Others wait briefly then retry
   Thread.sleep(50);
   return getWithLock(id);
}
```

#### # giải pháp: probabilistic early expiration (logic refresh bất đồng bộ)

Gắn thêm một cờ "sắp hết hạn" vào trong value của cache. Nếu thread nào đọc được dữ liệu và phát hiện data sắp hết hạn, nó vẫn trả về data cũ cho user, nhưng ngầm kích hoạt một thread chạy ngầm (async) để cập nhật cache mới.

```java
public Product getWithEarlyRefresh(UUID id) {
   String key = "product:" + id;
   CachedValue<Product> cached = redis.opsForValue().get(key);
   if (cached != null) {
       // Refresh proactively before actual expiry (random window)
       if (cached.shouldRefresh()) {
           CompletableFuture.runAsync(() -> refreshCache(id));
       }
       return cached.getValue();
   }
   return refreshCache(id);
}
```

### # data structures

#### # hash (object fields)

```java
// Store object as hash — partial updates without full serialization
HashOperations<String, String, String> hashOps = redis.opsForHash();

// Set fields
hashOps.put("user:123", "name", "John");
hashOps.put("user:123", "email", "john@example.com");
hashOps.putAll("user:123", Map.of("name", "John", "status", "active"));

// Get single field
String name = hashOps.get("user:123", "name");

// Increment numeric field
hashOps.increment("user:123", "loginCount", 1);
```

#### # sorted set (ranking/leaderboard)

```java
ZSetOperations<String, String> zOps = redis.opsForZSet();

// Add with score
zOps.add("leaderboard", "player1", 1500.0);
zOps.add("leaderboard", "player2", 2100.0);

// Top 10
Set<String> top10 = zOps.reverseRange("leaderboard", 0, 9);

// Rank of specific member
Long rank = zOps.reverseRank("leaderboard", "player1");
```

#### # list (queue)

```java
ListOperations<String, String> listOps = redis.opsForList();

// Producer
listOps.rightPush("queue:tasks", taskJson);

// Consumer (blocking pop)
String task = listOps.leftPop("queue:tasks", Duration.ofSeconds(5));
```

### # pub/sub

```java
// Publisher
redis.convertAndSend("channel:notifications", notification);

// Subscriber
@Component
public class NotificationSubscriber implements MessageListener {
   @Override
   public void onMessage(Message message, byte[] pattern) {
       String body = new String(message.getBody());
       processNotification(body);
   }
}

// Config
@Bean
public RedisMessageListenerContainer listenerContainer(RedisConnectionFactory factory) {
   RedisMessageListenerContainer container = new RedisMessageListenerContainer();
   container.setConnectionFactory(factory);
   container.addMessageListener(subscriber, new PatternTopic("channel:*"));
   return container;
}
```

### # common pitfalls

| Pitfall                    | Problem                          | Fix                                |
| -------------------------- | -------------------------------- | ---------------------------------- |
| No TTL                     | Memory grows forever             | Always set expiration              |
| JDK serialization          | Not readable, version-sensitive  | Use JSON serializer                |
| Large values               | Slow network, memory pressure    | Split or compress                  |
| Hot keys                   | Single shard overloaded          | Add random suffix, local cache     |
| Cache + DB inconsistency   | Stale reads after update         | Delete cache on write (not update) |
| Connection pool exhaustion | Blocked threads                  | Tune pool size, add timeout        |
| Missing null caching       | Cache miss → repeated DB queries | Cache null with short TTL          |

### # configuration (application.yml)

```yaml
spring:
  data:
    redis:
      host: localhost
      port: 6379
      password: ${REDIS_PASSWORD:}
      timeout: 2000ms
      lettuce:
        pool:
          max-active: 16
          max-idle: 8
          min-idle: 2
          max-wait: 1000ms
  cache:
    type: redis
    redis:
      time-to-live: 600000 # 10 minutes (ms)
      cache-null-values: true
```

> Chỉ là những ghi chép cá nhân với hy vọng mang lại chút giá trị. Nếu thấy hữu ích, đừng ngại chia sẻ cho bạn bè & đồng nghiệp nhé!

Happy coding <Twemoji emoji="clinking-beer-mugs" /> 😎 👍🏻 🚀 🔥.
