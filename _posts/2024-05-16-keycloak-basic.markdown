---
layout: post
title: "keycloak basic"
date: 2024-05-16 19:29:39 +0700
categories: [Software Development]
tags: [java, software-development, keycloak, best-practices, vietnamese]
---

### # keycloak

Nếu bạn đang làm việc trong môi trường kiến trúc phân tán hoặc Cloud Native,
bạn biết rằng **Identity and Access Management (IAM)** là trái tim của hệ thống. Nó không chỉ là chỗ đăng nhập,
mà còn là trụ cột quyết định tính bảo mật, hiệu suất và khả năng mở rộng (scalability).

`Keycloak` là một **Identity Provider (IdP)** mã nguồn mở mạnh mẽ và việc quyết định sử dụng nó ở quy mô lớn là một quyết định kiến trúc, không chỉ là lựa chọn phần mềm.

Bài viết này là tổng hợp các kinh nghiệm thực chiến, đi sâu vào những vấn đề quan trọng cần lưu ý khi vận hành Keycloak.

### # bài toán kinh tế

Trước khi nhảy vào code, ta cần hiểu tại sao các doanh nghiệp lại thích tự làm (`Build/Self-host Keycloak`) thay vì mua các giải pháp (`Buy/SaaS như Okta, Auth0`).

Ở quy mô người dùng hàng triệu, chi phí license của các nền tảng `SaaS` có thể tăng theo cấp số nhân (Variable Cost).
Một nghiên cứu cho thấy, chi phí này có thể vượt ngưỡng `$100,000` ngay cả với quy mô người dùng tương đối nhỏ, khiến các tổ chức lớn vào thế bị động về tài chính.

Lợi thế Keycloak (Fixed TCO):

- _**Fixed cost**_: keycloak là mã nguồn mở nên các tổ chức chỉ cần chi trả các chi phí vận hành (hạ tầng, nhân sự, bảo trì cluster), các chi phí này cố định và có thể dự đoán được.
- _**Kiểm soát tuyệt đối**_: keycloak mang lại quyền kiểm soát toàn bộ stack. Chúng ta có thể dùng `Service Provider Interfaces (SPIs)` để tùy chỉnh sâu vào luồng xác thực, tích hợp với các hệ thống `user directory legacy (LDAP/AD)` hoặc các quy trình bảo mật độc quyền tuỳ thuộc vào các đơn vị tổ chức.

Keycloak ở quy mô lớn là một **"Full-Scale Engineering Project"**. Nó đòi hỏi đầu tư kỹ thuật đáng kể vào `HA/Clustering` để tối ưu hóa database và infinispan caching.
Đây là chi phí kỹ thuật tối quan trọng cần lưu tâm.

### # OIDC, OAuth2 & JWT performance

Keycloak hoạt động như một **Authorization Server** tuân thủ nghiêm ngặt hai giao thức nền tảng: `OAuth 2.0 (Ủy quyền)` và `OpenID Connect (OIDC) (Xác thực)`.
Hiểu rõ cách chúng hoạt động là chìa khóa để bảo vệ hệ thống Microservices.

#### # OAuth 2.0 & OIDC

Keycloak có ba loại tokens chính, mỗi loại có mục đích riêng của nó:

