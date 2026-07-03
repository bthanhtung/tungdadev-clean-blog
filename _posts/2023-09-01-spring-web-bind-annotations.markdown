---
layout: post
title: "spring web bind annotations"
date: 2023-09-01 19:29:39 +0700
categories: [Software Development]
tags: [java, software-development, spring-framework, best-practices, vietnamese]
---

### # giới thiệu

`org.springframework.web.bind.annotation.*` chứa các annotation xử lý HTTP request/response trong Spring MVC. Đây là foundation của mọi REST API trong Spring Boot.

#### # dependency (đã có trong starter-web)

```xml
<dependency>
   <groupId>org.springframework.boot</groupId>
   <artifactId>spring-boot-starter-web</artifactId>
</dependency>
```

### # controller annotations

#### # @Controller vs @RestController

```java
// @Controller — trả về view name (Thymeleaf, JSP)
@Controller
@RequestMapping("/pages")
public class PageController {

   @GetMapping("/home")
   public String home(Model model) {
       model.addAttribute("title", "Home");
       return "home"; // → src/main/resources/templates/home.html
   }

   // Muốn trả JSON trong @Controller → thêm @ResponseBody
   @GetMapping("/api/data")
   @ResponseBody
   public Map<String, String> getData() {
       return Map.of("key", "value");
   }
}

// @RestController = @Controller + @ResponseBody (mọi method đều trả JSON)
@RestController
@RequestMapping("/api/v1/products")
public class ProductController {

   @GetMapping
   public List<ProductDTO> list() {
       return productService.findAll(); // Auto serialize to JSON
   }
}
```

#### # @RequestMapping — base mapping cho class/method

```java
@RestController
@RequestMapping(
   path = "/api/v1/products",            // Base URL
   produces = MediaType.APPLICATION_JSON_VALUE,  // Response Content-Type
   consumes = MediaType.APPLICATION_JSON_VALUE   // Request Content-Type (chỉ cho POST/PUT)
)
public class ProductController { ... }
```

**@RequestMapping attributes:**

| Attribute  | Mô tả                 | Ví dụ              |
| ---------- | --------------------- | ------------------ |
| path/value | URL pattern           | "/api/v1/users"    |
| method     | HTTP method           | RequestMethod.GET  |
| produces   | Response content type | "application/json" |
| consumes   | Request content type  | "application/json" |
| params     | Required params       | "type=active"      |
| headers    | Required headers      | "X-API-Key"        |

### # http method annotations

#### # @GetMapping, @PostMapping, @PutMapping, @PatchMapping, @DeleteMapping

```java
@RestController
@RequestMapping("/api/v1/orders")
@RequiredArgsConstructor
public class OrderController {

   private final OrderService orderService;

   // GET /api/v1/orders
   @GetMapping
   public ResponseEntity<APIResponse<Page<OrderDTO>>> list(Pageable pageable) {
       return ResponseEntity.ok(APIResponse.success(orderService.findAll(pageable)));
   }

   // GET /api/v1/orders/{id}
   @GetMapping("/{id}")
   public ResponseEntity<APIResponse<OrderDTO>> getById(@PathVariable UUID id) {
       return ResponseEntity.ok(APIResponse.success(orderService.getById(id)));
   }

   // GET /api/v1/orders/search?keyword=abc&status=PENDING
   @GetMapping("/search")
   public ResponseEntity<APIResponse<Page<OrderDTO>>> search(
           @RequestParam(required = false) String keyword,
           @RequestParam(required = false) OrderStatus status,
           Pageable pageable) {
       return ResponseEntity.ok(APIResponse.success(orderService.search(keyword, status, pageable)));
   }

   // POST /api/v1/orders
   @PostMapping
   @ResponseStatus(HttpStatus.CREATED)
   public ResponseEntity<APIResponse<OrderDTO>> create(
           @Valid @RequestBody CreateOrderRequest request) {
       OrderDTO created = orderService.create(request);
       URI location = URI.create("/api/v1/orders/" + created.getId());
       return ResponseEntity.created(location).body(APIResponse.success(created));
   }

   // PUT /api/v1/orders/{id} — Full update (replace toàn bộ)
   @PutMapping("/{id}")
   public ResponseEntity<APIResponse<OrderDTO>> update(
           @PathVariable UUID id,
           @Valid @RequestBody UpdateOrderRequest request) {
       return ResponseEntity.ok(APIResponse.success(orderService.update(id, request)));
   }

   // PATCH /api/v1/orders/{id} — Partial update (chỉ update fields gửi lên)
   @PatchMapping("/{id}")
   public ResponseEntity<APIResponse<OrderDTO>> patch(
           @PathVariable UUID id,
           @RequestBody Map<String, Object> updates) {
       return ResponseEntity.ok(APIResponse.success(orderService.patch(id, updates)));
   }

   // PATCH /api/v1/orders/{id}/status
   @PatchMapping("/{id}/status")
   public ResponseEntity<APIResponse<OrderDTO>> updateStatus(
           @PathVariable UUID id,
           @RequestParam OrderStatus status) {
       return ResponseEntity.ok(APIResponse.success(orderService.updateStatus(id, status)));
   }

   // DELETE /api/v1/orders/{id}
   @DeleteMapping("/{id}")
   @ResponseStatus(HttpStatus.NO_CONTENT)
   public void delete(@PathVariable UUID id) {
       orderService.delete(id);
   }
}
```

