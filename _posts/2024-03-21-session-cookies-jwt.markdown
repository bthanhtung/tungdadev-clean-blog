---
layout: post
title: "session, cookies & jwt"
date: 2024-03-21 19:29:39 +0700
categories: [Software Development]
tags: [java, software-development, session, cookies, jwt, vietnamese]
---

Trong phát triển ứng dụng web, việc xử lý thông tin người dùng là một yếu tố quan trọng để xây dựng các ứng dụng an toàn và hiệu quả. Ba công nghệ phổ biến được sử dụng để quản lý và lưu trữ thông tin phiên làm việc của người dùng là Session, Cookies, và JWT (JSON Web Token). Mỗi công nghệ này có những đặc điểm riêng, ưu nhược điểm khác nhau và ứng dụng cụ thể tùy thuộc vào yêu cầu của ứng dụng.

Trong bài viết này, chúng ta sẽ tìm hiểu chi tiết sự khác biệt giữa ba công nghệ này, cách thức hoạt động của chúng, kèm theo code minh hoạ bằng Java.

Bắt đầu thôi :)))

### # session

`Session` là một cơ chế lưu trữ thông tin tạm thời trên server, được sử dụng để duy trì trạng thái của người dùng trong suốt phiên làm việc. Khi người dùng truy cập vào trang web, server sẽ tạo ra một `session` mới và lưu trữ các thông tin liên quan đến người dùng (chẳng hạn như thông tin đăng nhập, quyền hạn, v.v.).

**_Cách hoạt động của Session_**: \

- Khi người dùng truy cập trang web, server sẽ tạo ra một session và lưu trữ thông tin người dùng trên server.
- Server sẽ tạo ra một ID session duy nhất và gửi ID này cho trình duyệt của người dùng thông qua cookie.
- Mỗi lần người dùng gửi yêu cầu đến server, ID session sẽ được gửi lại qua cookie, giúp server nhận diện người dùng và lấy lại thông tin đã lưu trữ.

**_Ưu điểm_**:

- Thông tin người dùng được lưu trữ trên server, giúp bảo mật hơn vì không lưu trữ thông tin nhạy cảm trên client.
- Server có thể dễ dàng quản lý và thay đổi dữ liệu liên quan đến session của người dùng.

**_Nhược điểm_**:

- Session có thể gây tải cho server vì phải lưu trữ nhiều dữ liệu người dùng.
- Nếu server bị tắt hoặc gặp sự cố, thông tin session có thể bị mất.

**_Ví dụ_**:

```java
@RestController
public class SessionController {
    @GetMapping("/login")
    public String login(HttpSession session) {
        session.setAttribute("username", "cristiano_ronaldo");
        return "User logged in and session started";
    }

    @GetMapping("/profile")
    public String getProfile(HttpSession session) {
        String username = (String) session.getAttribute("username");
        return "Welcome, " + username;
    }
}
```

### # cookies

`Cookies` là các tệp nhỏ được lưu trữ trên trình duyệt của người dùng và có thể chứa thông tin về người dùng hoặc trạng thái của phiên làm việc. `Cookies` được sử dụng rộng rãi để lưu trữ các thông tin như xác thực người dùng, ngôn ngữ trang web, sở thích cá nhân, và các dữ liệu khác mà không cần phải lưu trữ chúng trên server.

**_Cách hoạt động của Cookies_**:

- Mỗi khi người dùng truy cập trang web, server có thể gửi một cookie tới trình duyệt của người dùng.
- Trình duyệt sẽ lưu trữ cookie này và gửi lại nó trong mỗi yêu cầu tiếp theo tới server.
  Cookie có thể có thời gian hết hạn, giúp kiểm soát độ bền của dữ liệu.

**_Ưu điểm_**:

- Cookies giúp giảm tải cho server vì không cần phải lưu trữ dữ liệu trên server.
- Dữ liệu trong cookies có thể được truy cập trực tiếp từ client mà không cần phải gửi yêu cầu đến server.

**_Nhược điểm_**:

- Cookies có thể bị sửa đổi hoặc bị đánh cắp nếu không được mã hóa.
- Kích thước của cookie có giới hạn (khoảng 4KB), không thích hợp cho lưu trữ dữ liệu lớn.

**_Ví dụ_**:

```java
@RestController
public class CookieController {

    @GetMapping("/set-cookie")
    public String setCookie(HttpServletResponse response) {
        Cookie cookie = new Cookie("username", "cristiano_ronaldo");
        cookie.setMaxAge(60 * 60); // Cookie tồn tại trong 1 giờ
        response.addCookie(cookie);
        return "Cookie has been set";
    }

    @GetMapping("/get-cookie")
    public String getCookie(@CookieValue(value = "username", defaultValue = "Guest") String username) {
        return "Hello, " + username;
    }
}
```

### # jwt - json web token

