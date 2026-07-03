---
layout: post
title: "List, ArrayList & LinkedList trong Java"
date: 2023-12-21 19:29:39 +0700
categories: [Software Development]
tags: [software-development, java, list, linked-list, array-list]
---

Trong Java, `List` là một _interface_ thuộc bộ thư viện **Java Collections Framework**, cung cấp các phương thức để thao tác với danh sách các phần tử.
Hai trong số các lớp triển khai phổ biến nhất của `List` là `ArrayList` và `LinkedList`. Cả hai đều có những điểm mạnh, yếu khác nhau và thích hợp cho các tình huống khác nhau.

Trong bài viết này, chúng ta sẽ so sánh các điểm khác biệt, ưu nhược điểm và cách sử dụng `List`, `ArrayList` và `LinkedList`.

### # tổng quan

`List` đại diện cho một tập hợp các phần tử có thứ tự, trong đó cho phép các phần tử bị trùng lặp. Một vài phương thức quan trọng mà `List` cung cấp bao gồm:

- `add()`: Thêm phần tử vào danh sách.
- `get()`: Lấy phần tử tại vị trí chỉ định.
- `remove()`: Xóa phần tử khỏi danh sách.
- `size()`: Lấy kích thước của danh sách.

Vì `List` là một interface, để sử dụng nó, chúng ta cần sử dụng các lớp triển khai như `ArrayList` hoặc `LinkedList`.

### # arrayList

`ArrayList` là một lớp triển khai của `List`, sử dụng một **mảng động** để lưu trữ các phần tử. Mảng trong `ArrayList` có khả năng tự động thay đổi kích thước khi cần thiết.

#### # ưu điểm

- **Truy xuất ngẫu nhiên nhanh**: Nhờ sử dụng mảng, `ArrayList` cho phép truy cập phần tử qua chỉ số (**index**) rất nhanh, với BigO chỉ bằng **O(1)**.
- **Tự động tăng kích thước**: Khi mảng đầy, `ArrayList` sẽ tự động tăng gấp 1.5 lần kích thước mảng ban đầu.
- **Sử dụng bộ nhớ hiệu quả**: Khi không có quá nhiều phép thêm/xóa, `ArrayList` có xu hướng sử dụng bộ nhớ hiệu quả hơn so với `LinkedList`.

#### # nhược điểm

- **Chèn và xóa chậm**: Thao tác chèn hoặc xóa phần tử ở giữa danh sách sẽ phải dịch chuyển các phần tử khác, làm cho các thao tác này chậm hơn với `BigO = O(n)`.
- **Tốn bộ nhớ cho kích thước dư thừa**: Khi mảng tăng kích thước, `ArrayList` có thể tốn bộ nhớ không sử dụng (dư thừa), dẫn đến lãng phí tài nguyên.

#### # khi nào nên sử dụng

- Khi cần **truy cập ngẫu nhiên** các phần tử một cách nhanh chóng.
- Khi danh sách ít có sự thay đổi về số lượng phần tử (thêm/xóa) nhưng có nhiều thao tác đọc dữ liệu.

#### # ví dụ

Một ví dụ đơn giản về cách sử dụng `ArrayList` trong Java:

```java
import java.util.ArrayList;

public class ArrayListExample {
    public static void main(String[] args) {
        ArrayList<String> list = new ArrayList<>();

        // Thêm phần tử vào danh sách
        list.add("Java");
        list.add("Python");
        list.add("C++");

        // Truy cập phần tử tại chỉ số 1
        System.out.println("Phần tử tại index 1: " + list.get(1)); // Output: Python

        // Xóa phần tử tại chỉ số 2
        list.remove(2);

        // Kích thước danh sách sau khi xóa
        System.out.println("Kích thước của ArrayList: " + list.size()); // Output: 2
    }
}
```

### # LinkedList

`LinkedList` là một lớp triển khai của `List`, sử dụng cấu trúc **danh sách liên kết kép (doubly linked list)** để lưu trữ các phần tử. Mỗi phần tử trong `LinkedList` đều biết phần tử liền trước và phần tử liền sau nó.

#### # ưu điểm

- **Thêm và xóa phần tử nhanh**: Các thao tác thêm hoặc xóa phần tử ở đầu hoặc cuối danh sách rất nhanh chóng (O(1)).
- **Không bị giới hạn kích thước**: Không như `ArrayList` phải tăng kích thước mảng khi đầy, `LinkedList` có thể tự mở rộng mà không cần phải dịch chuyển các phần tử.