#### # mapping nâng cao

```java
// Multiple paths
@GetMapping({"/", "/list", "/all"})
public List<OrderDTO> listAll() { ... }

// Conditional mapping by params
@GetMapping(params = "type=draft")      // GET /orders?type=draft
public List<OrderDTO> getDrafts() { ... }

@GetMapping(params = "type=completed")  // GET /orders?type=completed
public List<OrderDTO> getCompleted() { ... }

// Conditional mapping by headers
@GetMapping(headers = "X-API-Version=2")
public List<OrderDTOv2> listV2() { ... }

// Conditional by Accept header
@GetMapping(produces = "application/xml")
public List<OrderDTO> listXml() { ... }

@GetMapping(produces = "application/json")
public List<OrderDTO> listJson() { ... }
```

### # request parameter annotations

#### # @PathVariable — url path segment

```java
// Cơ bản
@GetMapping("/{id}")
public OrderDTO getById(@PathVariable UUID id) { ... }

// Tên khác với parameter name
@GetMapping("/{order-id}")
public OrderDTO getById(@PathVariable("order-id") UUID orderId) { ... }

// Multiple path variables
@GetMapping("/{orderId}/items/{itemId}")
public OrderItemDTO getItem(
       @PathVariable UUID orderId,
       @PathVariable UUID itemId) { ... }

// Optional path variable
@GetMapping({"/orders", "/orders/{id}"})
public Object getOrders(@PathVariable(required = false) UUID id) {
   if (id != null) return orderService.getById(id);
   return orderService.findAll();
}

// Regex pattern
@GetMapping("/{id:\\d+}")  // Chỉ match số
public OrderDTO getByNumericId(@PathVariable Long id) { ... }

@GetMapping("/code/{code:[A-Z]{3}-\\d{4}}")  // Match pattern VD: ORD-0001
public OrderDTO getByCode(@PathVariable String code) { ... }
```

#### # @RequestParam — query parameters

```java
// Cơ bản — required by default
@GetMapping("/search")
public Page<OrderDTO> search(@RequestParam String keyword) { ... }
// GET /search?keyword=laptop → OK
// GET /search → 400 Bad Request (missing required param)

// Optional với default value
@GetMapping
public Page<OrderDTO> list(
       @RequestParam(defaultValue = "0") int page,
       @RequestParam(defaultValue = "20") int size,
       @RequestParam(defaultValue = "createdAt") String sortBy,
       @RequestParam(defaultValue = "desc") String direction) { ... }

// Optional (nullable)
@GetMapping("/filter")
public List<OrderDTO> filter(
       @RequestParam(required = false) OrderStatus status,    // null nếu không gửi
       @RequestParam(required = false) UUID categoryId,
       @RequestParam(required = false) String keyword) { ... }

// Collection parameter
@GetMapping("/batch")
public List<OrderDTO> getByIds(@RequestParam List<UUID> ids) { ... }
// GET /batch?ids=uuid1&ids=uuid2&ids=uuid3
// hoặc GET /batch?ids=uuid1,uuid2,uuid3

// Map — nhận tất cả params
@GetMapping("/dynamic")
public List<OrderDTO> dynamicFilter(@RequestParam Map<String, String> allParams) {
   // allParams = {keyword=abc, status=PENDING, page=0}
   return orderService.dynamicFilter(allParams);
}

// Enum parameter — auto convert string to enum
@GetMapping("/by-status")
public List<OrderDTO> byStatus(@RequestParam OrderStatus status) { ... }
// GET /by-status?status=PENDING → OrderStatus.PENDING
```

#### # @RequestHeader — http headers

```java
@GetMapping
public OrderDTO get(
       @RequestHeader("Authorization") String authHeader,
       @RequestHeader("X-Workspace-Id") UUID workspaceId,
       @RequestHeader(value = "X-Request-Id", required = false) String requestId,
       @RequestHeader(value = "Accept-Language", defaultValue = "vi") String lang) {
   // ...
}

// Nhận tất cả headers
@GetMapping
public void process(@RequestHeader HttpHeaders headers) {
   String auth = headers.getFirst("Authorization");
   List<MediaType> accepts = headers.getAccept();
}

// Map
@GetMapping
public void process(@RequestHeader Map<String, String> headers) { ... }
```

#### # @CookieValue — http cookies

```java
@GetMapping
public UserDTO getCurrentUser(
       @CookieValue("session_id") String sessionId,
       @CookieValue(value = "preferences", required = false) String preferences) {
   return userService.getBySession(sessionId);
}
```

#### # @RequestBody — json body → java object

