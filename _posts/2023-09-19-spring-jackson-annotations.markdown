---
layout: post
title: "spring jackson annotations"
date: 2023-09-19 19:29:39 +0700
categories: [Software Development]
tags: [java, software-development, spring-framework, best-practices, vietnamese]
---

Spring Boot tự động cấu hình `ObjectMapper` với Jackson, nên mọi `@RestController` response và `@RequestBody` input đều đi qua Jackson.

#### # dependency (đã có sẵn trong spring-boot-starter-web)

```xml
<dependency>
   <groupId>com.fasterxml.jackson.core</groupId>
   <artifactId>jackson-annotations</artifactId>
   <!-- Version quản lý bởi spring-boot-starter-parent -->
</dependency>
```

### # nhóm property naming & inclusion

#### # @JsonProperty — đổi tên field khi serialize/deserialize

```java
@Data
public class ProductDTO {

   @JsonProperty("product_id")  // JSON key = "product_id", Java field = "id"
   private UUID id;

   @JsonProperty("product_name")
   private String name;

   @JsonProperty(access = JsonProperty.Access.READ_ONLY)  // Chỉ xuất hiện trong response, bỏ qua khi deserialize
   private LocalDateTime createdAt;

   @JsonProperty(access = JsonProperty.Access.WRITE_ONLY) // Chỉ nhận từ request, không xuất hiện trong response
   private String password;

   @JsonProperty(defaultValue = "0")  // Giá trị mặc định trong schema (metadata)
   private BigDecimal price;
}
```

**Kết quả JSON:**

```json
{
  "product_id": "550e8400-e29b-41d4-a716-446655440000",
  "product_name": "Laptop",
  "created_at": "2024-01-15T10:30:00"
}
// password KHÔNG xuất hiện trong response
// createdAt KHÔNG cần gửi trong request
```

#### # @JsonNaming — đổi naming strategy cho cả class

```java
@Data
@JsonNaming(PropertyNamingStrategies.SnakeCaseStrategy.class)
public class OrderResponseDTO {
   private UUID orderId;          // → "order_id"
   private String customerName;   // → "customer_name"
   private LocalDateTime createdAt; // → "created_at"
   private BigDecimal totalAmount; // → "total_amount"
}
```

**Các strategy có sẵn:**
| Strategy | Input | Output |
|----------|-------|--------|
| SnakeCaseStrategy | orderId | order_id |
| UpperCamelCaseStrategy | orderId | OrderId |
| LowerCamelCaseStrategy | order_id | orderId |
| KebabCaseStrategy | orderId | order-id |
| LowerDotCaseStrategy | orderId | order.id |

#### # @JsonAlias — nhận nhiều tên khác nhau khi deserialize

```java
@Data
public class CreateUserRequest {

   @JsonAlias({"user_name", "userName", "username"})
   private String username;  // Nhận bất kỳ tên nào ở trên từ JSON input

   @JsonAlias({"email_address", "emailAddress"})
   private String email;
}
```

```json
// TẤT CẢ các JSON sau đều deserialize thành công:
{"user_name": "john"}
{"userName": "john"}
{"username": "john"}
```

#### # @JsonInclude — kiểm soát khi nào field được include trong json output

```java
@Data
@JsonInclude(JsonInclude.Include.NON_NULL) // Bỏ tất cả field null khỏi response
public class ProductDTO {
   private UUID id;
   private String name;

   @JsonInclude(JsonInclude.Include.NON_EMPTY) // Bỏ nếu empty string, empty list, null
   private String description;

   @JsonInclude(JsonInclude.Include.NON_DEFAULT) // Bỏ nếu = giá trị mặc định (0, false, null)
   private int quantity;

   private List<String> tags; // Áp dụng class-level NON_NULL
}
```

**Các Include value:**
| Value | Bỏ khi |
|-------|--------|
| ALWAYS | Không bao giờ bỏ (default) |
| NON_NULL | field = null |
| NON_ABSENT | null hoặc Optional.empty() |
| NON_EMPTY | null, empty string, empty collection, Optional.empty() |
| NON_DEFAULT | = giá trị mặc định (0, false, null, empty) |
| CUSTOM | Custom filter class |

**Cấu hình global trong Spring Boot:**

```yaml
spring:
  jackson:
    default-property-inclusion: non_null
```

#### # @JsonIgnore — bỏ field hoàn toàn (cả serialize & deserialize)

```java
@Data
public class UserDTO {
   private UUID id;
   private String username;

   @JsonIgnore  // KHÔNG bao giờ xuất hiện trong JSON
   private String passwordHash;

   @JsonIgnore
   private String internalNote;
}
```

#### # @JsonIgnoreProperties — bỏ nhiều fields hoặc ignore unknown fields

```java
// Bỏ nhiều fields cùng lúc
@Data
@JsonIgnoreProperties({"passwordHash", "internalNote", "deletedAt"})
public class UserDTO {
   private UUID id;
   private String username;
   private String passwordHash;
   private String internalNote;
   private LocalDateTime deletedAt;
}

// Bỏ qua unknown fields khi deserialize (không throw exception)
@Data
@JsonIgnoreProperties(ignoreUnknown = true)
public class ExternalApiResponse {
   private String status;
   private Object data;
   // Các field không khai báo trong JSON input sẽ bị bỏ qua thay vì throw error
}
```

