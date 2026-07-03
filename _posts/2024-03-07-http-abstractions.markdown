---
layout: post
title: "http abstractions"
date: 2024-03-07 19:29:39 +0700
categories: [Software Development]
tags: [java, software-development, spring-framework, best-practices, vietnamese]
---

### # giới thiệu

HTTP là ngôn ngữ mà mọi REST API nói. Nhưng raw HTTP trong Java rất verbose — `HttpURLConnection` cần hàng chục dòng code cho 1 GET request. Spring abstract hóa toàn bộ HTTP protocol thành type-safe Java objects.

Package `org.springframework.http` là vocabulary bạn dùng hàng ngày: `ResponseEntity` wrap response với status + headers, `HttpHeaders` quản lý headers type-safe, `MediaType` thay vì hardcode "application/json" string, và HTTP clients (`RestTemplate`, `WebClient`, `RestClient`) gọi external services.

Hiểu package này = hiểu cách controller trả response và cách service-to-service communication hoạt động trong microservices.

### # http-status — http status codes

Status code là "ngôn ngữ cơ thể" của API. Client không cần parse body để biết request thành công hay thất bại — nhìn status code là đủ. `200` = OK, `404` = không tìm thấy, `500` = server lỗi.

Spring cung cấp enum `HttpStatus` với tất cả standard codes + helper methods (`is2xxSuccessful()`, `is4xxClientError()`). Dùng enum thay vì magic number — code readable hơn và IDE autocomplete giúp bạn không nhớ sai.

```java
// Các status thường dùng
HttpStatus.OK                    // 200
HttpStatus.CREATED               // 201
HttpStatus.ACCEPTED              // 202
HttpStatus.NO_CONTENT            // 204
HttpStatus.BAD_REQUEST           // 400
HttpStatus.UNAUTHORIZED          // 401
HttpStatus.FORBIDDEN             // 403
HttpStatus.NOT_FOUND             // 404
HttpStatus.METHOD_NOT_ALLOWED    // 405
HttpStatus.CONFLICT              // 409
HttpStatus.UNPROCESSABLE_ENTITY  // 422
HttpStatus.TOO_MANY_REQUESTS     // 429
HttpStatus.INTERNAL_SERVER_ERROR // 500
HttpStatus.SERVICE_UNAVAILABLE   // 503

// Check category
HttpStatus status = HttpStatus.OK;
status.is2xxSuccessful();  // true
status.is4xxClientError(); // false
status.is5xxServerError(); // false
status.isError();          // false

// Value
status.value();            // 200
status.getReasonPhrase();  // "OK"
status.series();           // HttpStatus.Series.SUCCESSFUL
```

### # responseentity — full http response control

Đây là class bạn sẽ dùng nhiều nhất khi viết REST controllers. `ResponseEntity` cho bạn kiểm soát hoàn toàn response: status code, headers, và body.

Khi nào dùng `ResponseEntity` vs return trực tiếp? Rule of thumb: nếu method luôn trả 200 OK, return object trực tiếp cho gọn. Nếu cần custom status (201 Created, 204 No Content), custom headers (Location, ETag), hoặc conditional response (304 Not Modified) — dùng `ResponseEntity`.

Pattern quen thuộc: POST trả 201 + Location header chỉ resource mới tạo. DELETE trả 204 empty body. GET có thể trả 304 nếu client đã cache version mới nhất (ETag matching).