```java
@PostMapping
public OrderDTO create(@Valid @RequestBody CreateOrderRequest request) {
   return orderService.create(request);
}

// Optional body
@PatchMapping("/{id}")
public OrderDTO patch(
       @PathVariable UUID id,
       @RequestBody(required = false) Map<String, Object> updates) {
   if (updates == null || updates.isEmpty()) return orderService.getById(id);
   return orderService.patch(id, updates);
}
```

#### # @RequestPart — multipart request (file upload + json)

```java
@PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
public ResponseEntity<APIResponse<DocumentDTO>> upload(
       @RequestPart("file") MultipartFile file,
       @RequestPart("metadata") @Valid DocumentMetadataDTO metadata) {
   // file → binary data
   // metadata → JSON object (auto-deserialized)
   return ResponseEntity.ok(APIResponse.success(documentService.upload(file, metadata)));
}

// Multiple files
@PostMapping("/batch-upload")
public List<DocumentDTO> batchUpload(
       @RequestPart("files") List<MultipartFile> files,
       @RequestPart(value = "description", required = false) String description) {
   return files.stream()
       .map(file -> documentService.upload(file, description))
       .toList();
}
```

#### # @ModelAttribute — form data / query params → object

```java
// Bind query params vào object
@GetMapping("/search")
public Page<OrderDTO> search(@ModelAttribute OrderSearchCriteria criteria, Pageable pageable) {
   // GET /search?keyword=abc&status=PENDING&minPrice=100
   // → OrderSearchCriteria{keyword="abc", status=PENDING, minPrice=100}
   return orderService.search(criteria, pageable);
}

@Data
public class OrderSearchCriteria {
   private String keyword;
   private OrderStatus status;
   private BigDecimal minPrice;
   private BigDecimal maxPrice;
   private LocalDate fromDate;
   private LocalDate toDate;
}

// Pre-populate model (chạy trước mọi @RequestMapping trong controller)
@ModelAttribute("currentUser")
public UserDTO populateCurrentUser(Authentication auth) {
   return userService.getByUsername(auth.getName());
}
```

### # response annotations

#### # @ResponseStatus — set http status code

```java
// Method level
@PostMapping
@ResponseStatus(HttpStatus.CREATED)  // 201
public OrderDTO create(@Valid @RequestBody CreateOrderRequest request) { ... }

@DeleteMapping("/{id}")
@ResponseStatus(HttpStatus.NO_CONTENT)  // 204
public void delete(@PathVariable UUID id) { ... }

@PostMapping("/validate")
@ResponseStatus(HttpStatus.OK)  // 200 (explicit)
public ValidationResult validate(@RequestBody ValidateRequest request) { ... }

// Exception class level
@ResponseStatus(HttpStatus.NOT_FOUND)
public class ResourceNotFoundException extends RuntimeException {
   public ResourceNotFoundException(String message) { super(message); }
}

@ResponseStatus(value = HttpStatus.CONFLICT, reason = "Resource already exists")
public class DuplicateResourceException extends RuntimeException { ... }
```

#### # @ResponseBody — serialize return value to response body

```java
// Đã implicit trong @RestController, chỉ cần khi dùng @Controller
@Controller
public class HybridController {

   @GetMapping("/page")
   public String viewPage() { return "page"; }  // Returns view name

   @GetMapping("/api/data")
   @ResponseBody  // Returns JSON
   public DataDTO getData() { return new DataDTO(); }
}
```

#### # ResponseEntity — full control over response

```java
@RestController
@RequestMapping("/api/v1/files")
public class FileController {

   // Custom status + headers + body
   @PostMapping("/upload")
   public ResponseEntity<APIResponse<FileDTO>> upload(@RequestPart MultipartFile file) {
       FileDTO result = fileService.upload(file);
       return ResponseEntity
           .status(HttpStatus.CREATED)
           .header("X-File-Id", result.getId().toString())
           .header("Location", "/api/v1/files/" + result.getId())
           .body(APIResponse.success(result));
   }

   // File download
   @GetMapping("/{id}/download")
   public ResponseEntity<Resource> download(@PathVariable UUID id) {
       FileDownload download = fileService.getFile(id);
       return ResponseEntity.ok()
           .contentType(MediaType.parseMediaType(download.getContentType()))
           .header(HttpHeaders.CONTENT_DISPOSITION,
               "attachment; filename=\"" + download.getFilename() + "\"")
           .contentLength(download.getSize())
           .body(download.getResource());
   }

   // Conditional response (ETag/304)
   @GetMapping("/{id}")
   public ResponseEntity<FileDTO> get(@PathVariable UUID id, WebRequest request) {
       FileDTO file = fileService.getById(id);
       String etag = "\"" + file.getVersion() + "\"";

       if (request.checkNotModified(etag)) {
           return null;  // 304 Not Modified (Spring handles)
       }

       return ResponseEntity.ok()
           .eTag(etag)
           .cacheControl(CacheControl.maxAge(Duration.ofHours(1)))
           .body(file);
   }

   // No content (void alternatives)
   @DeleteMapping("/{id}")
   public ResponseEntity<Void> delete(@PathVariable UUID id) {
       fileService.delete(id);
       return ResponseEntity.noContent().build();
   }

   // Accepted (async processing)
   @PostMapping("/process")
   public ResponseEntity<Void> processAsync(@RequestBody ProcessRequest request) {
       String jobId = jobService.submit(request);
       return ResponseEntity.accepted()
           .header("X-Job-Id", jobId)
           .header("Location", "/api/v1/jobs/" + jobId)
           .build();
   }
}
```

