---
layout: post
title: "spring security với jwt"
date: 2024-05-02 19:29:39 +0700
categories: [Software Development]
tags: [java, software-development, spring-boot, spring-framework, jwt, vietnamese]
---

Trong bài viết này, chúng ta sẽ khám phá cách tích hợp Spring Security với JWT để xây dựng một lớp bảo mật vững chắc cho ứng dụng của mình. Chúng ta sẽ đi qua từng bước, từ cấu hình cơ bản cho đến việc triển khai bộ lọc xác thực tùy chỉnh, đảm bảo rằng bạn có đầy đủ công cụ cần thiết để bảo vệ API một cách hiệu quả và có khả năng mở rộng.

### # cấu hình

Tại Spring Initializr, chúng ta sẽ tạo một dự án sử dụng Java 21, Maven, Jar và các dependency sau:

- Spring Data JPA
- Spring Web
- Lombok
- Spring Security
- PostgreSQL Driver
- OAuth2 Resource Server

### # thiết lập cơ sở dữ liệu postgreSQL

Với Docker, bạn sẽ tạo cơ sở dữ liệu PostgreSQL bằng Docker Compose.
Hãy tạo một tệp `docker-compose.yaml` tại thư mục gốc của dự án.

```yml
services:
  postgre:
    image: postgres:latest
    ports:
      - '5432:5432'
    environment:
      - POSTGRES_DB=database
      - POSTGRES_USER=admin
      - POSTGRES_PASSWORD=admin
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
```

Chạy lệnh `docker compose up -d` để RUN container.

Thêm file `application.properties` để cấu hình cho ứng dụng Spring Boot:

```properties
# Database Configuration
spring.datasource.url=jdbc:postgresql://localhost:5432/your_database_name
spring.datasource.username=your_username
spring.datasource.password=your_password
spring.datasource.driver-class-name=org.postgresql.Driver

# JPA Configuration
spring.jpa.hibernate.ddl-auto=update
spring.jpa.properties.hibernate.dialect=org.hibernate.dialect.PostgreSQLDialect
spring.jpa.show-sql=true

# Server Configuration
server.port=8080
```

_Trong đó_:

- spring.datasource.url – URL kết nối tới PostgreSQL.
- spring.datasource.username – Tên người dùng PostgreSQL.
- spring.datasource.password – Mật khẩu truy cập cơ sở dữ liệu.
- spring.jpa.hibernate.ddl-auto – Tự động cập nhật schema cơ sở dữ liệu.
- spring.jpa.show-sql – Hiển thị câu lệnh SQL trong console để debug.
- server.port – Cấu hình cổng chạy ứng dụng (mặc định là 8080).

Hãy thay thế `your_database_name`, `your_username`, và `your_password` bằng thông tin thực tế của bạn.

### # tạo khóa private và public cho jwt

Để tạo khóa private và public cho JWT, hãy làm theo các bước sau:

**Tạo khóa Private**:

Chạy lệnh sau trong terminal để tạo khóa private trong thư mục resources:

```terminal
openssl genpkey -algorithm RSA -out src/main/resources/private.pem
```

**Tạo khóa Public (từ khóa Private)**:

```terminal
openssl rsa -pubout -in src/main/resources/private.pem -out src/main/resources/public.pem
```

**Lưu ý quan trọng**:

- **KHÔNG BAO GIỜ** commit các tệp `private.pem` và `public.pem` lên GitHub.
- Hãy lưu trữ chúng một cách an toàn hoặc sử dụng biến môi trường để tải chúng động.

Update `application.properties` để thêm các key vào cấu hình:

```properties
jwt.private.key=classpath:private.pem
jwt.public.key=classpath:public.pem
```

### # code thôi nào

Tạo class `SecurityConfig.java` trong thư mục `configs` và thêm mã sau vào file này:

```java
import java.security.interfaces.RSAPrivateKey;
import java.security.interfaces.RSAPublicKey;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import org.springframework.security.oauth2.jwt.NimbusJwtEncoder;
import org.springframework.security.web.SecurityFilterChain;

import com.nimbusds.jose.jwk.JWKSet;
import com.nimbusds.jose.jwk.RSAKey;
import com.nimbusds.jose.jwk.source.ImmutableJWKSet;

@Configuration
@EnableWebSecurity
@EnableMethodSecurity
public class SecurityConfig {

    @Value("${jwt.public.key}")
    private RSAPublicKey publicKey;

    @Value("${jwt.private.key}")
    private RSAPrivateKey privateKey;

    @Bean
    SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
                .csrf(csrf -> csrf.disable())
                .authorizeHttpRequests(auth -> auth.requestMatchers(HttpMethod.POST, "/signin").permitAll()
                        .requestMatchers(HttpMethod.POST, "/login").permitAll()
                        .anyRequest().authenticated())
                .oauth2ResourceServer(config -> config.jwt(jwt -> jwt.decoder(jwtDecoder())));

        return http.build();
    }

    @Bean
    BCryptPasswordEncoder bPasswordEncoder() {
        return new BCryptPasswordEncoder();
    }

    @Bean
    JwtEncoder jwtEncoder() {
        var jwk = new RSAKey.Builder(this.publicKey).privateKey(this.privateKey).build();

        var jwks = new ImmutableJWKSet<>(new JWKSet(jwk));

        return new NimbusJwtEncoder(jwks);
    }

    @Bean
    JwtDecoder jwtDecoder() {
        return NimbusJwtDecoder.withPublicKey(publicKey).build();
    }
}
```

Trong đó:

- @Configuration – Đánh dấu đây là một lớp cấu hình cho Spring.
- @EnableWebSecurity – Kích hoạt Spring Security cho ứng dụng.
- securityFilterChain – Cấu hình các quy tắc bảo mật, tắt CSRF (cho ứng dụng sử dụng JWT không trạng thái) và yêu cầu xác thực cho các endpoint còn lại.
- SessionCreationPolicy.STATELESS – Đảm bảo ứng dụng không tạo hoặc sử dụng session HTTP (ứng dụng không trạng thái với JWT).
- @EnableWebSecurity: Khi bạn sử dụng @EnableWebSecurity, nó sẽ tự động kích hoạt cấu hình bảo mật của Spring Security để bảo vệ các ứng dụng web. Cấu hình này bao gồm việc thiết lập các bộ lọc, bảo vệ các endpoint và áp dụng các quy tắc bảo mật khác nhau.

- @EnableMethodSecurity: Đây là một annotation trong Spring Security cho phép bảo mật ở cấp độ phương thức trong ứng dụng Spring của bạn. Nó cho phép bạn áp dụng các quy tắc bảo mật trực tiếp tại cấp độ phương thức thông qua các annotation như @PreAuthorize, - @PostAuthorize, @Secured, và @RolesAllowed.

- privateKey và publicKey: Đây là các khóa RSA công khai và riêng tư được sử dụng để ký và xác minh JWT. Annotation @Value sẽ tiêm các khóa này từ tệp cấu hình application.properties vào các trường này.

- CSRF: Tắt bảo vệ CSRF (Cross-Site Request Forgery), thường bị tắt trong các API REST không trạng thái, nơi JWT được sử dụng để xác thực.

- authorizeHttpRequests: Cấu hình các quy tắc phân quyền dựa trên URL.

- requestMatchers(HttpMethod.POST, "/signin").permitAll(): Cho phép truy cập không xác thực tới các endpoint /signin và /login, có nghĩa là ai cũng có thể truy cập những tuyến đường này mà không cần đăng nhập.

- anyRequest().authenticated(): Yêu cầu xác thực cho tất cả các yêu cầu khác.

- oauth2ResourceServer: Cấu hình ứng dụng như một OAuth 2.0 resource server sử dụng JWT để xác thực.

- config.jwt(jwt -> jwt.decoder(jwtDecoder())): Chỉ định bean JWT decoder (jwtDecoder) sẽ được sử dụng để giải mã và xác thực các token JWT.

- BCryptPasswordEncoder: Bean này định nghĩa một trình mã hóa mật khẩu sử dụng thuật toán băm BCrypt để mã hóa mật khẩu. BCrypt là một lựa chọn phổ biến để lưu trữ mật khẩu một cách an toàn vì tính thích ứng của nó, giúp chống lại các cuộc tấn công brute-force.

- JwtEncoder: Bean này chịu trách nhiệm mã hóa (ký) các token JWT.
  - RSAKey.Builder: Tạo một khóa RSA mới sử dụng các khóa công khai và riêng tư RSA đã cung cấp.

  - `ImmutableJWKSet<>(new JWKSet(jwk))`: Bao bọc khóa RSA trong một JSON Web Key Set (JWKSet) và làm cho nó không thể thay đổi.

  - NimbusJwtEncoder(jwks): Sử dụng thư viện Nimbus để tạo một JWT encoder sẽ ký các token với khóa RSA riêng.