#### # @JsonIgnoreType — bỏ qua hoàn toàn một type

```java
@JsonIgnoreType  // Mọi field kiểu InternalMetadata đều bị ignore
public class InternalMetadata {
   private String traceId;
   private String serverNode;
   private long processingTimeMs;
}

@Data
public class OrderDTO {
   private UUID id;
   private String status;
   private InternalMetadata metadata; // Tự động bị ignore vì type đánh @JsonIgnoreType
}
```

### # nhóm serialization control

#### # @JsonFormat — định dạng output (date, number, enum)

```java
@Data
public class TransactionDTO {

   // Date formatting
   @JsonFormat(shape = JsonFormat.Shape.STRING, pattern = "dd/MM/yyyy HH:mm:ss")
   private LocalDateTime transactionDate;

   @JsonFormat(shape = JsonFormat.Shape.STRING, pattern = "yyyy-MM-dd")
   private LocalDate dueDate;

   @JsonFormat(shape = JsonFormat.Shape.NUMBER) // Epoch milliseconds
   private Instant timestamp;

   // Number formatting
   @JsonFormat(shape = JsonFormat.Shape.STRING) // Serialize number as string "1500.50"
   private BigDecimal amount;

   // Enum formatting
   @JsonFormat(shape = JsonFormat.Shape.NUMBER) // Serialize enum as ordinal index
   private OrderStatus status;

   // Timezone
   @JsonFormat(shape = JsonFormat.Shape.STRING, pattern = "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
              timezone = "Asia/Ho_Chi_Minh")
   private Date createdAt;
}
```

#### # @JsonSerialize / @JsonDeserialize — custom serializer/deserializer

```java
@Data
public class MoneyDTO {

   @JsonSerialize(using = MoneySerializer.class)
   @JsonDeserialize(using = MoneyDeserializer.class)
   private BigDecimal amount;

   @JsonSerialize(using = MaskEmailSerializer.class)
   private String email; // Output: "j***n@gmail.com"
}

// Custom Serializer
public class MoneySerializer extends JsonSerializer<BigDecimal> {
   @Override
   public void serialize(BigDecimal value, JsonGenerator gen, SerializerProvider provider)
           throws IOException {
       gen.writeString(value.setScale(2, RoundingMode.HALF_UP).toPlainString() + " VND");
   }
}

// Custom Deserializer
public class MoneyDeserializer extends JsonDeserializer<BigDecimal> {
   @Override
   public BigDecimal deserialize(JsonParser p, DeserializationContext ctx) throws IOException {
       String text = p.getText().replace(" VND", "").replace(",", "");
       return new BigDecimal(text);
   }
}

// Mask email serializer
public class MaskEmailSerializer extends JsonSerializer<String> {
   @Override
   public void serialize(String email, JsonGenerator gen, SerializerProvider provider)
           throws IOException {
       if (email == null || !email.contains("@")) {
           gen.writeString(email);
           return;
       }
       String[] parts = email.split("@");
       String masked = parts[0].charAt(0)
           + "***"
           + parts[0].charAt(parts[0].length() - 1)
           + "@" + parts[1];
       gen.writeString(masked);
   }
}
```

#### # @JsonRawValue — inject raw json string vào output

```java
@Data
public class ConfigDTO {
   private String name;

   @JsonRawValue  // Không escape, inject trực tiếp vào JSON output
   private String metadata; // value = "{\"key\":\"value\",\"nested\":{\"a\":1}}"
}
```

**Output:**

```json
{
  "name": "config-1",
  "metadata": { "key": "value", "nested": { "a": 1 } }
}
// Thay vì: "metadata": "{\"key\":\"value\",\"nested\":{\"a\":1}}"
```

#### # @JsonValue — serialize object thành 1 giá trị duy nhất

```java
public enum OrderStatus {
   PENDING("pending"),
   CONFIRMED("confirmed"),
   SHIPPED("shipped"),
   DELIVERED("delivered"),
   CANCELLED("cancelled");

   private final String value;

   OrderStatus(String value) { this.value = value; }

   @JsonValue  // Khi serialize → dùng value này thay vì enum name
   public String getValue() { return value; }

   @JsonCreator  // Khi deserialize → dùng method này để parse
   public static OrderStatus fromValue(String value) {
       return Arrays.stream(values())
           .filter(s -> s.value.equals(value))
           .findFirst()
           .orElseThrow(() -> new IllegalArgumentException("Unknown status: " + value));
   }
}
```

**JSON:** `"status": "confirmed"` thay vì `"status": "CONFIRMED"`

#### # @JsonGetter / @JsonSetter — custom getter/setter methods

```java
@Data
public class UserDTO {
   private String firstName;
   private String lastName;

   @JsonGetter("full_name")  // Thêm field ảo "full_name" vào JSON output
   public String getFullName() {
       return firstName + " " + lastName;
   }

   @JsonSetter("full_name")  // Parse "full_name" từ input
   public void setFullName(String fullName) {
       String[] parts = fullName.split(" ", 2);
       this.firstName = parts[0];
       this.lastName = parts.length > 1 ? parts[1] : "";
   }
}
```

