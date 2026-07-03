---
layout: post
title: "lombok - giúp code java nhanh hơn 69.69%"
date: 2023-11-29 19:29:39 +0700
categories: [Software Development]
tags: [advanced, java, lombok, software-development, vietnamese]
---

### # lombok?

**Lombok** là một thư viện, một plugin, giúp chúng ta giảm thiểu các đoạn code thừa (boilerplate) bằng cách tự động sinh ra các hàm `Get`, `Set`, `Constructor`, v.v..

Chắc hẳn ai là `Java Developer` chinh chiến nhiều năm thì đều ngán ngẩm với việc ngồi viết những hàm `Get/Set`, Các `Constructor` có tham số lặp đi lặp lại, mặc dù các IDE đều hỗ trợ Generate tự động, tuy nhiên khi Project lớn, việc quản lý hàng chục function như vậy trông rất rối mắt và thừa thãi.

Từ đây, vị cứu tinh của chúng ta, `**Lombok**` ra đời :3 Với tiêu chí giúp developer tập trung vào tầng nghiệp vụ và logic thay vì mất thời gian làm những việc "thừa thãi". Không những làm cho code sáng sửa mà còn trông rất hợp lý, dễ quản lý hơn (Per con ông phệch). Sức mạnh của **Lombok** không chỉ dừng ở việc `Get/Set` mà còn nhiều khả năng tuyệt vời khác nữa, mình cũng tìm hiểu ở dưới nhé.

### # cài đặt

Để sử dụng được `Lombok` bạn cần có 2 điều kiện sau:

- Thư viện `lombok` trong project của bạn
- IDE cao cấp, hỗ trợ `lombok` (IntelliJ IDEA, Eclipse, ..)

Chúng ta đi vào từng phần:

#### # bước 1

Cách nhanh nhất để đưa 1 lib java vào project của bạn là sử dụng Maven, hoặc Gradle :3

_Maven_

```java
<!-- https://mvnrepository.com/artifact/org.projectlombok/lombok -->
<dependency>
    <groupId>org.projectlombok</groupId>
    <artifactId>lombok</artifactId>
    <version>1.18.4</version>
    <scope>provided</scope>
</dependency>
```

_Gradle_

```Java
// https://mvnrepository.com/artifact/org.projectlombok/lombok
provided group: 'org.projectlombok', name: 'lombok', version: '1.18.4'
```

Nếu bạn chưa biết `Maven` hay `Gradle` là gì thì xem [tại đây][link-maven] nhé

#### # bước 2

#### # góc giải thích nhẹ (bạn có thể bỏ qua và xuống phần cài đặt luôn)

Bạn cần cài `Lombok plugin` cho IDE của bạn, vì sao?

Bạn hiểu là IDE chỉ nhìn thấy những dòng code của bạn hiện tại, và từ đó tham chiếu tới nó, bây giờ bạn không viết hàm `Get/Set` nữa, thì nó không nhìn thấy, và điều gì sẽ xảy ra nếu bạn viết `user.getName()` trong khi function `getName()` không hề tồn tại :v oh siệc man. Thông báo lỗi `đỏ lè`.

Bản thân `Lombok` là một thư viện, nó sẽ tự động thêm `Get/Set` khi project của bạn được `build`. Tức tự viết thêm code vào class đó trước khi nó thành file `jar`.

Nên để IDE hiểu rằng class `User` đã có các hàm `Get/ Set/ Constructor` này rồi, hiển thị nó cho tao, thì bạn phải cài `Lombok Plugin`

#### # cài đặt lombok cho intellij idea

