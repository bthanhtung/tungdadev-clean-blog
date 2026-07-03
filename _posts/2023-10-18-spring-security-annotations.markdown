---
layout: post
title: "spring security annotations"
date: 2023-10-18 19:29:39 +0700
categories: [Software Development]
tags: [java, software-development, spring-framework, best-practices, vietnamese]
---

### # giới thiệu

Security không phải feature bạn thêm vào cuối — nó là foundation. Mọi request đến API phải trả lời 2 câu hỏi: "Bạn là ai?" (Authentication) và "Bạn được phép làm gì?" (Authorization).

Spring Security là framework bảo mật mạnh nhất trong Java ecosystem. Nó xử lý authentication (JWT, OAuth2, Basic Auth), authorization (role-based, permission-based), CSRF protection, CORS, session management, và hơn thế. Trong CSP, Spring Security tích hợp với Keycloak (OAuth2 Resource Server) để bảo vệ mọi API endpoint.

Package này đặc biệt quan trọng cho Senior vì security bugs = business impact trực tiếp. Một `@PreAuthorize` sai có thể expose data của workspace A cho user workspace B.

### # SecurityFilterChain — cấu hình security

Từ Spring Security 5.7+, không còn extend `WebSecurityConfigurerAdapter`. Thay vào đó, khai báo `SecurityFilterChain` bean.

```java
@Configuration
@EnableWebSecurity
@EnableMethodSecurity  // Bật @PreAuthorize, @PostAuthorize
public class SecurityConfig {

   @Bean
   public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
       return http
           .csrf(AbstractHttpConfigurer::disable)  // Disable cho REST API (stateless)
           .sessionManagement(session ->
               session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
           .oauth2ResourceServer(oauth ->
               oauth.jwt(jwt -> jwt.jwtAuthenticationConverter(jwtConverter())))
           .authorizeHttpRequests(auth -> auth
               .requestMatchers("/actuator/health", "/actuator/info").permitAll()
               .requestMatchers("/api/public/**").permitAll()
               .requestMatchers("/api/admin/**").hasRole("ADMIN")
               .requestMatchers("/api/v1/**").authenticated()
               .anyRequest().denyAll())
           .exceptionHandling(ex -> ex
               .authenticationEntryPoint(new CustomAuthEntryPoint())
               .accessDeniedHandler(new CustomAccessDeniedHandler()))
           .build();
   }

   private JwtAuthenticationConverter jwtConverter() {
       JwtGrantedAuthoritiesConverter converter = new JwtGrantedAuthoritiesConverter();
       converter.setAuthoritiesClaimName("realm_access.roles");
       converter.setAuthorityPrefix("ROLE_");

       JwtAuthenticationConverter jwtConverter = new JwtAuthenticationConverter();
       jwtConverter.setJwtGrantedAuthoritiesConverter(converter);
       return jwtConverter;
   }
}
```

### # @PreAuthorize / @PostAuthorize — method-level security

Đây là nơi security trở nên granular. Thay vì chỉ check "authenticated hay không" ở URL level, bạn check business rules ở method level: "user này có quyền xóa product này không?"

SpEL (Spring Expression Language) trong `@PreAuthorize` cho phép logic phức tạp: check roles, check ownership, check workspace membership — tất cả declarative, không pollute business logic.

```java
@RestController
@RequestMapping("/api/v1/products")
public class ProductController {

   // Chỉ user có role ADMIN
   @PreAuthorize("hasRole('ADMIN')")
   @DeleteMapping("/{id}")
   public void delete(@PathVariable UUID id) { ... }

   // Có bất kỳ role nào trong list
   @PreAuthorize("hasAnyRole('ADMIN', 'MANAGER')")
   @PostMapping
   public ProductDTO create(@RequestBody CreateProductRequest request) { ... }

   // Custom SpEL — check workspace ownership
   @PreAuthorize("@workspaceSecurity.hasAccess(#workspaceId, authentication)")
   @GetMapping
   public Page<ProductDTO> list(
           @RequestHeader("X-Workspace-Id") UUID workspaceId,
           Pageable pageable) { ... }

   // Check object-level permission AFTER retrieval
   @PostAuthorize("returnObject.createdBy == authentication.name or hasRole('ADMIN')")
   @GetMapping("/{id}")
   public ProductDTO get(@PathVariable UUID id) {
       return productService.getById(id);
   }

   // Combine conditions
   @PreAuthorize("hasRole('EDITOR') and #request.workspaceId == authentication.principal.claims['workspace_id']")
   @PutMapping("/{id}")
   public ProductDTO update(@PathVariable UUID id, @RequestBody UpdateRequest request) { ... }

   // Permission-based (finer than roles)
   @PreAuthorize("hasAuthority('PRODUCT_DELETE') or hasRole('ADMIN')")
   @DeleteMapping("/batch")
   public void batchDelete(@RequestBody List<UUID> ids) { ... }
}
```

