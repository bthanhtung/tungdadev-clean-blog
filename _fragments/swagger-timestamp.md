---
layout: fragment
title: 禁止 Swagger 文档里的 Timestamp 类型展开
tags: [java]
description: Swagger 文档里的 Timestamp 类型默认展开为 10 个字段，容易引导前端误解，如何禁止展开？
keywords: Java, Swagger, Timestamp
mermaid: false
sequence: false
flow: false
mathjax: false
mindmap: false
mindmap2: false
---

If the Model in the Swagger document has a Timestamp type field, it will be displayed like this by default:

![](/images/fragments/swagger-timestamp-default.png)

If it is expanded like this, the front-end students may easily misunderstand that this field is an object instead of a timestamp. How to prohibit expansion?

In the Swagger configuration, when building the Docket object, you can add `.directModelSubstitute(Timestamp.class, Date.class)` to specify that the Timestamp type in the document is replaced with the Date type.

For example:

```java
@Bean
public Docket api() {
    Docket docket = new Docket(DocumentationType.SWAGGER_2).apiInfo(apiInfo()).select()
        .apis(RequestHandlerSelectors.basePackage(this.basePackage))
        .paths(PathSelectors.any())
        .build()
        .enable(this.enable)
        .directModelSubstitute(Timestamp.class, Date.class)
        .securitySchemes(securitySchemes())
        .securityContexts(securityContexts())
        .useDefaultResponseMessages(false);
    log.info("[Swagger] inject swagger Docket to spring: {}", docket);
    return docket;
}
```

修改后的效果：

![](/images/fragments/swagger-timestamp-substituted.png)
