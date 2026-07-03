---
layout: post
title: "spring test annotations"
date: 2023-10-11 19:29:39 +0700
categories: [Software Development]
tags: [java, software-development, spring-framework, best-practices, vietnamese]
---

### # giới thiệu

"Code without tests is broken by design" — nhưng viết đúng loại test ở đúng layer mới quan trọng. Spring Boot cung cấp test slices — load chỉ phần context cần thiết thay vì toàn bộ application. Kết quả: tests nhanh, focused, và reliable.

Senior developer không chỉ viết tests — họ thiết kế test strategy: unit tests cho logic, slice tests cho từng layer, integration tests cho critical paths. Spring Test annotations giúp bạn execute strategy đó hiệu quả.

### # @SpringBootTest — full integration test

Load TOÀN BỘ Spring context. Dùng cho end-to-end tests cần tất cả beans wired together. Chậm nhất nhưng confident nhất.

```java
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@ActiveProfiles("test")
class OrderIntegrationTest {

   @Autowired
   private TestRestTemplate restTemplate;

   @Autowired
   private OrderRepository orderRepository;

   @Test
   void createOrder_endToEnd() {
       // Given
       CreateOrderRequest request = CreateOrderRequest.builder()
           .productId(testProductId)
           .quantity(2)
           .build();

       // When
       ResponseEntity<APIResponse<OrderDTO>> response = restTemplate.postForEntity(
           "/api/v1/orders", request, new ParameterizedTypeReference<>() {});

       // Then
       assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
       assertThat(response.getBody().getData().getStatus()).isEqualTo("PENDING");

       // Verify DB
       Order saved = orderRepository.findById(response.getBody().getData().getId()).orElseThrow();
       assertThat(saved.getQuantity()).isEqualTo(2);
   }
}

// WebEnvironment options
// MOCK (default): MockServlet, no real HTTP
// RANDOM_PORT: Real HTTP server on random port
// DEFINED_PORT: Real HTTP on server.port
// NONE: No web context
```

### # @WebMvcTest — controller layer only

Load CHỈ Web layer (controllers, filters, advice). Service/Repository beans phải mock. Fast, focused cho testing request mapping, validation, serialization.

```java
@WebMvcTest(ProductController.class)
class ProductControllerTest {

   @Autowired
   private MockMvc mockMvc;

   @MockBean  // Mock service layer
   private ProductService productService;

   @Test
   void getProduct_returns200() throws Exception {
       when(productService.getById(any()))
           .thenReturn(ProductDTO.builder().id(testId).name("Test").build());

       mockMvc.perform(get("/api/v1/products/{id}", testId)
               .header("Authorization", "Bearer " + validToken)
               .header("X-Workspace-Id", workspaceId))
           .andExpect(status().isOk())
           .andExpect(jsonPath("$.data.name").value("Test"))
           .andExpect(jsonPath("$.data.id").value(testId.toString()));
   }

   @Test
   void createProduct_invalidRequest_returns400() throws Exception {
       // Missing required field
       String invalidJson = "{}";

       mockMvc.perform(post("/api/v1/products")
               .contentType(MediaType.APPLICATION_JSON)
               .content(invalidJson)
               .header("Authorization", "Bearer " + validToken))
           .andExpect(status().isBadRequest())
           .andExpect(jsonPath("$.error_code").exists());
   }

   @Test
   void listProducts_pagination() throws Exception {
       when(productService.search(any(), any()))
           .thenReturn(new PageImpl<>(List.of(testProduct), PageRequest.of(0, 20), 1));

       mockMvc.perform(get("/api/v1/products")
               .param("page", "0")
               .param("size", "20")
               .param("keyword", "laptop"))
           .andExpect(status().isOk())
           .andExpect(jsonPath("$.data.content").isArray())
           .andExpect(jsonPath("$.data.totalElements").value(1));
   }
}
```

### # @DataJpaTest — repository layer only

Load CHỈ JPA layer (EntityManager, Repositories, Flyway/Liquibase). Tự động configure in-memory DB hoặc real DB. Transactional by default (rollback after each test).

```java
@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE) // Use real PostgreSQL
@Import(JpaAuditingConfig.class)
@ActiveProfiles("test")
class ProductRepositoryTest {

   @Autowired
   private ProductRepository productRepository;

   @Autowired
   private TestEntityManager em;

   @Test
   void findByCode_existingProduct_returnsProduct() {
       // Given
       Product product = em.persistAndFlush(Product.builder()
           .code("TEST-001").name("Test").price(BigDecimal.TEN)
           .status(ProductStatus.ACTIVE).category(testCategory).build());

       // When
       Optional<Product> result = productRepository.findByCode("TEST-001");

       // Then
       assertThat(result).isPresent();
       assertThat(result.get().getName()).isEqualTo("Test");
   }

   @Test
   void search_byKeywordAndStatus_returnsPaginated() {
       // Given
       em.persist(Product.builder().code("P1").name("Laptop Pro").status(ACTIVE)...build());
       em.persist(Product.builder().code("P2").name("Laptop Air").status(ACTIVE)...build());
       em.persist(Product.builder().code("P3").name("Phone").status(ACTIVE)...build());
       em.flush();

       // When
       Page<Product> result = productRepository.search("laptop", ACTIVE, null,
           PageRequest.of(0, 10));

       // Then
       assertThat(result.getContent()).hasSize(2);
       assertThat(result.getContent()).extracting("name")
           .containsExactlyInAnyOrder("Laptop Pro", "Laptop Air");
   }
}
```

