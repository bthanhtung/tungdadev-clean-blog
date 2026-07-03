---
layout: post
title: "jakarta bean validation & spring validation"
date: 2023-10-25 19:29:39 +0700
categories: [Software Development]
tags: [java, software-development, spring-framework, best-practices, vietnamese]
---

### # giới thiệu

"Never trust user input" — nguyên tắc security số 1. Mọi data từ bên ngoài (HTTP request, message queue, file import) phải được validate trước khi xử lý. Validation không chỉ chống injection — nó đảm bảo business rules được enforce ngay ở boundary.

Spring Boot tích hợp Jakarta Bean Validation (Hibernate Validator implementation) — declarative validation bằng annotations. Thay vì viết hàng chục `if (field == null || field.isEmpty())`, đánh `@NotBlank` và để framework lo.

Với Senior, validation strategy quan trọng hơn individual annotations: validate ở đâu (controller vs service vs entity), custom constraints cho business rules, validation groups cho different operations, và i18n error messages.

### # standard validation annotations

Đây là những annotations bạn dùng hàng ngày trên DTOs. Chúng đến từ `jakarta.validation.constraints` (trước đây `javax.validation`).

```java
@Data
public class CreateProductRequest {

   // String validations
   @NotNull(message = "Name must not be null")
   @NotBlank(message = "Name must not be blank")  // not null + not empty + not whitespace
   @Size(min = 2, max = 255, message = "Name must be 2-255 characters")
   private String name;

   @NotBlank
   @Pattern(regexp = "^[A-Z]{2,5}-\\d{3,6}$", message = "Code format: XX-000 to XXXXX-000000")
   private String code;

   @Email(message = "Invalid email format")
   private String contactEmail;

   @Size(max = 2000, message = "Description max 2000 characters")
   private String description;

   // Numeric validations
   @NotNull(message = "Price is required")
   @Positive(message = "Price must be positive")
   @DecimalMax(value = "99999999.99", message = "Price exceeds maximum")
   private BigDecimal price;

   @Min(value = 0, message = "Quantity cannot be negative")
   @Max(value = 100000, message = "Quantity exceeds maximum")
   private Integer quantity;

   @PositiveOrZero
   private BigDecimal discount;

   // Date validations
   @Future(message = "Expiry date must be in the future")
   private LocalDate expiryDate;

   @PastOrPresent(message = "Created date cannot be in the future")
   private LocalDateTime createdAt;

   // Collection validations
   @NotEmpty(message = "At least one tag is required")
   @Size(max = 10, message = "Maximum 10 tags")
   private List<@NotBlank(message = "Tag cannot be blank") String> tags;

   // Nested object validation
   @Valid  // Trigger validation cho nested object
   @NotNull(message = "Category is required")
   private CategoryRef category;

   // Boolean
   @AssertTrue(message = "Must accept terms")
   private Boolean termsAccepted;
}

@Data
public class CategoryRef {
   @NotNull
   private UUID id;

   @NotBlank
   @Size(max = 50)
   private String code;
}
```

#### # quick reference — built-in constraints

| Annotation                | Applies to                  | Validates                          |
| ------------------------- | --------------------------- | ---------------------------------- |
| @NotNull                  | Any                         | != null                            |
| @NotBlank                 | String                      | != null, not empty, not whitespace |
| @NotEmpty                 | String/Collection/Map/Array | != null, size > 0                  |
| @Size(min,max)            | String/Collection/Map/Array | Size within range                  |
| @Min(value)               | Numeric                     | `>=` value                         |
| `@Max(value)`             | Numeric                     | `<=` value                         |
| @Positive                 | Numeric                     | `>` 0                              |
| @PositiveOrZero           | Numeric                     | `>=` 0                             |
| @Negative                 | Numeric                     | `<` 0                              |
| @DecimalMin               | Numeric                     | `>=` value (string comparison)     |
| @DecimalMax               | Numeric                     | `<=` value                         |
| @Digits(integer,fraction) | Numeric                     | Digit count constraints            |
| @Email                    | String                      | Valid email format                 |
| @Pattern(regexp)          | String                      | Matches regex                      |
| @Past                     | Date/Time                   | Before now                         |
| @PastOrPresent            | Date/Time                   | Before or equal now                |
| @Future                   | Date/Time                   | After now                          |
| @FutureOrPresent          | Date/Time                   | After or equal now                 |
| @AssertTrue               | Boolean                     | Must be true                       |
| @AssertFalse              | Boolean                     | Must be false                      |

