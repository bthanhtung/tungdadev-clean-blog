---
layout: post
title: "spring data jpa"
date: 2023-09-21 19:29:39 +0700
categories: [Software Development]
tags: [java, software-development, spring-framework, best-practices, vietnamese]
---

### # giới thiệu

`org.springframework.data.jpa` cung cấp abstraction layer trên JPA (Hibernate), giúp giảm boilerplate code cho data access layer. Thay vì viết DAO/Repository thủ công, chỉ cần khai báo interface → Spring tự generate implementation.

#### # dependency

```xml
<dependency>
   <groupId>org.springframework.boot</groupId>
   <artifactId>spring-boot-starter-data-jpa</artifactId>
</dependency>
<dependency>
   <groupId>org.postgresql</groupId>
   <artifactId>postgresql</artifactId>
   <scope>runtime</scope>
</dependency>
```

#### # cấu hình cơ bản

```yaml
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/csp_db
    username: ${DB_USERNAME}
    password: ${DB_PASSWORD}
    hikari:
      maximum-pool-size: 20
      minimum-idle: 5
  jpa:
    hibernate:
      ddl-auto: validate # production: validate hoặc none
    show-sql: false
    properties:
      hibernate:
        format_sql: true
        default_schema: public
        jdbc.batch_size: 50
        order_inserts: true
        order_updates: true
```

### # repository hierarchy

```
Repository<T, ID>                          (marker interface)
 └── CrudRepository<T, ID>               (CRUD cơ bản)
     └── ListCrudRepository<T, ID>       (trả List thay Iterable)
         └── JpaRepository<T, ID>        (JPA-specific: flush, batch, Example)
             └── JpaSpecificationExecutor<T>  (dynamic queries)

PagingAndSortingRepository<T, ID>         (phân trang + sắp xếp)
```

#### # so sánh

| Interface                  | Phương thức chính                                    | Khi nào dùng      |
| -------------------------- | ---------------------------------------------------- | ----------------- |
| CrudRepository             | save, findById, findAll, delete, count, existsById   | CRUD đơn giản     |
| ListCrudRepository         | Giống Crud nhưng trả List (không Iterable)           | Default choice    |
| PagingAndSortingRepository | findAll(Pageable), findAll(Sort)                     | Cần phân trang    |
| JpaRepository              | flush, saveAndFlush, deleteInBatch, findAll(Example) | Full JPA features |
| JpaSpecificationExecutor   | findAll(Specification), count(Specification)         | Dynamic queries   |

#### # ví dụ cơ bản

```java
@Repository
public interface ProductRepository extends JpaRepository<Product, UUID> {
   // Spring tự generate implementation cho tất cả method của JpaRepository
   // + derived query methods bạn khai báo thêm
}
```

### # entity mapping

#### # base entity với auditing

```java
@MappedSuperclass
@EntityListeners(AuditingEntityListener.class)
@Getter
@Setter
public abstract class BaseEntity {

   @Id
   @GeneratedValue(strategy = GenerationType.UUID)
   private UUID id;

   @CreatedDate
   @Column(name = "created_at", nullable = false, updatable = false)
   private LocalDateTime createdAt;

   @LastModifiedDate
   @Column(name = "updated_at")
   private LocalDateTime updatedAt;

   @CreatedBy
   @Column(name = "created_by", updatable = false)
   private String createdBy;

   @LastModifiedBy
   @Column(name = "updated_by")
   private String updatedBy;

   @Version  // Optimistic locking
   private Long version;
}
```

#### # entity đầy đủ

```java
@Entity
@Table(name = "products", indexes = {
   @Index(name = "idx_product_code", columnList = "code", unique = true),
   @Index(name = "idx_product_category", columnList = "category_id"),
   @Index(name = "idx_product_status_created", columnList = "status, created_at")
})
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Product extends BaseEntity {

   @Column(name = "code", nullable = false, unique = true, length = 50)
   private String code;

   @Column(name = "name", nullable = false, length = 255)
   private String name;

   @Column(name = "description", columnDefinition = "TEXT")
   private String description;

   @Column(name = "price", precision = 15, scale = 2)
   private BigDecimal price;

   @Enumerated(EnumType.STRING)
   @Column(name = "status", nullable = false, length = 20)
   private ProductStatus status;

   @ManyToOne(fetch = FetchType.LAZY)
   @JoinColumn(name = "category_id", nullable = false)
   private Category category;

   @OneToMany(mappedBy = "product", cascade = CascadeType.ALL, orphanRemoval = true)
   @Builder.Default
   private List<ProductImage> images = new ArrayList<>();

   @ManyToMany
   @JoinTable(
       name = "product_tags",
       joinColumns = @JoinColumn(name = "product_id"),
       inverseJoinColumns = @JoinColumn(name = "tag_id")
   )
   @Builder.Default
   private Set<Tag> tags = new HashSet<>();

   @ElementCollection
   @CollectionTable(name = "product_attributes", joinColumns = @JoinColumn(name = "product_id"))
   @MapKeyColumn(name = "attr_key")
   @Column(name = "attr_value")
   private Map<String, String> attributes;

   // Soft delete
   @Column(name = "deleted_at")
   private LocalDateTime deletedAt;

   // Helper methods
   public void addImage(ProductImage image) {
       images.add(image);
       image.setProduct(this);
   }

   public void removeImage(ProductImage image) {
       images.remove(image);
       image.setProduct(null);
   }
}
```

#### # enum

```java
public enum ProductStatus {
   DRAFT,
   ACTIVE,
   INACTIVE,
   DISCONTINUED
}
```

#### # embedded & value objects

```java
@Embeddable
@Data
@NoArgsConstructor
@AllArgsConstructor
public class Money {
   @Column(name = "amount", precision = 15, scale = 2)
   private BigDecimal amount;

   @Column(name = "currency", length = 3)
   private String currency;
}

@Embeddable
@Data
public class Address {
   private String street;
   private String city;
   private String state;

   @Column(name = "zip_code", length = 10)
   private String zipCode;
}

@Entity
public class Order extends BaseEntity {

   @Embedded
   @AttributeOverrides({
       @AttributeOverride(name = "amount", column = @Column(name = "total_amount")),
       @AttributeOverride(name = "currency", column = @Column(name = "total_currency"))
   })
   private Money totalMoney;

   @Embedded
   @AttributeOverrides({
       @AttributeOverride(name = "street", column = @Column(name = "shipping_street")),
       @AttributeOverride(name = "city", column = @Column(name = "shipping_city")),
       @AttributeOverride(name = "state", column = @Column(name = "shipping_state")),
       @AttributeOverride(name = "zipCode", column = @Column(name = "shipping_zip"))
   })
   private Address shippingAddress;
}
```

### # derived query methods (query từ tên method)

