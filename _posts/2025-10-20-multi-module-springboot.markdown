---
layout: post
title: "multi module spring-boot structure"
date: 2025-10-20 19:29:39 +0700
categories: [Software Development]
tags: [java, software-development, spring-boot, best-practices, vietnamese]
---

Khi dự án dần phình to, việc chuyển đổi từ cấu trúc Monolith nguyên khối sang Multi-Module trong Spring Boot là một bước đi tất yếu để đảm bảo tính module hóa (modularity), dễ dàng bảo trì và phân chia công việc cho nhiều team.

Tuy nhiên, nếu chỉ tách code ra các module vật lý mà không có những **ràng buộc (constraints) chặt chẽ về mặt thiết kế**, bạn sẽ sớm tạo ra một mớ bòng bong (Big Ball of Mud) với những lỗi "chết người" như: xung đột Bean, cạn kiệt Connection Pool, hay rò rỉ (leak) configuration giữa các module.

Dưới đây là bộ tiêu chuẩn và những kinh nghiệm "xương máu" khi triển khai Multi-Module Spring Boot, được đúc kết từ quá trình thiết kế các hệ thống Backend quy mô lớn.

### # bean naming

Trong Spring, `ApplicationContext` là một không gian phẳng. Khi nhiều module cùng được load vào một ứng dụng (ví dụ: `ConsoleAppMainApplication`), nguy cơ hai module có cùng một class tên là `UserService` hoặc `PaymentConfig` là rất cao. Khi đó, Spring sẽ ném ra `ConflictingBeanDefinitionException` hoặc tệ hơn là override bean một cách âm thầm.

**Nguyên tắc cốt lõi:**

- Tất cả các class `@Configuration` **PHẢI** có explicit bean name theo format prefix của module. Ví dụ: `@Configuration("paymentModuleXxxConfig")`.
- Tất cả các `@Bean` được khai báo bên trong **PHẢI** được đặt tên rõ ràng: `@Bean("paymentModuleBeanName")`.
- **Tuyệt đối KHÔNG** dựa vào default bean name do Spring tự sinh. Việc tốn thêm vài giây gõ tên Bean sẽ cứu bạn khỏi hàng giờ debug trong giai đoạn tích hợp.

### # infrastructure bean reuse

Mỗi infrastructure bean (như `DataSource`, `RedisConnectionFactory`, `MongoTemplate`) đều đi kèm với một Connection Pool đắt đỏ. Nếu mỗi module tự tạo một `RedisConnectionFactory`, bạn sẽ nhanh chóng làm cạn kiệt số lượng kết nối tối đa của Redis Server.

**Nguyên tắc thiết kế:**

- **Single Source of Truth:** Chỉ một module cốt lõi (core/infrastructure) chịu trách nhiệm khởi tạo các connection này.
- **Reuse qua @Qualifier:** Các module khác khi cần sử dụng hạ tầng phải inject các bean đã tồn tại thông qua `@Qualifier("existingBeanName")`.
- **Custom Template:** Nếu một module cần cấu hình serialization riêng cho Redis, hãy tạo một `RedisTemplate` mới, nhưng vẫn phải **tái sử dụng** `ConnectionFactory` cũ.

> **Ví dụ thực tế trong hệ thống:**
>
> - `redisConnectionFactory`: Chỉ khởi tạo tại Register module (`RedisConfig`).
> - `cacheManager`: Khởi tạo tại BPM-Cluster module (`RedisBpmConfig`).
> - `MongoDB templates`: Phân tách rõ ràng từ Core module (như `DiscoveryMongoDbConfig`, `ProcessSystemMongoDbConfig`).

### # existing beans (không tạo lại)

- `redisConnectionFactory` — từ register module (RedisConfig)
- `cacheManager` — từ bpm-cluster module (RedisBpmConfig)
- MongoDB templates — từ core module (DiscoveryMongoDbConfig, ProcessSystemMongoDbConfig)

### # jpa configuration