### # nhóm deserialization control

#### # @JsonCreator — chỉ định constructor/factory để deserialize

```java
// Dùng với Immutable objects (không có setter)
public class Money {
   private final BigDecimal amount;
   private final String currency;

   @JsonCreator
   public Money(
           @JsonProperty("amount") BigDecimal amount,
           @JsonProperty("currency") String currency) {
       this.amount = amount;
       this.currency = currency;
   }

   // Getters only, no setters
   public BigDecimal getAmount() { return amount; }
   public String getCurrency() { return currency; }
}

// Factory method
public class Event {
   private final String type;
   private final Object payload;

   private Event(String type, Object payload) {
       this.type = type;
       this.payload = payload;
   }

   @JsonCreator
   public static Event create(
           @JsonProperty("type") String type,
           @JsonProperty("payload") Object payload) {
       // Validation logic
       if (type == null || type.isBlank()) throw new IllegalArgumentException("type required");
       return new Event(type, payload);
   }
}
```

#### # @JsonAnySetter / @JsonAnyGetter — dynamic properties (catch-all)

```java
@Data
public class DynamicConfigDTO {
   private String name;
   private String version;

   // Catch-all cho mọi field không khai báo explicitly
   private Map<String, Object> additionalProperties = new LinkedHashMap<>();

   @JsonAnySetter  // Khi deserialize: field không match → đưa vào map
   public void setAdditionalProperty(String key, Object value) {
       additionalProperties.put(key, value);
   }

   @JsonAnyGetter  // Khi serialize: flatten map vào root level
   public Map<String, Object> getAdditionalProperties() {
       return additionalProperties;
   }
}
```

**Input JSON:**

```json
{
  "name": "my-config",
  "version": "1.0",
  "timeout": 30,
  "retries": 3,
  "custom_flag": true
}
```

→ `name="my-config"`, `version="1.0"`, `additionalProperties={"timeout":30, "retries":3, "custom_flag":true}`

**Output JSON:** (flat, không nested map)

```json
{
  "name": "my-config",
  "version": "1.0",
  "timeout": 30,
  "retries": 3,
  "custom_flag": true
}
```

#### # @JsonSetter(nulls) — xử lý null/empty trong input

```java
@Data
public class UpdateProfileRequest {

   @JsonSetter(nulls = Nulls.SKIP)  // Nếu JSON gửi null → giữ giá trị cũ (không set null)
   private String displayName;

   @JsonSetter(nulls = Nulls.AS_EMPTY)  // null → empty string ""
   private String bio;

   @JsonSetter(contentNulls = Nulls.SKIP)  // Trong collection: skip null elements
   private List<String> tags;
}
```

#### # @JsonEnumDefaultValue — default value khi enum không match

```java
public enum Priority {
   HIGH,
   MEDIUM,
   LOW,

   @JsonEnumDefaultValue  // Khi JSON chứa giá trị không hợp lệ → dùng UNKNOWN
   UNKNOWN
}
```

Cần bật feature:

```java
@Bean
public ObjectMapper objectMapper() {
   return new ObjectMapper()
       .enable(DeserializationFeature.READ_UNKNOWN_ENUM_VALUES_USING_DEFAULT_VALUE);
}
```

### # nhóm polymorphism (đa hình)

#### # @JsonTypeInfo + @JsonSubTypes — serialize/deserialize class hierarchy

```java
// Base class
@Data
@JsonTypeInfo(
   use = JsonTypeInfo.Id.NAME,        // Dùng tên logic để phân biệt type
   include = JsonTypeInfo.As.PROPERTY, // Thêm field "type" vào JSON
   property = "type"                   // Tên field
)
@JsonSubTypes({
   @JsonSubTypes.Type(value = EmailNotification.class, name = "email"),
   @JsonSubTypes.Type(value = SmsNotification.class, name = "sms"),
   @JsonSubTypes.Type(value = PushNotification.class, name = "push")
})
public abstract class Notification {
   private UUID id;
   private String message;
   private LocalDateTime sentAt;
}

// Subclasses
@Data
@EqualsAndHashCode(callSuper = true)
public class EmailNotification extends Notification {
   private String to;
   private String subject;
   private List<String> cc;
}

@Data
@EqualsAndHashCode(callSuper = true)
public class SmsNotification extends Notification {
   private String phoneNumber;
   private String sender;
}

@Data
@EqualsAndHashCode(callSuper = true)
public class PushNotification extends Notification {
   private String deviceToken;
   private Map<String, String> data;
}
```

**JSON output/input:**

```json
{
  "type": "email",
  "id": "...",
  "message": "Hello",
  "sentAt": "2024-01-15T10:00:00",
  "to": "user@example.com",
  "subject": "Welcome",
  "cc": ["admin@example.com"]
}
```

**Controller nhận polymorphic request:**