- JwtDecoder: Bean này chịu trách nhiệm giải mã (xác minh) các token JWT.
  - NimbusJwtDecoder.withPublicKey(publicKey).build(): Tạo một JWT decoder sử dụng khóa công khai RSA, được sử dụng để xác minh chữ ký của các token JWT.

Class `ClientEntity` lưu trữ thông tin user:

```java
mport org.springframework.security.crypto.password.PasswordEncoder;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(name = "tb_clients")
@Getter
@Setter
@NoArgsConstructor
public class ClientEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.SEQUENCE)
    @Column(name = "client_id")
    private Long clientId;

    private String name;

    @Column(unique = true)
    private String cpf;

    @Column(unique = true)
    private String email;

    private String password;

    @Column(name = "user_type")
    private String userType = "client";

    public Boolean isLoginCorrect(String password, PasswordEncoder passwordEncoder) {
        return passwordEncoder.matches(password, this.password);
    }
}
```

Class `ClientRepository` tương tác trực tiếp với database:

```java
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.tungdadev.spring_jwt.entities.ClientEntity;

@Repository
public interface ClientRepository extends JpaRepository<ClientEntity, Long> {
    Optional<ClientEntity> findByEmail(String email);

    Optional<ClientEntity> findByCpf(String cpf);

    Optional<ClientEntity> findByEmailOrCpf(String email, String cpf);
}
```

Các Service để xử lý logic:

- _Client service_:

```java
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import com.tungdadev.spring_jwt.entities.ClientEntity;
import com.tungdadev.spring_jwt.repositories.ClientRepository;

@Service
public class ClientService {

    @Autowired
    private ClientRepository clientRepository;

    @Autowired
    private BCryptPasswordEncoder bPasswordEncoder;

    public ClientEntity createClient(String name, String cpf, String email, String password) {

        var clientExists = this.clientRepository.findByEmailOrCpf(email, cpf);

        if (clientExists.isPresent()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Email/Cpf already exists.");
        }

        var newClient = new ClientEntity();

        newClient.setName(name);
        newClient.setCpf(cpf);
        newClient.setEmail(email);
        newClient.setPassword(bPasswordEncoder.encode(password));

        return clientRepository.save(newClient);
    }
}
```

- _Token service_:

```java
import java.time.Instant;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.oauth2.jwt.JwtClaimsSet;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtEncoderParameters;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import com.tungdadev.spring_jwt.repositories.ClientRepository;

@Service
public class TokenService {

    @Autowired
    private ClientRepository clientRepository;

    @Autowired
    private JwtEncoder jwtEncoder;

    @Autowired
    private BCryptPasswordEncoder bCryptPasswordEncoder;

    public String login(String email, String password) {

        var client = this.clientRepository.findByEmail(email)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.BAD_REQUEST, "Email not found"));

        var isCorrect = client.isLoginCorrect(password, bCryptPasswordEncoder);

        if (!isCorrect) {
            throw new BadCredentialsException("Email/password invalid");
        }

        var now = Instant.now();
        var expiresIn = 300L;

        var claims = JwtClaimsSet.builder()
                .issuer("pic_pay_backend")
                .subject(client.getEmail())
                .issuedAt(now)
                .expiresAt(now.plusSeconds(expiresIn))
                .claim("scope", client.getUserType())
                .build();

        var jwtValue = jwtEncoder.encode(JwtEncoderParameters.from(claims)).getTokenValue();

        return jwtValue;

    }
}
```

Cuối cùng là Controller, nơi nhận các request:

- _Client controller_:

```java
package com.tungdadev.spring_jwt.controllers;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import com.tungdadev.spring_jwt.controllers.dto.NewClientDTO;
import com.tungdadev.spring_jwt.entities.ClientEntity;
import com.tungdadev.spring_jwt.services.ClientService;

@RestController
public class ClientController {

    @Autowired
    private ClientService clientService;

    @PostMapping("/signin")
    public ResponseEntity<ClientEntity> createNewClient(@RequestBody NewClientDTO client) {
        var newClient = this.clientService.createClient(client.name(), client.cpf(), client.email(), client.password());

        return ResponseEntity.status(HttpStatus.CREATED).body(newClient);
    }

    @GetMapping("/protectedRoute")
    @PreAuthorize("hasAuthority('SCOPE_client')")
    public ResponseEntity<String> protectedRoute(JwtAuthenticationToken token) {
        return ResponseEntity.ok("Authorized");
    }

}
```