Spring Data JPA parse tên method để tự sinh SQL query.

#### # cú pháp

```
find/read/get/query/search/stream + [Distinct] + By + <Condition> + [OrderBy + <Property> + Asc|Desc]
count + By + <Condition>
exists + By + <Condition>
delete/remove + By + <Condition>
```

#### # bảng keywords

| Keyword          | SQL         | Ví dụ method                     |
| ---------------- | ----------- | -------------------------------- |
| And              | AND         | findByNameAndStatus              |
| Or               | OR          | findByNameOrCode                 |
| Is, Equals       | =           | findByStatusIs                   |
| Not              | !=          | findByStatusNot                  |
| Between          | BETWEEN     | findByPriceBetween               |
| LessThan         | `<`         | findByPriceLessThan              |
| LessThanEqual    | `<=`        | findByPriceLessThanEqual         |
| GreaterThan      | `>`         | findByPriceGreaterThan           |
| GreaterThanEqual | `>=`        | findByPriceGreaterThanEqual      |
| IsNull           | IS NULL     | findByDeletedAtIsNull            |
| IsNotNull        | IS NOT NULL | findByDeletedAtIsNotNull         |
| Like             | LIKE        | findByNameLike                   |
| NotLike          | NOT LIKE    | findByNameNotLike                |
| StartingWith     | LIKE 'x%'   | findByNameStartingWith           |
| EndingWith       | LIKE '%x'   | findByNameEndingWith             |
| Containing       | LIKE '%x%'  | findByNameContaining             |
| In               | IN          | findByStatusIn                   |
| NotIn            | NOT IN      | findByStatusNotIn                |
| True             | = true      | findByActiveTrue                 |
| False            | = false     | findByActiveFalse                |
| OrderBy          | ORDER BY    | findByStatusOrderByCreatedAtDesc |
| IgnoreCase       | UPPER()     | findByNameIgnoreCase             |
| Top/First        | LIMIT       | findTop5ByStatus                 |

#### # ví dụ đầy đủ

```java
@Repository
public interface ProductRepository extends JpaRepository<Product, UUID> {

   // === FIND methods ===

   // SELECT * FROM products WHERE code = ?
   Optional<Product> findByCode(String code);

   // SELECT * FROM products WHERE status = ? AND deleted_at IS NULL
   List<Product> findByStatusAndDeletedAtIsNull(ProductStatus status);

   // SELECT * FROM products WHERE name LIKE '%keyword%' (case insensitive)
   List<Product> findByNameContainingIgnoreCase(String keyword);

   // SELECT * FROM products WHERE price BETWEEN ? AND ?
   List<Product> findByPriceBetween(BigDecimal minPrice, BigDecimal maxPrice);

   // SELECT * FROM products WHERE status IN (?, ?)
   List<Product> findByStatusIn(Collection<ProductStatus> statuses);

   // SELECT * FROM products WHERE category_id = ? ORDER BY price DESC
   List<Product> findByCategoryIdOrderByPriceDesc(UUID categoryId);

   // SELECT TOP 10 FROM products WHERE status = ? ORDER BY created_at DESC
   List<Product> findTop10ByStatusOrderByCreatedAtDesc(ProductStatus status);

   // SELECT DISTINCT * FROM products WHERE name = ?
   Optional<Product> findDistinctByName(String name);

   // === Pagination ===

   // SELECT * FROM products WHERE status = ? (with pagination)
   Page<Product> findByStatus(ProductStatus status, Pageable pageable);

   // Slice (không count total — performance better)
   Slice<Product> findByCategory(Category category, Pageable pageable);

   // === COUNT, EXISTS, DELETE ===

   // SELECT COUNT(*) FROM products WHERE status = ?
   long countByStatus(ProductStatus status);

   // SELECT COUNT(*) > 0 FROM products WHERE code = ?
   boolean existsByCode(String code);

   // SELECT COUNT(*) > 0 FROM products WHERE code = ? AND id != ?
   boolean existsByCodeAndIdNot(String code, UUID id);

   // DELETE FROM products WHERE status = ? AND deleted_at < ?
   int deleteByStatusAndDeletedAtBefore(ProductStatus status, LocalDateTime before);

   // === Stream (large datasets) ===

   @QueryHints(@QueryHint(name = HINT_FETCH_SIZE, value = "50"))
   Stream<Product> findByStatusIs(ProductStatus status);

   // === Nested property ===

   // JOIN category → WHERE category.name = ?
   List<Product> findByCategoryName(String categoryName);

   // WHERE category.id = ? AND status = ?
   Page<Product> findByCategoryIdAndStatus(UUID categoryId, ProductStatus status, Pageable pageable);
}
```

### # @Query — jpql & native sql

#### # jpql (java persistence query language)

```java
@Repository
public interface ProductRepository extends JpaRepository<Product, UUID> {

   // JPQL cơ bản — tham chiếu entity name, field name (không phải table/column name)
   @Query("SELECT p FROM Product p WHERE p.status = :status AND p.deletedAt IS NULL")
   List<Product> findActiveByStatus(@Param("status") ProductStatus status);

   // JOIN FETCH — giải quyết N+1 problem
   @Query("SELECT p FROM Product p JOIN FETCH p.category WHERE p.id = :id")
   Optional<Product> findByIdWithCategory(@Param("id") UUID id);

   @Query("SELECT p FROM Product p JOIN FETCH p.category JOIN FETCH p.images WHERE p.id = :id")
   Optional<Product> findByIdWithCategoryAndImages(@Param("id") UUID id);

   // Pagination với JPQL (cần countQuery riêng khi có JOIN FETCH)
   @Query(value = "SELECT p FROM Product p JOIN FETCH p.category WHERE p.status = :status",
          countQuery = "SELECT COUNT(p) FROM Product p WHERE p.status = :status")
   Page<Product> findByStatusWithCategory(@Param("status") ProductStatus status, Pageable pageable);

   // Search với nhiều điều kiện optional
   @Query("""
       SELECT p FROM Product p
       WHERE (:keyword IS NULL OR LOWER(p.name) LIKE LOWER(CONCAT('%', :keyword, '%')))
       AND (:status IS NULL OR p.status = :status)
       AND (:categoryId IS NULL OR p.category.id = :categoryId)
       AND p.deletedAt IS NULL
       ORDER BY p.createdAt DESC
       """)
   Page<Product> search(
       @Param("keyword") String keyword,
       @Param("status") ProductStatus status,
       @Param("categoryId") UUID categoryId,
       Pageable pageable);

   // Aggregate functions
   @Query("SELECT COUNT(p) FROM Product p WHERE p.category.id = :categoryId AND p.status = 'ACTIVE'")
   long countActiveByCategoryId(@Param("categoryId") UUID categoryId);

   @Query("SELECT AVG(p.price) FROM Product p WHERE p.category.id = :categoryId")
   BigDecimal getAveragePriceByCategoryId(@Param("categoryId") UUID categoryId);

   @Query("SELECT MAX(p.price) FROM Product p WHERE p.status = :status")
   BigDecimal getMaxPrice(@Param("status") ProductStatus status);

   // DTO Projection (JPQL constructor expression)
   @Query("""
       SELECT new vn.com.vpbank.internal.csp.product.dto.ProductSummaryDTO(
           p.id, p.name, p.code, p.price, p.status, p.category.name, p.createdAt
       )
       FROM Product p WHERE p.status = :status
       """)
   Page<ProductSummaryDTO> findSummaryByStatus(@Param("status") ProductStatus status, Pageable pageable);

   // IN clause
   @Query("SELECT p FROM Product p WHERE p.id IN :ids AND p.deletedAt IS NULL")
   List<Product> findByIds(@Param("ids") Collection<UUID> ids);

   // CASE expression
   @Query("""
       SELECT p.status, COUNT(p)
       FROM Product p
       WHERE p.deletedAt IS NULL
       GROUP BY p.status
       """)
   List<Object[]> countByStatusGrouped();
}
```

