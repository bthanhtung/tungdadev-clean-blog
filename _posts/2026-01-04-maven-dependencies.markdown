---
layout: post
title: "maven dependencies"
date: 2026-01-04 19:29:39 +0700
categories: [Software Development]
tags: [java, software-development, maven, best-practices, vietnamese]
---

Trong các hệ thống phân tán và kiến trúc microservices hiện đại, cấu hình build không đơn thuần chỉ là công cụ đóng gói phần mềm. Nó là bản thiết kế thể hiện sự gọn gàng, tính nhất quán và tính dễ bảo trì của cả một dự án. Quản lý tồi, bạn sẽ rơi vào "Dependency Hell". Quản lý tốt, hệ thống sẽ tự động vận hành trơn tru từ môi trường local cho đến production.

Bài viết này sẽ đào sâu vào nghệ thuật làm chủ Maven, từ việc tổ chức cấu trúc POM tinh giản, quản lý phiên bản tập trung bằng BOM, cho đến cách xây dựng kiến trúc Multi-module tiêu chuẩn.

### # pom structure

Một file `pom.xml` được tổ chức tốt cần phản ánh rõ sự phân tách trách nhiệm (Separation of Concerns). Thay vì nhồi nhét mọi thứ, chúng ta sử dụng cơ chế kế thừa (Parent) và gom nhóm thuộc tính (Properties).

```xml
<project>
   <!-- Coordinates -->
   <groupId>vn.com.vpbank.internal</groupId>
   <artifactId>my-service</artifactId>
   <version>1.0.0-SNAPSHOT</version>
   <packaging>jar</packaging>

   <!-- Parent (inherits config) -->
   <parent>
       <groupId>org.springframework.boot</groupId>
       <artifactId>spring-boot-starter-parent</artifactId>
       <version>3.2.5</version>
   </parent>

   <!-- Properties (centralize versions) -->
   <properties>
       <java.version>21</java.version>
       <mapstruct.version>1.5.5.Final</mapstruct.version>
   </properties>

   <!-- Dependency Management (BOM imports) -->
   <dependencyManagement>
       <dependencies>
           <dependency>
               <groupId>org.springframework.cloud</groupId>
               <artifactId>spring-cloud-dependencies</artifactId>
               <version>2023.0.1</version>
               <type>pom</type>
               <scope>import</scope>
           </dependency>
       </dependencies>
   </dependencyManagement>

   <!-- Actual Dependencies -->
   <dependencies>
       <dependency>
           <groupId>org.springframework.boot</groupId>
           <artifactId>spring-boot-starter-web</artifactId>
           <!-- version inherited from parent -->
       </dependency>
   </dependencies>
</project>
```

### # dependency scopes

Việc hiểu đúng Scope giúp giữ cho dung lượng file JAR/WAR cuối cùng ở mức tối giản nhất, giảm thiểu thời gian khởi động và rủi ro bảo mật.
| Scope | Compile | Test | Runtime | Packaged |
| ----------------- | ------- | ---- | ------- | -------- |
| compile (default) | ✓ | ✓ | ✓ | ✓ |
| provided | ✓ | ✓ | ✗ | ✗ |
| runtime | ✗ | ✓ | ✓ | ✓ |
| test | ✗ | ✓ | ✗ | ✗ |
| system | ✓ | ✓ | ✗ | ✗ |

Ví dụ thực tế:

```xml
<!-- Examples -->
<dependency>
   <groupId>org.projectlombok</groupId>
   <artifactId>lombok</artifactId>
   <scope>provided</scope> <!-- annotation processor, not in final jar -->
</dependency>

<dependency>
   <groupId>org.postgresql</groupId>
   <artifactId>postgresql</artifactId>
   <scope>runtime</scope> <!-- only needed at runtime via JDBC -->
</dependency>

<dependency>
   <groupId>org.springframework.boot</groupId>
   <artifactId>spring-boot-starter-test</artifactId>
   <scope>test</scope>
</dependency>
```

### # bom (bill of materials)

Trong các dự án lớn hoặc kiến trúc Microservices, việc hardcode version ở từng module là một "Anti-pattern". BOM giải quyết bài toán này bằng cách đóng vai trò là một "Single Source of Truth" cho toàn bộ phiên bản thư viện.

Tại file Parent hoặc Shared BOM:

```xml
<!-- In parent or shared BOM -->
<dependencyManagement>
   <dependencies>
       <!-- Spring Cloud BOM -->
       <dependency>
           <groupId>org.springframework.cloud</groupId>
           <artifactId>spring-cloud-dependencies</artifactId>
           <version>${spring-cloud.version}</version>
           <type>pom</type>
           <scope>import</scope>
       </dependency>

       <!-- Internal libraries BOM -->
       <dependency>
           <groupId>vn.com.vpbank.internal</groupId>
           <artifactId>csp-common</artifactId>
           <version>${csp-common.version}</version>
       </dependency>
   </dependencies>
</dependencyManagement>
```

