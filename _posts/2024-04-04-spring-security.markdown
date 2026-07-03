---
layout: post
title: "spring security"
date: 2024-04-04 19:29:39 +0700
categories: [Software Development]
tags: [java, software-development, spring-security, best-practices, vietnamese]
---

Spring Security thường được ví như một "hộp đen" đầy phép thuật ngầm khiến không ít kỹ sư e ngại khi mới tiếp cận. Tuy nhiên, khi xây dựng các hệ thống backend quy mô lớn, việc chỉ biết "copy-paste" cấu hình là chưa đủ. Bài viết này sẽ bóc tách những khái niệm rườm rà, đưa Spring Security về đúng bản chất kiến trúc của nó và hướng dẫn bạn cách thiết lập một hệ thống bảo mật thanh lịch, vững chãi chuẩn Production.

### # bản chất

Đừng để những annotation đánh lừa bạn. Nhìn sâu vào bản chất, Spring Security hoạt động dựa trên một pattern kinh điển của Servlet: Filter Chain.

Mọi HTTP request trước khi chạm đến cánh cửa của Controller đều phải đi qua một "trạm trạm kiểm lâm" gồm nhiều lớp màng lọc. Tại đây, hai câu hỏi sinh tử sẽ được giải quyết:

- Authentication: Anh là ai? (Xác thực danh tính)
- Authorization: Anh có quyền làm việc này không? (Cấp quyền truy cập)

### # dòng chảy của một request

![spring-req-flow]({{ site.baseurl }}/assets/img/blog/spring-req-flow.png)

Dưới đây là sơ đồ luồng đi tường minh của một request qua các tầng bảo mật:

```
HTTP Request
    │
    ▼
DelegatingFilterProxy
    │
    ▼
FilterChainProxy
    │
    ▼
SecurityFilterChain (ordered filters)
    ├── DisableEncodeUrlFilter
    ├── SecurityContextHolderFilter
    ├── CsrfFilter
    ├── LogoutFilter
    ├── OAuth2AuthorizationRequestRedirectFilter
    ├── BearerTokenAuthenticationFilter  ← JWT validation
    ├── RequestCacheAwareFilter
    ├── AnonymousAuthenticationFilter
    ├── ExceptionTranslationFilter
    └── AuthorizationFilter             ← access control
         │
         ▼
    Controller (nếu authorized)
```

### # core components

Để điều khiển được Spring Security, bạn cần thuộc nằm lòng các bánh răng cấu thành nên bộ máy này:
| Component | Vai trò |
| ---------------------- | ---------------------------------------- |
| SecurityFilterChain | Chuỗi filters xử lý security |
| AuthenticationManager | Orchestrate authentication |
| AuthenticationProvider | Thực hiện authentication logic |
| UserDetailsService | Load user data từ DB/LDAP |
| SecurityContext | Lưu Authentication object (current user) |
| GrantedAuthority | Quyền/role của user |

### # SecurityFilterChain configuration (spring boot 3)

Với Spring Boot 3, cách tiếp cận cấu hình đã chuyển dịch hoàn toàn sang Lambda DSL, mang lại sự rành mạch và an toàn kiểu (type-safe) cao hơn rất nhiều. Dưới đây là blueprint cấu hình cho một RESTful API theo chuẩn Stateless:

