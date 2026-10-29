# BrothCalm 内容生产与质量政策

## 适用范围
BrothCalm 面向英语国家普通读者。英文页面为独立原创主页面，中文页面是自然编辑改写；不得中英混写。品牌名统一为 BrothCalm，不使用 SymptomCalm 后缀。

## 文章类型与长度
| 类型 | 推荐英文词数 | 硬性英文范围 | 推荐中文字符 | 硬性中文范围 |
|---|---:|---:|---:|---:|
| ingredient | 900–1,600 | 700–2,000 | 1,200–2,200 | 900–2,800 |
| tea | 1,000–1,800 | 800–2,200 | 1,300–2,400 | 1,000–3,000 |
| recipe | 700–1,400 | 600–1,800 | 1,000–2,000 | 800–2,500 |
| food-therapy / symptom | 1,400–2,500 | 1,000–3,000 | 1,800–3,200 | 1,400–4,000 |
| theory / other | 1,200–2,200 | 900–2,600 | 1,500–2,800 | 1,100–3,400 |

超出推荐范围不自动判错，但超过硬性范围不得进入普通 pending。

## 固定质量模块与自由主体
所有页面必须有 Quick answer、传统 TCM 背景及边界、现代营养/证据说明、实际用法、安全边界、来源和教育免责声明。主体 H2 可按文章意图自由设计。症状类必须有证据局限、Practical Takeaways（或 How to Try It）和 When to Seek Professional Care（或 When to See a Doctor）。食谱不强制 Research 标题，改用 Nutrition note 即可。

## 类比
推荐一个贯穿全文的主类比，可有 0–2 个辅助类比；每个类比说明“这只是解释工具，不等同于现代解剖/生理事实”。

## 来源
ingredient/recipe 至少 2 个可靠且相关来源；tea 至少 2 个；food-therapy/symptom 至少 3 个，其中至少一个政府、医院、大学、WHO、NIH、NHS、CDC、PubMed 或系统综述来源。来源必须位于 Sources/参考资料段落，不能把 canonical、导航或社交链接当来源。URL 必须可访问，生成器不得凭空编造。

## 合规
禁止未经证实的 cure/treat/heal/prevent/detox/guaranteed 等疗效承诺、替代医疗、停药、改变药物剂量、虚假 testimonials 和贬低西医。免责声明、研究原文标题、疗法名称或否定式安全说明可保留这些词；验证器按语境判断，不做全文关键词误杀。

## 高风险
孕期/哺乳、儿童、慢性病、肝肾病、糖尿病、高血压、抗凝药/药物相互作用、手术、癫痫、浓缩草药/补充剂进入 pending-review，不进入普通自动发布队列。页面必须给出具体 professional-care boundary。

## 差异化
队列项目必须携带 primary_intent、audience、angle、related_cluster、avoid_overlap_with。每个主题簇 30 天内最多发布 2–3 篇；达到 3 篇后暂停该簇，改选其他真实搜索需求。生成前读取同集群页面标题和 H2；普通文章主体 H2 重叠率目标 <30%，专题文章 <20%，共享 Safety/Sources/FAQ 等通用模块不计入。相似度或 H2 重叠过高时改写角度或进入 review。

## SEO/GEO 内容策略
每次内容生产前先刷新 `.cron/.seo-keyword-research.json`。研究美国、英国、加拿大、澳大利亚的英文搜索问题、季节需求、比较词和近期趋势；趋势必须有日期和真实来源 URL，不得编造搜索量。关键词分为 evergreen、seasonal、trend signals，优先长尾问题和可服务的搜索意图。每个集群必须直接服务 BrothCalm 的主题：食材、茶饮、汤方、食谱、饮食选择、烹饪准备或中医食疗理论。若热点只有宽泛 wellness、疾病、药物、补充剂、减重、美容、健身或生活方式关联，则拒绝，不为流量偏离站点主题。

每篇新文使用 1 个 primary keyword、3–6 个 secondary keywords、2–4 个真实 question variants 和 1 个明确 angle。Primary keyword 在标题、前 120 词、一个自然 H2 和 meta description 中出现（语法自然时），禁止堆砌同义词。热点词必须通过“去掉热点词后仍然是有用的 BrothCalm 食物内容”测试；只能转化为低风险的食材比较、做法、文化解释或营养边界文章，不能为了热度制造疾病、减重、补充剂或药物承诺。

GEO 友好内容应在开头直接回答问题，解释 TCM 术语，使用清晰 H2、列表、表格、定义、条件式答案和可独立引用的短段落；同时给出来源、证据局限和安全边界。关键词研究报告本身是运行时文件，不发布到网站。

## SEO/HTML
`<title>` 与 `og:title` 由同一标题逐字生成，统一包含 `| BrothCalm`；description 包含主题关键词且不超过 155 字符；保留 FAQ 占位符交给后处理；canonical、hreflang、sitemap、内链和 Schema 必须通过审计。OG 使用真实 JPG，缺图使用 `/images/default-og.jpg`，禁止伪造文章图 URL。



## 发布门禁
生成 → 语境合规/长度/结构/来源/Schema/URL/重复检查 → 普通 pending 或 pending-review → 每天只发布 1 个完整 EN/ZH pair → 每周一次只读集中审计。只有发现真实问题才修改页面；不重复刷新全部页面，不批量更新无变化页面的 lastmod。所有规则必须是幂等脚本，不能只修改一次 HTML。