### # exception handling annotations

#### # @ExceptionHandler — xử lý exception trong controller

```java
@RestController
@RequestMapping("/api/v1/products")
public class ProductController {

   // Chỉ apply cho controller này
   @ExceptionHandler(ProductNotFoundException.class)
   @ResponseStatus(HttpStatus.NOT_FOUND)
   public APIResponse<Void> handleNotFound(ProductNotFoundException ex) {
       return APIResponse.error("PRD_001_404", ex.getMessage());
   }

   @ExceptionHandler(DuplicateProductException.class)
   public ResponseEntity<APIResponse<Void>> handleDuplicate(DuplicateProductException ex) {
       return ResponseEntity.status(HttpStatus.CONFLICT)
           .body(APIResponse.error("PRD_002_409", ex.getMessage()));
   }
}
```

#### # @RestControllerAdvice / @ControllerAdvice — global exception handling

```java
@RestControllerAdvice  // = @ControllerAdvice + @ResponseBody
@Slf4j
public class GlobalExceptionHandler {

   // Validation errors (Jakarta Bean Validation)
   @ExceptionHandler(MethodArgumentNotValidException.class)
   @ResponseStatus(HttpStatus.BAD_REQUEST)
   public APIResponse<Map<String, String>> handleValidation(MethodArgumentNotValidException ex) {
       Map<String, String> errors = ex.getBindingResult().getFieldErrors().stream()
           .collect(Collectors.toMap(
               FieldError::getField,
               fe -> fe.getDefaultMessage() != null ? fe.getDefaultMessage() : "Invalid",
               (a, b) -> a  // merge duplicates
           ));
       return APIResponse.error("VALIDATION_ERROR", "Validation failed", errors);
   }

   // Constraint violation (path params, query params)
   @ExceptionHandler(ConstraintViolationException.class)
   @ResponseStatus(HttpStatus.BAD_REQUEST)
   public APIResponse<List<String>> handleConstraint(ConstraintViolationException ex) {
       List<String> errors = ex.getConstraintViolations().stream()
           .map(v -> v.getPropertyPath() + ": " + v.getMessage())
           .toList();
       return APIResponse.error("CONSTRAINT_ERROR", "Constraint violation", errors);
   }

   // Entity not found
   @ExceptionHandler(EntityNotFoundException.class)
   @ResponseStatus(HttpStatus.NOT_FOUND)
   public APIResponse<Void> handleNotFound(EntityNotFoundException ex) {
       return APIResponse.error("NOT_FOUND", ex.getMessage());
   }

   // Access denied
   @ExceptionHandler(AccessDeniedException.class)
   @ResponseStatus(HttpStatus.FORBIDDEN)
   public APIResponse<Void> handleForbidden(AccessDeniedException ex) {
       return APIResponse.error("FORBIDDEN", "Access denied");
   }

   // Bad request (type mismatch, missing params)
   @ExceptionHandler({
       MissingServletRequestParameterException.class,
       MethodArgumentTypeMismatchException.class,
       HttpMessageNotReadableException.class
   })
   @ResponseStatus(HttpStatus.BAD_REQUEST)
   public APIResponse<Void> handleBadRequest(Exception ex) {
       return APIResponse.error("BAD_REQUEST", ex.getMessage());
   }

   // Method not allowed (405)
   @ExceptionHandler(HttpRequestMethodNotSupportedException.class)
   @ResponseStatus(HttpStatus.METHOD_NOT_ALLOWED)
   public APIResponse<Void> handleMethodNotAllowed(HttpRequestMethodNotSupportedException ex) {
       return APIResponse.error("METHOD_NOT_ALLOWED",
           "Method " + ex.getMethod() + " not supported. Use: " + ex.getSupportedHttpMethods());
   }

   // Unsupported media type (415)
   @ExceptionHandler(HttpMediaTypeNotSupportedException.class)
   @ResponseStatus(HttpStatus.UNSUPPORTED_MEDIA_TYPE)
   public APIResponse<Void> handleUnsupportedMedia(HttpMediaTypeNotSupportedException ex) {
       return APIResponse.error("UNSUPPORTED_MEDIA", ex.getMessage());
   }

   // Optimistic lock (409 Conflict)
   @ExceptionHandler(OptimisticLockException.class)
   @ResponseStatus(HttpStatus.CONFLICT)
   public APIResponse<Void> handleOptimisticLock(OptimisticLockException ex) {
       return APIResponse.error("CONFLICT", "Resource was modified by another user. Please retry.");
   }

   // Catch-all
   @ExceptionHandler(Exception.class)
   @ResponseStatus(HttpStatus.INTERNAL_SERVER_ERROR)
   public APIResponse<Void> handleGeneral(Exception ex, HttpServletRequest request) {
       String traceId = request.getHeader("X-Trace-Id");
       log.error("[traceId={}] Unhandled exception at {}", traceId, request.getRequestURI(), ex);
       return APIResponse.error("INTERNAL_ERROR", "An unexpected error occurred");
   }
}
```