#### # native sql

```java
@Repository
public interface ProductRepository extends JpaRepository<Product, UUID> {

   // Native SQL — dùng table/column name thực tế
   @Query(value = """
       SELECT p.* FROM products p
       INNER JOIN categories c ON p.category_id = c.id
       WHERE p.status = :status
       AND c.is_active = true
       AND p.deleted_at IS NULL
       ORDER BY p.created_at DESC
       LIMIT :limit OFFSET :offset
       """, nativeQuery = true)
   List<Product> findActiveProductsNative(
       @Param("status") String status,
       @Param("limit") int limit,
       @Param("offset") int offset);

   // Native with pagination
   @Query(value = "SELECT * FROM products WHERE status = :status AND deleted_at IS NULL",
          countQuery = "SELECT COUNT(*) FROM products WHERE status = :status AND deleted_at IS NULL",
          nativeQuery = true)
   Page<Product> findByStatusNative(@Param("status") String status, Pageable pageable);

   // Full-text search (PostgreSQL)
   @Query(value = """
       SELECT * FROM products
       WHERE to_tsvector('english', name || ' ' || COALESCE(description, ''))
             @@ plainto_tsquery('english', :query)
       AND deleted_at IS NULL
       ORDER BY ts_rank(to_tsvector('english', name || ' ' || COALESCE(description, '')),
                       plainto_tsquery('english', :query)) DESC
       """, nativeQuery = true)
   List<Product> fullTextSearch(@Param("query") String query);

   // JSON operations (PostgreSQL)
   @Query(value = """
       SELECT * FROM products
       WHERE attributes->>'brand' = :brand
       AND deleted_at IS NULL
       """, nativeQuery = true)
   List<Product> findByAttributeBrand(@Param("brand") String brand);

   // Bulk operations
   @Modifying
   @Transactional
   @Query(value = """
       UPDATE products SET status = :newStatus, updated_at = NOW()
       WHERE status = :oldStatus AND created_at < :before
       """, nativeQuery = true)
   int bulkUpdateStatus(
       @Param("oldStatus") String oldStatus,
       @Param("newStatus") String newStatus,
       @Param("before") LocalDateTime before);
}
```

#### # @Modifying — UPDATE, DELETE queries

```java
@Repository
public interface ProductRepository extends JpaRepository<Product, UUID> {

   // JPQL update
   @Modifying(clearAutomatically = true, flushAutomatically = true)
   @Transactional
   @Query("UPDATE Product p SET p.status = :status, p.updatedAt = :now WHERE p.id = :id")
   int updateStatus(@Param("id") UUID id, @Param("status") ProductStatus status,
                    @Param("now") LocalDateTime now);

   // Soft delete
   @Modifying
   @Transactional
   @Query("UPDATE Product p SET p.deletedAt = :now WHERE p.id = :id AND p.deletedAt IS NULL")
   int softDelete(@Param("id") UUID id, @Param("now") LocalDateTime now);

   // Bulk soft delete
   @Modifying
   @Transactional
   @Query("UPDATE Product p SET p.deletedAt = :now WHERE p.id IN :ids AND p.deletedAt IS NULL")
   int softDeleteByIds(@Param("ids") Collection<UUID> ids, @Param("now") LocalDateTime now);

   // Hard delete
   @Modifying
   @Transactional
   @Query("DELETE FROM Product p WHERE p.status = :status AND p.deletedAt < :before")
   int purgeOldDeleted(@Param("status") ProductStatus status, @Param("before") LocalDateTime before);
}
```

**Lưu ý @Modifying:**

- `clearAutomatically = true`: Clear persistence context sau khi execute (tránh stale data)
- `flushAutomatically = true`: Flush pending changes trước khi execute
- Phải đi kèm `@Transactional`

### # projections — chỉ lấy fields cần thiết

#### # interface projection (closed)

```java
// Chỉ lấy 3 fields thay vì toàn bộ entity → performance tốt hơn
public interface ProductSummaryProjection {
   UUID getId();
   String getName();
   String getCode();
   BigDecimal getPrice();

   // Nested projection
   CategoryInfo getCategory();

   interface CategoryInfo {
       String getName();
   }

   // SpEL expression — computed field
   @Value("#{target.name + ' (' + target.code + ')'}")
   String getDisplayName();
}

// Repository
@Repository
public interface ProductRepository extends JpaRepository<Product, UUID> {

   List<ProductSummaryProjection> findByStatus(ProductStatus status);

   Page<ProductSummaryProjection> findByStatusAndDeletedAtIsNull(
       ProductStatus status, Pageable pageable);

   // Kết hợp @Query
   @Query("SELECT p FROM Product p WHERE p.category.id = :categoryId")
   List<ProductSummaryProjection> findSummaryByCategoryId(@Param("categoryId") UUID categoryId);
}
```

#### # class-based projection (dto)

```java
// DTO class — phải có constructor matching
@Data
@AllArgsConstructor
public class ProductSummaryDTO {
   private UUID id;
   private String name;
   private String code;
   private BigDecimal price;
   private ProductStatus status;
   private String categoryName;
   private LocalDateTime createdAt;
}

// Repository — dùng với JPQL constructor expression
@Query("""
   SELECT new vn.com.vpbank.internal.csp.product.dto.ProductSummaryDTO(
       p.id, p.name, p.code, p.price, p.status, c.name, p.createdAt
   )
   FROM Product p JOIN p.category c
   WHERE p.status = :status
   """)
Page<ProductSummaryDTO> findSummaryDTOByStatus(@Param("status") ProductStatus status, Pageable pageable);
```