```java
@PostMapping("/notifications")
public ResponseEntity<APIResponse<Void>> send(@RequestBody Notification notification) {
   // Jackson tự động deserialize đúng subclass dựa trên field "type"
   if (notification instanceof EmailNotification email) {
       emailService.send(email);
   } else if (notification instanceof SmsNotification sms) {
       smsService.send(sms);
   }
   return ResponseEntity.ok(APIResponse.success(null));
}

// Hoặc nhận List
@PostMapping("/notifications/batch")
public ResponseEntity<Void> sendBatch(@RequestBody List<Notification> notifications) {
   // Mỗi item trong list có thể là type khác nhau
   notifications.forEach(notificationDispatcher::dispatch);
   return ResponseEntity.ok().build();
}
```

#### # @JsonTypeInfo với EXISTING_PROPERTY

```java
// Dùng field đã có trong class (không thêm field mới)
@JsonTypeInfo(use = JsonTypeInfo.Id.NAME, property = "eventType",
             include = JsonTypeInfo.As.EXISTING_PROPERTY)
@JsonSubTypes({
   @JsonSubTypes.Type(value = OrderCreated.class, name = "ORDER_CREATED"),
   @JsonSubTypes.Type(value = OrderCancelled.class, name = "ORDER_CANCELLED")
})
@Data
public abstract class DomainEvent {
   private String eventType;  // Field này đã tồn tại, dùng luôn để phân biệt
   private Instant occurredAt;
}
```

### # nhóm object structure

#### # @JsonRootName — wrap response trong root element

```java
@Data
@JsonRootName("product")  // Cần enable WRAP_ROOT_VALUE feature
public class ProductDTO {
   private UUID id;
   private String name;
}
```

**Output khi enable:**

```json
{
  "product": {
    "id": "...",
    "name": "Laptop"
  }
}
```

Enable trong Spring Boot:

```yaml
spring:
  jackson:
    serialization:
      wrap-root-value: true
    deserialization:
      unwrap-root-value: true
```

#### # @JsonUnwrapped — flatten nested object vào parent

```java
@Data
public class OrderDTO {
   private UUID id;
   private String status;

   @JsonUnwrapped  // Flatten address fields vào OrderDTO level
   private Address address;

   @JsonUnwrapped(prefix = "billing_")  // Với prefix
   private Address billingAddress;
}

@Data
public class Address {
   private String street;
   private String city;
   private String zipCode;
}
```

**Output:**

```json
{
  "id": "...",
  "status": "confirmed",
  "street": "123 Main St",
  "city": "Hanoi",
  "zipCode": "100000",
  "billing_street": "456 Payment Ave",
  "billing_city": "HCMC",
  "billing_zipCode": "700000"
}
```

#### # @JsonManagedReference / @JsonBackReference — giải quyết circular reference (jpa)

```java
// Parent entity
@Entity
@Data
public class Department {
   @Id
   private UUID id;
   private String name;

   @OneToMany(mappedBy = "department")
   @JsonManagedReference  // Sẽ được serialize
   private List<Employee> employees;
}

// Child entity
@Entity
@Data
public class Employee {
   @Id
   private UUID id;
   private String name;

   @ManyToOne
   @JsonBackReference  // Sẽ KHÔNG được serialize (tránh infinite loop)
   private Department department;
}
```

**Output Department:**

```json
{
  "id": "...",
  "name": "Engineering",
  "employees": [
    { "id": "...", "name": "John" },
    { "id": "...", "name": "Jane" }
  ]
}
// Employee KHÔNG chứa lại department → tránh infinite recursion
```

#### # @JsonIdentityInfo — giải quyết circular reference bằng id

```java
@Data
@JsonIdentityInfo(generator = ObjectIdGenerators.PropertyGenerator.class, property = "id")
public class Employee {
   private UUID id;
   private String name;

   private Employee manager;       // Có thể reference Employee khác
   private List<Employee> reports; // Có thể circular
}
```

**Output:** Lần đầu serialize đầy đủ, lần sau chỉ serialize ID:

```json
{
  "id": "emp-001",
  "name": "Alice",
  "manager": null,
  "reports": [
    {
      "id": "emp-002",
      "name": "Bob",
      "manager": "emp-001",
      "reports": []
    }
  ]
}
```

#### # @JsonPropertyOrder — sắp xếp thứ tự fields trong json output

```java
@Data
@JsonPropertyOrder({"id", "status", "customer_name", "total", "created_at"})
public class OrderDTO {
   private BigDecimal total;
   private UUID id;            // Luôn ở đầu
   private String customerName;
   private String status;
   private LocalDateTime createdAt; // Luôn ở cuối
}

// Alphabetical order
@Data
@JsonPropertyOrder(alphabetic = true)
public class AlphabeticalDTO {
   private String zebra;   // output: apple, banana, zebra
   private String apple;
   private String banana;
}
```

### # nhóm views — hiển thị khác nhau cho cùng 1 object

#### # @JsonView — cùng dto, response khác nhau tùy context