#### # @ControllerAdvice với scope hạn chế

```java
// Chỉ apply cho package cụ thể
@RestControllerAdvice(basePackages = "vn.com.vpbank.internal.csp.product.controller")
public class ProductExceptionHandler { ... }

// Chỉ apply cho controllers có annotation cụ thể
@RestControllerAdvice(annotations = RestController.class)
public class RestExceptionHandler { ... }

// Chỉ apply cho classes cụ thể
@RestControllerAdvice(assignableTypes = {ProductController.class, OrderController.class})
public class CommerceExceptionHandler { ... }
```

### # @CrossOrigin — CORS Configuration

```java
// Method level
@GetMapping("/public-data")
@CrossOrigin(origins = "https://app.vpbank.com")
public List<DataDTO> getPublicData() { ... }

// Controller level
@RestController
@RequestMapping("/api/v1/products")
@CrossOrigin(
   origins = {"https://app.vpbank.com", "https://admin.vpbank.com"},
   methods = {RequestMethod.GET, RequestMethod.POST},
   allowedHeaders = {"Authorization", "Content-Type", "X-Workspace-Id"},
   exposedHeaders = {"X-Total-Count", "X-Page-Count"},
   allowCredentials = "true",
   maxAge = 3600  // preflight cache 1 hour
)
public class ProductController { ... }

// Global CORS (thường dùng cách này thay vì @CrossOrigin)
@Configuration
public class CorsConfig implements WebMvcConfigurer {

   @Override
   public void addCorsMappings(CorsRegistry registry) {
       registry.addMapping("/api/**")
           .allowedOrigins("https://app.vpbank.com", "https://admin.vpbank.com")
           .allowedMethods("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS")
           .allowedHeaders("*")
           .exposedHeaders("X-Total-Count")
           .allowCredentials(true)
           .maxAge(3600);
   }
}
```

### # @InitBinder — custom data binding

```java
@RestController
@RequestMapping("/api/v1/reports")
public class ReportController {

   // Áp dụng cho tất cả methods trong controller này
   @InitBinder
   public void initBinder(WebDataBinder binder) {
       // Custom date format cho @RequestParam
       SimpleDateFormat dateFormat = new SimpleDateFormat("dd/MM/yyyy");
       dateFormat.setLenient(false);
       binder.registerCustomEditor(Date.class, new CustomDateEditor(dateFormat, true));

       // Trim whitespace cho String params
       binder.registerCustomEditor(String.class, new StringTrimmerEditor(true));

       // Disallow binding certain fields (security)
       binder.setDisallowedFields("id", "createdAt", "createdBy");
   }

   @GetMapping
   public List<ReportDTO> getReports(
           @RequestParam Date fromDate,  // Sẽ parse "15/01/2024" thành Date
           @RequestParam Date toDate) { ... }
}

// Global InitBinder
@ControllerAdvice
public class GlobalBinderAdvice {

   @InitBinder
   public void initBinder(WebDataBinder binder) {
       binder.registerCustomEditor(String.class, new StringTrimmerEditor(true));
   }
}
```

### # @RequestAttribute & @SessionAttribute

#### # @RequestAttribute — dữ liệu từ filter/interceptor

```java
// Filter set attribute
@Component
public class WorkspaceFilter extends OncePerRequestFilter {
   @Override
   protected void doFilterInternal(HttpServletRequest request,
           HttpServletResponse response, FilterChain chain) throws ServletException, IOException {
       String workspaceId = request.getHeader("X-Workspace-Id");
       request.setAttribute("workspaceId", UUID.fromString(workspaceId));
       chain.doFilter(request, response);
   }
}

// Controller nhận attribute
@GetMapping
public List<ProductDTO> list(@RequestAttribute UUID workspaceId) {
   return productService.findByWorkspace(workspaceId);
}

@GetMapping("/{id}")
public ProductDTO get(
       @PathVariable UUID id,
       @RequestAttribute(required = false) String currentUserId) { ... }
```

#### # @SessionAttributes — lưu data trong session (mvc forms)