```java
@RestController
@RequestMapping("/api/v1/products")
public class ProductController {

   // 200 OK với body
   @GetMapping("/{id}")
   public ResponseEntity<APIResponse<ProductDTO>> get(@PathVariable UUID id) {
       ProductDTO product = productService.getById(id);
       return ResponseEntity.ok(APIResponse.success(product));
   }

   // 201 Created với Location header
   @PostMapping
   public ResponseEntity<APIResponse<ProductDTO>> create(@Valid @RequestBody CreateRequest req) {
       ProductDTO created = productService.create(req);
       URI location = ServletUriComponentsBuilder.fromCurrentRequest()
           .path("/{id}")
           .buildAndExpand(created.getId())
           .toUri();
       return ResponseEntity.created(location).body(APIResponse.success(created));
   }

   // 204 No Content
   @DeleteMapping("/{id}")
   public ResponseEntity<Void> delete(@PathVariable UUID id) {
       productService.delete(id);
       return ResponseEntity.noContent().build();
   }

   // 202 Accepted (async processing)
   @PostMapping("/import")
   public ResponseEntity<Void> importAsync(@RequestBody ImportRequest request) {
       String jobId = jobService.submit(request);
       return ResponseEntity.accepted()
           .header("X-Job-Id", jobId)
           .header("Location", "/api/v1/jobs/" + jobId)
           .build();
   }

   // Custom status + headers
   @GetMapping("/export")
   public ResponseEntity<byte[]> export() {
       byte[] data = exportService.generateCsv();
       return ResponseEntity.ok()
           .contentType(MediaType.parseMediaType("text/csv"))
           .contentLength(data.length)
           .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"export.csv\"")
           .header(HttpHeaders.CACHE_CONTROL, "no-cache")
           .body(data);
   }

   // Conditional — ETag / 304 Not Modified
   @GetMapping("/{id}")
   public ResponseEntity<ProductDTO> getWithEtag(@PathVariable UUID id, WebRequest request) {
       ProductDTO product = productService.getById(id);
       String etag = "\"v" + product.getVersion() + "\"";

       if (request.checkNotModified(etag)) {
           return null; // Spring returns 304 automatically
       }

       return ResponseEntity.ok()
           .eTag(etag)
           .lastModified(product.getUpdatedAt().toInstant(ZoneOffset.UTC))
           .cacheControl(CacheControl.maxAge(Duration.ofMinutes(5)))
           .body(product);
   }

   // Error responses
   @ExceptionHandler(EntityNotFoundException.class)
   public ResponseEntity<APIResponse<Void>> handleNotFound(EntityNotFoundException ex) {
       return ResponseEntity.status(HttpStatus.NOT_FOUND)
           .body(APIResponse.error("NOT_FOUND", ex.getMessage()));
   }
}
```

#### # responseentity builder methods

| Method                                 | Status | Use Case                  |
| -------------------------------------- | ------ | ------------------------- |
| `ResponseEntity.ok(body)`              | 200    | Successful GET/PUT/PATCH  |
| `ResponseEntity.created(uri).body(b)`  | 201    | Successful POST           |
| `ResponseEntity.accepted()`            | 202    | Async processing accepted |
| `ResponseEntity.noContent().build()`   | 204    | Successful DELETE         |
| `ResponseEntity.badRequest().body(b)`  | 400    | Validation error          |
| `ResponseEntity.notFound().build()`    | 404    | Resource not found        |
| `ResponseEntity.status(code).body(b)`  | Custom | Any status                |
| `ResponseEntity.unprocessableEntity()` | 422    | Business rule violation   |

### # HttpHeaders — http header management

Headers mang metadata về request/response: authentication token, content type, caching directives, custom business context (workspace ID, trace ID). Spring cung cấp `HttpHeaders` class với typed accessors thay vì raw string manipulation.

Trong CSP microservices, headers truyền context xuyên suốt request chain: `X-Workspace-Id` xác định tenant, `X-Request-Id` cho distributed tracing, `Authorization` mang JWT token. Mọi service đọc headers này để biết "ai đang gọi, trong context nào."