#### # dynamic projections — cùng method, nhiều return types

```java
@Repository
public interface ProductRepository extends JpaRepository<Product, UUID> {

   // Gọi với type khác nhau → return khác nhau
   <T> List<T> findByStatus(ProductStatus status, Class<T> type);

   <T> Optional<T> findById(UUID id, Class<T> type);
}

// Usage
List<ProductSummaryProjection> summaries = repo.findByStatus(ACTIVE, ProductSummaryProjection.class);
List<Product> fullEntities = repo.findByStatus(ACTIVE, Product.class);
```

### # specification — dynamic queries (criteria api wrapper)

#### # khai báo

```java
@Repository
public interface ProductRepository extends JpaRepository<Product, UUID>,
                                          JpaSpecificationExecutor<Product> {
   // JpaSpecificationExecutor cung cấp:
   // findAll(Specification, Pageable)
   // findAll(Specification, Sort)
   // findOne(Specification)
   // count(Specification)
   // exists(Specification)
}
```

#### # specification class

```java
public class ProductSpecification {

   public static Specification<Product> hasName(String name) {
       return (root, query, cb) -> {
           if (name == null || name.isBlank()) return cb.conjunction(); // no-op
           return cb.like(cb.lower(root.get("name")), "%" + name.toLowerCase() + "%");
       };
   }

   public static Specification<Product> hasStatus(ProductStatus status) {
       return (root, query, cb) -> {
           if (status == null) return cb.conjunction();
           return cb.equal(root.get("status"), status);
       };
   }

   public static Specification<Product> hasCategoryId(UUID categoryId) {
       return (root, query, cb) -> {
           if (categoryId == null) return cb.conjunction();
           return cb.equal(root.get("category").get("id"), categoryId);
       };
   }

   public static Specification<Product> priceBetween(BigDecimal min, BigDecimal max) {
       return (root, query, cb) -> {
           if (min == null && max == null) return cb.conjunction();
           if (min != null && max != null) return cb.between(root.get("price"), min, max);
           if (min != null) return cb.greaterThanOrEqualTo(root.get("price"), min);
           return cb.lessThanOrEqualTo(root.get("price"), max);
       };
   }

   public static Specification<Product> createdAfter(LocalDateTime date) {
       return (root, query, cb) -> {
           if (date == null) return cb.conjunction();
           return cb.greaterThanOrEqualTo(root.get("createdAt"), date);
       };
   }

   public static Specification<Product> isNotDeleted() {
       return (root, query, cb) -> cb.isNull(root.get("deletedAt"));
   }

   // JOIN + subquery
   public static Specification<Product> hasTag(String tagName) {
       return (root, query, cb) -> {
           if (tagName == null) return cb.conjunction();
           Join<Product, Tag> tagJoin = root.join("tags", JoinType.INNER);
           return cb.equal(cb.lower(tagJoin.get("name")), tagName.toLowerCase());
       };
   }

   // IN clause
   public static Specification<Product> statusIn(Collection<ProductStatus> statuses) {
       return (root, query, cb) -> {
           if (statuses == null || statuses.isEmpty()) return cb.conjunction();
           return root.get("status").in(statuses);
       };
   }
}
```

#### # service sử dụng specification

```java
@Service
@RequiredArgsConstructor
public class ProductService {

   private final ProductRepository productRepository;

   public Page<ProductDTO> search(ProductSearchRequest request, Pageable pageable) {

       Specification<Product> spec = Specification
           .where(ProductSpecification.isNotDeleted())
           .and(ProductSpecification.hasName(request.getKeyword()))
           .and(ProductSpecification.hasStatus(request.getStatus()))
           .and(ProductSpecification.hasCategoryId(request.getCategoryId()))
           .and(ProductSpecification.priceBetween(request.getMinPrice(), request.getMaxPrice()))
           .and(ProductSpecification.createdAfter(request.getCreatedAfter()));

       return productRepository.findAll(spec, pageable).map(this::toDTO);
   }
}
```

#### # SearchRequest dto

```java
@Data
public class ProductSearchRequest {
   private String keyword;
   private ProductStatus status;
   private UUID categoryId;
   private BigDecimal minPrice;
   private BigDecimal maxPrice;
   private LocalDateTime createdAfter;
   private List<ProductStatus> statuses;
}
```

### # pagination & sorting

#### # pageable — phân trang

```java
// Controller
@GetMapping
public ResponseEntity<APIResponse<Page<ProductDTO>>> list(
       @RequestParam(defaultValue = "0") int page,
       @RequestParam(defaultValue = "20") int size,
       @RequestParam(defaultValue = "createdAt,desc") String[] sort) {

   Pageable pageable = PageRequest.of(page, size, parseSort(sort));
   Page<ProductDTO> result = productService.findAll(pageable);
   return ResponseEntity.ok(APIResponse.success(result));
}

// Hoặc dùng Spring auto-resolve
@GetMapping
public Page<ProductDTO> list(Pageable pageable) {
   // Auto from: ?page=0&size=20&sort=name,asc&sort=createdAt,desc
   return productService.findAll(pageable);
}

// Sort helper
private Sort parseSort(String[] sortParams) {
   List<Sort.Order> orders = new ArrayList<>();
   for (String param : sortParams) {
       String[] parts = param.split(",");
       String property = parts[0];
       Sort.Direction direction = parts.length > 1 && parts[1].equalsIgnoreCase("asc")
           ? Sort.Direction.ASC : Sort.Direction.DESC;
       orders.add(new Sort.Order(direction, property));
   }
   return Sort.by(orders);
}
```

#### # sort — sắp xếp

```java
// Các cách tạo Sort
Sort sort = Sort.by("name");                           // ASC
Sort sort = Sort.by(Sort.Direction.DESC, "createdAt"); // DESC
Sort sort = Sort.by("status").ascending()              // Multiple fields
   .and(Sort.by("createdAt").descending());

// Sort.Order với null handling
Sort sort = Sort.by(
   Sort.Order.asc("status"),
   Sort.Order.desc("createdAt").nullsLast(),
   Sort.Order.asc("name").ignoreCase()
);

// Repository usage
List<Product> products = repo.findByStatus(ProductStatus.ACTIVE, Sort.by("name"));
```

#### # page vs slice

```java
// Page — biết total count (thêm 1 query COUNT)
Page<Product> page = repo.findByStatus(ACTIVE, PageRequest.of(0, 20));
page.getContent();        // List<Product>
page.getTotalElements();  // Tổng record (VD: 150)
page.getTotalPages();     // Tổng trang (VD: 8)
page.getNumber();         // Trang hiện tại (0)
page.getSize();           // Kích thước trang (20)
page.hasNext();           // Có trang tiếp?
page.isFirst();           // Là trang đầu?

// Slice — KHÔNG biết total count (performance tốt hơn)
Slice<Product> slice = repo.findByCategory(category, PageRequest.of(0, 20));
slice.getContent();       // List<Product>
slice.hasNext();          // Có phần tử tiếp? (query N+1 records)
slice.getNumber();
// KHÔNG có getTotalElements(), getTotalPages()
```