- **ID Token (OIDC)**: phục vụ mục đích Xác thực `(Authentication)`. Nó chứa thông tin về người dùng `(user identity)`. Client sử dụng token này để biết ai đang đăng nhập, không dùng để truy cập API.
- \*\*Access Token (OAuth 2.0)((: phục vụ mục đích Ủy quyền `1`(Authorization)`1`. Đây là `Bearer Token` được gửi đến Resource Server (API) để chứng minh quyền truy cập tài nguyên. Token này chứa `Roles` và `Scopes`.
- **Refresh Token**: dùng để làm mới `Access Token` mà không cần người dùng phải đăng nhập lại. Token này phải được lưu trữ cực kỳ an toàn.

#### # PKCE và Confidential Clients - bảo mật luồng token

Đối với các ứng dụng Web/Mobile (Public Clients), `Authorization Code Flow` là tiêu chuẩn. Keycloak sử dụng `PKCE (Proof Key for Code Exchange)` để bảo vệ luồng này.

**PKCE**: Ngăn chặn kẻ tấn công đánh cắp `Authorization Code` trên đường truyền và đổi code lấy tokens, bởi vì chúng thiếu khóa bí mật `(code_verifier)`. Đây là lớp bảo vệ thiết yếu cho các `client` không thể giữ bí mật `(client_secret)`.

#### # tối ưu hoá JWT validation

Để Microservices hoạt động stateless và hiệu suất cao, ta phải tự xác thực `JWT` cục bộ `(Local JWT Validation)` bằng cách tải `JWKs (public keys)` của Keycloak, nhằm tránh gọi API Introspection đồng bộ tốn kém.

Quy tắc Vàng cho Resource Server (API): phải xác minh nghiêm ngặt các claims sau theo RFC 7519 :

- `iss (Issuer)`: keycloak có phải là bên phát hành hợp lệ không?
- `aud (Audience)`: đây là claim quan trọng nhất. Nó xác định đối tượng nhận token. Nếu `Resource Server` của bạn bỏ qua kiểm tra aud, bạn đã tạo ra một lỗ hổng bảo mật nghiêm trọng. Attacker có thể lấy `Access Token` cấp cho `Client A` và sử dụng nó để gọi API của `Microservice B` (token tái sử dụng chéo).
- `exp (Expiration Time)`: token đã hết hạn chưa?

#### # soft revocation: hack hiệu suất bằng NBF

Thách thức cố hữu của `JWT stateless` là làm thế nào để thu hồi ngay lập tức một `Access Token` đã được phát hành (ví dụ: người dùng bị admin buộc logout) trước khi thời gian hết hạn `(exp)` của nó kết thúc?

Keycloak giải quyết vấn đề này bằng `Not-Before Policy (NBF)`.

- Khi một phiên bị thu hồi, Keycloak tăng giá trị `NBF` của `realm` hoặc `client`.
- Resource Server, trong quá trình xác thực JWT cục bộ, sẽ kiểm tra thời gian phát hành `(iat)` của token. Nếu `iat` sớm hơn `NBF` mới, token đó sẽ bị từ chối.

Cơ chế `Soft Revocation` này cho phép vô hiệu hóa token tương đối nhanh chóng mà không cần `Token Introspection` đồng bộ, giúp API duy trì độ trễ ở mức thấp.

### # HA, scalability và sticky sessions

Việc đạt được `High Availability (HA)` với `Keycloak Cluster` là một bài toán thực sự đau đầu và thách thức.

#### # sticky sessions

Đây là điểm phải làm và không thể thỏa hiệp: Mặc dù `Sticky Sessions (Session Affinity)` là một anti-pattern trong microservices thuần túy - là yêu cầu kiến trúc BẮT BUỘC đối với Keycloak Cluster.

_**Lý do**_: keycloak sử dụng Infinispan cho cache phân tán `(distributed cache)` để quản lý trạng thái phiên. Nếu `Load Balancer` liên tục chuyển yêu cầu của cùng một phiên người dùng đến các node khác nhau, mỗi node sẽ phải gọi `Infinispan` để truyền tải toàn bộ trạng thái phiên qua mạng.
Quá trình này gây ra độ trễ cao và tăng tải network không cần thiết.

- _**Giải pháp**_: cấu hình `Load Balancer` để áp dụng `Sticky Sessions` (thường dựa trên cookie `AUTH_SESSION_ID`) --> tối ưu hóa việc sử dụng tài nguyên và duy trì hiệu suất thấp độ trễ.

#### # infinispan cache

Để đảm bảo `HA` và chịu lỗi, cần tinh chỉnh cache phân tán của Keycloak:

- _**Owner count**_: đối với `Distributed Cache`, nên cấu hình `Owner Count` (số lượng bản sao dữ liệu cache) là 2 hoặc 3 nodes. Điều này đảm bảo dữ liệu luôn sẵn có ngay cả khi một node cluster thất bại.
- _**Database HA**_: bắt buộc sử dụng `Database production-ready (PostgreSQL/MySQL)` với chiến lược `Primary-Secondary Replication` và `Automatic Failover` để xử lý tải và sự cố.

### # ủy quyền nâng cao và khả năng mở rộng

#### # vượt ra ngoài RBAC: PEP, PDP && PBAC

Keycloak Authorization Services cung cấp khung `Policy-Based Access Control (PBAC)`, lý tưởng cho các quyết định truy cập phức tạp cần ngữ cảnh `(contextual information)`:

- _**PEP (Policy Enforcement Point)**_: đặt tại `Resource Server (API)` --> chặn yêu cầu và thực thi quyết định.
- _**PDP (Policy Decision Point)**_: đặt tại Keycloak --> đánh giá các chính sách dựa trên vai trò, thuộc tính, thời gian và ngữ cảnh để đưa ra quyết định truy cập.

#### # UMA 2.0: party-to-party authorization

Keycloak là `Authorization Server` tuân thủ chuẩn `User-Managed Access (UMA) 2.0`. Đây là mô hình ủy quyền tiên tiến, đặc biệt quan trọng cho các kịch bản chia sẻ dữ liệu (ví dụ: chia sẻ hồ sơ y tế, Open Banking).

- _**Party-to-Party Authorization**_: UMA cho phép **Chủ sở hữu tài nguyên** `(Resource Owner) hoặc (người dùng cuối)` quản lý và cấp quyền truy cập dữ liệu của họ cho các bên thứ ba `(Requesting Parties)` khác.
- _**Quy trình bất đồng bộ**_: người dùng có thể định nghĩa và thay đổi chính sách cấp quyền một cách bất đồng bộ. `Resource Server` trả về `Permission Ticket` (token mờ) khi truy cập bị từ chối và `Client` sử dụng `Ticket` này để yêu cầu `Requesting Party Token (RPT)` - `(Access Token cuối cùng)` từ Keycloak.

#### # extensibility: user storage SPI và webAuthn

Khả năng mở rộng bằng `SPIs` là lợi thế `TCO` lớn nhất của Keycloak.

- _**User storage SPI**_: cho phép Keycloak kết nối và xác thực người dùng từ các kho lưu trữ ngoài `(LDAP, AD, Custom DB)` mà không cần nhập (import) toàn bộ dữ liệu.
  - ((_Thách thức dữ liệu cũ (Stale Data)\*\*_: khi dùng SPI, dữ liệu người dùng được cache trong `Infinispan`. Nếu dữ liệu thay đổi ở nguồn ngoài, ta cần xây dựng cơ chế để chủ động vô hiệu hóa cache `(cache invalidation)` nhằm ngăn Keycloak phục vụ dữ liệu cũ.
- \_\*_WebAuthn/FIDO2_\_\_: keycloak đang chuyển dịch mạnh mẽ sang hỗ trợ chuẩn WebAuthn (thường đi kèm FIDO2). WebAuthn sử dụng thông tin đăng nhập dựa trên khóa công khai, loại bỏ việc sử dụng mật khẩu và là hàng rào hiệu quả chống lại Phishing.

### # tích Hợp keycloak & spring boot

Là Java Developers, ta cần triển khai Spring Boot Microservice theo hai vai trò chính: `SSO Client (Web App)` và `Stateless Resource Server (API)`.

#### # pattern 1: SSO client (web application)

Mô hình này sử dụng Spring Boot làm `Confidential Client`, thực hiện `Authorization Code Flow` và quản lý phiên `HTTP (Session-based)`.

Dependencies: `spring-boot-starter-oauth2-client và spring-boot-starter-security`.

Cấu hình `application.yml` (SSO Client)

```yaml
server:
  port: 8082

spring:
  application:
    name: keycloak-sso-client
  security:
    oauth2:
      client:
        registration:
          # Đăng ký Client ID Keycloak
          keycloak:
            client-id: food-ordering-client
            client-secret: your-client-secret # Confidential Client
            scope: openid,profile,email # Yêu cầu Scope OIDC
            redirect-uri: http://localhost:8082/login/oauth2/code/keycloak
        provider:
          # Cấu hình Keycloak Provider
          keycloak:
            # Issuer URI là bắt buộc cho Discovery
            issuer-uri: http://localhost:8088/realms/food-ordering-realm
```

Security Configuration (`SecurityConfig.java` - SSO Client). Sử dụng `.oauth2Login()` để kích hoạt luồng SSO và quản lý logout.

```java
@Configuration
@EnableWebSecurity
public class SecurityConfig {

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
          .authorizeHttpRequests(authorize -> authorize
              .requestMatchers("/").permitAll()
              .requestMatchers("/menu").authenticated() // Yêu cầu xác thực
              .anyRequest().authenticated()
            )
          .oauth2Login(oauth2 -> oauth2 // Kích hoạt OAuth2 Login (SSO)
              .loginPage("/oauth2/authorization/keycloak")
              .defaultSuccessUrl("/menu", true)
            )
          .logout(logout -> logout // Hỗ trợ Single Sign-Out
              .logoutSuccessUrl("/")
              .invalidateHttpSession(true)
              .clearAuthentication(true)
              .deleteCookies("JSESSIONID")
            );
        return http.build();
    }
}
```

#### # pattern 2: stateless resource server (API protection)

Đây là mô hình tiêu chuẩn cho Microservices: `Stateless` và bảo vệ bằng `JWT Validation (Bearer Token)`.

Dependencies: `spring-boot-starter-oauth2-resource-server`.

Cấu hình `application.yml` (Resource Server)

Cấu hình tối giản. `Resource Server` chỉ cần biết `issuer-uri` để `Spring Security` tự động tải J`WKS (public keys)` từ Keycloak.

```yaml
server:
  port: 8083

spring:
  security:
    oauth2:
      resourceserver:
        jwt:
          # Chỉ cần Issuer URI. Spring Security tự động tìm JWKS endpoint
          issuer-uri: http://localhost:8088/realms/food-ordering-realm
```

Security Configuration (`ResourceServerConfig.java` - API). Phần quan trọng nhất là `Custom JWT Converter` để ánh xạ `Roles/Authorities` của Keycloak sang định dạng `Spring Security`.

```java
@Configuration
@EnableWebSecurity
public class ResourceServerConfig {

    @Bean
    public SecurityFilterChain resourceServerSecurityFilterChain(HttpSecurity http) throws Exception {
        http
           // Tắt CSRF/Session vì đây là stateless REST API
        .csrf(csrf -> csrf.disable())
        .sessionManagement(sm -> sm.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
        .authorizeHttpRequests(auth -> auth
            .requestMatchers("/api/public").permitAll()
            .requestMatchers("/api/admin/**").hasRole("ADMIN") // Kiểm tra Role đã ánh xạ
            .anyRequest().authenticated()
            )
           // Kích hoạt Resource Server và sử dụng Custom Converter
        .oauth2ResourceServer(oauth2 -> oauth2
            .jwt(jwt -> jwt.jwtAuthenticationConverter(keycloakJwtConverter()))
            );
        return http.build();
    }

    // Custom JWT Converter: Ánh xạ claims Keycloak sang GrantedAuthority
    @Bean
    public JwtAuthenticationConverter keycloakJwtConverter() {
        // Cần Custom Converter vì Keycloak đặt Roles trong claims tùy chỉnh
        // (ví dụ: 'realm_access.roles').

        JwtGrantedAuthoritiesConverter grantedAuthoritiesConverter = new JwtGrantedAuthoritiesConverter();
        // Mặc định Spring Security ánh xạ 'scope' claim thành Authority với prefix 'SCOPE_'
        grantedAuthoritiesConverter.setAuthorityPrefix("SCOPE_");

        // TODO: Chúng ta cần triển khai logic để đọc claim 'realm_access.roles'
        // hoặc 'resource_access' từ JWT Keycloak và ánh xạ thành Authorities với prefix 'ROLE_'
        // để có thể dùng.hasRole('ADMIN') trong Spring Security.
        // Logic này thường nằm trong một lớp riêng biệt triển khai Converter.

        JwtAuthenticationConverter jwtAuthenticationConverter = new JwtAuthenticationConverter();
        jwtAuthenticationConverter.setJwtGrantedAuthoritiesConverter(grantedAuthoritiesConverter);
        return jwtAuthenticationConverter;
    }
}
```

### # lời kết

Keycloak không phải là giải pháp mua về rồi tích hợp vào dùng là xong. Nó là nền tảng cần phải xây dựng lên. Bù lại, nó mang lại sự kiểm soát và hiệu quả chi phí không thể sánh được ở quy mô lớn.

Hãy chuẩn bị cho đội ngũ kiến thức đầy đủ để đối mặt với những thách thức mà quá trình tích hợp cũng như vận hành keycloak mang lại.

> Chỉ là những ghi chép cá nhân với hy vọng mang lại chút giá trị. Nếu thấy hữu ích, đừng ngại chia sẻ cho bạn bè & đồng nghiệp nhé!

Happy coding <Twemoji emoji="clinking-beer-mugs" /> 😎 👍🏻 🚀 🔥.