```java
// Tạo headers
HttpHeaders headers = new HttpHeaders();
headers.setContentType(MediaType.APPLICATION_JSON);
headers.setAccept(List.of(MediaType.APPLICATION_JSON));
headers.setBearerAuth("eyJhbGciOiJSUzI1NiIs...");
headers.set("X-Workspace-Id", workspaceId.toString());
headers.set("X-Request-Id", UUID.randomUUID().toString());
headers.setCacheControl(CacheControl.noCache());

// Common header constants
HttpHeaders.AUTHORIZATION       // "Authorization"
HttpHeaders.CONTENT_TYPE        // "Content-Type"
HttpHeaders.ACCEPT              // "Accept"
HttpHeaders.CACHE_CONTROL       // "Cache-Control"
HttpHeaders.CONTENT_DISPOSITION // "Content-Disposition"
HttpHeaders.CONTENT_LENGTH      // "Content-Length"
HttpHeaders.LOCATION            // "Location"
HttpHeaders.ETAG                // "ETag"
HttpHeaders.IF_NONE_MATCH       // "If-None-Match"
HttpHeaders.IF_MODIFIED_SINCE   // "If-Modified-Since"
HttpHeaders.COOKIE              // "Cookie"
HttpHeaders.SET_COOKIE          // "Set-Cookie"
HttpHeaders.ORIGIN              // "Origin"
HttpHeaders.ACCESS_CONTROL_ALLOW_ORIGIN // "Access-Control-Allow-Origin"

// Read headers in controller
@GetMapping
public ProductDTO get(@RequestHeader HttpHeaders headers) {
   String auth = headers.getFirst(HttpHeaders.AUTHORIZATION);
   MediaType contentType = headers.getContentType();
   long contentLength = headers.getContentLength();
   List<MediaType> accepts = headers.getAccept();
}

// Content-Disposition for file download
ContentDisposition disposition = ContentDisposition.attachment()
   .filename("report.pdf", StandardCharsets.UTF_8)
   .build();
headers.setContentDisposition(disposition);
```

### # mediatype — content types

`Content-Type` header cho biết body đang ở format gì. Hardcode string "application/json" khắp nơi là recipe cho typo bugs. `MediaType` constants type-safe, IDE-friendly, và bao gồm utility methods để parse và check compatibility.

Dùng trong `produces`/`consumes` trên controller methods, trong `HttpHeaders.setContentType()`, và khi build HTTP clients. Spring dựa vào MediaType để chọn đúng `HttpMessageConverter` (Jackson cho JSON, JAXB cho XML, etc.).

```java
// Predefined constants
MediaType.APPLICATION_JSON               // application/json
MediaType.APPLICATION_JSON_VALUE         // "application/json" (String)
MediaType.APPLICATION_XML                // application/xml
MediaType.APPLICATION_OCTET_STREAM      // application/octet-stream (binary)
MediaType.APPLICATION_PDF               // application/pdf
MediaType.APPLICATION_FORM_URLENCODED   // application/x-www-form-urlencoded
MediaType.MULTIPART_FORM_DATA           // multipart/form-data
MediaType.TEXT_PLAIN                     // text/plain
MediaType.TEXT_HTML                      // text/html
MediaType.TEXT_EVENT_STREAM             // text/event-stream (SSE)
MediaType.IMAGE_PNG                     // image/png
MediaType.IMAGE_JPEG                    // image/jpeg

// Custom media type
MediaType custom = new MediaType("application", "vnd.vpbank.v2+json");
MediaType csv = MediaType.parseMediaType("text/csv;charset=UTF-8");

// Check compatibility
MediaType.APPLICATION_JSON.isCompatibleWith(MediaType.parseMediaType("application/json"));

// Usage in controller
@GetMapping(produces = MediaType.APPLICATION_JSON_VALUE)
@PostMapping(consumes = MediaType.APPLICATION_JSON_VALUE)
@GetMapping(value = "/stream", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
```

### # RequestEntity & HttpEntity — http request representation

`HttpEntity` đóng gói headers + body thành 1 object duy nhất — tiện khi pass vào RestTemplate. `RequestEntity` mở rộng thêm HTTP method + URI — mô hình hóa đầy đủ 1 HTTP request.

Bạn sẽ gặp chúng chủ yếu khi viết HTTP clients (gọi service khác). Khi viết controllers, Spring tự parse request cho bạn qua `@RequestBody`, `@RequestHeader` — không cần dùng trực tiếp.

