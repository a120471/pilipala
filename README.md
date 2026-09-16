# PiliPala (非线性视频缩放 Fork 版本)

> **关于本分支**：
> 本仓库基于原版 [PiliPala](https://github.com/guozhigq/pilipala) 进行定制与增强，核心引入了**「视频自适应非线性边缘压缩算法」**与全新的**「双指缩放与平移手势交互体系」**。致力于解决手机宽屏/全面屏播放不同比例视频时的大黑边与画面裁切矛盾，实现**在消除黑边的同时，100% 完整保留画面内容不被裁切**。

### 📺 演示视频与功能介绍
- **Bilibili 演示视频**：[https://www.bilibili.com/video/BV1kKbs6jEUk](https://www.bilibili.com/video/BV1kKbs6jEUk)
- **视频简介**：该视频为本 Fork 仓库专门制作的特性演示与使用指南，直观展示了自适应非线性边缘压缩效果（包括样条平滑、双曲正切等多种算法策略切换对比）、双指动态焦点平移缩放手势、迟滞防抖状态机效果，以及刘海/挖孔屏全面屏沉浸适配效果。

### 🚀 Fork 核心功能特性总结 (`commit 3413280`)

1. **播放器自适应非线性边缘压缩算法**
   - **中心 1:1 保真与边缘平滑压缩**：中心区域（默认 60%）保持原始比例等比无畸变渲染，仅对画面四边溢出区域进行非线性渐进平滑压缩；在大幅减少/消除黑边的同时，保证 **100% 画面内容不被裁切**。
   - **5 种算法策略自由切换**：内置分段样条平滑（Piecewise Spline，默认推荐）、双曲正切（Tanh）、正弦拉伸（Sine）、幂函数强力压缩（Power）及等比线性对照组（Linear），满足多样化的观影习惯。
   - **GPU 着色器硬件加速**：引入 Flutter FragmentShader（片段着色器 `video_edge_compress.frag`）以及 MPV GLSL 用户着色器，通过底层 GPU 实现像素级精确映射与低功耗流畅渲染。

2. **双指手势体系与交互体验重构**
   - **动态焦点缩放与平移**：支持双指自由缩放与平移拖动，缩放中心动态锚定双指聚焦点，操作随手自然。
   - **迟滞阈值防抖机制**：引入双向迟滞阈值状态机，实现平移与缩放操作互斥，彻底消除手势触摸与释放过程中的画面微抖与比例频闪。
   - **常驻快捷胶囊控件**：播放界面常驻显示当前缩放倍率及一键复位胶囊按钮，并支持点击/长按快捷呼出算法策略切换面板。
   - **大倍率平滑回退**：缩放倍率大于 1.5x 时自动平滑回退为传统等比局部细节放大，兼顾细节查看需求。

3. **几何视口引擎与渲染架构优化**
   - **独立四边界几何模型**：抽象建立 `VideoCanvasRect`（物理视口）与 `VideoViewRect`（画面几何体）模型，上下左右四边界独立计算溢出因子，仅单侧超出时仅对单侧压缩，未超出边界保持零畸变原生呈现。
   - **渲染管线深度协调**：精确配合 Flutter Transform 与底层着色器，消除外层 ClipRect 对边缘压缩内容的物理截断。

4. **全面屏与挖孔/刘海屏沉浸适配**
   - Android 原生层适配 `LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES`。
   - 播放设置中新增「全屏扩展至挖孔/刘海区域」持久化配置开关，充分利用现代全面屏显示区域。

5. **工程质量与自动化测试**
   - 新增 `canvas_view_containment_test`、`video_render_transform_test`、`video_scale_strategy_test` 等 52 个单元测试用例，覆盖多种屏幕/视频比例与手势边界场景。

---

<div align="center">
    <img width="200" height="200" src="https://github.com/guozhigq/pilipala/blob/main/assets/images/logo/logo_android.png">
</div>

<div align="center">
    <h1>PiliPala</h1>
<div align="center">
    
![GitHub repo size](https://img.shields.io/github/repo-size/guozhigq/pilipala) 
![GitHub Repo stars](https://img.shields.io/github/stars/guozhigq/pilipala) 
![GitHub all releases](https://img.shields.io/github/downloads/guozhigq/pilipala/total) 

</div>
    <p>使用 Flutter 开发的 BiliBili 第三方客户端</p>
    
<img src="https://github.com/guozhigq/pilipala/blob/main/assets/screenshots/510shots_so.png" width="32%" alt="home" />
<img src="https://github.com/guozhigq/pilipala/blob/main/assets/screenshots/174shots_so.png" width="32%" alt="home" />
<img src="https://github.com/guozhigq/pilipala/blob/main/assets/screenshots/850shots_so.png" width="32%" alt="home" />
<br/>
<img src="https://github.com/guozhigq/pilipala/blob/main/assets/screenshots/main_screen.png" width="96%" alt="home" />
<br/>
</div>

## 开发环境

Xcode 13.4 不支持 ```auto_orientation```，请注释相关代码

```bash
[✓] Flutter (Channel stable, 3.19.6, on macOS 14.1.2 23B92 darwin-arm64, locale
    zh-Hans-CN)
[✓] Android toolchain - develop for Android devices (Android SDK version 34.0.0)
[✓] Xcode - develop for iOS and macOS (Xcode 15.1)
[✓] Chrome - develop for the web
[✓] Android Studio (version 2022.3)
[✓] VS Code (version 1.87.2)
[✓] Connected device (3 available)
[✓] Network resources
```

## 技术交流

Telegram: [https://t.me/+1DFtqS6usUM5MDNl](https://t.me/+1DFtqS6usUM5MDNl)

Telegram Beta 版本：@PiliPala_Beta

QQ 频道: https://pd.qq.com/s/365esodk3

## 功能

目前着重移动端 (Android、iOS)，暂时没有适配桌面端、Pad 端、手表端等

现有功能及[开发计划](https://github.com/users/guozhigq/projects/5)

- [x] 推荐视频列表 (app 端)
- [x] 最热视频列表
- [x] 热门直播
- [x] 番剧列表
- [x] 屏蔽黑名单内用户视频
- [x] 排行榜

- [x] 用户相关
  - [x] 粉丝、关注用户、拉黑用户查看
  - [x] 用户主页查看
  - [x] 关注/取关用户
  - [ ] 离线缓存
  - [x] 稍后再看
  - [x] 观看记录
  - [x] 我的收藏
  - [x] 黑名单管理 
  
- [x] 动态相关
  - [x] 全部、投稿、番剧分类查看
  - [x] 动态评论查看
  - [x] 动态评论回复功能
  - [x] 动态未读标记 

- [x] 视频播放相关
  - [x] 双击快进/快退
  - [x] 双击播放/暂停
  - [x] 垂直方向调节亮度/音量
  - [x] 垂直方向上滑全屏、下滑退出全屏
  - [x] 水平方向手势快进/快退
  - [x] 全屏方向设置
  - [x] 倍速选择/长按 2 倍速
  - [x] 硬件加速 (视机型而定)
  - [x] 画质选择 (高清画质未解锁)
  - [x] 音质选择 (视视频而定)
  - [x] 解码格式选择 (视视频而定)
  - [x] 弹幕
  - [x] 字幕
  - [x] 记忆播放
  - [x] 视频比例：高度/宽度适应、填充、包含等
  - [x] 视频快照
  - [x] 直播弹幕
     
- [x] 搜索相关
  - [x] 热搜
  - [x] 搜索历史
  - [x] 默认搜索词
  - [x] 投稿、番剧、直播间、用户搜索
  - [x] 视频搜索排序、按时长筛选
    
- [x] 视频详情页相关
  - [x] 视频选集 (分 p) 切换
  - [x] 点赞、投币、收藏/取消收藏
  - [x] 相关视频查看
  - [x] 评论用户身份标识
  - [x] 评论 (排序) 查看、二楼评论查看
  - [x] 主楼、二楼评论/表情回复功能
  - [x] 评论点赞
  - [x] 评论笔记图片查看、保存

- [x] 设置相关
  - [x] 画质、音质、解码方式预设      
  - [x] 图片质量设定
  - [x] 主题模式：亮色/暗色/跟随系统
  - [x] 震动反馈 (可选)
  - [x] 高帧率
  - [x] 自动全屏
- [ ] 等等

## 下载

可以通过右侧 Releases 进行下载或拉取代码到本地进行编译

### 从 F-Droid 安装

<a href="https://f-droid.org/packages/com.guozhigq.pilipala">
    <img src="https://fdroid.gitlab.io/artwork/badge/get-it-on-zh-cn.png"
    alt="Get it on F-Droid"
    height="80">
</a>

## 声明

此项目 (PiliPala) 是个人为了兴趣而开发, 仅用于学习和测试。
所用 API 皆从官方网站收集, 不提供任何破解内容。

感谢使用

## 致谢

- [bilibili-API-collect](https://github.com/SocialSisterYi/bilibili-API-collect)
- [flutter_meedu_videoplayer](https://github.com/zezo357/flutter_meedu_videoplayer)
- [media-kit](https://github.com/media-kit/media-kit)
- [dio](https://pub.dev/packages/dio)
- 等等