#### # cấu hình pageable defaults

```yaml
spring:
  data:
    web:
      pageable:
        default-page-size: 20
        max-page-size: 100
        one-indexed-parameters: false # page bắt đầu từ 0
        page-parameter: page
        size-parameter: size
      sort:
        sort-parameter: sort
```

### # auditing — tự động track ai/khi nào thay đổi

#### # cấu hình

```java
@Configuration
@EnableJpaAuditing(auditorAwareRef = "auditorProvider")
public class JpaAuditingConfig {

   @Bean
   public AuditorAware<String> auditorProvider() {
       return () -> Optional.ofNullable(SecurityContextHolder.getContext().getAuthentication())
           .filter(Authentication::isAuthenticated)
           .map(auth -> {
               if (auth.getPrincipal() instanceof Jwt jwt) {
                   return jwt.getClaimAsString("preferred_username");
               }
               return auth.getName();
           });
   }
}
```

#### # annotations

| Annotation        | Column     | Auto-fill khi   |
| ----------------- | ---------- | --------------- |
| @CreatedDate      | created_at | INSERT          |
| @LastModifiedDate | updated_at | INSERT + UPDATE |
| @CreatedBy        | created_by | INSERT          |
| @LastModifiedBy   | updated_by | INSERT + UPDATE |

#### # entity callback (thay thế auditing cho logic phức tạp)

```java
@Component
public class ProductEntityCallback implements BeforeConvertCallback<Product> {

   @Override
   public Product onBeforeConvert(Product product) {
       if (product.getCode() == null) {
           product.setCode(generateCode());
       }
       return product;
   }
}
```

### # @Transactional — transaction management

#### # cơ bản

```java
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)  // Default cho cả class: read-only
public class ProductService {

   private final ProductRepository productRepository;
   private final CategoryRepository categoryRepository;

   // Read operations — dùng class-level @Transactional(readOnly = true)
   public ProductDTO getById(UUID id) {
       return productRepository.findById(id)
           .map(this::toDTO)
           .orElseThrow(() -> new EntityNotFoundException("Product not found: " + id));
   }

   // Write operations — override với readOnly = false
   @Transactional  // readOnly = false (default)
   public ProductDTO create(CreateProductRequest request) {
       Category category = categoryRepository.findById(request.getCategoryId())
           .orElseThrow(() -> new EntityNotFoundException("Category not found"));

       Product product = Product.builder()
           .code(request.getCode())
           .name(request.getName())
           .price(request.getPrice())
           .category(category)
           .status(ProductStatus.DRAFT)
           .build();

       return toDTO(productRepository.save(product));
   }

   // Rollback rules
   @Transactional(rollbackFor = Exception.class)  // Rollback cho mọi exception
   public void importProducts(List<CreateProductRequest> requests) {
       requests.forEach(this::create);
   }

   // Isolation level
   @Transactional(isolation = Isolation.SERIALIZABLE)
   public void transferStock(UUID fromId, UUID toId, int quantity) {
       // Critical section — needs highest isolation
   }

   // Timeout
   @Transactional(timeout = 30)  // 30 giây
   public void longRunningOperation() { ... }
}
```

#### # propagation levels

| Propagation        | Behavior                                     |
| ------------------ | -------------------------------------------- |
| REQUIRED (default) | Join existing TX, hoặc tạo mới nếu chưa có   |
| REQUIRES_NEW       | Luôn tạo TX mới (suspend existing)           |
| NESTED             | Tạo savepoint trong TX hiện tại              |
| SUPPORTS           | Join TX nếu có, không thì chạy không TX      |
| NOT_SUPPORTED      | Suspend TX hiện tại, chạy không TX           |
| MANDATORY          | Bắt buộc phải có TX sẵn, exception nếu không |
| NEVER              | Bắt buộc KHÔNG có TX, exception nếu có       |

```java
@Service
@RequiredArgsConstructor
public class OrderService {

   private final OrderRepository orderRepository;
   private final AuditLogService auditLogService;

   @Transactional
   public OrderDTO createOrder(CreateOrderRequest request) {
       Order order = buildOrder(request);
       order = orderRepository.save(order);

       // Audit log trong TX riêng — không rollback nếu main TX fail
       auditLogService.logOrderCreated(order.getId());

       return toDTO(order);
   }
}

@Service
public class AuditLogService {

   @Transactional(propagation = Propagation.REQUIRES_NEW)
   public void logOrderCreated(UUID orderId) {
       // TX riêng — commit ngay cả khi caller TX rollback
       auditLogRepository.save(new AuditLog("ORDER_CREATED", orderId));
   }
}
```

#### # lưu ý quan trọng về @Transactional

```java
// ❌ SAI — self-invocation bypass proxy
@Service
public class ProductService {

   public void doSomething() {
       this.internalMethod(); // KHÔNG qua proxy → @Transactional bị bỏ qua
   }

   @Transactional
   public void internalMethod() {
       // Transaction KHÔNG hoạt động khi gọi từ cùng class
   }
}

// ✅ ĐÚNG — inject service khác hoặc dùng ApplicationContext
@Service
@RequiredArgsConstructor
public class ProductService {

   private final AnotherService anotherService; // Gọi qua bean khác

   public void doSomething() {
       anotherService.internalMethod(); // Qua proxy → @Transactional hoạt động
   }
}

// ❌ SAI — @Transactional trên private method
@Transactional
private void secretMethod() { } // Proxy không thể override private

// ❌ SAI — catch exception trong TX method
@Transactional
public void create() {
   try {
       repo.save(entity);
       externalCall(); // throws RuntimeException
   } catch (Exception e) {
       log.error("Error", e); // Swallow exception → TX vẫn marked rollback-only
       // Spring sẽ throw UnexpectedRollbackException
   }
}
```

### # n+1 problem & solutions

#### # vấn đề

```java
// Entity
@Entity
public class Product {
   @ManyToOne(fetch = FetchType.LAZY)
   private Category category;
}

// Code gây N+1
List<Product> products = productRepository.findAll(); // 1 query
for (Product p : products) {
   p.getCategory().getName(); // N queries (mỗi product 1 query lấy category)
}
// Tổng: 1 + N queries
```

#### # solution 1: join fetch (jpql)

```java
@Query("SELECT p FROM Product p JOIN FETCH p.category WHERE p.status = :status")
List<Product> findByStatusWithCategory(@Param("status") ProductStatus status);
// 1 query duy nhất với JOIN
```