```java
// HttpEntity — base class (headers + body)
HttpEntity<CreateProductRequest> entity = new HttpEntity<>(request, headers);

// RequestEntity — includes method + URL
RequestEntity<CreateProductRequest> requestEntity = RequestEntity
   .post(URI.create("http://product-service/api/v1/products"))
   .contentType(MediaType.APPLICATION_JSON)
   .header("X-Workspace-Id", workspaceId.toString())
   .header("Authorization", "Bearer " + token)
   .body(request);

// GET without body
RequestEntity<Void> getRequest = RequestEntity
   .get(URI.create("http://product-service/api/v1/products/" + id))
   .accept(MediaType.APPLICATION_JSON)
   .header("Authorization", "Bearer " + token)
   .build();
```

### # RestTemplate (classic http client)

`RestTemplate` là HTTP client blocking truyền thống của Spring — đã tồn tại từ Spring 3 và vẫn hoạt động tốt. Mỗi request block thread cho đến khi nhận response.

Trong CSP, các services gọi nhau qua REST (sync communication). RestTemplate đơn giản, dễ hiểu, dễ debug — phù hợp cho hầu hết use cases khi bạn không cần reactive programming.

Lưu ý: Spring team đã đánh dấu RestTemplate là "maintenance mode" (không deprecated nhưng không thêm feature mới). Cho project mới, cân nhắc `RestClient` (Spring 6.1+) — API hiện đại hơn, cùng blocking model.

```java
@Configuration
public class RestTemplateConfig {

   @Bean
   public RestTemplate restTemplate(RestTemplateBuilder builder) {
       return builder
           .setConnectTimeout(Duration.ofSeconds(5))
           .setReadTimeout(Duration.ofSeconds(10))
           .rootUri("http://localhost:8080")
           .defaultHeader("X-Source", "csp-console")
           .errorHandler(new CustomErrorHandler())
           .interceptors(new LoggingInterceptor())
           .build();
   }
}

@Service
@RequiredArgsConstructor
@Slf4j
public class ProductClient {

   private final RestTemplate restTemplate;

   // GET
   public ProductDTO getProduct(UUID id) {
       return restTemplate.getForObject("/api/v1/products/{id}", ProductDTO.class, id);
   }

   // GET with ResponseEntity (access headers, status)
   public ResponseEntity<ProductDTO> getProductEntity(UUID id) {
       return restTemplate.getForEntity("/api/v1/products/{id}", ProductDTO.class, id);
   }

   // POST
   public ProductDTO createProduct(CreateProductRequest request) {
       return restTemplate.postForObject("/api/v1/products", request, ProductDTO.class);
   }

   // PUT
   public void updateProduct(UUID id, UpdateProductRequest request) {
       restTemplate.put("/api/v1/products/{id}", request, id);
   }

   // DELETE
   public void deleteProduct(UUID id) {
       restTemplate.delete("/api/v1/products/{id}", id);
   }

   // Exchange (full control)
   public Page<ProductDTO> searchProducts(String keyword, int page) {
       HttpHeaders headers = new HttpHeaders();
       headers.setBearerAuth(getToken());

       HttpEntity<Void> entity = new HttpEntity<>(headers);

       ResponseEntity<RestPageResponse<ProductDTO>> response = restTemplate.exchange(
           "/api/v1/products?keyword={keyword}&page={page}",
           HttpMethod.GET,
           entity,
           new ParameterizedTypeReference<>() {},
           keyword, page
       );

       return response.getBody();
   }

   // PATCH
   public ProductDTO patchProduct(UUID id, Map<String, Object> updates) {
       HttpHeaders headers = new HttpHeaders();
       headers.setContentType(MediaType.APPLICATION_JSON);
       HttpEntity<Map<String, Object>> entity = new HttpEntity<>(updates, headers);

       return restTemplate.patchForObject("/api/v1/products/{id}", entity, ProductDTO.class, id);
   }
}
```

### # WebClient (reactive http client — spring webflux)

`WebClient` là HTTP client non-blocking, reactive — design cho high-throughput scenarios. Nó không block thread trong khi chờ response, cho phép 1 thread handle nhiều concurrent requests.