Tại các Child Module: (Mã nguồn trở nên gọn gàng, không còn sự hiện diện của thẻ `<version>`)

```xml
<!-- In child module — no version needed -->
<dependencies>
   <dependency>
       <groupId>org.springframework.cloud</groupId>
       <artifactId>spring-cloud-starter-netflix-eureka-client</artifactId>
       <!-- version resolved from BOM -->
   </dependency>
</dependencies>
```

### # dependency resolution

Khi hai thư viện kéo theo (transitive dependencies) cùng một thư viện khác nhưng khác phiên bản, Maven áp dụng quy tắc "Nearest wins" (Khoảng cách gần nhất tới gốc POM sẽ thắng).

Để ép buộc hệ thống dùng đúng phiên bản mong muốn hoặc loại bỏ các thư viện rác, chúng ta dùng cơ chế Exclusions:

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-web</artifactId>
    <exclusions>
        <exclusion>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-tomcat</artifactId>
        </exclusion>
    </exclusions>
</dependency>
```

#### # useful commands

```bash
# Hiển thị cây thư viện để truy vết nguồn gốc dependency
./mvnw dependency:tree

# Lọc nhanh các xung đột
./mvnw dependency:tree -Dverbose | grep "omitted for conflict"

# Phát hiện các dependency đang được khai báo nhưng không dùng tới
./mvnw dependency:analyze

# Show effective POM (resolved inheritance)
./mvnw help:effective-pom

# Show effective settings
./mvnw help:effective-settings
```

### # profiles

```xml
<profiles>
   <!-- Dev profile (default) -->
   <profile>
       <id>dev</id>
       <activation>
           <activeByDefault>true</activeByDefault>
       </activation>
       <properties>
           <packaging.type>jar</packaging.type>
           <spring.profiles.active>dev</spring.profiles.active>
       </properties>
   </profile>

   <!-- Production profile -->
   <profile>
       <id>prod</id>
       <properties>
           <packaging.type>war</packaging.type>
           <spring.profiles.active>prod</spring.profiles.active>
       </properties>
       <dependencies>
           <dependency>
               <groupId>org.springframework.boot</groupId>
               <artifactId>spring-boot-starter-tomcat</artifactId>
               <scope>provided</scope>
           </dependency>
       </dependencies>
   </profile>

   <!-- Skip tests profile -->
   <profile>
       <id>fast</id>
       <properties>
           <maven.test.skip>true</maven.test.skip>
           <checkstyle.skip>true</checkstyle.skip>
       </properties>
   </profile>
</profiles>
```

```bash
# Activate profile
./mvnw clean package -Pprod
./mvnw clean package -Pdev,fast

# Property override
./mvnw clean package -DskipTests
```

### # multi-module project

Với các hệ thống tuân theo Clean Architecture hoặc Domain-Driven Design, việc chia tách mã nguồn thành các module độc lập (Core, Infrastructure, Application) là bắt buộc. Maven Multi-module giữ cho cấu trúc này liên kết chặt chẽ nhưng độc lập về mặt biên dịch.

Parent POM: Quản lý danh sách các module con.

```xml
<modules>
    <module>core</module>
    <module>application</module>
    <module>infrastructure</module>
</modules>
```

#### # build commands

```bash
# Build all modules
./mvnw clean install

# Build specific module + dependencies
./mvnw clean install -pl application -am

# Build specific module only (no deps)
./mvnw clean install -pl bpm-cluster

