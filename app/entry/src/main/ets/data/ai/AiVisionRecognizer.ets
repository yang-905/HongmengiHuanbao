import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { image } from '@kit.ImageKit';
import { common } from '@kit.AbilityKit';
import { mindSporeLite } from '@kit.MindSporeLiteKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { Biz } from '../../ui/Theme';
import { LocalFactor, LocalRecord, MockStore } from '../MockStore';
import { AppClock } from '../../utils/AppClock';

/**
 * ImageNet 类别 → 低碳行为因子 的映射条目。
 * ------------------------------------------------------------------
 * mobilenetv2.ms（MindSpore 官方 quick_start 模型）输出 1001 维：
 * 下标 0 为背景类，业务类从 1 开始，即 ImageNet 1000 类的
 * synset 序号 + 1。下表只收录与碳因子库相关的类别。
 */
interface ClassMapEntry {
  /** 模型输出下标（synset 序号 + 1） */
  index: number;
  /** 中文展示名（写入识别依据与 remark） */
  name: string;
  /** 对应因子 code（MockStore.factorByCode 可查） */
  code: string;
}

/** 聚合后的候选因子：同一 code 的多个 ImageNet 类概率相加 */
interface CodeScore {
  code: string;
  /** 该 code 下概率最高的类中文名 */
  name: string;
  /** 聚合后的概率（softmax 求和） */
  score: number;
}

/**
 * 端侧视觉识别结果
 * ------------------------------------------------------------------
 * 与演示链路（DataSource.recognize）产出结构保持一致：
 * record 直接喂给页面，keyword / snippet 仅用于展示「识别依据」，
 * 让用户知道结论是从哪些图像类别推出来的。
 */
export interface AiVisionResult {
  /** 可直接入账的记录（recordSource 恒为 'ai'） */
  record: LocalRecord;
  /** 命中的 ImageNet 类别中文名，如「山地自行车」 */
  keyword: string;
  /** 端侧置信度 0~1（模型 softmax 聚合概率，高于演示链路） */
  confidence: number;
  /** 识别依据：Top 3 类别概率摘要，如「山地自行车 62% · 小巴 8%」 */
  snippet: string;
}

/**
 * 端侧 AI 视觉识别器（AI 拍照识别的真实引擎）
 * ------------------------------------------------------------------
 * 背景：早期「AI 拍照识别」是输入图片文件名走关键词匹配的**演示**，
 * 没有任何真实推理。本类把它换成真正的端侧 AI 链路。
 *
 * 引擎选择（SDK 24 / OpenHarmony 实测可用 API）：
 *   · runtimeOS=OpenHarmony，HMS 侧 Core Vision Kit（OCR /
 *     图像分类）**不可用**，编译期即被 ArkTS SDK 拒绝；
 *   · OpenHarmony 侧唯一可用的端侧推理框架是
 *     **MindSpore Lite（@kit.MindSporeLiteKit）**：
 *     loadModelFromBuffer → getInputs → setData → predict；
 *   · 模型采用 MindSpore 官方 quick_start 的 mobilenetv2.ms
 *     （ImageNet 1000 类，输入 [1,3,224,224] NCHW float32），
 *     官方下载地址：
 *     https://download.mindspore.cn/model_zoo/official/lite/quick_start/mobilenetv2.ms
 *
 * 完整链路：
 *   ① PhotoViewPicker 选图（免权限，不申请整个相册读取权）
 *   ② uri → PixelMap：解码限长边 640 → 放大覆盖 224 → 居中裁剪 224
 *     （与 ImageNet 训练预处理一致：scale(256) → center crop(224)）
 *   ③ 像素 → Float32Array：RGBA 逐通道归一化
 *     (x/255 - mean) / std，mean=[0.485,0.456,0.406] std=[0.229,0.224,0.225]
 *   ④ MindSpore Lite 推理 → softmax → 类别概率
 *   ⑤ ImageNet 类别 → 因子 code 映射（同 code 多类概率聚合）
 *   ⑥ 组装 LocalRecord（减排/积分口径与手动录入完全一致）
 *
 * 降级策略：模型文件缺失 / 设备无 MindSporeLite syscap / 解码失败时
 * 抛错，由页面 catch 后回退「演示词库」链路，保证任何环境可用。
 */
export class AiVisionRecognizer {
  /** 模型文件名：放置于 entry/src/main/resources/rawfile/ 下 */
  private static readonly MODEL_NAME: string = 'mobilenetv2.ms';