#### # nhược điểm

- **Truy cập chậm**: Để truy cập một phần tử bất kỳ, `LinkedList` phải duyệt qua toàn bộ danh sách từ đầu (O(n)).
- **Tốn bộ nhớ hơn**: Mỗi phần tử trong `LinkedList` cần lưu trữ cả liên kết tới phần tử trước và sau, dẫn đến tốn bộ nhớ hơn `ArrayList`.

#### # khi nào nên sử dụng

- Khi cần nhiều thao tác **thêm/xóa** các phần tử, đặc biệt là ở đầu hoặc cuối danh sách.
- Khi không cần truy cập phần tử một cách ngẫu nhiên thường xuyên.

#### # ví dụ

Một ví dụ đơn giản về cách sử dụng `LinkedList` trong Java:

```java
import java.util.LinkedList;

public class LinkedListExample {
    public static void main(String[] args) {
        LinkedList<String> list = new LinkedList<>();

        // Thêm phần tử vào danh sách
        list.add("Java");
        list.add("Python");
        list.add("C++");

        // Truy cập phần tử tại chỉ số 1
        System.out.println("Phần tử tại index 1: " + list.get(1)); // Output: Python

        // Xóa phần tử tại chỉ số 2
        list.remove(2);

        // Kích thước danh sách sau khi xóa
        System.out.println("Kích thước của LinkedList: " + list.size()); // Output: 2
    }
}
```

### # so sánh ArrayList và LinkedList

| Đặc điểm                               | ArrayList                                     | LinkedList                                      |
| -------------------------------------- | --------------------------------------------- | ----------------------------------------------- |
| **Cấu trúc**                           | Mảng động                                     | Danh sách liên kết kép                          |
| **Truy xuất**                          | Nhanh (O(1))                                  | Chậm (O(n))                                     |
| **Thêm/Xóa**                           | Chậm nếu ở giữa danh sách (O(n))              | Nhanh nếu ở đầu/cuối danh sách (O(1))           |
| **Sử dụng bộ nhớ**                     | Hiệu quả hơn với ít thao tác thêm/xóa         | Tốn bộ nhớ hơn vì lưu cả liên kết giữa các node |
| **Thao tác thêm/xóa ở giữa danh sách** | Chậm (O(n))                                   | Nhanh (O(n) cho duyệt, O(1) cho thêm/xóa)       |
| **Khi nào sử dụng**                    | Truy cập ngẫu nhiên thường xuyên, ít thêm/xóa | Thêm/xóa nhiều, ít truy cập ngẫu nhiên          |

### # trường hợp sử dụng

- **Sử dụng ArrayList** khi ứng dụng cần **truy cập phần tử** nhiều hơn là các thao tác thêm hoặc xóa. Ví dụ, khi quản lý danh sách người dùng trong một trang web, khi danh sách thay đổi không nhiều và chúng ta chủ yếu cần hiển thị hoặc tìm kiếm dữ liệu.
- **Sử dụng LinkedList** khi ứng dụng cần **thao tác thêm/xóa** các phần tử thường xuyên, như trong trường hợp xây dựng một hệ thống hàng đợi (queue) hoặc danh sách các thao tác cần hoàn tác (undo/redo), nơi việc thêm hoặc xóa ở đầu/cuối danh sách là chủ yếu.

### # lời kết

`ArrayList` và `LinkedList` là hai lớp triển khai phổ biến của interface `List`, mỗi lớp có các đặc điểm riêng biệt phù hợp với từng tình huống khác nhau. `ArrayList` thường phù hợp cho các ứng dụng cần truy cập ngẫu nhiên nhanh, trong khi `LinkedList` thích hợp hơn cho các thao tác thêm/xóa thường xuyên. Việc lựa chọn giữa chúng phụ thuộc vào yêu cầu cụ thể của ứng dụng đang phát triển.

> Chỉ là những ghi chép cá nhân với hy vọng mang lại chút giá trị. Nếu thấy hữu ích, đừng ngại chia sẻ cho bạn bè & đồng nghiệp nhé!

Happy coding <Twemoji emoji="clinking-beer-mugs" /> 😎 👍🏻 🚀 🔥.