Trong đó:

- /protectedRoute: Đây là một route riêng tư chỉ có thể truy cập được khi có JWT sau khi đăng nhập.

- Token phải được đưa vào trong header dưới dạng Bearer token: Ví dụ, token sẽ được truyền trong header của yêu cầu HTTP như sau:

```http
Authorization: Bearer <your-jwt-token>
```

- Token có thể được sử dụng sau đó trong ứng dụng: Bạn có thể sử dụng thông tin từ token trong các lớp dịch vụ của ứng dụng để thực hiện các hành động bảo mật hoặc truy vấn dữ liệu.

- @PreAuthorize: Annotation `@PreAuthorize` trong Spring Security được sử dụng để thực hiện kiểm tra phân quyền trước khi một phương thức được gọi. Annotation này thường được áp dụng ở cấp độ phương thức trong các component của Spring (như controller hoặc service) để hạn chế quyền truy cập dựa trên vai trò, quyền hạn của người dùng hoặc các điều kiện bảo mật khác.
  - Annotation này xác định điều kiện mà phương thức phải đáp ứng trước khi được thực thi. Nếu điều kiện trả về true, phương thức sẽ được thực hiện. Nếu điều kiện trả về false, quyền truy cập bị từ chối.

- "hasAuthority('SCOPE_client')": Điều này kiểm tra xem người dùng hoặc client đang được xác thực có quyền hạn cụ thể là SCOPE_client hay không. Nếu có, phương thức protectedRoute() sẽ được thực thi. Nếu không, quyền truy cập sẽ bị từ chối.

- Token Controller: Ở đây, bạn có thể đăng nhập vào ứng dụng, và nếu đăng nhập thành công, ứng dụng sẽ trả về một token. Token này sẽ được sử dụng để xác thực các yêu cầu truy cập vào các route bảo mật khác.

- _Token Controller_: class xử lý login và trả về `token` nếu login success.

```java
package com.tungdadev.spring_jwt.controllers;

import java.util.Map;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RestController;

import com.tungdadev.spring_jwt.controllers.dto.LoginDTO;
import com.tungdadev.spring_jwt.services.TokenService;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;

@RestController
public class TokenController {

    @Autowired
    private TokenService tokenService;

    @PostMapping("/login")
    public ResponseEntity<Map<String, String>> login(@RequestBody LoginDTO loginDTO) {
        var token = this.tokenService.login(loginDTO.email(), loginDTO.password());

        return ResponseEntity.ok(Map.of("token", token));
    }

}
```

### # lời kết

Bảo mật là một yếu tố không thể thiếu trong việc xây dựng các ứng dụng web hiện đại. Việc tích hợp Spring Security với JWT mang lại một lớp bảo mật mạnh mẽ và linh hoạt, giúp bảo vệ các API của bạn khỏi các mối đe dọa từ bên ngoài. Trong bài viết này, chúng ta đã cùng nhau đi qua các bước từ việc cấu hình cơ bản đến triển khai bộ lọc xác thực tùy chỉnh, giúp bạn có thể triển khai bảo mật hiệu quả cho các ứng dụng của mình.

Hãy nhớ rằng việc bảo vệ ứng dụng của bạn không chỉ dừng lại ở việc cấu hình bảo mật ban đầu, mà còn cần phải kiểm tra và tối ưu thường xuyên để đối phó với các mối nguy cơ mới. Hy vọng bài viết này đã cung cấp cho bạn những kiến thức hữu ích để bảo vệ ứng dụng của mình một cách an toàn và hiệu quả.

> Chỉ là những ghi chép cá nhân với hy vọng mang lại chút giá trị. Nếu thấy hữu ích, đừng ngại chia sẻ cho bạn bè & đồng nghiệp nhé!

Happy coding <Twemoji emoji="clinking-beer-mugs" /> 😎 👍🏻 🚀 🔥.

**Reference**:

- [**Spring Security**](https://docs.spring.io/spring-security/reference/index.html)
- [**Spring Security with JWT**](https://dev.to/mspilari/spring-security-with-jwt-2bl6)