  /** 模型输入边长（ImageNet 标准 224） */
  private static readonly INPUT_SIZE: number = 224;

  /** 解码上限（最长边）：原图常见 4000×3000 全解码约 48MB，限制内存占用 */
  private static readonly DECODE_MAX_EDGE: number = 640;

  /** 低于该聚合概率视为「没识别出」，避免噪声类误命中 */
  private static readonly MIN_CONFIDENCE: number = 0.05;

  /** ImageNet 标准归一化参数（与训练保持一致，否则精度断崖下跌） */
  private static readonly MEAN: number[] = [0.485, 0.456, 0.406];
  private static readonly STD: number[] = [0.229, 0.224, 0.225];

  /**
   * ImageNet 类别 → 低碳行为因子 映射表。
   * 下标 = synset 序号 + 1（模型 1001 维输出的第 0 维是背景）。
   * 同一因子允许映射多个类（如各种自行车 → bike），概率聚合更稳。
   */
  private static readonly CLASS_MAP: ClassMapEntry[] = [
    // 骑行出行：各种两轮车
    { index: 672, name: '山地自行车', code: 'bike' },
    { index: 445, name: '双人自行车', code: 'bike' },
    { index: 881, name: '独轮车', code: 'bike' },
    // 公交出行
    { index: 655, name: '小巴', code: 'bus' },
    { index: 780, name: '校车', code: 'bus' },
    // 塑料回收
    { index: 738, name: '汽水瓶', code: 'plastic' },
    { index: 899, name: '水瓶', code: 'plastic' },
    { index: 729, name: '塑料袋', code: 'bag' },
    { index: 908, name: '酒瓶', code: 'glass' },
    // 纸品回收 / 垃圾分类
    { index: 701, name: '纸巾', code: 'paper_waste' },
    { index: 570, name: '垃圾车', code: 'classify' },
    // 光盘行动：餐厅 / 餐食场景
    { index: 763, name: '餐厅', code: 'clearplate' },
    { index: 960, name: '意面', code: 'clearplate' },
    // 清洁能源 / 节电
    { index: 808, name: '太阳能装置', code: 'elec' },
    // 自带水杯
    { index: 505, name: '咖啡杯', code: 'cup' },
    { index: 969, name: '杯子', code: 'cup' },
    // 素食 / 水果蔬菜
    { index: 949, name: '苹果', code: 'veggie' },
    { index: 955, name: '香蕉', code: 'veggie' },
    { index: 939, name: '花椰菜', code: 'veggie' },
    { index: 940, name: '西葫芦', code: 'veggie' },
    { index: 944, name: '黄瓜', code: 'veggie' },
    { index: 945, name: '洋蓟', code: 'veggie' },
    { index: 946, name: '甜椒', code: 'veggie' },
    { index: 948, name: '蘑菇', code: 'veggie' },
    { index: 950, name: '草莓', code: 'veggie' },
    { index: 951, name: '橙子', code: 'veggie' },
    { index: 952, name: '柠檬', code: 'veggie' },
    { index: 954, name: '菠萝', code: 'veggie' }
  ];

  /** 已加载的模型实例（单例，全会话复用） */
  private static model: mindSporeLite.Model | undefined = undefined;

  /** 模型加载中的 Promise（防并发重复加载） */
  private static loading: Promise<mindSporeLite.Model> | undefined = undefined;

  /** 模型不可用标记：同一会话内不再反复尝试注定失败的加载 */
  private static broken: boolean = false;

  /** 上一次加载失败的真实原因（会话内复用，给用户明确提示） */
  private static brokenReason: string = '';

  /* ---------- ① 选图（免权限） ---------- */

  /**
   * 唤起系统相册选择器，返回选中图片的 uri。
   * 用户取消时返回空串（不抛错，与页面「取消即无操作」语义一致）。
   */
  static async pickPhoto(): Promise<string> {
    const picker = new photoAccessHelper.PhotoViewPicker();
    const result = await picker.select({
      MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
      maxSelectNumber: 1
    });
    if (result.photoUris.length === 0) return '';
    return result.photoUris[0];
  }

  /* ---------- ② 模型加载 ---------- */

