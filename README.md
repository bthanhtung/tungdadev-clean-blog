# TungDaDev Clean Blog

Đây là mã nguồn blog cá nhân của TungDaDev, được xây dựng dựa trên [Jekyll](https://jekyllrb.com/) và giao diện Clean Blog tối giản.

## 🚀 Khởi chạy dự án (Sử dụng Docker)

Bạn không cần cài đặt Ruby hay Jekyll vào máy thật. Tất cả đã được đóng gói trong Docker.

### Cách 1: Chạy trực tiếp (Dùng cho Development - Hỗ trợ Hot Reload)
Dùng lệnh sau để chạy và tự động cập nhật khi bạn sửa file:

```bash
docker run --rm -v "$PWD:/srv/jekyll" -p 4000:4000 jekyll/builder:latest bash -c "bundle config set path 'vendor/bundle' && bundle install && bundle exec jekyll serve --host 0.0.0.0"
```

### Cách 2: Build Image bằng Dockerfile (Dùng cho Production)
```bash
# Build image
docker build -t tungdadev-blog .

# Chạy container
docker run --rm -p 4000:4000 tungdadev-blog
```

Sau khi chạy xong, truy cập vào trang web tại: [http://localhost:4000](http://localhost:4000)

---

## 📝 Cách viết bài mới

Tất cả các bài viết được đặt trong thư mục `_posts`.
Để tạo một bài viết mới, bạn tạo một file Markdown (`.md` hoặc `.markdown`) theo định dạng tên:
`YYYY-MM-DD-ten-bai-viet.markdown` (Ví dụ: `2024-10-01-bai-viet-moi.markdown`).

Cấu trúc đầu file (Front Matter) bắt buộc phải có:

```yaml
---
layout: post
title: "Tiêu đề bài viết"
date: 2024-10-01 19:29:39 +0700
categories: [Software Development]
tags: [Java, Backend]
---

Nội dung bài viết bắt đầu từ đây...
```

---

## 💬 Hệ thống bình luận (Giscus)
Blog sử dụng hệ thống bình luận **Giscus** (dựa trên Github Discussions).
Cấu hình nằm trong file `_config.yml` ở phần `giscus:`.

Để thay đổi thông tin Giscus cho repo của bạn:
1. Vào mục Settings của Repository trên Github, bật chức năng **Discussions**.
2. Truy cập [giscus.app](https://giscus.app/vi) để cấp quyền và lấy `repo-id`, `category-id`.
3. Thay thế các thông số tương ứng trong `_config.yml`.
