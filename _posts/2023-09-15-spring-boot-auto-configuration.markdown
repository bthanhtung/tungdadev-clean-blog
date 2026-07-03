---
layout: post
title: "spring boot auto-configuration"
date: 2023-09-15 19:29:39 +0700
categories: [Software Development]
tags: [java, software-development, spring-boot, best-practices, vietnamese]
---

### # giới thiệu

"Tại sao thêm `spring-boot-starter-data-jpa` vào pom.xml là tự có DataSource, EntityManager, TransactionManager?" — Đây là câu hỏi phỏng vấn senior yêu thích.

Câu trả lời: **Auto-Configuration**. Spring Boot scan classpath, detect dependencies, và tự động configure beans phù hợp. Thêm PostgreSQL driver → auto-configure DataSource. Thêm Jackson → auto-configure ObjectMapper. Không cần bạn viết `@Bean` cho mỗi thứ.

Cơ chế behind the scenes: `@Conditional` annotations. Mỗi auto-config class có conditions — "chỉ tạo bean này NẾU class X tồn tại trên classpath VÀ property Y = true VÀ chưa có bean kiểu Z." Hiểu mechanism này = hiểu cách customize, override, và debug Spring Boot behavior.

### # @Conditional family — conditional bean creation

#### # @ConditionalOnProperty — bean theo config value

```java
// Cache chỉ enable khi property = true
@Configuration
@ConditionalOnProperty(name = "app.cache.enabled", havingValue = "true", matchIfMissing = false)
public class CacheConfig {
   @Bean
   public CacheManager redisCacheManager(RedisConnectionFactory factory) {
       return RedisCacheManager.builder(factory).build();
   }
}

// Feature flag
@Bean
@ConditionalOnProperty(name = "feature.new-pricing", havingValue = "true")
public PricingEngine newPricingEngine() { return new NewPricingEngine(); }

@Bean
@ConditionalOnProperty(name = "feature.new-pricing", havingValue = "false", matchIfMissing = true)
public PricingEngine legacyPricingEngine() { return new LegacyPricingEngine(); }
```

#### # @ConditionalOnClass / @ConditionalOnMissingClass — bean theo classpath

```java
// Redis config chỉ load khi Lettuce driver có trên classpath
@Configuration
@ConditionalOnClass(name = "io.lettuce.core.RedisClient")
public class RedisConfig {
   @Bean
   public RedisTemplate<String, Object> redisTemplate(RedisConnectionFactory factory) { ... }
}

// Fallback khi không có Redis
@Configuration
@ConditionalOnMissingClass("io.lettuce.core.RedisClient")
public class InMemoryCacheConfig {
   @Bean
   public CacheManager inMemoryCache() { return new ConcurrentMapCacheManager(); }
}
```

#### # @ConditionalOnBean / @ConditionalOnMissingBean — bean theo sự tồn tại bean khác

Đây là cách auto-configuration "nhường" cho user config. User khai báo bean → auto-config không override.

```java
// Auto-config cung cấp default ObjectMapper
@Bean
@ConditionalOnMissingBean  // CHỈ tạo nếu user CHƯA khai báo ObjectMapper bean
public ObjectMapper objectMapper() {
   return new ObjectMapper().registerModule(new JavaTimeModule());
}

// User override — vì có @Bean ObjectMapper rồi, auto-config skip
@Configuration
public class MyJacksonConfig {
   @Bean
   public ObjectMapper objectMapper() {
       return new ObjectMapper()
           .registerModule(new JavaTimeModule())
           .setPropertyNamingStrategy(PropertyNamingStrategies.SNAKE_CASE); // Custom
   }
}
```

#### # @ConditionalOnExpression — SpEL condition

```java
@Bean
@ConditionalOnExpression("${app.notifications.enabled:true} and '${app.environment}' != 'test'")
public NotificationService realNotificationService() {
   return new SmtpNotificationService();
}
```

### # tự viết auto-configuration

Khi bạn build shared library (như `csp-common`, `csp-auth-verification`), auto-configuration cho phép consuming services chỉ cần thêm dependency — không cần manual `@Import` hay `@ComponentScan`.

#### # step 1: auto-configuration class

```java
@AutoConfiguration
@ConditionalOnClass(JwtDecoder.class)
@EnableConfigurationProperties(CspAuthProperties.class)
public class CspAuthAutoConfiguration {

   @Bean
   @ConditionalOnMissingBean
   public JwtAuthFilter jwtAuthFilter(CspAuthProperties properties) {
       return new JwtAuthFilter(properties.getJwksUri(), properties.getIssuer());
   }

   @Bean
   @ConditionalOnMissingBean
   @ConditionalOnProperty(name = "csp.auth.permission-check.enabled", havingValue = "true")
   public PermissionCheckFilter permissionFilter(PermissionClient client) {
       return new PermissionCheckFilter(client);
   }
}
```

