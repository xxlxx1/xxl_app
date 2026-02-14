# xxl_app - 照片日历

一款 iOS 照片日历应用，将系统相册中的照片按日期自动排列到日历格子中，直观回顾每一天的拍摄记录。

## 功能

### 月历视图
- 以周一为每周起始日，展示选定月份的日历网格
- 每天自动从系统相册中随机选取一张照片作为缩略图
- 滚轮选择年份（2000–2030）和月份，带防抖优化

### 年历视图
- 一页纵览全年 12 个月的缩略日历
- 点击月份标题可跳转到对应月历视图

### 照片查看
- 点击缩略图全屏查看原图
- 支持双指缩放（1x–5x）和拖动平移
- 双击快速切换 3x 放大 / 还原
- 支持从系统相册中删除当前照片

### 拍摄地点
- 自动识别当月照片的 GPS 信息，反向地理编码获取城市名
- 逐个实时展示识别结果，保持列表顺序稳定
- 地理编码支持 Apple CLGeocoder、BigDataCloud、OpenStreetMap Nominatim 三重回退

### 导出保存
- 将当月日历（含照片缩略图和拍摄地点）渲染为高清图片
- 一键保存到系统相册

## 技术栈

- **语言**: Swift 5
- **UI**: SwiftUI
- **最低系统版本**: iOS 17.0
- **主要框架**: Photos / PhotosUI / CoreLocation / MapKit / Combine / SwiftData

## 项目结构

```
xxl_app/
├── xxl_appApp.swift          # App 入口
├── CalendarPhotoView.swift   # 主视图（月历/年历切换、滚轮选择器、导出）
├── CalendarGridView.swift    # 月历网格布局
├── YearlyCalendarView.swift  # 年历网格布局
├── DayPhotoView.swift        # 日期格子（缩略图展示）
├── PhotoAlbumManager.swift   # 核心管理器（照片加载、地理编码）
├── ContentView.swift         # 系统相册选择器视图
└── Item.swift                # SwiftData 数据模型
```

## 权限说明

| 权限 | 用途 |
|------|------|
| 相册访问 | 读取照片及 GPS 信息，保存导出图片 |
| 网络访问 | iCloud 照片加载、地理编码 API 调用 |

## 构建与运行

1. 使用 Xcode 15+ 打开 `xxl_app/xxl_app.xcodeproj`
2. 选择目标设备（iPhone / iPad），最低 iOS 17.0
3. Build & Run