Khi nào dùng WebClient thay RestTemplate?

- Cần gọi nhiều external services song song (fan-out pattern)
- Application đã dùng WebFlux/reactive stack
- Cần streaming responses (SSE, large file downloads)
- Cần built-in retry, timeout, backpressure

Dù WebClient là reactive, bạn vẫn có thể dùng nó blocking (`.block()`) trong servlet-based apps. Nhiều team dùng WebClient cho cả 2 cases vì API fluent và powerful hơn RestTemplate.

```java
@Configuration
public class WebClientConfig {

   @Bean
   public WebClient webClient() {
       return WebClient.builder()
           .baseUrl("http://product-service")
           .defaultHeader(HttpHeaders.CONTENT_TYPE, MediaType.APPLICATION_JSON_VALUE)
           .filter(ExchangeFilterFunctions.basicAuthentication("user", "pass"))
           .codecs(config -> config.defaultCodecs().maxInMemorySize(16 * 1024 * 1024))
           .build();
   }
}

@Service
@RequiredArgsConstructor
public class ProductWebClient {

   private final WebClient webClient;

   // GET — blocking
   public ProductDTO getProduct(UUID id) {
       return webClient.get()
           .uri("/api/v1/products/{id}", id)
           .header("Authorization", "Bearer " + token)
           .retrieve()
           .onStatus(HttpStatusCode::is4xxClientError, response ->
               Mono.error(new ResourceNotFoundException("Product not found")))
           .bodyToMono(ProductDTO.class)
           .block();  // Block for synchronous usage
   }

   // GET — reactive
   public Mono<ProductDTO> getProductReactive(UUID id) {
       return webClient.get()
           .uri("/api/v1/products/{id}", id)
           .retrieve()
           .bodyToMono(ProductDTO.class);
   }

   // GET list
   public List<ProductDTO> getProducts(String keyword) {
       return webClient.get()
           .uri(uriBuilder -> uriBuilder
               .path("/api/v1/products")
               .queryParam("keyword", keyword)
               .queryParam("size", 50)
               .build())
           .retrieve()
           .bodyToFlux(ProductDTO.class)
           .collectList()
           .block();
   }

   // POST
   public ProductDTO createProduct(CreateProductRequest request) {
       return webClient.post()
           .uri("/api/v1/products")
           .bodyValue(request)
           .retrieve()
           .bodyToMono(ProductDTO.class)
           .block();
   }

   // PUT with error handling
   public ProductDTO updateProduct(UUID id, UpdateProductRequest request) {
       return webClient.put()
           .uri("/api/v1/products/{id}", id)
           .bodyValue(request)
           .retrieve()
           .onStatus(HttpStatusCode::is4xxClientError, response ->
               response.bodyToMono(String.class)
                   .flatMap(body -> Mono.error(new ClientException(body))))
           .onStatus(HttpStatusCode::is5xxServerError, response ->
               Mono.error(new ServiceUnavailableException("Product service down")))
           .bodyToMono(ProductDTO.class)
           .timeout(Duration.ofSeconds(10))
           .retryWhen(Retry.backoff(3, Duration.ofSeconds(1)))
           .block();
   }

   // DELETE
   public void deleteProduct(UUID id) {
       webClient.delete()
           .uri("/api/v1/products/{id}", id)
           .retrieve()
           .toBodilessEntity()
           .block();
   }
}
```

### # RestClient (spring 6.1+ — modern blocking client)

`RestClient` là "RestTemplate 2.0" — cùng blocking model nhưng API fluent, hiện đại, consistent với WebClient style. Nếu bạn đang Spring Boot 3.2+, đây là recommended choice cho blocking HTTP calls.

API design giống WebClient (`.get().uri().retrieve().body()`) nhưng synchronous — không cần `.block()`, không cần hiểu Mono/Flux. Best of both worlds: đơn giản như RestTemplate, fluent như WebClient.