#### # custom security expression bean

```java
@Component("workspaceSecurity")
@RequiredArgsConstructor
public class WorkspaceSecurity {

   private final WorkspaceMemberRepository memberRepo;

   public boolean hasAccess(UUID workspaceId, Authentication auth) {
       String userId = ((Jwt) auth.getPrincipal()).getSubject();
       return memberRepo.existsByWorkspaceIdAndUserId(workspaceId, userId);
   }

   public boolean isOwner(UUID resourceId, Authentication auth) {
       String userId = ((Jwt) auth.getPrincipal()).getSubject();
       return resourceRepo.existsByIdAndCreatedBy(resourceId, userId);
   }

   public boolean hasPermission(UUID workspaceId, String permission, Authentication auth) {
       String userId = ((Jwt) auth.getPrincipal()).getSubject();
       return permissionService.check(workspaceId, userId, permission);
   }
}

// Usage
@PreAuthorize("@workspaceSecurity.hasPermission(#workspaceId, 'PRODUCT_WRITE', authentication)")
@PostMapping
public ProductDTO create(...) { ... }
```

### # @Secured / @RolesAllowed — simpler alternatives

`@Secured` và `@RolesAllowed` đơn giản hơn `@PreAuthorize` — chỉ check role, không có SpEL. Dùng khi logic đơn giản, team prefer readability over flexibility.

```java
@Secured("ROLE_ADMIN")  // Spring Security native
@DeleteMapping("/{id}")
public void delete(@PathVariable UUID id) { ... }

@RolesAllowed({"ADMIN", "MANAGER"})  // Jakarta (JSR-250) standard
@PostMapping
public ProductDTO create(@RequestBody CreateRequest request) { ... }
```

### # @WithMockUser — testing security

Khi viết unit/integration tests, bạn cần mock authenticated user. Spring Security Test cung cấp annotations tiện lợi.

```java
@WebMvcTest(ProductController.class)
class ProductControllerTest {

   @Autowired MockMvc mockMvc;
   @MockBean ProductService productService;

   // Mock user với role
   @Test
   @WithMockUser(username = "admin", roles = {"ADMIN"})
   void deleteProduct_asAdmin_returns204() throws Exception {
       mockMvc.perform(delete("/api/v1/products/{id}", productId))
           .andExpect(status().isNoContent());
   }

   // Mock user không có quyền
   @Test
   @WithMockUser(username = "viewer", roles = {"VIEWER"})
   void deleteProduct_asViewer_returns403() throws Exception {
       mockMvc.perform(delete("/api/v1/products/{id}", productId))
           .andExpect(status().isForbidden());
   }

   // Không authenticated
   @Test
   void deleteProduct_unauthenticated_returns401() throws Exception {
       mockMvc.perform(delete("/api/v1/products/{id}", productId))
           .andExpect(status().isUnauthorized());
   }

   // Custom JWT mock
   @Test
   void listProducts_withJwt() throws Exception {
       mockMvc.perform(get("/api/v1/products")
               .with(jwt().authorities(new SimpleGrantedAuthority("ROLE_USER"))
                   .jwt(j -> j.claim("workspace_id", workspaceId))))
           .andExpect(status().isOk());
   }
}
```

### # quick reference

| Annotation               | Mục đích                                        |
| ------------------------ | ----------------------------------------------- |
| @EnableWebSecurity       | Bật Spring Security config                      |
| @EnableMethodSecurity    | Bật @PreAuthorize/@PostAuthorize                |
| @PreAuthorize            | Check trước khi method chạy                     |
| @PostAuthorize           | Check sau khi method chạy (access return value) |
| @PreFilter               | Filter input collection theo condition          |
| @PostFilter              | Filter return collection theo condition         |
| @Secured                 | Simple role check (no SpEL)                     |
| @RolesAllowed            | JSR-250 role check                              |
| @WithMockUser            | Test: mock authenticated user                   |
| @WithAnonymousUser       | Test: mock anonymous user                       |
| @AuthenticationPrincipal | Inject current user principal                   |

> Chỉ là những ghi chép cá nhân với hy vọng mang lại chút giá trị. Nếu thấy hữu ích, đừng ngại chia sẻ cho bạn bè & đồng nghiệp nhé!

Happy coding <Twemoji emoji="clinking-beer-mugs" /> 😎 👍🏻 🚀 🔥.