```java
@Controller
@SessionAttributes("wizard")  // Lưu "wizard" object trong session
@RequestMapping("/wizard")
public class WizardController {

   @ModelAttribute("wizard")
   public WizardForm createWizard() {
       return new WizardForm();
   }

   @PostMapping("/step1")
   public String step1(@ModelAttribute("wizard") WizardForm wizard,
                       @RequestParam String name) {
       wizard.setName(name);
       return "redirect:/wizard/step2";
   }

   @PostMapping("/step2")
   public String step2(@ModelAttribute("wizard") WizardForm wizard,
                       @RequestParam String email,
                       SessionStatus status) {
       wizard.setEmail(email);
       wizardService.complete(wizard);
       status.setComplete();  // Clear session attribute
       return "redirect:/wizard/done";
   }
}
```

### # @MatrixVariable — url matrix parameters

```java
// URL: /api/products/filter;color=red;size=L/sort;by=price;dir=asc
@GetMapping("/filter/{filter}/sort/{sort}")
public List<ProductDTO> filter(
       @MatrixVariable(pathVar = "filter") Map<String, String> filterParams,
       @MatrixVariable(pathVar = "sort") Map<String, String> sortParams) {
   // filterParams = {color=red, size=L}
   // sortParams = {by=price, dir=asc}
   return productService.filter(filterParams, sortParams);
}

// Specific matrix variable
// URL: /api/products;category=electronics;brand=samsung
@GetMapping("/{path}")
public List<ProductDTO> filter(
       @MatrixVariable String category,
       @MatrixVariable(required = false) String brand) { ... }
```

**Cần enable trong config:**

```java
@Configuration
public class WebConfig implements WebMvcConfigurer {
   @Override
   public void configurePathMatch(PathMatchConfigurer configurer) {
       UrlPathHelper helper = new UrlPathHelper();
       helper.setRemoveSemicolonContent(false); // Enable matrix variables
       configurer.setUrlPathHelper(helper);
   }
}
```

### # async & streaming

#### # async response

```java
@RestController
@RequestMapping("/api/v1/reports")
public class ReportController {

   // DeferredResult — long-polling
   @GetMapping("/{id}/status")
   public DeferredResult<ResponseEntity<ReportStatusDTO>> pollStatus(@PathVariable UUID id) {
       DeferredResult<ResponseEntity<ReportStatusDTO>> result = new DeferredResult<>(30000L);

       result.onTimeout(() ->
           result.setResult(ResponseEntity.status(HttpStatus.REQUEST_TIMEOUT).build()));

       reportService.onStatusChange(id, status ->
           result.setResult(ResponseEntity.ok(status)));

       return result;
   }

   // Callable — async processing trên thread khác
   @GetMapping("/heavy")
   public Callable<List<ReportDTO>> getHeavyReport() {
       return () -> {
           // Chạy trên async thread (không block servlet thread)
           return reportService.generateHeavyReport();
       };
   }

   // StreamingResponseBody — large file download
   @GetMapping("/{id}/export")
   public ResponseEntity<StreamingResponseBody> export(@PathVariable UUID id) {
       StreamingResponseBody stream = outputStream -> {
           reportService.streamReport(id, outputStream);
       };
       return ResponseEntity.ok()
           .contentType(MediaType.APPLICATION_OCTET_STREAM)
           .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"report.csv\"")
           .body(stream);
   }

   // SSE (Server-Sent Events)
   @GetMapping(value = "/stream", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
   public Flux<ServerSentEvent<ProgressDTO>> streamProgress() {
       return progressService.getProgressStream()
           .map(progress -> ServerSentEvent.<ProgressDTO>builder()
               .id(String.valueOf(progress.getStep()))
               .event("progress")
               .data(progress)
               .build());
   }
}
```

### # content negotiation

```java
@RestController
@RequestMapping("/api/v1/products")
public class ProductController {

   // Trả JSON hoặc XML tùy Accept header
   @GetMapping(value = "/{id}", produces = {
       MediaType.APPLICATION_JSON_VALUE,
       MediaType.APPLICATION_XML_VALUE
   })
   public ProductDTO get(@PathVariable UUID id) {
       return productService.getById(id);
   }

   // Chỉ nhận JSON
   @PostMapping(consumes = MediaType.APPLICATION_JSON_VALUE)
   public ProductDTO create(@RequestBody CreateProductRequest request) { ... }

   // Chỉ nhận multipart
   @PostMapping(value = "/import", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
   public ImportResult importFile(@RequestPart MultipartFile file) { ... }

   // Trả text/plain
   @GetMapping(value = "/{id}/name", produces = MediaType.TEXT_PLAIN_VALUE)
   public String getName(@PathVariable UUID id) {
       return productService.getById(id).getName();
   }
}
```

### # validation annotations (kết hợp jakarta bean validation)