```java
@Configuration
public class RestClientConfig {

   @Bean
   public RestClient restClient() {
       return RestClient.builder()
           .baseUrl("http://product-service")
           .defaultHeader(HttpHeaders.CONTENT_TYPE, MediaType.APPLICATION_JSON_VALUE)
           .requestInterceptor((request, body, execution) -> {
               request.getHeaders().setBearerAuth(tokenProvider.getToken());
               return execution.execute(request, body);
           })
           .build();
   }
}

@Service
@RequiredArgsConstructor
public class ProductRestClient {

   private final RestClient restClient;

   public ProductDTO getProduct(UUID id) {
       return restClient.get()
           .uri("/api/v1/products/{id}", id)
           .retrieve()
           .body(ProductDTO.class);
   }

   public ProductDTO createProduct(CreateProductRequest request) {
       return restClient.post()
           .uri("/api/v1/products")
           .body(request)
           .retrieve()
           .body(ProductDTO.class);
   }

   public ResponseEntity<ProductDTO> getWithStatus(UUID id) {
       return restClient.get()
           .uri("/api/v1/products/{id}", id)
           .retrieve()
           .toEntity(ProductDTO.class);
   }

   public void deleteProduct(UUID id) {
       restClient.delete()
           .uri("/api/v1/products/{id}", id)
           .retrieve()
           .toBodilessEntity();
   }
}
```

### # CacheControl — http caching

HTTP caching là performance optimization miễn phí — client/CDN cache response, giảm load lên server. Nhưng cache sai thì user thấy data cũ. `CacheControl` builder giúp bạn set đúng directives.

Rule of thumb: static resources (images, CSS) → `max-age` dài. Dynamic API responses → short `max-age` + `must-revalidate`, hoặc ETag-based validation. Sensitive data (user profile, payment) → `no-store`.

```java
@GetMapping("/{id}")
public ResponseEntity<ProductDTO> get(@PathVariable UUID id) {
   ProductDTO product = productService.getById(id);
   return ResponseEntity.ok()
       .cacheControl(CacheControl.maxAge(Duration.ofMinutes(5))
           .mustRevalidate()
           .cachePublic())
       .body(product);
}

// No cache
@GetMapping("/me")
public ResponseEntity<UserDTO> getCurrentUser() {
   return ResponseEntity.ok()
       .cacheControl(CacheControl.noStore())
       .body(userService.getCurrentUser());
}

// CacheControl options
CacheControl.maxAge(Duration.ofHours(1))       // max-age=3600
CacheControl.maxAge(60, TimeUnit.SECONDS)      // max-age=60
CacheControl.noCache()                          // no-cache (revalidate every time)
CacheControl.noStore()                          // no-store (never cache)
CacheControl.empty()                            // No directives
   .mustRevalidate()                           // must-revalidate
   .cachePublic()                              // public
   .cachePrivate()                             // private
   .sMaxAge(Duration.ofMinutes(10))           // s-maxage (shared cache)
   .staleWhileRevalidate(Duration.ofSeconds(30)) // stale-while-revalidate
```

### # HttpMethod — http methods enum

Đơn giản nhưng cần thiết: enum cho tất cả HTTP methods. Dùng thay vì hardcode string khi build dynamic requests hoặc configure CORS allowed methods. Type-safe > string comparison.

```java
HttpMethod.GET
HttpMethod.POST
HttpMethod.PUT
HttpMethod.PATCH
HttpMethod.DELETE
HttpMethod.HEAD
HttpMethod.OPTIONS
HttpMethod.TRACE

// Usage with RestTemplate
restTemplate.exchange(url, HttpMethod.PATCH, entity, ProductDTO.class);

// Check method
HttpMethod method = HttpMethod.valueOf("POST");
method.matches("POST");  // true
```

### # cookie & ResponseCookie

Cookies truyền state giữa client và server — session IDs, refresh tokens, preferences. `ResponseCookie` builder đảm bảo bạn set đúng security attributes: `HttpOnly` (JS không đọc được), `Secure` (chỉ HTTPS), `SameSite` (chống CSRF).

