---
layout: post
title: "Java coding convention"
date: 2025-01-07 19:29:39 +0700
categories: [Software Development]
tags: [java, software-development, coding-convention, best-practices, vietnamese]
---

Sau nhiều năm đắm chìm trong thế giới coding, trải qua nhiều dự án lớn nhỏ trong và ngoài nước , tôi nhận ra một điều: **Coding Convention** không chỉ là _"quy tắc viết code"_ – mà là cách một team giao tiếp, hợp tác và cùng nhau phát triển.

Một đội ngũ mạnh không phải nhờ từng cá nhân giỏi, mà nhờ khả năng hiểu nhau qua từng dòng code, review hiệu quả và phối hợp trơn tru trong xuyên suốt quá trình làm việc và phát triển cùng nhau.

Trong bài viết này, tôi muốn chia sẻ góc nhìn của mình về Coding Convention cho backend Java, dựa trên chuẩn Google Java Style Guide, kết hợp với kinh nghiệm và một số best practices giúp đội ngũ phát triển nhanh – sạch – bền vững.

### # tại sao coding convention lại quan trọng?

Có ba điều khiến convention trở thành yếu tố bắt buộc chứ không chỉ "khuyến nghị":

#### # code là tài sản chung

Dự án sống 2–3 năm thậm chí là vài chục năm, người thì rời team - người mới join vào. Mỗi người một style, thứ đảm bảo codebase được nhất quán suông sẻ chính là Coding convention.

Convention giúp code trở thành dạng "documentation thực tế", nhất quán và có thể đọc hiểu dễ dàng.

#### # giảm friction khi review

Một team có thể tiết kiệm 30–40% thời gian review pull request nếu:

- không tranh luận về style
- không sửa các lỗi vặt như spacing, naming, indentation
- tập trung vào logic & kiến trúc
- ...

#### # hạn chế bugs và tăng maintainability

Một số quy tắc naming, cấu trúc class, tổ chức package giúp kiến trúc ổn định, giảm lỗi tiềm ẩn và đảm bảo mở rộng dễ dàng khi hệ thống lớn dần.

### # các nguyên tắc quan trọng trong Google Java Style Guide

#### 1. Naming – đặt tên cho ra hồn

- Class: `PascalCase` → `UserService`, `OrderController`
- Method & variable: `camelCase` → `calculatePrice()`, `requestId`
- Constant: `UPPER_SNAKE_CASE` → `DEFAULT_TIMEOUT_MS`
- Package: toàn chữ thường, không underscore → `com.tungdadev.payment.service`

Note: Tên phải mô tả được mục đích, không mô tả kiểu dữ liệu.

Bad → `data`, `obj`, `tmp`

Good → `paymentRequest`, `sessionToken`

#### 2. Class & package structure

Để tránh loạn, nên dùng 1 layout chuẩn kiểu Clean Architecture:

```plaintext
/controller
/service
/service/impl
/repository
/model
/model/entity
/model/dto/request
/model/dto/response
/config
/exception
/util
```

#### 3. Java coding style (chuẩn Google)

Indentation: 2 spaces (Google), nhưng đa số team chọn 4 spaces cho dễ nhìn → Miễn đồng nhất toàn repo.

Line length: Tối đa **120 chars** (thực tế hơn chuẩn 100 chars của Google).

Braces

```java
if (condition) {
    // code
} else {
    // code
}
```

Không bao giờ được bỏ `{}` — hạn chế bug khi thêm dòng mới. Trừ trường hợp chỉ có mỗi `return`

Comment WHY, không phải WHAT & JavaDoc cho public method hoặc những logic phức tạp
Bad:

```java
i++; // increase i by 1
```

Good:

```javajava
// Retry until circuit breaker is half-open to avoid overloading external API
retryPolicy.execute();
```

#### 4. Logging convention

Mọi log phải có `traceId` (tự generate hoặc từ gateway).

Không log info khi không cần.

Không log dữ liệu nhạy cảm (token, password, phone, OTP…)

Format chuẩn:

```java
log.info("[traceId={}] Create order for user={}, amount={}", traceId, userId, amount);
```

Exception: `log.error("...", e)` (phải để stack trace).

#### 5. Exception Handling

Rule:

- Không throw Exception chung chung.
- Tạo BusinessException + enum code.

- Template:

```java
throw new BusinessException(ErrorCode.PAYMENT_FAILED, "Payment gateway error");
```

- ControllerAdvice: Bắt lỗi và trả JSON thống nhất:

```java
{
  "code": "PAYMENT_FAILED",
  "message": "Payment gateway error"
}
```

#### 6. REST API Style

URL: danh từ số nhiều → `/users`, `/orders/{id}`

Không dùng động từ trong URL.

Dùng HTTP status đúng nghĩa:

- 200 OK
- 201 Created
- 400 Bad Request
- 404 Not Found
- 409 Conflict
- 500 Internal Server Error

#### 7. DTO vs Entity

Không bao giờ return entity ra ngoài.

Phải dùng DTO tách bạch.

Bad:

```java
return userRepository.findById(id);
```

Good:

```java
return mapper.toResponse(user);
```

#### 8. Dependency Injection

Không `"new"` tùm lum trong service.

Dùng constructor injection:

```java
@RequiredArgsConstructor
@Service
public class PaymentService {
    private final UserRepository userRepository;
}
```

#### 9. Null Handling

Không return null (trừ cực kỳ cần).

Dùng `Optional` cho repository.

Check null rõ ràng, không lạm dụng Optional trong entity.

#### 10. Testing

Unit test phải test logic thuần (không đánh DB…).

Test đặt tên dạng BDD:

```java
shouldCalculateDiscountCorrectly_whenUserIsVIP
```

Không để test mơ hồ, đảm bảo mỗi test-case được xem là một document cho chức năng.

### # kết luận

Một team backend mạnh không phải team viết code hay, mà là team viết code giống nhau, hiểu nhau và cùng nhau tiến bộ.

Coding Convention:

- giảm friction
- tăng chất lượng
- thúc đẩy tốc độ
- và quan trọng nhất: tạo một văn hóa kỹ thuật kỷ luật và chuyên nghiệp

Với vai trò là một Software Engineer, hãy không chỉ viết code tốt – mà còn tạo ra chuẩn mực để cả đội cùng phát triển.

`Coding Convention` là bước đầu của một engineering culture mạnh

> Chỉ là những ghi chép cá nhân với hy vọng mang lại chút giá trị. Nếu thấy hữu ích, đừng ngại chia sẻ cho bạn bè & đồng nghiệp nhé!

Happy coding <Twemoji emoji="clinking-beer-mugs" /> 😎 👍🏻 🚀 🔥.

**Reference**:

- [**Google Java Style Guide**](https://google.github.io/styleguide/javaguide.html)