#### # step 2: register via imports file

```
# src/main/resources/META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports
vn.com.vpbank.internal.csp.auth.CspAuthAutoConfiguration
```

#### # step 3: properties class

```java
@Data
@ConfigurationProperties(prefix = "csp.auth")
public class CspAuthProperties {
   private String jwksUri;
   private String issuer;
   private Duration tokenExpiry = Duration.ofHours(1);
   private PermissionCheck permissionCheck = new PermissionCheck();

   @Data
   public static class PermissionCheck {
       private boolean enabled = false;
       private String serviceUrl;
   }
}
```

### # tự viết custom @Conditional

Khi built-in conditions không đủ, tạo custom condition. Ví dụ: chỉ enable bean khi đang chạy trong Docker, hoặc khi database schema version >= X.

```java
// Custom condition annotation
@Target({ElementType.TYPE, ElementType.METHOD})
@Retention(RetentionPolicy.RUNTIME)
@Conditional(OnLinuxCondition.class)
public @interface ConditionalOnLinux {}

// Condition implementation
public class OnLinuxCondition implements Condition {
   @Override
   public boolean matches(ConditionContext context, AnnotatedTypeMetadata metadata) {
       String os = System.getProperty("os.name");
       return os != null && os.toLowerCase().contains("linux");
   }
}

// Usage
@Bean
@ConditionalOnLinux
public FileWatcher linuxFileWatcher() {
   return new InotifyFileWatcher(); // Linux-specific inotify
}
```

### # debug auto-configuration

Khi auto-config không hoạt động như mong đợi:

```yaml
# Xem report tất cả conditions matched/not matched
debug: true
# Output: CONDITIONS EVALUATION REPORT (positive matches, negative matches)

# Hoặc qua actuator
management:
  endpoints:
    web:
      exposure:
        include: conditions
# GET /actuator/conditions → JSON report
```

```bash
# Exclude specific auto-config
spring.autoconfigure.exclude=org.springframework.boot.autoconfigure.jdbc.DataSourceAutoConfiguration
```

### # @ConfigurationProperties — type-safe config (advanced)

#### # immutable config (java records)

```java
@ConfigurationProperties(prefix = "app.rabbitmq")
public record RabbitMqProperties(
   String host,
   int port,
   String username,
   String password,
   @DefaultValue("5") int retryAttempts,
   @DefaultValue("1s") Duration retryDelay,
   Map<String, QueueConfig> queues
) {
   public record QueueConfig(
       String name,
       boolean durable,
       @DefaultValue("3") int prefetchCount
   ) {}
}
```

#### # validation

```java
@Data
@ConfigurationProperties(prefix = "app.security")
@Validated
public class SecurityProperties {

   @NotBlank
   private String jwtSecret;

   @Min(300) @Max(86400)
   private int tokenExpirySeconds = 3600;

   @NotEmpty
   private List<@URL String> allowedOrigins;

   @Valid
   @NotNull
   private RateLimit rateLimit = new RateLimit();

   @Data
   public static class RateLimit {
       @Min(1)
       private int requestsPerMinute = 100;
       private boolean enabled = true;
   }
}
```

### # quick reference

| Annotation                      | Condition                  |
| ------------------------------- | -------------------------- |
| @ConditionalOnProperty          | Property value matches     |
| @ConditionalOnClass             | Class on classpath         |
| @ConditionalOnMissingClass      | Class NOT on classpath     |
| @ConditionalOnBean              | Bean exists in context     |
| @ConditionalOnMissingBean       | Bean NOT in context        |
| @ConditionalOnExpression        | SpEL expression = true     |
| @ConditionalOnResource          | Resource file exists       |
| @ConditionalOnWebApplication    | Running as web app         |
| @ConditionalOnNotWebApplication | NOT web app                |
| @ConditionalOnJava              | Java version matches       |
| @AutoConfiguration              | Declare auto-config class  |
| @EnableConfigurationProperties  | Bind properties class      |
| @ConfigurationProperties        | Type-safe config binding   |
| @ConstructorBinding             | Immutable config (records) |

> Chỉ là những ghi chép cá nhân với hy vọng mang lại chút giá trị. Nếu thấy hữu ích, đừng ngại chia sẻ cho bạn bè & đồng nghiệp nhé!

Happy coding <Twemoji emoji="clinking-beer-mugs" /> 😎 👍🏻 🚀 🔥.