Trong CSP với OAuth2/JWT, access token thường ở header, nhưng refresh token có thể ở HttpOnly cookie — secure hơn vì JavaScript (và XSS attacks) không access được.

```java
// Tạo cookie
ResponseCookie cookie = ResponseCookie.from("session_id", sessionId)
   .httpOnly(true)
   .secure(true)
   .path("/")
   .maxAge(Duration.ofHours(24))
   .sameSite("Strict")
   .domain(".vpbank.com")
   .build();

// Set trong response
@PostMapping("/login")
public ResponseEntity<LoginResponse> login(@RequestBody LoginRequest request) {
   LoginResponse response = authService.login(request);
   ResponseCookie cookie = ResponseCookie.from("refresh_token", response.getRefreshToken())
       .httpOnly(true).secure(true).path("/api/auth").maxAge(Duration.ofDays(7)).build();

   return ResponseEntity.ok()
       .header(HttpHeaders.SET_COOKIE, cookie.toString())
       .body(response);
}

// Delete cookie
ResponseCookie deleteCookie = ResponseCookie.from("session_id", "")
   .maxAge(0)
   .path("/")
   .build();
```

### # HttpStatusCode & ProblemDetail (spring 6+)

`ProblemDetail` implement RFC 7807 — standard format cho error responses. Thay vì mỗi team tự định nghĩa error JSON khác nhau, RFC 7807 cung cấp structure chung: `type` (URI xác định loại lỗi), `title`, `status`, `detail`, `instance`.

Lợi ích: API consumers biết chính xác cấu trúc error response — parse được, hiển thị được, log được. Spring 6 tích hợp native — chỉ cần return `ProblemDetail` từ `@ExceptionHandler` là có chuẩn RFC 7807.

```java
// ProblemDetail — RFC 7807 error response
@ExceptionHandler(ProductNotFoundException.class)
public ProblemDetail handleNotFound(ProductNotFoundException ex) {
   ProblemDetail problem = ProblemDetail.forStatusAndDetail(
       HttpStatus.NOT_FOUND, ex.getMessage());
   problem.setTitle("Product Not Found");
   problem.setType(URI.create("https://api.vpbank.com/errors/product-not-found"));
   problem.setProperty("productId", ex.getProductId());
   problem.setProperty("timestamp", Instant.now());
   return problem;
}
```

**Output RFC 7807:**

```json
{
  "type": "https://api.vpbank.com/errors/product-not-found",
  "title": "Product Not Found",
  "status": 404,
  "detail": "Product with ID abc-123 not found",
  "instance": "/api/v1/products/abc-123",
  "productId": "abc-123",
  "timestamp": "2024-01-15T10:30:00Z"
}
```

### # quick reference

| Class/Interface    | Mục đích                                     |
| ------------------ | -------------------------------------------- |
| HttpStatus         | HTTP status code enum                        |
| HttpStatusCode     | Status code interface (Spring 6)             |
| ResponseEntity     | Full response (status + headers + body)      |
| RequestEntity      | Full request (method + URI + headers + body) |
| HttpEntity         | Headers + body wrapper                       |
| HttpHeaders        | HTTP header manipulation                     |
| MediaType          | Content-Type constants                       |
| HttpMethod         | HTTP method enum                             |
| CacheControl       | Cache-Control header builder                 |
| ContentDisposition | Content-Disposition header                   |
| ResponseCookie     | Set-Cookie builder                           |
| ProblemDetail      | RFC 7807 error response                      |
| RestTemplate       | Classic blocking HTTP client                 |
| WebClient          | Reactive/non-blocking HTTP client            |
| RestClient         | Modern blocking client (Spring 6.1+)         |

> Chỉ là những ghi chép cá nhân với hy vọng mang lại chút giá trị. Nếu thấy hữu ích, đừng ngại chia sẻ cho bạn bè & đồng nghiệp nhé!

Happy coding <Twemoji emoji="clinking-beer-mugs" /> 😎 👍🏻 🚀 🔥.