### # custom constraints — business rule validation

Built-in annotations cover generic cases. Business rules cần custom constraints. Ví dụ: validate VPBank account number format, check product code uniqueness, validate Vietnamese phone number.

Pattern: tạo annotation + tạo validator class.

```java
// === Custom annotation ===
@Target({ElementType.FIELD, ElementType.PARAMETER})
@Retention(RetentionPolicy.RUNTIME)
@Constraint(validatedBy = ValidPhoneNumberValidator.class)
@Documented
public @interface ValidPhoneNumber {
   String message() default "Invalid Vietnamese phone number";
   Class<?>[] groups() default {};
   Class<? extends Payload>[] payload() default {};
}

// === Validator implementation ===
public class ValidPhoneNumberValidator implements ConstraintValidator<ValidPhoneNumber, String> {

   private static final Pattern VN_PHONE = Pattern.compile("^(\\+84|0)(3|5|7|8|9)\\d{8}$");

   @Override
   public boolean isValid(String value, ConstraintValidatorContext context) {
       if (value == null) return true;  // @NotNull handles null — separation of concerns
       return VN_PHONE.matcher(value).matches();
   }
}

// === Usage ===
@Data
public class CreateCustomerRequest {
   @NotBlank
   private String name;

   @NotBlank
   @ValidPhoneNumber
   private String phoneNumber;
}
```

#### # cross-field validation — class-level constraint

Khi validation cần so sánh nhiều fields (password confirm, date range, conditional required):

```java
// Annotation trên class level
@Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)
@Constraint(validatedBy = ValidDateRangeValidator.class)
public @interface ValidDateRange {
   String message() default "End date must be after start date";
   Class<?>[] groups() default {};
   Class<? extends Payload>[] payload() default {};
   String startField();
   String endField();
}

// Validator
public class ValidDateRangeValidator implements ConstraintValidator<ValidDateRange, Object> {

   private String startField;
   private String endField;

   @Override
   public void initialize(ValidDateRange annotation) {
       this.startField = annotation.startField();
       this.endField = annotation.endField();
   }

   @Override
   public boolean isValid(Object obj, ConstraintValidatorContext ctx) {
       try {
           LocalDate start = (LocalDate) BeanUtils.getPropertyDescriptor(obj.getClass(), startField)
               .getReadMethod().invoke(obj);
           LocalDate end = (LocalDate) BeanUtils.getPropertyDescriptor(obj.getClass(), endField)
               .getReadMethod().invoke(obj);

           if (start == null || end == null) return true;
           return end.isAfter(start);
       } catch (Exception e) {
           return false;
       }
   }
}

// Usage
@Data
@ValidDateRange(startField = "startDate", endField = "endDate")
public class ReportRequest {
   @NotNull
   private LocalDate startDate;

   @NotNull
   private LocalDate endDate;
}
```

### # validation groups — different rules for different operations

Cùng 1 DTO nhưng Create cần validate khác Update: Create không có ID, Update bắt buộc có ID. Validation Groups giải quyết.

```java
// Define groups
public interface OnCreate {}
public interface OnUpdate {}

// DTO với groups
@Data
public class ProductRequest {

   @Null(groups = OnCreate.class, message = "ID must be null when creating")
   @NotNull(groups = OnUpdate.class, message = "ID is required when updating")
   private UUID id;

   @NotBlank(groups = {OnCreate.class, OnUpdate.class})
   private String name;

   @NotNull(groups = OnCreate.class, message = "Price required on creation")
   private BigDecimal price;

   @NotBlank(groups = OnCreate.class)
   private String code;  // Required only on create, immutable after
}

// Controller specifies which group to validate
@PostMapping
public ProductDTO create(@Validated(OnCreate.class) @RequestBody ProductRequest request) { ... }

@PutMapping("/{id}")
public ProductDTO update(
       @PathVariable UUID id,
       @Validated(OnUpdate.class) @RequestBody ProductRequest request) { ... }
```