Một sai lầm phổ biến là đặt `@EntityScan` và `@EnableJpaRepositories` ở class Main của ứng dụng để nó tự động scan toàn bộ project. Điều này phá vỡ hoàn toàn tính đóng gói (encapsulation) của kiến trúc Multi-Module.

Mỗi module chứa Entity phải là một "vương quốc độc lập" và tự quản lý cấu hình JPA của mình:

```java
@Configuration
@Qualifier("moduleNameJpaConfig")
@EntityScan(basePackages = {"vn.com.vpbank.internal.csp.moduleName.entity"})
@EnableJpaRepositories(basePackages = {"vn.com.vpbank.internal.csp.moduleName.repository"})
public class ModuleNameJpaConfig {}
```

### # auto-configuration excludes

Cơ chế Auto-Configuration của Spring Boot rất ma thuật, nhưng trong kiến trúc Multi-Module, sự ma thuật này cần được kìm cương.

- Chặn từ cửa Main: Class Main App phải loại trừ (exclude) các Auto-Config không cần thiết ở mức global (ví dụ: RabbitAutoConfiguration, MongoAutoConfiguration, MongoDataAutoConfiguration) để tránh Spring Boot tự động kết nối vào các hạ tầng mặc định khi chưa có cấu hình chuẩn.
- Tránh duplicate Annotations: \* Tuyệt đối KHÔNG thêm @EnableCaching vô tội vạ nếu một module core đã đảm nhận việc này.
  - KHÔNG dùng @EnableAsync bừa bãi. Hãy luôn sử dụng explicit bean name cho các ThreadPool/Executor (@Async("myModuleExecutor")) để tránh việc Spring ném mọi background task vào chung một SimpleAsyncTaskExecutor mặc định.

### # postgresql + stringtype=unspecified

Đây là một case study điển hình mà bạn sẽ hiếm khi tìm thấy trong document cơ bản.

Khi làm việc với PostgreSQL qua JDBC driver, nếu bạn thiết lập parameter ?stringtype=unspecified trong chuỗi kết nối, driver sẽ gửi các tham số (parameters) xuống DB dưới dạng bytea (kiểu byte array không định kiểu) thay vì varchar. Điều này giúp PostgreSQL tự ép kiểu (auto-cast) cho các trường hợp so sánh đa hình, nhưng lại gây ra "thảm họa" với Hibernate/JPQL:

- Lỗi Nullable Parameters: Các câu lệnh JPQL có điều kiện IS NULL hoặc OR với parameter sẽ bị crash với lỗi could not determine data type of parameter.
- Lỗi Function String: Hàm LOWER(:param) trong JPQL sẽ thất bại vì DB báo lỗi function lower(bytea) does not exist.

Giải pháp dứt điểm:

- Phải chuyển sang dùng Native Query thay vì JPQL cho các query phức tạp dính đến lỗi này.
- Ép kiểu (CAST) một cách tường minh ngay trong Native Query: CAST(:param AS text), CAST(:param AS boolean), CAST(:param AS uuid).
- Xử lý Enum: Enum parameters truyền từ Java xuống không được để nguyên, phải dùng .name() để convert sang String trước khi pass vào Native Query.
- Lưu ý khi Sort: Khi dùng Native Query kết hợp với Pageable để sort, bắt buộc phải sort theo tên cột vật lý trong DB (ví dụ: created_date), tuyệt đối không dùng JPA field name (createdDate).

### # verify checklist (trước khi output code)

- [ ] Không có bean name trùng với module khác
- [ ] Không tạo duplicate infrastructure beans
- [ ] Tất cả @Qualifier reference đúng tên bean đã tồn tại
- [ ] JpaConfig có @EnableJpaRepositories nếu module có @Repository
- [ ] @Configuration class có explicit bean name

> Chỉ là những ghi chép cá nhân với hy vọng mang lại chút giá trị. Nếu thấy hữu ích, đừng ngại chia sẻ cho bạn bè & đồng nghiệp nhé!

Happy coding <Twemoji emoji="clinking-beer-mugs" /> 😎 👍🏻 🚀 🔥.