```java
@RestController
@RequestMapping("/api/v1/users")
@Validated  // Enable validation cho @RequestParam, @PathVariable
public class UserController {

   // @Valid trên @RequestBody → trigger validation
   @PostMapping
   public UserDTO create(@Valid @RequestBody CreateUserRequest request) { ... }

   // Validate path variable
   @GetMapping("/{id}")
   public UserDTO getById(
           @PathVariable @NotNull UUID id) { ... }

   // Validate request params
   @GetMapping("/search")
   public Page<UserDTO> search(
           @RequestParam @Size(min = 2, max = 100) String keyword,
           @RequestParam @Min(0) int page,
           @RequestParam @Min(1) @Max(100) int size) { ... }
}

// Request DTO với validation
@Data
public class CreateUserRequest {

   @NotBlank(message = "Username is required")
   @Size(min = 3, max = 50, message = "Username must be 3-50 characters")
   @Pattern(regexp = "^[a-zA-Z0-9._-]+$", message = "Username contains invalid characters")
   private String username;

   @NotBlank(message = "Email is required")
   @Email(message = "Invalid email format")
   private String email;

   @NotBlank(message = "Password is required")
   @Size(min = 8, max = 128, message = "Password must be 8-128 characters")
   private String password;

   @NotNull(message = "Role is required")
   private UserRole role;

   @Size(max = 500, message = "Bio max 500 characters")
   private String bio;

   @Valid  // Trigger validation cho nested object
   @NotNull
   private AddressDTO address;

   @Valid
   @Size(max = 5, message = "Max 5 phone numbers")
   private List<@NotBlank String> phoneNumbers;
}

@Data
public class AddressDTO {
   @NotBlank
   private String street;

   @NotBlank
   private String city;

   @Pattern(regexp = "^\\d{5,6}$", message = "Invalid zip code")
   private String zipCode;
}
```

#### # custom validation groups

```java
// Groups
public interface OnCreate {}
public interface OnUpdate {}

@Data
public class ProductRequest {

   @Null(groups = OnCreate.class, message = "ID must be null on create")
   @NotNull(groups = OnUpdate.class, message = "ID required on update")
   private UUID id;

   @NotBlank(groups = {OnCreate.class, OnUpdate.class})
   private String name;

   @NotNull(groups = OnCreate.class)
   private BigDecimal price;
}

// Controller
@PostMapping
public ProductDTO create(@Validated(OnCreate.class) @RequestBody ProductRequest request) { ... }

@PutMapping("/{id}")
public ProductDTO update(@Validated(OnUpdate.class) @RequestBody ProductRequest request) { ... }
```

### # patterns thực tế — full rest controller

```java
@RestController
@RequestMapping("/api/v1/products")
@RequiredArgsConstructor
@Slf4j
@Validated
public class ProductController {

   private final ProductService productService;

   @GetMapping
   public ResponseEntity<APIResponse<Page<ProductDTO>>> list(
           @RequestParam(required = false) String keyword,
           @RequestParam(required = false) ProductStatus status,
           @RequestParam(required = false) UUID categoryId,
           @RequestParam(defaultValue = "0") @Min(0) int page,
           @RequestParam(defaultValue = "20") @Min(1) @Max(100) int size,
           @RequestParam(defaultValue = "createdAt,desc") String sort,
           @RequestHeader("X-Workspace-Id") UUID workspaceId) {

       Pageable pageable = buildPageable(page, size, sort);
       ProductSearchCriteria criteria = ProductSearchCriteria.builder()
           .keyword(keyword)
           .status(status)
           .categoryId(categoryId)
           .workspaceId(workspaceId)
           .build();

       Page<ProductDTO> result = productService.search(criteria, pageable);
       return ResponseEntity.ok(APIResponse.success(result));
   }

   @GetMapping("/{id}")
   public ResponseEntity<APIResponse<ProductDTO>> getById(
           @PathVariable UUID id,
           @RequestHeader("X-Workspace-Id") UUID workspaceId) {
       ProductDTO product = productService.getById(id, workspaceId);
       return ResponseEntity.ok(APIResponse.success(product));
   }

   @PostMapping
   public ResponseEntity<APIResponse<ProductDTO>> create(
           @Valid @RequestBody CreateProductRequest request,
           @RequestHeader("X-Workspace-Id") UUID workspaceId) {
       log.info("Creating product | workspaceId={} | code={}", workspaceId, request.getCode());
       ProductDTO created = productService.create(request, workspaceId);
       URI location = URI.create("/api/v1/products/" + created.getId());
       return ResponseEntity.created(location).body(APIResponse.success(created));
   }

   @PutMapping("/{id}")
   public ResponseEntity<APIResponse<ProductDTO>> update(
           @PathVariable UUID id,
           @Valid @RequestBody UpdateProductRequest request,
           @RequestHeader("X-Workspace-Id") UUID workspaceId) {
       log.info("Updating product | id={} | workspaceId={}", id, workspaceId);
       ProductDTO updated = productService.update(id, request, workspaceId);
       return ResponseEntity.ok(APIResponse.success(updated));
   }

   @PatchMapping("/{id}/status")
   public ResponseEntity<APIResponse<ProductDTO>> updateStatus(
           @PathVariable UUID id,
           @RequestParam @NotNull ProductStatus status,
           @RequestHeader("X-Workspace-Id") UUID workspaceId) {
       ProductDTO updated = productService.updateStatus(id, status, workspaceId);
       return ResponseEntity.ok(APIResponse.success(updated));
   }

   @DeleteMapping("/{id}")
   public ResponseEntity<Void> delete(
           @PathVariable UUID id,
           @RequestHeader("X-Workspace-Id") UUID workspaceId) {
       log.info("Deleting product | id={} | workspaceId={}", id, workspaceId);
       productService.delete(id, workspaceId);
       return ResponseEntity.noContent().build();
   }

   @PostMapping("/batch")
   public ResponseEntity<APIResponse<BatchResult>> batchCreate(
           @Valid @RequestBody @Size(min = 1, max = 100) List<CreateProductRequest> requests,
           @RequestHeader("X-Workspace-Id") UUID workspaceId) {
       BatchResult result = productService.batchCreate(requests, workspaceId);
       return ResponseEntity.ok(APIResponse.success(result));
   }

   @PostMapping("/{id}/images")
   public ResponseEntity<APIResponse<ProductDTO>> uploadImage(
           @PathVariable UUID id,
           @RequestPart("file") MultipartFile file,
           @RequestPart(value = "caption", required = false) String caption,
           @RequestHeader("X-Workspace-Id") UUID workspaceId) {
       ProductDTO updated = productService.addImage(id, file, caption, workspaceId);
       return ResponseEntity.ok(APIResponse.success(updated));
   }

   @GetMapping("/export")
   public ResponseEntity<StreamingResponseBody> export(
           @RequestParam(required = false) ProductStatus status,
           @RequestHeader("X-Workspace-Id") UUID workspaceId) {
       StreamingResponseBody stream = out -> productService.exportCsv(status, workspaceId, out);
       return ResponseEntity.ok()
           .contentType(MediaType.parseMediaType("text/csv"))
           .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"products.csv\"")
           .body(stream);
   }

   private Pageable buildPageable(int page, int size, String sort) {
       String[] parts = sort.split(",");
       String property = parts[0];
       Sort.Direction direction = parts.length > 1 && "asc".equalsIgnoreCase(parts[1])
           ? Sort.Direction.ASC : Sort.Direction.DESC;
       return PageRequest.of(page, size, Sort.by(direction, property));
   }
}
```

