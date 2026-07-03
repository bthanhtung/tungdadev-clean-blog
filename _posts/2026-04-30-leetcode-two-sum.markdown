---
layout: post
title: "leetcode - two sum"
date: 2026-04-30 19:29:39 +0700
categories: [Software Development]
tags: [java, software-development, leet-code, upskill, vietnamese]
---

### # đề bài & tổng quan

Bài toán Two Sum yêu cầu tìm hai số trong một mảng sao cho tổng của chúng bằng một số mục tiêu (target). Bạn cần trả về chỉ số của hai số đó.

_Ví dụ_:

```
Đầu vào: nums = [2, 7, 11, 15], target = 9
Đầu ra: [0, 1]
Trong đó:: nums[0] + nums[1] = 2 + 7 = 9.
```

Để giải bài toán này, ta có thể sử dụng các phương pháp sau:

- Duyệt Brute-Force (O(n²)): Duyệt qua mọi cặp phần tử trong mảng và kiểm tra xem chúng có tạo ra tổng bằng target không.
- Sử dụng HashMap (O(n)): Dùng một HashMap để lưu trữ các giá trị đã duyệt, nhằm giảm độ phức tạp xuống còn O(n).
- Sắp xếp và sử dụng hai con trỏ (O(nlogn)): Sắp xếp mảng rồi sử dụng hai con trỏ (left và right) để tìm cặp số phù hợp.

### # code demo

_Giải pháp 1_: **Brute-Force**

```java
public int[] twoSum(int[] nums, int target) {
    for (int i = 0; i < nums.length; i++) {
        for (int j = i + 1; j < nums.length; j++) {
            if (nums[i] + nums[j] == target) {
                return new int[]{i, j};
            }
        }
    }
    throw new IllegalArgumentException("Không có cặp số nào thỏa mãn!");
}
```

Trong đó:

- Duyệt qua từng cặp (i, j) trong mảng.
- Kiểm tra tổng của hai phần tử nums[i] và nums[j].
- Nếu tìm thấy cặp phù hợp, trả về chỉ số của chúng.

Độ phức tạp:

- Thời gian: O(n²)
- Không gian: O(1)

_Giải pháp 2_: **Sử dụng HashMap**

```java
import java.util.HashMap;

public int[] twoSum(int[] nums, int target) {
    HashMap<Integer, Integer> map = new HashMap<>();
    for (int i = 0; i < nums.length; i++) {
        int complement = target - nums[i];
        if (map.containsKey(complement)) {
            return new int[]{map.get(complement), i};
        }
        map.put(nums[i], i);
    }
    throw new IllegalArgumentException("Không có cặp số nào thỏa mãn!");
}
```

Trong đó:

- HashMap được sử dụng để lưu trữ các số đã duyệt cùng với chỉ số của chúng.
- Với mỗi số nums[i], tính toán giá trị bù (complement = target - nums[i]).
- Nếu giá trị bù đã tồn tại trong HashMap, ta đã tìm được cặp số.
- Nếu không, thêm nums[i] vào HashMap.

Độ phức tạp:

- Thời gian: O(n)
- Không gian: O(n)

_Giải pháp 3_: **Hai Con Trỏ**

```java
import java.util.Arrays;

public int[] twoSumTwoPointer(int[] nums, int target) {
    int[][] numsWithIndices = new int[nums.length][2];
    for (int i = 0; i < nums.length; i++) {
        numsWithIndices[i][0] = nums[i];
        numsWithIndices[i][1] = i;
    }
    Arrays.sort(numsWithIndices, (a, b) -> Integer.compare(a[0], b[0]));

    int left = 0, right = nums.length - 1;
    while (left < right) {
        int sum = numsWithIndices[left][0] + numsWithIndices[right][0];
        if (sum == target) {
            return new int[]{numsWithIndices[left][1], numsWithIndices[right][1]};
        } else if (sum < target) {
            left++;
        } else {
            right--;
        }
    }
    throw new IllegalArgumentException("Không có cặp số nào thỏa mãn!");
}
```

Trong đó:

- Sắp xếp mảng cùng với chỉ số ban đầu.
- Sử dụng hai con trỏ left và right.
- Nếu tổng của hai số lớn hơn target, giảm right. Nếu nhỏ hơn, tăng left.

Độ phức tạp:

- Thời gian: O(n log n)
- Không gian: O(n)

So sánh các giải pháp
| Phương pháp | Thời gian | Không gian | Ghi chú |
|---------------------|-------------|--------------|----------------------------------------------|
| Duyệt Brute-Force | O(n²) | O(1) | Dễ cài đặt, nhưng chậm với mảng lớn |
| HashMap | O(n) | O(n) | Nhanh và tối ưu nhất cho mảng không sắp xếp |
| Hai Con Trỏ | O(n log n) | O(n) | Chỉ áp dụng nếu cần chỉ số gốc hoặc mảng sắp xếp |

### # lời kết

Bài toán Two Sum là một bài toán cơ bản trong lập trình, đặc biệt hữu ích để luyện tư duy tối ưu hóa. Tùy vào yêu cầu cụ thể, bạn có thể lựa chọn giải pháp phù hợp.

Nếu ưu tiên tốc độ, sử dụng HashMap.
Nếu cần chỉ số gốc trong một mảng đã sắp xếp, dùng phương pháp hai con trỏ.
Nếu mới làm quen với thuật toán, phương pháp Brute-Force là khởi đầu tốt.
Bạn đã thử giải bài toán này theo cách nào? Chia sẻ ý kiến trong phần bình luận nhé! 😊

> Chỉ là những ghi chép cá nhân với hy vọng mang lại chút giá trị. Nếu thấy hữu ích, đừng ngại chia sẻ cho bạn bè & đồng nghiệp nhé!

Happy coding <Twemoji emoji="clinking-beer-mugs" /> 😎 👍🏻 🚀 🔥.

**Reference**:

- [**Two Sum**](https://leetcode.com/problems/two-sum/description/)