```java
// Định nghĩa Views
public class Views {
   public interface Summary {}                    // Ít thông tin
   public interface Detail extends Summary {}     // Thông tin đầy đủ
   public interface Admin extends Detail {}       // Bao gồm internal fields
}

// DTO với nhiều view
@Data
public class UserDTO {

   @JsonView(Views.Summary.class)
   private UUID id;

   @JsonView(Views.Summary.class)
   private String username;

   @JsonView(Views.Detail.class)   // Chỉ thấy ở Detail trở lên
   private String email;

   @JsonView(Views.Detail.class)
   private String phone;

   @JsonView(Views.Admin.class)    // Chỉ Admin mới thấy
   private String role;

   @JsonView(Views.Admin.class)
   private LocalDateTime lastLoginAt;

   @JsonView(Views.Admin.class)
   private boolean isLocked;
}

// Controller dùng @JsonView
@RestController
@RequestMapping("/api/v1/users")
public class UserController {

   @GetMapping  // List → chỉ summary
   @JsonView(Views.Summary.class)
   public List<UserDTO> listUsers() {
       return userService.findAll();
   }

   @GetMapping("/{id}")  // Detail view
   @JsonView(Views.Detail.class)
   public UserDTO getUser(@PathVariable UUID id) {
       return userService.getById(id);
   }

   @GetMapping("/{id}/admin")  // Admin full view
   @JsonView(Views.Admin.class)
   @PreAuthorize("hasRole('ADMIN')")
   public UserDTO getUserAdmin(@PathVariable UUID id) {
       return userService.getById(id);
   }
}
```

**Response Summary:** `{"id":"...", "username":"john"}`
**Response Detail:** `{"id":"...", "username":"john", "email":"...", "phone":"..."}`
**Response Admin:** `{"id":"...", "username":"john", "email":"...", "phone":"...", "role":"ADMIN", "lastLoginAt":"...", "isLocked":false}`

### # nhóm filter — dynamic filtering

#### # @JsonFilter — lọc fields tại runtime

```java
@Data
@JsonFilter("dynamicFilter")
public class ProductDTO {
   private UUID id;
   private String name;
   private String description;
   private BigDecimal price;
   private String internalCode;
   private LocalDateTime createdAt;
}

// Service/Controller áp dụng filter
@GetMapping("/products")
public MappingJacksonValue listProducts(@RequestParam(required = false) String fields) {
   List<ProductDTO> products = productService.findAll();

   MappingJacksonValue wrapper = new MappingJacksonValue(products);

   if (fields != null) {
       // Chỉ trả về fields được yêu cầu
       Set<String> fieldSet = Set.of(fields.split(","));
       SimpleBeanPropertyFilter filter = SimpleBeanPropertyFilter.filterOutAllExcept(fieldSet);
       wrapper.setFilters(new SimpleFilterProvider().addFilter("dynamicFilter", filter));
   } else {
       // Trả về tất cả trừ internal fields
       SimpleBeanPropertyFilter filter = SimpleBeanPropertyFilter.serializeAllExcept("internalCode");
       wrapper.setFilters(new SimpleFilterProvider().addFilter("dynamicFilter", filter));
   }

   return wrapper;
}
```

**Request:** `GET /products?fields=id,name,price`
**Response:** `[{"id":"...", "name":"Laptop", "price":1500}]`

### # nhóm builder & constructor

#### # @JsonPOJOBuilder — dùng với lombok @Builder

```java
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@JsonDeserialize(builder = ProductDTO.ProductDTOBuilder.class)
public class ProductDTO {
   private UUID id;
   private String name;
   private BigDecimal price;

   @JsonPOJOBuilder(withPrefix = "")  // Lombok builder không có prefix "with"
   public static class ProductDTOBuilder {}
}
```

#### # @JsonCreator + @Builder — immutable dto

```java
@Value  // Lombok: final fields, getters only, no setters
@Builder
public class CreateOrderCommand {
   UUID customerId;
   List<OrderItem> items;
   String shippingAddress;

   @JsonCreator
   public CreateOrderCommand(
           @JsonProperty("customerId") UUID customerId,
           @JsonProperty("items") List<OrderItem> items,
           @JsonProperty("shippingAddress") String shippingAddress) {
       this.customerId = customerId;
       this.items = items != null ? List.copyOf(items) : List.of();
       this.shippingAddress = shippingAddress;
   }
}
```

### # nhóm mixin — thêm annotation mà không sửa class gốc

#### # @JsonMixin (jackson 2.13+) — annotate classes bạn không sở hữu

```java
// Class từ thư viện bên thứ 3 — không thể sửa
public class ThirdPartyUser {
   private String name;
   private String ssn;          // Sensitive — muốn ignore
   private String internalId;   // Internal — muốn ignore
   // getters/setters
}

// Tạo Mixin
@JsonIgnoreProperties({"ssn", "internalId"})
@JsonPropertyOrder({"name"})
public abstract class ThirdPartyUserMixin {

   @JsonProperty("user_name")
   abstract String getName();
}

// Đăng ký Mixin trong ObjectMapper config
@Configuration
public class JacksonConfig {

   @Bean
   public Jackson2ObjectMapperBuilderCustomizer customizer() {
       return builder -> builder.mixIn(ThirdPartyUser.class, ThirdPartyUserMixin.class);
   }
}
```