#### # solution 2: @EntityGraph

```java
@Repository
public interface ProductRepository extends JpaRepository<Product, UUID> {

   // Attribut paths to eagerly fetch
   @EntityGraph(attributePaths = {"category"})
   List<Product> findByStatus(ProductStatus status);

   @EntityGraph(attributePaths = {"category", "images"})
   Optional<Product> findWithDetailsById(UUID id);

   // Kết hợp @Query
   @EntityGraph(attributePaths = {"category", "tags"})
   @Query("SELECT p FROM Product p WHERE p.deletedAt IS NULL")
   Page<Product> findAllActive(Pageable pageable);
}
```

#### # solution 3: named EntityGraph (trên entity)

```java
@Entity
@NamedEntityGraph(
   name = "Product.withCategoryAndImages",
   attributeNodes = {
       @NamedAttributeNode("category"),
       @NamedAttributeNode("images")
   }
)
@NamedEntityGraph(
   name = "Product.full",
   attributeNodes = {
       @NamedAttributeNode("category"),
       @NamedAttributeNode("images"),
       @NamedAttributeNode(value = "tags")
   }
)
public class Product extends BaseEntity { ... }

// Repository
@EntityGraph("Product.withCategoryAndImages")
List<Product> findByStatus(ProductStatus status);
```

#### # solution 4: batch size (hibernate config)

```yaml
spring:
  jpa:
    properties:
      hibernate:
        default_batch_fetch_size: 20
        # Khi access lazy collection → load 20 items per batch
        # Giảm từ N queries → N/20 queries
```

Hoặc per-entity:

```java
@OneToMany(mappedBy = "product")
@BatchSize(size = 20)
private List<ProductImage> images;
```

#### # so sánh solutions

| Solution       | Khi nào dùng                    | Trade-off                                  |
| -------------- | ------------------------------- | ------------------------------------------ |
| JOIN FETCH     | Biết chính xác cần gì           | Cartesian product với multiple collections |
| @EntityGraph   | Flexible per-query              | Giống JOIN FETCH nhưng declarative         |
| Batch Size     | Mặc định an toàn                | Không tối ưu bằng JOIN FETCH               |
| DTO Projection | Read-only, performance critical | Mất flexibility                            |

### # custom repository implementation

#### # khi derived queries & @Query không đủ

```java
// 1. Tạo custom interface
public interface ProductRepositoryCustom {
   List<Product> searchWithComplexCriteria(ProductSearchCriteria criteria);
   void bulkUpdatePrices(Map<UUID, BigDecimal> priceMap);
}

// 2. Implement (naming: Repository + "Impl")
@Repository
@RequiredArgsConstructor
public class ProductRepositoryImpl implements ProductRepositoryCustom {

   private final EntityManager em;

   @Override
   public List<Product> searchWithComplexCriteria(ProductSearchCriteria criteria) {
       CriteriaBuilder cb = em.getCriteriaBuilder();
       CriteriaQuery<Product> cq = cb.createQuery(Product.class);
       Root<Product> root = cq.from(Product.class);

       List<Predicate> predicates = new ArrayList<>();

       if (criteria.getKeyword() != null) {
           predicates.add(cb.or(
               cb.like(cb.lower(root.get("name")), "%" + criteria.getKeyword().toLowerCase() + "%"),
               cb.like(cb.lower(root.get("code")), "%" + criteria.getKeyword().toLowerCase() + "%")
           ));
       }

       if (criteria.getMinPrice() != null) {
           predicates.add(cb.greaterThanOrEqualTo(root.get("price"), criteria.getMinPrice()));
       }

       predicates.add(cb.isNull(root.get("deletedAt")));

       cq.where(predicates.toArray(new Predicate[0]));
       cq.orderBy(cb.desc(root.get("createdAt")));

       return em.createQuery(cq)
           .setMaxResults(criteria.getLimit())
           .getResultList();
   }

   @Override
   @Transactional
   public void bulkUpdatePrices(Map<UUID, BigDecimal> priceMap) {
       String sql = "UPDATE products SET price = :price, updated_at = NOW() WHERE id = :id";
       Query query = em.createNativeQuery(sql);

       for (Map.Entry<UUID, BigDecimal> entry : priceMap.entrySet()) {
           query.setParameter("id", entry.getKey());
           query.setParameter("price", entry.getValue());
           query.executeUpdate();
       }

       em.flush();
       em.clear();
   }
}

// 3. Main repository extends cả hai
@Repository
public interface ProductRepository extends JpaRepository<Product, UUID>,
                                          JpaSpecificationExecutor<Product>,
                                          ProductRepositoryCustom {
   // Có tất cả: JPA methods + Specification + Custom methods
}
```

### # query by example (qbe)

```java
// Tạo example entity
Product probe = new Product();
probe.setStatus(ProductStatus.ACTIVE);
probe.setName("Laptop");

// ExampleMatcher — cấu hình matching behavior
ExampleMatcher matcher = ExampleMatcher.matching()
   .withIgnoreNullValues()                          // Bỏ qua null fields
   .withMatcher("name", match -> match.contains().ignoreCase()) // LIKE '%laptop%'
   .withIgnorePaths("id", "createdAt", "version");  // Bỏ qua fields này

Example<Product> example = Example.of(probe, matcher);

// Repository usage
List<Product> results = productRepository.findAll(example);
Page<Product> pagedResults = productRepository.findAll(example, PageRequest.of(0, 20));
long count = productRepository.count(example);
boolean exists = productRepository.exists(example);
```

### # locking strategies

#### # optimistic locking (@Version)

```java
@Entity
public class Product extends BaseEntity {

   @Version  // Hibernate tự quản lý, +1 mỗi update
   private Long version;
}

// Khi 2 users update cùng lúc → OptimisticLockException
// Service handle:
@Transactional
public ProductDTO update(UUID id, UpdateProductRequest request) {
   try {
       Product product = productRepository.findById(id).orElseThrow();
       product.setName(request.getName());
       return toDTO(productRepository.save(product));
   } catch (OptimisticLockException e) {
       throw new ConflictException("Product was modified by another user. Please retry.");
   }
}
```

#### # pessimistic locking

```java
@Repository
public interface ProductRepository extends JpaRepository<Product, UUID> {

   // SELECT ... FOR UPDATE (block other transactions)
   @Lock(LockModeType.PESSIMISTIC_WRITE)
   @Query("SELECT p FROM Product p WHERE p.id = :id")
   Optional<Product> findByIdForUpdate(@Param("id") UUID id);

   // SELECT ... FOR SHARE (allow reads, block writes)
   @Lock(LockModeType.PESSIMISTIC_READ)
   @Query("SELECT p FROM Product p WHERE p.id = :id")
   Optional<Product> findByIdWithSharedLock(@Param("id") UUID id);

   // With timeout (PostgreSQL)
   @Lock(LockModeType.PESSIMISTIC_WRITE)
   @QueryHints(@QueryHint(name = "jakarta.persistence.lock.timeout", value = "5000"))
   @Query("SELECT p FROM Product p WHERE p.id = :id")
   Optional<Product> findByIdForUpdateWithTimeout(@Param("id") UUID id);
}
```