### # method-level validation — @Validated on class

Validate method parameters (không chỉ @RequestBody). Hữu ích cho service layer validation.

```java
@Service
@Validated  // Enable method-level validation
public class ProductService {

   public ProductDTO getById(@NotNull UUID id) {
       return productRepository.findById(id)
           .map(this::toDTO)
           .orElseThrow();
   }

   public Page<ProductDTO> search(
           @Size(min = 2, max = 100) String keyword,
           @Min(0) int page,
           @Min(1) @Max(100) int size) {
       return productRepository.search(keyword, PageRequest.of(page, size)).map(this::toDTO);
   }

   public void updatePrice(
           @NotNull UUID id,
           @Positive @DecimalMax("99999999.99") BigDecimal newPrice) {
       // ConstraintViolationException nếu params invalid
   }
}
```

### # error response — xử lý validation errors đẹp

```java
@RestControllerAdvice
public class ValidationExceptionHandler {

   // @RequestBody validation errors
   @ExceptionHandler(MethodArgumentNotValidException.class)
   @ResponseStatus(HttpStatus.BAD_REQUEST)
   public APIResponse<List<FieldError>> handleValidation(MethodArgumentNotValidException ex) {
       List<FieldError> errors = ex.getBindingResult().getFieldErrors().stream()
           .map(fe -> new FieldError(fe.getField(), fe.getDefaultMessage(), fe.getRejectedValue()))
           .toList();
       return APIResponse.error("VALIDATION_ERROR", "Input validation failed", errors);
   }

   // Method param validation errors (@Validated on class)
   @ExceptionHandler(ConstraintViolationException.class)
   @ResponseStatus(HttpStatus.BAD_REQUEST)
   public APIResponse<List<String>> handleConstraint(ConstraintViolationException ex) {
       List<String> errors = ex.getConstraintViolations().stream()
           .map(v -> v.getPropertyPath() + ": " + v.getMessage())
           .toList();
       return APIResponse.error("CONSTRAINT_ERROR", "Parameter validation failed", errors);
   }

   @Data
   @AllArgsConstructor
   public static class FieldError {
       private String field;
       private String message;
       private Object rejectedValue;
   }
}
```

**Response example:**

```json
{
  "status_code": 400,
  "error_code": "VALIDATION_ERROR",
  "message": "Input validation failed",
  "data": [
    {
      "field": "name",
      "message": "Name must not be blank",
      "rejectedValue": ""
    },
    {
      "field": "price",
      "message": "Price must be positive",
      "rejectedValue": -10
    },
    {
      "field": "code",
      "message": "Code format: XX-000 to XXXXX-000000",
      "rejectedValue": "abc"
    }
  ]
}
```

### # validation best practices

1. **Validate at boundary** — Controller DTOs (input) và trước gọi external services (output)
2. **Custom constraints cho business rules** — không validate business logic bằng if/else trong service
3. **@NotNull vs @NotBlank vs @NotEmpty** — hiểu rõ sự khác nhau (null, "", " " )
4. **Custom constraint KHÔNG nên query DB** — tránh waste connection pool. Check uniqueness trong service layer
5. **i18n messages** — dùng message keys `{jakarta.validation.constraints.NotBlank.message}` thay vì hardcode
6. **Fail fast** — validate input đầu tiên, trước mọi business logic
7. **Separate request DTOs** — Create ≠ Update ≠ Patch. Mỗi operation có validation rules riêng

> Chỉ là những ghi chép cá nhân với hy vọng mang lại chút giá trị. Nếu thấy hữu ích, đừng ngại chia sẻ cho bạn bè & đồng nghiệp nhé!

Happy coding <Twemoji emoji="clinking-beer-mugs" /> 😎 👍🏻 🚀 🔥.