`JWT` (JSON Web Token) là một phương pháp xác thực phân tán được sử dụng để xác thực và trao đổi thông tin giữa các bên, đặc biệt là trong các ứng dụng web phân tán. `JWT` chứa các phần: `header, payload, và signature`. `JWT` thường được sử dụng trong các ứng dụng RESTful API và hệ thống phân tán, nơi mà việc chia sẻ thông tin giữa các hệ thống là cần thiết.

**_Cách hoạt động của JWT_**:

- Khi người dùng đăng nhập thành công, server tạo ra một `JWT` chứa thông tin về người dùng (thường là quyền truy cập và ID người dùng).
- `JWT` được gửi về cho client và client lưu trữ nó (thường trong localStorage hoặc sessionStorage).
- Mỗi khi người dùng gửi yêu cầu đến server, `JWT` sẽ được gửi theo tiêu đề `HTTP (Authorization: Bearer <token>)`.
- Server sẽ xác thực `JWT` và nếu hợp lệ, cho phép truy cập vào tài nguyên yêu cầu.

**_Ưu điểm_**:

- `JWT` là tự chứa, tức là tất cả thông tin cần thiết cho việc xác thực và ủy quyền đều có trong token, giúp giảm tải cho server.
- Có thể được sử dụng trong môi trường phân tán hoặc `microservices` vì không cần phải truy vấn đến cơ sở dữ liệu để xác thực người dùng.

**_Nhược điểm_**:

- `Token` có thể bị đánh cắp nếu không mã hóa đúng cách.
- Không thể xóa hoặc sửa đổi thông tin trong `JWT` mà không phải tạo một token mới.

**_Ví dụ_**:

```java
@RestController
public class JwtController {

    private final String SECRET_KEY = "CR7";

    @PostMapping("/login")
    public String login(@RequestBody User user) {
        if ("cristiano_ronaldo".equals(user.getUsername()) && "password".equals(user.getPassword())) {
            String jwt = Jwts.builder()
                .setSubject(user.getUsername())
                .signWith(SignatureAlgorithm.HS256, SECRET_KEY)
                .compact();
            return "Bearer " + jwt;
        }
        return "Invalid credentials";
    }

    @GetMapping("/profile")
    public String getProfile(@RequestHeader("Authorization") String authorization) {
        String token = authorization.replace("Bearer ", "");
        try {
            Jws<Claims> claims = Jwts.parser()
                .setSigningKey(SECRET_KEY)
                .parseClaimsJws(token);
            String username = claims.getBody().getSubject();
            return "Welcome, " + username;
        } catch (JwtException e) {
            return "Invalid or expired token";
        }
    }
}
```

### # so sánh session, cookies & jwt

| **Đặc điểm**       | **Session**                                             | **Cookies**                                          | **JWT**                                                           |
| ------------------ | ------------------------------------------------------- | ---------------------------------------------------- | ----------------------------------------------------------------- |
| **Lưu trữ**        | Server                                                  | Client (trình duyệt)                                 | Client (trình duyệt hoặc server)                                  |
| **Bảo mật**        | An toàn hơn, lưu trữ thông tin trên server              | Kém an toàn hơn, có thể bị đánh cắp nếu không mã hóa | Có thể bị đánh cắp nếu không bảo vệ đúng cách                     |
| **Kích thước**     | Không giới hạn (tùy thuộc vào dung lượng bộ nhớ server) | Giới hạn khoảng 4KB                                  | Không giới hạn, nhưng độ dài token có thể ảnh hưởng đến hiệu suất |
| **Tính phân tán**  | Không thích hợp cho môi trường phân tán                 | Không hỗ trợ môi trường phân tán                     | Phù hợp với môi trường phân tán hoặc microservices                |
| **Dễ dàng hủy bỏ** | Có thể hủy bỏ (xóa session)                             | Có thể xóa cookie dễ dàng                            | Cần tạo lại token mới                                             |

### # lời kết

Mỗi công nghệ `Session`, `Cookies`, và `JWT` có ưu nhược điểm riêng và được sử dụng trong các tình huống khác nhau. `Session` thích hợp cho các ứng dụng không yêu cầu phân tán, nơi thông tin người dùng cần được lưu trữ trên server. `Cookies` là một phương pháp nhẹ nhàng và hiệu quả để lưu trữ thông tin nhỏ trên client. Trong khi đó, `JWT` được ưa chuộng trong các ứng dụng phân tán hoặc microservices, nơi xác thực và ủy quyền cần được xử lý nhanh chóng và độc lập giữa các hệ thống.

Tùy thuộc vào yêu cầu của ứng dụng, bạn sẽ chọn phương pháp phù hợp để tối ưu hóa hiệu suất và bảo mật cho người dùng.

> Chỉ là những ghi chép cá nhân với hy vọng mang lại chút giá trị. Nếu thấy hữu ích, đừng ngại chia sẻ cho bạn bè & đồng nghiệp nhé!

Happy coding <Twemoji emoji="clinking-beer-mugs" /> 😎 👍🏻 🚀 🔥.