```java
@Configuration
@EnableWebSecurity
@EnableMethodSecurity
public class SecurityConfig {

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
            // Tắt CSRF vì REST API Stateless không dùng Cookie/Session
            .csrf(csrf -> csrf.disable())

            // Cấu hình CORS chặt chẽ từ một source tách biệt
            .cors(cors -> cors.configurationSource(corsConfigSource()))

            // Ép hệ thống chạy ở chế độ Stateless (Không sinh JSESSIONID)
            .sessionManagement(session ->
                session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))

            // Định tuyến quyền truy cập từng endpoint
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/actuator/health", "/api/public/**").permitAll()
                .requestMatchers("/api/admin/**").hasRole("ADMIN")
                .requestMatchers("/api/**").authenticated()
                .anyRequest().denyAll() // Nguyên tắc Default Deny
            )

            // Tích hợp OAuth2 Resource Server cho JWT
            .oauth2ResourceServer(oauth2 -> oauth2
                .jwt(jwt -> jwt.jwtDecoder(jwtDecoder()))
            )

            // Xử lý ngoại lệ thanh lịch
            .exceptionHandling(ex -> ex
                .authenticationEntryPoint(new HttpStatusEntryPoint(HttpStatus.UNAUTHORIZED))
                .accessDeniedHandler((req, res, e) -> res.setStatus(HttpServletResponse.SC_FORBIDDEN))
            );

        return http.build();
    }
}
```

Nguyên tắc tối thượng trong cấu hình Security là "Default Deny" (Từ chối mặc định). Hãy luôn để anyRequest().denyAll() ở cuối cùng để đảm bảo không một endpoint mới nào bị rò rỉ quyền truy cập do quên cấu hình.

### # oauth2 resource server (jwt)

Trong các hệ thống phân tán hoặc Microservices, việc ủy quyền xác thực cho một Identity Provider (như Keycloak) là điều hiển nhiên.

#### # config

Khai báo tĩnh qua application.yml

```yaml
spring:
  security:
    oauth2:
      resourceserver:
        jwt:
          issuer-uri: http://keycloak:8080/realms/davintek-realm
          # Jwks-uri giúp load public key động để verify token signature
          jwk-set-uri: http://keycloak:8080/realms/davintek-realm/protocol/openid-connect/certs
```

#### # custom jwt → authentication mapping

Identity Providers thường có cấu trúc JWT Claims riêng biệt (Ví dụ Keycloak nhét roles vào realm_access). Ta cần một "bộ phiên dịch" để Spring hiểu được:

```java
@Bean
public JwtAuthenticationConverter jwtAuthenticationConverter() {
   JwtGrantedAuthoritiesConverter authoritiesConverter = new JwtGrantedAuthoritiesConverter();
   authoritiesConverter.setAuthoritiesClaimName("realm_access.roles"); // Keycloak format
   authoritiesConverter.setAuthorityPrefix("ROLE_");

   JwtAuthenticationConverter converter = new JwtAuthenticationConverter();
   converter.setJwtGrantedAuthoritiesConverter(authoritiesConverter);
   return converter;
}

// Hoặc custom converter cho Keycloak nested roles
@Bean
public Converter<Jwt, AbstractAuthenticationToken> keycloakJwtConverter() {
   return jwt -> {
       Collection<GrantedAuthority> authorities = extractKeycloakRoles(jwt);
       return new JwtAuthenticationToken(jwt, authorities, jwt.getClaimAsString("preferred_username"));
   };
}

private Collection<GrantedAuthority> extractKeycloakRoles(Jwt jwt) {
   Map<String, Object> realmAccess = jwt.getClaimAsMap("realm_access");
   if (realmAccess == null) return Collections.emptyList();

   List<String> roles = (List<String>) realmAccess.get("roles");
   return roles.stream()
       .map(role -> new SimpleGrantedAuthority("ROLE_" + role.toUpperCase()))
       .collect(Collectors.toList());
}
```

### # method security

Đẩy logic phân quyền xuống tận lớp Business (Service Layer) giúp code tái sử dụng tốt hơn và tránh controller bị phình to. Spring Security cung cấp SpEL (Spring Expression Language) cực kỳ mạnh mẽ.

```java
@Service
public class OrderService {

    // Chỉ ADMIN mới được xóa
    @PreAuthorize("hasRole('ADMIN')")
    public void deleteOrder(String orderId) { ... }

    // User chỉ được lấy danh sách đơn hàng của chính mình
    @PreAuthorize("hasRole('USER') and #userId == authentication.name")
    public List<Order> getOrders(String userId) { ... }

    // Gọi đến một permission evaluator bean động
    @PreAuthorize("@permissionEvaluator.hasWorkspaceAccess(#workspaceId, 'READ')")
    public Workspace getWorkspace(String workspaceId) { ... }

    // Lọc dữ liệu đầu ra: Lấy order xong mới check xem có phải của mình không
    @PostAuthorize("returnObject.ownerId == authentication.name or hasRole('ADMIN')")
    public Order getOrder(String orderId) { ... }
}
```