### # cấu hình global trong spring boot

#### # application.yml

```yaml
spring:
  jackson:
    # Serialization
    serialization:
      write-dates-as-timestamps: false # ISO-8601 string thay vì epoch
      write-durations-as-timestamps: false
      indent-output: false # Pretty print (true cho dev)
      fail-on-empty-beans: false # Không lỗi khi serialize empty object
      write-enums-using-to-string: false
      order-map-entries-by-keys: true

    # Deserialization
    deserialization:
      fail-on-unknown-properties: false # Bỏ qua unknown fields
      fail-on-null-for-primitives: true # Lỗi nếu primitive field = null
      accept-single-value-as-array: true # "tag" → ["tag"]
      read-unknown-enum-values-using-default-value: true

    # Other
    default-property-inclusion: non_null # Global NON_NULL
    date-format: "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
    time-zone: 'Asia/Ho_Chi_Minh'
    locale: 'vi_VN'

    # Modules
    mapper:
      default-view-inclusion: true
```

#### # custom ObjectMapper bean

```java
@Configuration
public class JacksonConfig {

   @Bean
   public ObjectMapper objectMapper() {
       ObjectMapper mapper = new ObjectMapper();

       // Modules
       mapper.registerModule(new JavaTimeModule());          // Java 8 date/time
       mapper.registerModule(new Jdk8Module());             // Optional support
       mapper.registerModule(new ParameterNamesModule());   // Constructor param names

       // Serialization
       mapper.disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS);
       mapper.disable(SerializationFeature.FAIL_ON_EMPTY_BEANS);
       mapper.setSerializationInclusion(JsonInclude.Include.NON_NULL);

       // Deserialization
       mapper.disable(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES);
       mapper.enable(DeserializationFeature.READ_UNKNOWN_ENUM_VALUES_USING_DEFAULT_VALUE);
       mapper.enable(DeserializationFeature.ACCEPT_SINGLE_VALUE_AS_ARRAY);

       // Naming strategy (global)
       mapper.setPropertyNamingStrategy(PropertyNamingStrategies.SNAKE_CASE);

       // Date format
       mapper.setDateFormat(new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"));
       mapper.setTimeZone(TimeZone.getTimeZone("Asia/Ho_Chi_Minh"));

       return mapper;
   }

   // Hoặc dùng Customizer (không replace toàn bộ)
   @Bean
   public Jackson2ObjectMapperBuilderCustomizer jsonCustomizer() {
       return builder -> builder
           .featuresToDisable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS)
           .featuresToDisable(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES)
           .serializationInclusion(JsonInclude.Include.NON_NULL)
           .modules(new JavaTimeModule());
   }
}
```

### # patterns thực tế trong spring boot

#### # pattern 1: request/response dto tách biệt

```java
// Request DTO — chỉ nhận những gì cần
@Data
@JsonIgnoreProperties(ignoreUnknown = true)
public class CreateProductRequest {

   @NotBlank
   @JsonProperty("name")
   private String name;

   @NotNull
   @Positive
   private BigDecimal price;

   @JsonProperty("category_code")
   private String categoryCode;

   @JsonInclude(JsonInclude.Include.NON_EMPTY)
   private Map<String, String> attributes;
}

// Response DTO — trả về format chuẩn
@Data
@Builder
@JsonNaming(PropertyNamingStrategies.SnakeCaseStrategy.class)
@JsonInclude(JsonInclude.Include.NON_NULL)
public class ProductResponse {
   private UUID id;
   private String name;
   private BigDecimal price;
   private String categoryCode;
   private String categoryName;
   private Map<String, String> attributes;

   @JsonFormat(shape = JsonFormat.Shape.STRING, pattern = "yyyy-MM-dd'T'HH:mm:ss")
   private LocalDateTime createdAt;

   @JsonFormat(shape = JsonFormat.Shape.STRING, pattern = "yyyy-MM-dd'T'HH:mm:ss")
   private LocalDateTime updatedAt;
}
```

#### # pattern 2: generic api response wrapper

```java
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@JsonInclude(JsonInclude.Include.NON_NULL)
public class APIResponse<T> {

   @JsonProperty("status_code")
   private int statusCode;

   private String message;
   private T data;

   @JsonProperty("error_code")
   private String errorCode;

   @JsonFormat(shape = JsonFormat.Shape.STRING, pattern = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'")
   private Instant timestamp;

   @JsonProperty("trace_id")
   private String traceId;

   // Pagination info (null nếu không phân trang)
   @JsonProperty("page_info")
   private PageInfo pageInfo;

   @Data
   @Builder
   public static class PageInfo {
       private int page;
       private int size;

       @JsonProperty("total_elements")
       private long totalElements;

       @JsonProperty("total_pages")
       private int totalPages;
   }
}
```

#### # pattern 3: enum với display values