#### # khi nào dùng gì

| Scenario                         | Locking           | Lý do                           |
| -------------------------------- | ----------------- | ------------------------------- |
| Low contention (ít conflict)     | Optimistic        | Không block, retry khi conflict |
| High contention (nhiều conflict) | Pessimistic       | Tránh retry storm               |
| Read-heavy                       | Optimistic        | Reads không bị block            |
| Financial/critical operations    | Pessimistic WRITE | Đảm bảo consistency tuyệt đối   |
| Inventory/stock management       | Pessimistic WRITE | Tránh overselling               |

### # events & callbacks (entity lifecycle)

#### # jpa entity callbacks

```java
@Entity
public class Product extends BaseEntity {

   @PrePersist
   public void prePersist() {
       if (this.status == null) this.status = ProductStatus.DRAFT;
       if (this.code == null) this.code = generateCode();
   }

   @PreUpdate
   public void preUpdate() {
       this.updatedAt = LocalDateTime.now();
   }

   @PostPersist
   public void postPersist() {
       // Sau khi INSERT thành công (có ID)
       log.info("Product created: {}", this.getId());
   }

   @PostLoad
   public void postLoad() {
       // Sau khi load từ DB (computed fields)
   }

   @PreRemove
   public void preRemove() {
       // Trước khi DELETE
   }
}
```

#### # spring data domain events

```java
@Entity
public class Order extends BaseEntity {

   @DomainEvents  // Spring Data tự publish sau save()
   public Collection<Object> domainEvents() {
       List<Object> events = new ArrayList<>();
       if (this.status == OrderStatus.CONFIRMED) {
           events.add(new OrderConfirmedEvent(this.getId(), this.getCustomerId()));
       }
       return events;
   }

   @AfterDomainEventPublication  // Cleanup sau khi publish
   public void clearDomainEvents() {
       // Reset state nếu cần
   }
}

// Hoặc extend AbstractAggregateRoot (recommended)
@Entity
public class Order extends AbstractAggregateRoot<Order> {

   public Order confirm() {
       this.status = OrderStatus.CONFIRMED;
       registerEvent(new OrderConfirmedEvent(this.id, this.customerId));
       return this;
   }
}

// Listener
@Component
public class OrderEventListener {

   @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
   public void onOrderConfirmed(OrderConfirmedEvent event) {
       // Send notification, update inventory, etc.
       notificationService.notifyCustomer(event.getCustomerId());
   }
}
```

### # soft delete pattern

#### # cách 1: @Where (hibernate — deprecated trong 6.x, dùng @SQLRestriction)

```java
@Entity
@SQLRestriction("deleted_at IS NULL")  // Hibernate 6.3+
// Hoặc @Where(clause = "deleted_at IS NULL")  // Hibernate < 6.3
public class Product extends BaseEntity {
   private LocalDateTime deletedAt;
}

// findAll() tự động thêm WHERE deleted_at IS NULL
// findById() cũng tự động filter
```

#### # cách 2: manual filter trong repository

```java
@Repository
public interface ProductRepository extends JpaRepository<Product, UUID> {

   // Override default methods để thêm soft delete filter
   @Query("SELECT p FROM Product p WHERE p.id = :id AND p.deletedAt IS NULL")
   Optional<Product> findActiveById(@Param("id") UUID id);

   @Query("SELECT p FROM Product p WHERE p.deletedAt IS NULL")
   Page<Product> findAllActive(Pageable pageable);

   // Soft delete
   @Modifying
   @Transactional
   @Query("UPDATE Product p SET p.deletedAt = :now WHERE p.id = :id")
   int softDelete(@Param("id") UUID id, @Param("now") LocalDateTime now);

   // Restore
   @Modifying
   @Transactional
   @Query("UPDATE Product p SET p.deletedAt = NULL WHERE p.id = :id")
   int restore(@Param("id") UUID id);

   // Admin: xem cả deleted
   @Query("SELECT p FROM Product p WHERE p.id = :id")
   Optional<Product> findByIdIncludeDeleted(@Param("id") UUID id);
}
```

#### # cách 3: base repository với soft delete

```java
@NoRepositoryBean
public interface SoftDeleteRepository<T, ID> extends JpaRepository<T, ID> {

   @Query("SELECT e FROM #{#entityName} e WHERE e.deletedAt IS NULL")
   List<T> findAllActive();

   @Query("SELECT e FROM #{#entityName} e WHERE e.id = :id AND e.deletedAt IS NULL")
   Optional<T> findActiveById(@Param("id") ID id);

   @Modifying
   @Query("UPDATE #{#entityName} e SET e.deletedAt = CURRENT_TIMESTAMP WHERE e.id = :id")
   int softDelete(@Param("id") ID id);
}

// Usage
@Repository
public interface ProductRepository extends SoftDeleteRepository<Product, UUID> {
   // Thừa kế tất cả soft delete methods
}
```

### # performance tips

#### # batch operations

```java
@Service
@RequiredArgsConstructor
public class ProductBatchService {

   private final EntityManager em;

   @Transactional
   public void batchInsert(List<Product> products) {
       int batchSize = 50;
       for (int i = 0; i < products.size(); i++) {
           em.persist(products.get(i));
           if (i > 0 && i % batchSize == 0) {
               em.flush();  // Gửi batch INSERT về DB
               em.clear();  // Giải phóng memory
           }
       }
       em.flush();
       em.clear();
   }
}
```

#### # read-only optimization

```java
// readOnly = true → Hibernate skip dirty checking → faster
@Transactional(readOnly = true)
public List<ProductDTO> findAll() {
   return productRepository.findAll().stream().map(this::toDTO).toList();
}
```

#### # dto projection thay vì entity

```java
// ❌ Load full entity chỉ để lấy 3 fields
List<Product> products = repo.findAll(); // Load ALL columns + lazy proxies
products.stream().map(p -> new ProductSummary(p.getId(), p.getName(), p.getPrice()));

// ✅ DTO Projection — chỉ SELECT đúng columns cần
@Query("SELECT new ...ProductSummaryDTO(p.id, p.name, p.price) FROM Product p")
List<ProductSummaryDTO> findAllSummary();
```

#### # avoid fetching unnecessary data