### # custom authentication filter

```java
public class ApiKeyAuthFilter extends OncePerRequestFilter {

   private static final String API_KEY_HEADER = "X-API-Key";

   @Override
   protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain chain) throws ServletException, IOException {

       String apiKey = request.getHeader(API_KEY_HEADER);

       if (apiKey != null && apiKeyService.isValid(apiKey)) {
           ApiKeyAuthentication auth = new ApiKeyAuthentication(apiKey, apiKeyService.getAuthorities(apiKey));
           SecurityContextHolder.getContext().setAuthentication(auth);
       }

       chain.doFilter(request, response);
   }

   @Override
   protected boolean shouldNotFilter(HttpServletRequest request) {
       return !request.getRequestURI().startsWith("/api/external/");
   }
}

// Register filter
@Bean
public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
   http.addFilterBefore(new ApiKeyAuthFilter(), BearerTokenAuthenticationFilter.class);
   return http.build();
}
```

### # cors configuration

```java
@Bean
public CorsConfigurationSource corsConfigSource() {
   CorsConfiguration config = new CorsConfiguration();
   config.setAllowedOrigins(List.of("http://localhost:3000", "https://app.example.com"));
   config.setAllowedMethods(List.of("GET", "POST", "PUT", "DELETE", "OPTIONS"));
   config.setAllowedHeaders(List.of("*"));
   config.setAllowCredentials(true);
   config.setMaxAge(3600L);

   UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
   source.registerCorsConfiguration("/api/**", config);
   return source;
}
```

### # SecurityContext — lấy current user

```java
// Trong Controller/Service
public String getCurrentUserId() {
   Authentication auth = SecurityContextHolder.getContext().getAuthentication();
   if (auth instanceof JwtAuthenticationToken jwtAuth) {
       return jwtAuth.getToken().getClaimAsString("sub");
   }
   return auth.getName();
}

// Inject trực tiếp trong Controller
@GetMapping("/me")
public UserDTO getCurrentUser(@AuthenticationPrincipal Jwt jwt) {
   String userId = jwt.getSubject();
   String email = jwt.getClaimAsString("email");
   List<String> roles = jwt.getClaimAsStringList("roles");
   return userService.getUser(userId);
}
```

### # multiple SecurityFilterChains

Trong một hệ thống thực thụ, bạn hiếm khi chỉ có một chính sách bảo mật. Ví dụ: API cho Mobile App dùng JWT, nhưng API cho đối tác ngoại vi lại dùng API Key, và Actuator thì dùng Basic Auth.

Giải pháp là tạo nhiều Filter Chain với Order khác nhau:

```java
@Configuration
public class MultiSecurityConfig {

   // Chain 1: API endpoints (JWT)
   @Bean
   @Order(1)
   public SecurityFilterChain apiFilterChain(HttpSecurity http) throws Exception {
       http
           .securityMatcher("/api/**")
           .oauth2ResourceServer(oauth2 -> oauth2.jwt(Customizer.withDefaults()))
           .authorizeHttpRequests(auth -> auth.anyRequest().authenticated());
       return http.build();
   }

   // Chain 2: Actuator endpoints (Basic Auth)
   @Bean
   @Order(2)
   public SecurityFilterChain actuatorFilterChain(HttpSecurity http) throws Exception {
       http
           .securityMatcher("/actuator/**")
           .httpBasic(Customizer.withDefaults())
           .authorizeHttpRequests(auth -> auth.anyRequest().hasRole("ACTUATOR"));
       return http.build();
   }

   // Chain 3: Public (no auth)
   @Bean
   @Order(3)
   public SecurityFilterChain publicFilterChain(HttpSecurity http) throws Exception {
       http
           .securityMatcher("/public/**", "/health")
           .authorizeHttpRequests(auth -> auth.anyRequest().permitAll());
       return http.build();
   }
}
```