### # @MockBean vs @SpyBean

`@MockBean` thay thế bean trong context bằng Mockito mock (mọi method return null/default).
`@SpyBean` wrap real bean — real behavior by default, override specific methods khi cần.

```java
@SpringBootTest
class OrderServiceIntegrationTest {

   @Autowired
   private OrderService orderService;

   @MockBean  // Hoàn toàn fake — không gọi external service
   private PaymentGateway paymentGateway;

   @SpyBean  // Real implementation, nhưng verify interactions
   private NotificationService notificationService;

   @Test
   void createOrder_callsPaymentAndNotification() {
       // Setup mock
       when(paymentGateway.authorize(any())).thenReturn(PaymentResult.success());

       // Execute
       OrderDTO order = orderService.create(testRequest);

       // Verify mock was called
       verify(paymentGateway).authorize(argThat(req ->
           req.getAmount().compareTo(expectedAmount) == 0));

       // Verify spy (real method ran, but we can check it was called)
       verify(notificationService).sendOrderConfirmation(eq(order.getId()));
   }
}
```

### # @TestConfiguration — test-specific beans

Beans chỉ tồn tại trong test context — override production beans hoặc thêm test utilities.

```java
@TestConfiguration
public class TestSecurityConfig {

   // Override real security cho tests
   @Bean
   public SecurityFilterChain testSecurity(HttpSecurity http) throws Exception {
       return http.authorizeHttpRequests(a -> a.anyRequest().permitAll()).build();
   }
}

@TestConfiguration
public class TestDataConfig {

   @Bean
   public TestDataGenerator testDataGenerator(EntityManager em) {
       return new TestDataGenerator(em);
   }
}

// Import in test
@SpringBootTest
@Import(TestSecurityConfig.class)
class MyTest { ... }
```

### # Testcontainers — real infrastructure in tests

Khi in-memory DB không đủ (PostgreSQL-specific features, MongoDB, Redis), dùng Testcontainers — Docker containers cho tests.

```java
@SpringBootTest
@Testcontainers
@ActiveProfiles("test")
class ProductServiceIT {

   @Container
   static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:15-alpine")
       .withDatabaseName("testdb")
       .withUsername("test")
       .withPassword("test");

   @Container
   static GenericContainer<?> redis = new GenericContainer<>("redis:7-alpine")
       .withExposedPorts(6379);

   @DynamicPropertySource
   static void configureProperties(DynamicPropertyRegistry registry) {
       registry.add("spring.datasource.url", postgres::getJdbcUrl);
       registry.add("spring.datasource.username", postgres::getUsername);
       registry.add("spring.datasource.password", postgres::getPassword);
       registry.add("spring.data.redis.host", redis::getHost);
       registry.add("spring.data.redis.port", () -> redis.getMappedPort(6379));
   }

   @Autowired
   private ProductService productService;

   @Test
   void createProduct_persistsToRealPostgres() {
       ProductDTO created = productService.create(testRequest);
       assertThat(created.getId()).isNotNull();

       ProductDTO fetched = productService.getById(created.getId());
       assertThat(fetched.getName()).isEqualTo(testRequest.getName());
   }
}
```

### # other test slices

| Annotation      | Loads                               | Use for               |
| --------------- | ----------------------------------- | --------------------- |
| @WebMvcTest     | Controllers, Filters, Advice        | REST endpoint testing |
| @DataJpaTest    | JPA repos, EntityManager            | Repository queries    |
| @DataMongoTest  | MongoDB repos, MongoTemplate        | MongoDB operations    |
| @DataRedisTest  | Redis repos, RedisTemplate          | Redis operations      |
| @JsonTest       | ObjectMapper, JsonComponent         | JSON serialization    |
| @RestClientTest | RestTemplate, MockRestServiceServer | HTTP client testing   |
| @WebFluxTest    | WebFlux controllers                 | Reactive endpoints    |

### # quick reference

| Annotation             | Scope                     | Speed              |
| ---------------------- | ------------------------- | ------------------ |
| @SpringBootTest        | Full context              | Slow (5-30s)       |
| @WebMvcTest            | Web layer only            | Fast (1-3s)        |
| @DataJpaTest           | JPA layer only            | Fast (2-5s)        |
| @DataMongoTest         | MongoDB only              | Fast (2-4s)        |
| @MockBean              | Replace bean with mock    | —                  |
| @SpyBean               | Wrap bean with spy        | —                  |
| @TestConfiguration     | Test-only beans           | —                  |
| @DynamicPropertySource | Runtime property override | —                  |
| @ActiveProfiles        | Activate test profile     | —                  |
| @Sql                   | Execute SQL before test   | —                  |
| @Testcontainers        | Docker containers         | Slow (first start) |
| @Container             | Single container instance | —                  |
| @WithMockUser          | Mock security context     | —                  |

> Chỉ là những ghi chép cá nhân với hy vọng mang lại chút giá trị. Nếu thấy hữu ích, đừng ngại chia sẻ cho bạn bè & đồng nghiệp nhé!

Happy coding <Twemoji emoji="clinking-beer-mugs" /> 😎 👍🏻 🚀 🔥.