Mình sử dụng `IntelliJ IDEA` nha mọi người, `Eclipse` cũng tương tự nhé (khác mỗi chỗ cài đặt :") )

Các bạn vào `File` > `Setting` > `Plugins` ..

Search: "Lombok"

Chọn `Lombok Plugin` và nhấn `Install`

Chớ quên `Apply` nhé!

Tadaaa, Chưa xong đâu ==! nếu là **lần đầu**, bạn sẽ phải làm thêm 2 bước này nữa.

Restart IDE > `File` > `Setting` > `Other Setting` > `Lombok Plugin` > `Enable Lombok plugin for this project` > `Apply`

`File` > `Setting` > `Build, Execution, Deployment` > `Complier` > `Annotation Processors` > `Apply`

Rồi, chính thức là xong! Bây giờ project của bạn đã có `Lombok`

### # sử dụng lombok

`Lombok` dùng `Annotation` để khai báo với trình biên dịch.

#### # @data

Nhìn lại vào ví dụ đầu tiên, 2 đoạn code này là tương đương.

`@Data` sẽ có tác dụng generate ra `Constructor` rỗng hoặc có tham số theo yêu cầu (cái này sẽ nói sau), toàn bộ `Get/Set`, hàm `equals`, `hashCode`, `toString()`

Khi bạn đã đánh dấu 1 class là `@Data`, thì tại bất cứ đâu trong project. Khi sử dụng tới class này, nó sẽ tự có các function đã generate mà không cần code thêm bất kì dòng nào:

#### # constructor với **inline_code_placeholder_55**, **inline_code_placeholder_56**, **inline_code_placeholder_57**

Trong trường hợp bạn muốn định nghĩa các `Constructor` theo ý mình, thì `Lombok` hỗ trợ 3 `Annotation`:

- `@NoArgsConstructor`: Hàm khởi tạo rỗng, đã đề cập ở trên
- `@AllArgsConstructor`: Hàm khởi tạo chứa tất cả thuộc tính, ví dụ `Champion(String name, String type)`
- `@RequiredArgsConstructor`: Hàm khởi tạo theo yêu cầu. Bạn chỉ muốn hàm khởi tạo có vài thuộc tính do bạn chọn thôi, thì bạn thêm `final` trước thuộc tính trong class, nó sẽ tự sinh ra `Constructor` như thế.

```java
@RequiredArgsConstructor
public class Champion {
  private final String name;
  private String type;
//  @RequiredArgsConstructor + final đồng nghĩa với Constructor như thế này.
//  public Champion(String name) {
//    this.name = name;
//  }
}
```

`@RequiredArgsConstructor` là một vũ khí cực kì, cực kì lợi hại nhé :3 Sau này khi tới các bài về `Spring` và nâng cao hơn, mình sẽ cho các bạn thấy tác dụng kì riệu của e nó :3

#### # @getter/@setter

Khi bạn chỉ muốn generate mỗi `Get/Set` thôi và không muốn dùng `@Data` vì nó quá nhiều chức năng, thì có thể xài 2 câu thần chú `@Getter` và `@Setter`

```java
@Getter
@Setter
public class Champion {
  private String name;
  private String type;
}
```

Nâng cao hơn, bạn chỉ muốn xài `Get/Set` cho 1 thuộc tính thì sao? thì như này nè :3

```java
public class Champion {
  // Tạo ra get/set cho name
  @Getter @Setter private String name;
  // Tạo ra protected setType(String) thay vì public
  @Setter(AccessLevel.PROTECTED) private String type;
}
```

#### # @ToString và @EqualsAndHashCode

Nhìn tên các bạn cũng đoán ra phải không, để tý thì đây đều là các chức năng riêng rẽ mà đã được `@Data` gom lại thành 1.

- `@ToString`: Tạo ra hàm `toString()` từ thuộc tính class.
- `@EqualsAndHashCode`: Tạo ra hàm `equals` và `hashCode`

Cái này ví dụ ở đầu bài viết mình đã chỉ ra rồi, phần này có một vấn đề thôi, là nếu bạn không muốn làm `toString` hay `equals` **KHÔNG** tác động tới 1 thuộc tính nào đó, thì làm như nào?

Lúc này chúng ta sẽ dùng tới `Exclude`

```java
@ToString
public class Champion {
  private String name;
  @ToString.Exclude private String type;
  // Thuộc tính type đã bị bỏ qua
//  @Override
//  public String toString() {
//    return "Champion{" + "name='" + name + '\'' + '}';
//  }
}
```

#### # @builder

Chắc hẳn ai cũng ngại khi viết 1 class `Builder` cổ điển phải không, tự dưng phải tạo thêm 1 class nữa, gấp đôi số lượng thuộc tính khai báo, gấp đôi số hàm cần viết huhu. :"((

Và một lần nữa, vị cứu tinh `Lombok` lại đến và lau đi nước mắt của `tungdadev` với `@Builder`. Đây là một chức năng đặc biệt dành cho người lười biếng (như mình).

Put

```
@Data
@Builder
public class Champion {
  private String name;
  private String type;
}
```

Then

```java
Champion tungdadev = Champion.builder()
        .name("tungdadev")
        .type("Support")
        .build();
```

### # lời kết

Cảm ơn chúa, cảm ơn `Reinier Zwitserloot` và cộng đồng mã nguồn mở đã cứu rỗi lấy linh hồn của những thánh lười như `tungdadev` :3

`Lombok` còn rất nhiều tính năng hay ho, mình đã giới thiệu các phần thông dụng nhất mà project nào cũng sẽ cần đến và cách sử dụng nó, khi tới các bài viết về các `framework` của `Java`, mình sẽ đề cập thêm các yếu tố nâng cao hơn của nó. Còn bạn nào muốn tìm hiểu thêm thì hãy vào [trang chủ][lombok] của `Lombok`.

> Chỉ là những ghi chép cá nhân với hy vọng mang lại chút giá trị. Nếu thấy hữu ích, đừng ngại chia sẻ cho bạn bè & đồng nghiệp nhé!

Happy coding <Twemoji emoji="clinking-beer-mugs" /> 😎 👍🏻 🚀 🔥.