### # annotation quick reference

| Annotation            | Target           | Mục đích                        |
| --------------------- | ---------------- | ------------------------------- |
| @RestController       | Class            | REST controller (JSON response) |
| @Controller           | Class            | MVC controller (view response)  |
| @RequestMapping       | Class/Method     | Base URL mapping                |
| @GetMapping           | Method           | HTTP GET                        |
| @PostMapping          | Method           | HTTP POST                       |
| @PutMapping           | Method           | HTTP PUT                        |
| @PatchMapping         | Method           | HTTP PATCH                      |
| @DeleteMapping        | Method           | HTTP DELETE                     |
| @PathVariable         | Parameter        | URL path segment                |
| @RequestParam         | Parameter        | Query parameter                 |
| @RequestBody          | Parameter        | JSON body → object              |
| @RequestHeader        | Parameter        | HTTP header value               |
| @CookieValue          | Parameter        | Cookie value                    |
| @RequestPart          | Parameter        | Multipart part                  |
| @ModelAttribute       | Parameter/Method | Form data binding               |
| @RequestAttribute     | Parameter        | Servlet request attribute       |
| @SessionAttribute     | Parameter        | Session attribute               |
| @MatrixVariable       | Parameter        | Matrix URI variable             |
| @ResponseStatus       | Method/Class     | Set HTTP status                 |
| @ResponseBody         | Method           | Return value → response body    |
| @ExceptionHandler     | Method           | Handle specific exception       |
| @RestControllerAdvice | Class            | Global exception handler        |
| @ControllerAdvice     | Class            | Global controller advice        |
| @CrossOrigin          | Class/Method     | CORS configuration              |
| @InitBinder           | Method           | Custom data binder              |
| @Validated            | Class/Parameter  | Enable method-level validation  |

### # kết luận

Một số nguyên tắc khi dùng Spring Web Bind Annotations:

1. **@RestController** cho API, **@Controller** cho MVC views — không mix
2. **@Valid trên @RequestBody** luôn luôn — validate input sớm nhất có thể
3. **@Validated trên class** khi cần validate @RequestParam, @PathVariable
4. **ResponseEntity** khi cần custom status/headers — plain return khi đơn giản
5. **@RestControllerAdvice** cho global error handling — consistent error format
6. **@PathVariable cho resource ID**, **@RequestParam cho filters/search** — RESTful convention
7. **@RequestPart cho file upload** thay vì @RequestParam(MultipartFile)
8. **Không expose entity trực tiếp** — luôn dùng DTO (request DTO ≠ response DTO)

> Chỉ là những ghi chép cá nhân với hy vọng mang lại chút giá trị. Nếu thấy hữu ích, đừng ngại chia sẻ cho bạn bè & đồng nghiệp nhé!

Happy coding <Twemoji emoji="clinking-beer-mugs" /> 😎 👍🏻 🚀 🔥.