```java
public enum DocumentStatus {
   DRAFT("Bản nháp", 1),
   PENDING_REVIEW("Chờ duyệt", 2),
   APPROVED("Đã duyệt", 3),
   REJECTED("Từ chối", 4),
   ARCHIVED("Lưu trữ", 5);

   private final String displayName;
   private final int order;

   DocumentStatus(String displayName, int order) {
       this.displayName = displayName;
       this.order = order;
   }

   @JsonValue
   public Map<String, Object> toJson() {
       return Map.of(
           "code", name(),
           "display", displayName,
           "order", order
       );
   }

   @JsonCreator
   public static DocumentStatus fromCode(String code) {
       // Hỗ trợ cả input là string "DRAFT" hoặc object {"code":"DRAFT"}
       return valueOf(code.toUpperCase());
   }
}
```

**Output:**

```json
{
  "status": {
    "code": "PENDING_REVIEW",
    "display": "Chờ duyệt",
    "order": 2
  }
}
```

#### # pattern 4: sensitive data masking

```java
@Data
public class CustomerDTO {
   private String name;

   @JsonSerialize(using = MaskPhoneSerializer.class)
   private String phone;  // Output: "****567890"

   @JsonSerialize(using = MaskIdCardSerializer.class)
   private String idCard; // Output: "***456***"

   @JsonProperty(access = JsonProperty.Access.WRITE_ONLY)
   private String bankAccount; // Không bao giờ return
}

public class MaskPhoneSerializer extends JsonSerializer<String> {
   @Override
   public void serialize(String value, JsonGenerator gen, SerializerProvider prov) throws IOException {
       if (value == null || value.length() < 6) {
           gen.writeString("****");
           return;
       }
       gen.writeString("****" + value.substring(value.length() - 6));
   }
}
```

### # xử lý các trường hợp đặc biệt

#### # java 8+ Date/Time (LocalDate, LocalDateTime, Instant)

```java
// Cần module
// spring-boot-starter-web đã include jackson-datatype-jsr310
@Data
public class EventDTO {

   @JsonFormat(pattern = "yyyy-MM-dd")
   private LocalDate eventDate;

   @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ss")
   private LocalDateTime startTime;

   // Instant mặc định serialize thành epoch seconds → đổi thành ISO string
   @JsonFormat(shape = JsonFormat.Shape.STRING)
   private Instant createdAt;

   @JsonFormat(pattern = "HH:mm:ss")
   private LocalTime checkInTime;

   // Duration mặc định serialize thành seconds → đổi thành string "PT30M"
   @JsonFormat(shape = JsonFormat.Shape.STRING)
   private Duration timeout;
}
```

#### # optional fields

```java
// Cần jackson-datatype-jdk8 (đã có trong starter-web)
@Data
public class SearchRequest {

   private String keyword;

   // Optional.empty() → null → bỏ qua nếu dùng NON_NULL/NON_ABSENT
   @JsonInclude(JsonInclude.Include.NON_ABSENT)
   private Optional<String> category;

   @JsonInclude(JsonInclude.Include.NON_ABSENT)
   private Optional<BigDecimal> minPrice;
}
```

#### # Generics và TypeReference

```java
// Khi deserialize generic types, cần TypeReference
ObjectMapper mapper = new ObjectMapper();

// Deserialize List<ProductDTO>
List<ProductDTO> products = mapper.readValue(json,
   new TypeReference<List<ProductDTO>>() {});

// Deserialize APIResponse<List<ProductDTO>>
APIResponse<List<ProductDTO>> response = mapper.readValue(json,
   new TypeReference<APIResponse<List<ProductDTO>>>() {});

// Deserialize Map<String, List<String>>
Map<String, List<String>> groupedTags = mapper.readValue(json,
   new TypeReference<Map<String, List<String>>>() {});
```

#### # record classes (java 16+)

```java
// Jackson hỗ trợ Java Records từ 2.12+
@JsonNaming(PropertyNamingStrategies.SnakeCaseStrategy.class)
@JsonInclude(JsonInclude.Include.NON_NULL)
public record ProductRecord(
   UUID id,
   String name,
   @JsonProperty("unit_price") BigDecimal price,
   @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ss") LocalDateTime createdAt
) {}

// Record + custom deserialization
public record Money(
   @JsonProperty("amount") BigDecimal amount,
   @JsonProperty("currency") String currency
) {
   @JsonCreator
   public Money {}  // Compact canonical constructor
}
```

### # troubleshooting — lỗi thường gặp

#### # lỗi 1: InvalidDefinitionException — no serializer found

```
com.fasterxml.jackson.databind.exc.InvalidDefinitionException:
No serializer found for class X and no properties discovered
```

**Nguyên nhân:** Class không có getter hoặc public fields
**Fix:**

```java
// Thêm @Data (Lombok) hoặc getters
// Hoặc disable feature:
mapper.disable(SerializationFeature.FAIL_ON_EMPTY_BEANS);
```

#### # lỗi 2: UnrecognizedPropertyException — unknown field

```
com.fasterxml.jackson.databind.exc.UnrecognizedPropertyException:
Unrecognized field "unknown_field"
```

**Fix:**

```java
// Class level
@JsonIgnoreProperties(ignoreUnknown = true)

// Hoặc global
spring.jackson.deserialization.fail-on-unknown-properties=false
```