```java
// ❌ findById khi chỉ cần check exists
Optional<Product> product = repo.findById(id); // Load toàn bộ entity
if (product.isEmpty()) throw new NotFoundException();

// ✅ existsById — chỉ SELECT COUNT
if (!repo.existsById(id)) throw new NotFoundException();

// ❌ findAll khi chỉ cần count
long count = repo.findByStatus(ACTIVE).size(); // Load tất cả records vào memory

// ✅ countBy — chỉ SELECT COUNT
long count = repo.countByStatus(ACTIVE);
```

#### # query hints

```java
@QueryHints({
   @QueryHint(name = "org.hibernate.fetchSize", value = "50"),     // JDBC fetch size
   @QueryHint(name = "org.hibernate.readOnly", value = "true"),    // Read-only mode
   @QueryHint(name = "org.hibernate.cacheable", value = "true"),   // 2nd level cache
   @QueryHint(name = "jakarta.persistence.query.timeout", value = "5000")  // 5s timeout
})
@Query("SELECT p FROM Product p WHERE p.status = :status")
List<Product> findByStatusOptimized(@Param("status") ProductStatus status);
```

### # testing repository

```java
@DataJpaTest  // Chỉ load JPA layer (Repository + EntityManager + DataSource)
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE) // Dùng real DB
@Import(JpaAuditingConfig.class)
class ProductRepositoryTest {

   @Autowired
   private ProductRepository productRepository;

   @Autowired
   private TestEntityManager em;

   @Autowired
   private CategoryRepository categoryRepository;

   private Category testCategory;

   @BeforeEach
   void setUp() {
       testCategory = categoryRepository.save(
           Category.builder().name("Electronics").code("ELEC").build()
       );
   }

   @Test
   void findByCode_existingProduct_returnsProduct() {
       // Given
       Product product = Product.builder()
           .code("PRD-001")
           .name("Test Product")
           .price(BigDecimal.valueOf(1000))
           .status(ProductStatus.ACTIVE)
           .category(testCategory)
           .build();
       em.persistAndFlush(product);

       // When
       Optional<Product> result = productRepository.findByCode("PRD-001");

       // Then
       assertThat(result).isPresent();
       assertThat(result.get().getName()).isEqualTo("Test Product");
   }

   @Test
   void findByStatus_withPagination_returnsPage() {
       // Given
       IntStream.rangeClosed(1, 25).forEach(i ->
           em.persist(Product.builder()
               .code("PRD-" + i)
               .name("Product " + i)
               .price(BigDecimal.valueOf(i * 100))
               .status(ProductStatus.ACTIVE)
               .category(testCategory)
               .build())
       );
       em.flush();

       // When
       Page<Product> page = productRepository.findByStatus(
           ProductStatus.ACTIVE, PageRequest.of(0, 10, Sort.by("name")));

       // Then
       assertThat(page.getContent()).hasSize(10);
       assertThat(page.getTotalElements()).isEqualTo(25);
       assertThat(page.getTotalPages()).isEqualTo(3);
   }

   @Test
   void softDelete_setsDeletedAt() {
       // Given
       Product product = em.persistAndFlush(Product.builder()
           .code("DEL-001").name("To Delete")
           .price(BigDecimal.ONE).status(ProductStatus.ACTIVE)
           .category(testCategory).build());

       // When
       LocalDateTime now = LocalDateTime.now();
       int affected = productRepository.softDelete(product.getId(), now);

       // Then
       assertThat(affected).isEqualTo(1);
       em.clear(); // Clear cache
       Product deleted = em.find(Product.class, product.getId());
       assertThat(deleted.getDeletedAt()).isNotNull();
   }
}
```

### # quick reference — annotations

| Annotation                 | Package                         | Mục đích                  |
| -------------------------- | ------------------------------- | ------------------------- |
| @Repository                | springframework.stereotype      | Đánh dấu DAO bean         |
| @Query                     | springframework.data.jpa        | Custom JPQL/SQL query     |
| @Modifying                 | springframework.data.jpa        | UPDATE/DELETE queries     |
| @Param                     | springframework.data.repository | Named parameter binding   |
| @EntityGraph               | springframework.data.jpa        | Eager fetch associations  |
| @Lock                      | springframework.data.jpa        | Locking mode              |
| @QueryHints                | springframework.data.jpa        | Hibernate/JPA hints       |
| @Transactional             | springframework.transaction     | Transaction boundary      |
| @CreatedDate               | springframework.data.annotation | Auto audit timestamp      |
| @LastModifiedDate          | springframework.data.annotation | Auto audit timestamp      |
| @CreatedBy                 | springframework.data.annotation | Auto audit user           |
| @LastModifiedBy            | springframework.data.annotation | Auto audit user           |
| @EnableJpaAuditing         | springframework.data.jpa        | Enable audit features     |
| @NoRepositoryBean          | springframework.data.repository | Base repository (no impl) |
| @Entity                    | jakarta.persistence             | JPA entity                |
| @Table                     | jakarta.persistence             | Table mapping             |
| @Id                        | jakarta.persistence             | Primary key               |
| @GeneratedValue            | jakarta.persistence             | ID generation strategy    |
| @Column                    | jakarta.persistence             | Column mapping            |
| @Enumerated                | jakarta.persistence             | Enum persistence type     |
| @ManyToOne / @OneToMany    | jakarta.persistence             | Relationship mapping      |
| @JoinColumn                | jakarta.persistence             | FK column                 |
| @Version                   | jakarta.persistence             | Optimistic locking        |
| @PrePersist / @PostPersist | jakarta.persistence             | Entity lifecycle callback |
| @Embedded / @Embeddable    | jakarta.persistence             | Value object              |
| @MappedSuperclass          | jakarta.persistence             | Base entity class         |

### # kết luận

Spring Data JPA là abstraction mạnh giúp giảm đáng kể boilerplate code cho data access layer. Một số nguyên tắc:

1. **Derived queries** cho simple cases, **@Query** cho complex cases, **Specification** cho dynamic queries
2. **Luôn dùng `FetchType.LAZY`** cho relationships — explicit fetch khi cần bằng JOIN FETCH hoặc @EntityGraph
3. **DTO Projection** cho read-heavy operations — không load toàn bộ entity khi không cần
4. **@Transactional(readOnly = true)** mặc định cho service class — override cho write methods
5. **Soft delete** thay vì hard delete trong production
6. **Optimistic locking (@Version)** cho hầu hết cases — pessimistic chỉ khi contention cao
7. **Batch operations** khi xử lý nhiều records — flush + clear theo batch size
8. **Auditing** tự động — không set createdAt/updatedAt thủ công

> Chỉ là những ghi chép cá nhân với hy vọng mang lại chút giá trị. Nếu thấy hữu ích, đừng ngại chia sẻ cho bạn bè & đồng nghiệp nhé!

Happy coding <Twemoji emoji="clinking-beer-mugs" /> 😎 👍🏻 🚀 🔥.