# Skip modules
./mvnw clean install -pl !integration-tests
```

**Flags**:

- `-pl` (projects list): specify modules to build
- `-am` (also make): build required dependencies
- `-amd` (also make dependents): build modules that depend on specified
- `-rf` (resume from): restart build from specific module

### # build lifecycle

#### # default lifecycle phases

Maven thực thi theo tính tuyến tính. Gọi một phase sẽ kích hoạt tất cả các phase trước đó:
validate → compile → test → package (tạo JAR) → verify (chạy Integration test & Checkstyle) → install (đưa vào local repo) → deploy (đưa lên Nexus).
| Phase | Action |
| -------- | ------------------------------------- |
| validate | Check POM correctness |
| compile | Compile source code |
| test | Run unit tests |
| package | Create JAR/WAR |
| verify | Run integration tests, quality checks |
| install | Install to local .m2 repository |
| deploy | Upload to remote Nexus repository |

```bash
# Each phase runs all preceding phases
./mvnw package    # → validate → compile → test → package
./mvnw verify     # → ... → package → verify (JaCoCo, Fortify)
./mvnw install    # → ... → verify → install
```

#### # plugin configuration

```xml
<build>
   <plugins>
       <!-- Compiler -->
       <plugin>
           <groupId>org.apache.maven.plugins</groupId>
           <artifactId>maven-compiler-plugin</artifactId>
           <configuration>
               <release>21</release>
               <compilerArgs>
                   <arg>--enable-preview</arg>
               </compilerArgs>
               <annotationProcessorPaths>
                   <path>
                       <groupId>org.projectlombok</groupId>
                       <artifactId>lombok</artifactId>
                       <version>${lombok.version}</version>
                   </path>
                   <path>
                       <groupId>org.mapstruct</groupId>
                       <artifactId>mapstruct-processor</artifactId>
                       <version>${mapstruct.version}</version>
                   </path>
               </annotationProcessorPaths>
           </configuration>
       </plugin>

       <!-- Spring Boot packaging -->
       <plugin>
           <groupId>org.springframework.boot</groupId>
           <artifactId>spring-boot-maven-plugin</artifactId>
           <configuration>
               <excludes>
                   <exclude>
                       <groupId>org.projectlombok</groupId>
                       <artifactId>lombok</artifactId>
                   </exclude>
               </excludes>
           </configuration>
       </plugin>

       <!-- JaCoCo coverage -->
       <plugin>
           <groupId>org.jacoco</groupId>
           <artifactId>jacoco-maven-plugin</artifactId>
           <executions>
               <execution>
                   <goals><goal>prepare-agent</goal></goals>
               </execution>
               <execution>
                   <id>check</id>
                   <phase>verify</phase>
                   <goals><goal>check</goal></goals>
                   <configuration>
                       <rules>
                           <rule>
                               <limits>
                                   <limit>
                                       <counter>LINE</counter>
                                       <minimum>0.80</minimum>
                                   </limit>
                               </limits>
                           </rule>
                       </rules>
                   </configuration>
               </execution>
           </executions>
       </plugin>
   </plugins>
</build>
```

### # private repository (nexus)

#### # settings.xml

```xml
<settings>
   <servers>
       <server>
           <id>nexus-releases</id>
           <username>${env.NEXUS_USER}</username>
           <password>${env.NEXUS_PASS}</password>
       </server>
       <server>
           <id>nexus-snapshots</id>
           <username>${env.NEXUS_USER}</username>
           <password>${env.NEXUS_PASS}</password>
       </server>
   </servers>

   <mirrors>
       <mirror>
           <id>nexus</id>
           <mirrorOf>*</mirrorOf>
           <url>https://nexus.company.com/repository/maven-public/</url>
       </mirror>
   </mirrors>
</settings>
```

#### # deploy to nexus

```xml
<distributionManagement>
   <repository>
       <id>nexus-releases</id>
       <url>https://nexus.company.com/repository/maven-releases/</url>
   </repository>
   <snapshotRepository>
       <id>nexus-snapshots</id>
       <url>https://nexus.company.com/repository/maven-snapshots/</url>
   </snapshotRepository>
</distributionManagement>
```

```bash
./mvnw deploy -s settings.xml
```

### # resource filtering

```xml
<build>
   <resources>
       <resource>
           <directory>src/main/resources</directory>
           <filtering>true</filtering> <!-- replace ${...} placeholders -->
           <includes>
               <include>application.yml</include>
           </includes>
       </resource>
       <resource>
           <directory>src/main/resources</directory>
           <filtering>false</filtering> <!-- don't corrupt binary files -->
           <excludes>
               <exclude>application.yml</exclude>
           </excludes>
       </resource>
   </resources>
</build>
```

### # common pitfalls

| Pitfall                                  | Problem                       | Fix                                         |
| ---------------------------------------- | ----------------------------- | ------------------------------------------- |
| Version in child when parent manages     | Overrides BOM, diverges       | Remove version from child                   |
| Missing `<type>pom</type>` on BOM import | Imports as regular dep        | Add `<type>pom</type><scope>import</scope>` |
| `compile` scope for test utilities       | Pollutes production classpath | Use `test` scope                            |
| Snapshot dependency in release           | Non-reproducible build        | Pin to release versions                     |
| Annotation processor order wrong         | Lombok + MapStruct conflict   | Lombok first, then MapStruct                |
| Missing `-am` flag                       | Module build fails (no deps)  | Use `-pl module -am`                        |
| `mvn install` without `clean`            | Stale classes in target       | Always `clean install`                      |

### # quick reference

```bash
# Common workflows
./mvnw clean package -Pdev              # Build for dev
./mvnw clean package -Pprod             # Build WAR for production
./mvnw clean verify -s settings.xml     # Build + coverage check
./mvnw clean install -pl core -am       # Build core + its deps
./mvnw dependency:tree                  # Show dep tree
./mvnw versions:display-dependency-updates  # Check for updates
./mvnw spring-boot:run                  # Run locally
./mvnw test -Dtest=UserServiceTest      # Run specific test class
./mvnw test -Dtest="UserServiceTest#testCreate"  # Run specific method
```

> Chỉ là những ghi chép cá nhân với hy vọng mang lại chút giá trị. Nếu thấy hữu ích, đừng ngại chia sẻ cho bạn bè & đồng nghiệp nhé!

Happy coding <Twemoji emoji="clinking-beer-mugs" /> 😎 👍🏻 🚀 🔥.