  /**
   * 取模型实例：已加载直接返回；加载中复用同一 Promise；
   * 失败置 broken 标记并抛错（由页面降级演示链路）。
   */
  private static ensureModel(): Promise<mindSporeLite.Model> {
    if (AiVisionRecognizer.model !== undefined) {
      return Promise.resolve(AiVisionRecognizer.model);
    }
    if (AiVisionRecognizer.broken) {
      return Promise.reject(new Error(AiVisionRecognizer.brokenReason.length > 0
        ? AiVisionRecognizer.brokenReason
        : '端侧推理不可用'));
    }
    if (AiVisionRecognizer.loading !== undefined) {
      return AiVisionRecognizer.loading;
    }
    const p: Promise<mindSporeLite.Model> = AiVisionRecognizer.loadModel();
    AiVisionRecognizer.loading = p;
    p.then((m: mindSporeLite.Model): void => {
      AiVisionRecognizer.model = m;
      AiVisionRecognizer.loading = undefined;
    }).catch((err: Object): void => {
      AiVisionRecognizer.broken = true;
      AiVisionRecognizer.brokenReason = AiVisionRecognizer.errMsg(err);
      AiVisionRecognizer.loading = undefined;
    });
    return p;
  }

  /**
   * 从 rawfile 读取模型 buffer 并创建 MindSpore Lite 推理实例。
   * CPU 2 线程 + 大核优先（与官方 quick_start 样例一致）。
   *
   * 失败分类（2026-10-23 修复「端侧模型暂不可用」误报）：
   *   ① 系统能力缺失：部分模拟器 / 精简 OHOS 镜像不带
   *      SystemCapability.AI.MindSporeLite。原先这与「文件没打包」
   *      混为一谈，提示「未安装 mobilenetv2.ms」纯属误导——
   *      文件确实在包里（已核实：HAP 内 resources/rawfile/
   *      mobilenetv2.ms 13.9MB，文件头 MSL2 魔数有效）。
   *      现在 canIUse 预检，直接给准确原因。
   *   ② 线程/亲和配置不被环境接受（模拟器常见）：完整 Context 失败后
   *      自动退最小 Context 重试一次。
   *   ③ 真实错误不再被吞：一律把 err.message 带给上层。
   */
  private static async loadModel(): Promise<mindSporeLite.Model> {
    if (!canIUse('SystemCapability.AI.MindSporeLite')) {
      throw new Error('当前环境不支持端侧 AI 推理（缺少 MindSporeLite 系统能力，可改用演示样例）');
    }
    const ctx: common.Context | undefined = AppStorage.get<common.Context>('appContext');
    if (ctx === undefined || ctx === null) {
      throw new Error('应用上下文未初始化：请确认 EntryAbility 已写入 appContext');
    }
    let bytes: Uint8Array;
    try {
      bytes = await ctx.resourceManager.getRawFileContent(AiVisionRecognizer.MODEL_NAME);
    } catch (err) {
      throw new Error('模型文件读取失败：' + AiVisionRecognizer.errMsg(err));
    }
    if (bytes === undefined || bytes.byteLength === 0) {
      throw new Error('模型文件为空：mobilenetv2.ms 未正确打进包');
    }
    // Uint8Array 可能带 byteOffset，必须裁剪出有效区段再交给引擎
    const buf: ArrayBuffer = bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength);
    const full: mindSporeLite.Context = {
      target: ['cpu'],
      cpu: {
        threadNum: 2,
        threadAffinityMode: mindSporeLite.ThreadAffinityMode.BIG_CORES_FIRST
      }
    };
    try {
      return await mindSporeLite.loadModelFromBuffer(buf, full);
    } catch (err) {
      // 模拟器等环境可能不认线程亲和/线程数配置：退最小配置再试一次
      const minimal: mindSporeLite.Context = { target: ['cpu'] };
      return await mindSporeLite.loadModelFromBuffer(buf, minimal);
    }
  }

  /** 任意 throw 值 → 可读字符串（ArkTS catch 到的是 Object） */
  private static errMsg(err: Object | undefined): string {
    if (err === undefined || err === null) return '未知错误';
    const e: Error = err as Error;
    if (e.message !== undefined && e.message.length > 0) return e.message;
    return '' + err;
  }

  /* ---------- ③ 图片解码与预处理 ---------- */

  /**
   * 解码图片为 224×224 的 PixelMap。
   * 三步：① 限长边 640 解码（省内存）→ ② scale 放大使短边覆盖 224
   * → ③ 居中裁剪 224。与 ImageNet 训练预处理（resize 256 →
   * center crop 224）语义一致，避免直接拉伸导致精度下降。
   *
   * ⚠️ content:// 媒体库 URI 必须走 fs 拿 fd（2026-10-23 修复）：
   * PhotoViewPicker 返回的就是 content:// 形式，image 的字符串重载
   * 只保证 file:// / 沙箱路径，且失败时**返回 undefined 而不抛错**——
   * 随后在 getImageInfo() 上抛 TypeError，被页面笼统兜成
   * 「端侧模型暂不可用」，把解码问题误报成模型问题。
   * fd 姿势与 ProfilePage 头像选图一致，是本工程已验证的可靠路径。
   * fd 保持打开到 source.release() 之后，防 ImageSource 惰性读取。
   */
  private static async decodeForModel(uri: string): Promise<image.PixelMap> {
    const opened: fs.File | undefined = AiVisionRecognizer.openReadable(uri);
    const source: image.ImageSource = opened !== undefined
      ? image.createImageSource(opened.fd)
      : image.createImageSource(uri);
    if (source === undefined || source === null) {
      if (opened !== undefined) {
        try {
          fs.closeSync(opened);
        } catch (err) {
          // 句柄清理失败不影响主流程
        }
      }
      throw new Error('图片解码失败：无法读取该图片（URI 可能已失效）');
    }
    try {
      const info: image.ImageInfo = await source.getImageInfo();
      const w: number = info.size.width;
      const h: number = info.size.height;
      if (w <= 0 || h <= 0) {
        throw new Error('图片尺寸异常');
      }
      const edge: number = Math.max(w, h);
      let dw: number = w;
      let dh: number = h;
      if (edge > AiVisionRecognizer.DECODE_MAX_EDGE) {
        const s: number = AiVisionRecognizer.DECODE_MAX_EDGE / edge;
        dw = Math.max(1, Math.round(w * s));
        dh = Math.max(1, Math.round(h * s));
      }
      const opts: image.DecodingOptions = {
        desiredSize: { width: dw, height: dh },
        desiredPixelFormat: image.PixelMapFormat.RGBA_8888,
        editable: true
      };
      const pixelMap: image.PixelMap = await source.createPixelMap(opts);

      // 放大到短边刚好覆盖 224
      const shortEdge: number = Math.min(dw, dh);
      const scale: number = AiVisionRecognizer.INPUT_SIZE / shortEdge;
      await pixelMap.scale(scale, scale);

      // 居中裁剪 224×224（scale 后尺寸以实际读取为准）
      const scaled: image.ImageInfo = await pixelMap.getImageInfo();
      const cw: number = scaled.size.width;
      const ch: number = scaled.size.height;
      const cx: number = Math.max(0, Math.floor((cw - AiVisionRecognizer.INPUT_SIZE) / 2));
      const cy: number = Math.max(0, Math.floor((ch - AiVisionRecognizer.INPUT_SIZE) / 2));
      if (cw > AiVisionRecognizer.INPUT_SIZE || ch > AiVisionRecognizer.INPUT_SIZE) {
        await pixelMap.crop({
          x: cx,
          y: cy,
          size: { width: AiVisionRecognizer.INPUT_SIZE, height: AiVisionRecognizer.INPUT_SIZE }
        });
      }
      return pixelMap;
    } finally {
      source.release();
      if (opened !== undefined) {
        try {
          fs.closeSync(opened);
        } catch (err) {
          // 解码已完成，句柄已失效时忽略
        }
      }
    }
  }

  /** 打开只读句柄：仅 content:// 需要（媒体库临时授权 URI）；
   *  打不开时返回 undefined，交给 image.createImageSource(string) 再试。 */
  private static openReadable(uri: string): fs.File | undefined {
    if (uri.indexOf('content://') !== 0) return undefined;
    try {
      return fs.openSync(uri, fs.OpenMode.READ_ONLY);
    } catch (err) {
      return undefined;
    }
  }

  /**
   * PixelMap → 模型输入张量 [1,3,224,224] NCHW float32。
   * RGBA_8888 逐像素读 4 字节，取 RGB 三通道按 ImageNet 标准归一化，
   * 按 NCHW 平面顺序排布（R 平面 → G 平面 → B 平面）。
   */
  private static async preprocessAsync(pixelMap: image.PixelMap): Promise<ArrayBuffer> {
    const pixels: number = AiVisionRecognizer.INPUT_SIZE * AiVisionRecognizer.INPUT_SIZE;
    const raw: ArrayBuffer = new ArrayBuffer(pixels * 4);
    await pixelMap.readPixelsToBuffer(raw);
    const px: Uint8Array = new Uint8Array(raw);

    const input: ArrayBuffer = new ArrayBuffer(pixels * 3 * 4);
    const fv: Float32Array = new Float32Array(input);
    const plane: number = pixels;
    const mean: number[] = AiVisionRecognizer.MEAN;
    const std: number[] = AiVisionRecognizer.STD;
    for (let i = 0; i < pixels; i++) {
      const o: number = i * 4;
      fv[i] = (px[o] / 255 - mean[0]) / std[0];
      fv[plane + i] = (px[o + 1] / 255 - mean[1]) / std[1];
      fv[plane * 2 + i] = (px[o + 2] / 255 - mean[2]) / std[2];
    }
    return input;
  }

  /* ---------- ④ 推理与类别映射 ---------- */

  /**
   * 跑一次端侧推理，返回 softmax 后的输出概率数组。
   * 输出长度 1001（下标 0 为背景）或 1000，两种都兼容。
   */
  private static async infer(model: mindSporeLite.Model, pixelMap: image.PixelMap): Promise<Float32Array> {
    const inputs: mindSporeLite.MSTensor[] = model.getInputs();
    if (inputs.length === 0) {
      throw new Error('模型输入无效');
    }
    const input: mindSporeLite.MSTensor = inputs[0];
    input.setData(await AiVisionRecognizer.preprocessAsync(pixelMap));

    const outputs: mindSporeLite.MSTensor[] = await model.predict(inputs);
    if (outputs.length === 0) {
      throw new Error('模型输出无效');
    }
    const out: mindSporeLite.MSTensor = outputs[0];
    if (out.dtype !== mindSporeLite.DataType.NUMBER_TYPE_FLOAT32) {
      throw new Error('模型输出类型不支持：期望 float32');
    }
    const buf: ArrayBuffer = out.getData();
    const logits: Float32Array = new Float32Array(buf);
    if (logits.length === 0) {
      throw new Error('模型输出为空');
    }
    return AiVisionRecognizer.softmax(logits);
  }

  /** 数值稳定版 softmax：先减最大值再归一，防 exp 上溢 */
  private static softmax(logits: Float32Array): Float32Array {
    let max: number = logits[0];
    for (let i = 1; i < logits.length; i++) {
      if (logits[i] > max) max = logits[i];
    }
    let sum: number = 0;
    for (let i = 0; i < logits.length; i++) {
      sum += Math.exp(logits[i] - max);
    }
    const out: Float32Array = new Float32Array(logits.length);
    for (let i = 0; i < logits.length; i++) {
      out[i] = Math.exp(logits[i] - max) / sum;
    }
    return out;
  }

  /**
   * 类别概率 → 因子聚合：同一 code 的多个 ImageNet 类概率相加
   * （拍到的自行车可能是山地车/双人车/独轮车中的任一类，
   * 聚合后不会因为具体子类不同而漏判）。
   * 返回按概率降序的候选列表。
   */
  private static aggregate(probs: Float32Array): CodeScore[] {
    const codes: string[] = [];
    const scores: number[] = [];
    const names: string[] = [];
    const bestP: number[] = [];
    const table: ClassMapEntry[] = AiVisionRecognizer.CLASS_MAP;
    for (let i = 0; i < table.length; i++) {
      const idx: number = table[i].index;
      if (idx >= probs.length) continue;
      const p: number = probs[idx];
      if (p <= 0) continue;
      let slot: number = -1;
      for (let k = 0; k < codes.length; k++) {
        if (codes[k] === table[i].code) {
          slot = k;
          break;
        }
      }
      if (slot < 0) {
        codes.push(table[i].code);
        scores.push(p);
        names.push(table[i].name);
        bestP.push(p);
      } else {
        scores[slot] += p;
        if (p > bestP[slot]) {
          bestP[slot] = p;
          names[slot] = table[i].name;
        }
      }
    }
    // 组装并按分数降序排列（插入排序，候选数量很小）
    const out: CodeScore[] = [];
    for (let k = 0; k < codes.length; k++) {
      out.push({ code: codes[k], name: names[k], score: scores[k] });
    }
    for (let a = 1; a < out.length; a++) {
      const cur: CodeScore = out[a];
      let b: number = a - 1;
      while (b >= 0 && out[b].score < cur.score) {
        out[b + 1] = out[b];
        b--;
      }
      out[b + 1] = cur;
    }
    return out;
  }

  /**
   * 识别依据摘要：Top 3 类别概率（含未映射类），
   * 让用户看到模型「看到」了什么，如「山地自行车 62% · 小巴 8%」。
   */
  private static snippetOf(probs: Float32Array): string {
    const top: number[] = [0, 0, 0];
    const topP: number[] = [-1, -1, -1];
    for (let i = 0; i < probs.length; i++) {
      if (probs[i] > topP[0]) {
        topP[2] = topP[1]; top[2] = top[1];
        topP[1] = topP[0]; top[1] = top[0];
        topP[0] = probs[i]; top[0] = i;
      } else if (probs[i] > topP[1]) {
        topP[2] = topP[1]; top[2] = top[1];
        topP[1] = probs[i]; top[1] = i;
      } else if (probs[i] > topP[2]) {
        topP[2] = probs[i]; top[2] = i;
      }
    }
    let s: string = '';
    for (let k = 0; k < 3; k++) {
      if (topP[k] <= 0) break;
      if (s.length > 0) s += ' · ';
      s += AiVisionRecognizer.classNameOf(top[k]) + ' ' +
        Math.round(topP[k] * 100) + '%';
    }
    return s;
  }

  /** 模型下标 → 中文展示名（未映射类显示原始英文序号说明） */
  private static classNameOf(index: number): string {
    const table: ClassMapEntry[] = AiVisionRecognizer.CLASS_MAP;
    for (let i = 0; i < table.length; i++) {
      if (table[i].index === index) return table[i].name;
    }
    return '其他类别 #' + index;
  }

  /* ---------- ⑤ 组合入口 ---------- */

  /**
   * 端侧识别主入口：选好的图片 uri → 可入账记录。
   * 未命中任何低碳行为时返回 undefined（页面提示「没识别出」）。
   *
   * @param uri  PhotoViewPicker 返回的图片 uri
   * @throws 模型未安装 / 推理失败 / 图片解码失败
   */
  static async recognize(uri: string): Promise<AiVisionResult | undefined> {
    if (uri.length === 0) {
      throw new Error('未选择图片');
    }
    const model: mindSporeLite.Model = await AiVisionRecognizer.ensureModel();
    const pixelMap: image.PixelMap = await AiVisionRecognizer.decodeForModel(uri);
    try {
      const probs: Float32Array = await AiVisionRecognizer.infer(model, pixelMap);
      const ranked: CodeScore[] = AiVisionRecognizer.aggregate(probs);
      if (ranked.length === 0 || ranked[0].score < AiVisionRecognizer.MIN_CONFIDENCE) {
        return undefined;
      }
      const best: CodeScore = ranked[0];

      const f: LocalFactor | undefined = MockStore.factorByCode(best.code);
      if (f === undefined) return undefined;

      const record: LocalRecord = {
        recordId: 0,
        itemId: f.itemId,
        itemCode: f.itemCode,
        itemName: f.itemName,
        icon: f.icon,
        category: f.category,
        amount: f.defaultAmount,
        unit: f.unit,
        reduceKg: Math.round(f.factorValue * f.defaultAmount * 1000) / 1000,
        points: Biz.pointsOf(f.factorValue * f.defaultAmount),
        behaviorTime: AiVisionRecognizer.now(),
        dateStr: AiVisionRecognizer.today(),
        recordSource: 'ai',
        remark: 'AI识图：' + best.name
      };
      return {
        record: record,
        keyword: best.name,
        confidence: Math.round(Math.min(0.99, best.score) * 100) / 100,
        snippet: AiVisionRecognizer.snippetOf(probs)
      };
    } finally {
      pixelMap.release();
    }
  }

  /**
   * 预热：在页面 aboutToAppear 里调用，提前把模型加载好。
   * 模型加载约几十毫秒（rawfile 内嵌，无网络下载），
   * 预热可把耗时藏在「选图 → 点识别」的用户操作间隙里。
   * 失败静默（置 broken 标记），不影响页面渲染。
   */
  static async warmUp(): Promise<void> {
    try {
      await AiVisionRecognizer.ensureModel();
    } catch (err) {
      // 无模型设备：标记后本次会话不再尝试，页面自动走演示链路
    }
  }

  /** 端侧引擎是否可用（模型加载成功过才算可用） */
  static usable(): boolean {
    return AiVisionRecognizer.model !== undefined;
  }

  /**
   * 端侧引擎不可用的真实原因（会话内尝试过且失败才有值）。
   * 页面用它做常驻说明，取代原先笼统的「未安装 mobilenetv2.ms」。
   */
  static unavailableReason(): string {
    return AiVisionRecognizer.broken ? AiVisionRecognizer.brokenReason : '';
  }

  /* ---------- 工具 ---------- */

  private static today(): string {
    return AppClock.dateStr();
  }

  private static now(): string {
    return AppClock.dateTimeStr();
  }
}