### # exception handling

Một ứng dụng trả về toàn bộ Stack Trace lỗi Java cho client là một thảm họa bảo mật. Hãy format lại Error Response cho chuẩn mực:

```java
@Component
public class CustomAuthEntryPoint implements AuthenticationEntryPoint {

   @Override
   public void commence(HttpServletRequest request, HttpServletResponse response,
                        AuthenticationException authException) throws IOException {
       response.setContentType("application/json");
       response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
       // Có thể dùng ObjectMapper để serialize một ErrorResponse object tĩnh
        response.getWriter().write("""
            {
                "status": 401,
                "error": "UNAUTHORIZED",
                "message": "Token không hợp lệ hoặc đã hết hạn"
            }
        """);
   }
}

@Component
public class CustomAccessDeniedHandler implements AccessDeniedHandler {

   @Override
   public void handle(HttpServletRequest request, HttpServletResponse response,
                      AccessDeniedException accessDeniedException) throws IOException {
       response.setContentType("application/json");
       response.setStatus(HttpServletResponse.SC_FORBIDDEN);
       response.getWriter().write("""
           {"error": "FORBIDDEN", "message": "Insufficient permissions"}
       """);
   }
}
```

### # testing

```java
@WebMvcTest(OrderController.class)
class OrderControllerSecurityTest {

   @Test
   @WithMockUser(roles = "ADMIN")
   void adminCanDeleteOrder() throws Exception {
       mockMvc.perform(delete("/api/orders/123"))
           .andExpect(status().isOk());
   }

   @Test
   @WithMockUser(roles = "USER")
   void userCannotDeleteOrder() throws Exception {
       mockMvc.perform(delete("/api/orders/123"))
           .andExpect(status().isForbidden());
   }

   @Test
   void unauthenticatedGetsDenied() throws Exception {
       mockMvc.perform(get("/api/orders"))
           .andExpect(status().isUnauthorized());
   }

   @Test
   @WithMockUser(username = "user-1")
   void userCanOnlyAccessOwnOrders() throws Exception {
       mockMvc.perform(get("/api/users/user-1/orders"))
           .andExpect(status().isOk());

       mockMvc.perform(get("/api/users/user-2/orders"))
           .andExpect(status().isForbidden());
   }
}
```

### # production checklist

Trước khi đưa mã nguồn từ môi trường Staging lên Production, hãy chắc chắn bạn đã tick đủ các mục sau:

- [ ] Tắt CSRF chỉ khi ứng dụng thực sự Stateless (REST APIs không dùng cookie session).
- [ ] Cấu hình CORS nghiêm ngặt: Loại bỏ hoàn toàn \* ở allowedOrigins trên môi trường Prod.
- [ ] Xác minh JWT toàn diện: Check đủ Issuer, Audience, và Expiration.
- [ ] Áp dụng Method Security (@PreAuthorize) cho mọi thao tác write/delete nhạy cảm ở Service layer.
- [ ] Cấu hình Custom Exception Handling để che giấu kiến trúc nội bộ.
- [ ] Bổ sung Security Headers (X-Content-Type-Options, X-Frame-Options, Strict-Transport-Security).
- [ ] Thiết lập Rate Limiting chặn tấn công Brute-force.
- [ ] Bật Audit Logging ghi nhận mọi sự kiện Đăng nhập thành công/Thất bại.

> Chỉ là những ghi chép cá nhân với hy vọng mang lại chút giá trị. Nếu thấy hữu ích, đừng ngại chia sẻ cho bạn bè & đồng nghiệp nhé!

Happy coding <Twemoji emoji="clinking-beer-mugs" /> 😎 👍🏻 🚀 🔥.