#### # lỗi 3: infinite recursion — StackOverflowError (jpa entities)

```
com.fasterxml.jackson.databind.JsonMappingException: Infinite recursion
```

**Fix:**

```java
// Option 1: @JsonManagedReference + @JsonBackReference
// Option 2: @JsonIdentityInfo
// Option 3: KHÔNG serialize entities trực tiếp → dùng DTO
// (RECOMMENDED: Luôn dùng DTO, không serialize Entity ra controller)
```

#### # lỗi 4: cannot deserialize LocalDateTime

```
com.fasterxml.jackson.databind.exc.InvalidDefinitionException:
Cannot construct instance of `java.time.LocalDateTime`
```

**Fix:**

```java
// Đảm bảo register JavaTimeModule
@Bean
public Jackson2ObjectMapperBuilderCustomizer jsonCustomizer() {
   return builder -> builder.modules(new JavaTimeModule());
}

// Hoặc trong application.yml
spring.jackson.serialization.write-dates-as-timestamps=false
```

#### # lỗi 5: MismatchedInputException — cannot deserialize enum

```
Cannot deserialize value of type `OrderStatus` from String "pending"
```

**Fix:**

```java
// Option 1: @JsonCreator trên enum
@JsonCreator
public static OrderStatus fromValue(String value) {
   return Arrays.stream(values())
       .filter(e -> e.name().equalsIgnoreCase(value))
       .findFirst()
       .orElse(UNKNOWN);
}

// Option 2: Global setting
mapper.enable(DeserializationFeature.READ_ENUMS_USING_TO_STRING);
// + @JsonValue trên toString() hoặc getter
```

### # 14. annotation quick reference

| Annotation            | Serialize | Deserialize | Mục đích                          |
| --------------------- | :-------: | :---------: | --------------------------------- |
| @JsonProperty         |     ✓     |      ✓      | Đổi tên field                     |
| @JsonAlias            |           |      ✓      | Nhận nhiều tên                    |
| @JsonIgnore           |     ✓     |      ✓      | Bỏ qua field                      |
| @JsonIgnoreProperties |     ✓     |      ✓      | Bỏ nhiều fields / ignore unknown  |
| @JsonInclude          |     ✓     |             | Kiểm soát inclusion (null, empty) |
| @JsonFormat           |     ✓     |      ✓      | Định dạng date/number             |
| @JsonSerialize        |     ✓     |             | Custom serializer                 |
| @JsonDeserialize      |           |      ✓      | Custom deserializer               |
| @JsonCreator          |           |      ✓      | Custom constructor/factory        |
| @JsonValue            |     ✓     |             | Serialize object thành 1 value    |
| @JsonRawValue         |     ✓     |             | Inject raw JSON                   |
| @JsonUnwrapped        |     ✓     |      ✓      | Flatten nested object             |
| @JsonManagedReference |     ✓     |      ✓      | Parent side (circular ref)        |
| @JsonBackReference    |           |      ✓      | Child side (circular ref)         |
| @JsonIdentityInfo     |     ✓     |      ✓      | Resolve circular by ID            |
| @JsonTypeInfo         |     ✓     |      ✓      | Polymorphic type handling         |
| @JsonSubTypes         |           |      ✓      | Subclass mapping                  |
| @JsonView             |     ✓     |      ✓      | Multiple views cho cùng DTO       |
| @JsonFilter           |     ✓     |             | Dynamic field filtering           |
| @JsonNaming           |     ✓     |      ✓      | Naming strategy cho class         |
| @JsonPropertyOrder    |     ✓     |             | Thứ tự fields                     |
| @JsonRootName         |     ✓     |      ✓      | Root wrapper element              |
| @JsonAnySetter        |           |      ✓      | Catch-all unknown fields          |
| @JsonAnyGetter        |     ✓     |             | Flatten map vào output            |
| @JsonGetter           |     ✓     |             | Custom getter method              |
| @JsonSetter           |           |      ✓      | Custom setter + null handling     |

### # kết luận

Jackson annotations là công cụ mạnh để kiểm soát chính xác JSON serialization/deserialization trong Spring Boot. Một số nguyên tắc:

1. **Luôn dùng DTO** thay vì serialize JPA Entity trực tiếp — tránh infinite recursion, data leak
2. **Global config trước** (application.yml) → override per-class/per-field khi cần
3. **@JsonInclude(NON_NULL)** nên đặt global — response sạch hơn
4. **@JsonIgnoreProperties(ignoreUnknown = true)** nên đặt global — tránh lỗi khi API thay đổi
5. **@JsonFormat cho dates** — luôn explicit format, không rely on default
6. **@JsonView** khi cần multiple representations — đỡ tạo nhiều DTO classes
7. **Custom serializer** chỉ khi annotation không đủ — giữ simple trước

> Chỉ là những ghi chép cá nhân với hy vọng mang lại chút giá trị. Nếu thấy hữu ích, đừng ngại chia sẻ cho bạn bè & đồng nghiệp nhé!

Happy coding <Twemoji emoji="clinking-beer-mugs" /> 😎 👍🏻 🚀 🔥.
