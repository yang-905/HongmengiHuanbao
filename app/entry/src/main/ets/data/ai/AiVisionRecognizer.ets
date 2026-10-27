/** 端侧 MindSpore Lite 视觉识别器，将 ImageNet 类别映射为低碳行为因子。 */
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { image } from '@kit.ImageKit';
import { common } from '@kit.AbilityKit';
import { mindSporeLite } from '@kit.MindSporeLiteKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { Biz } from '../../ui/Theme';
import { LocalFactor, LocalRecord, MockStore } from '../MockStore';
import { AppClock } from '../../utils/AppClock';

/** ImageNet 类别 → 低碳行为因子 的映射条目 */
interface ClassMapEntry {
  index: number;
  name: string;
  code: string;
}

/** 同一 code 的多个 ImageNet 类概率聚合结果 */
interface CodeScore {
  code: string;
  name: string;
  score: number;
}

/** 端侧视觉识别结果，与 DataSource.recognize 结构一致 */
export interface AiVisionResult {
  record: LocalRecord;
  keyword: string;
  confidence: number;
  snippet: string;
}

export class AiVisionRecognizer {
  private static readonly MODEL_NAME: string = 'mobilenetv2.ms';
  private static readonly INPUT_SIZE: number = 224;
  private static readonly DECODE_MAX_EDGE: number = 640;
  private static readonly MIN_CONFIDENCE: number = 0.05;
  private static readonly MEAN: number[] = [0.485, 0.456, 0.406];
  private static readonly STD: number[] = [0.229, 0.224, 0.225];

  /** ImageNet 类别 → 低碳行为因子 映射表，下标 = synset 序号 + 1 */
  private static readonly CLASS_MAP: ClassMapEntry[] = [
    { index: 672, name: '山地自行车', code: 'bike' },
    { index: 445, name: '双人自行车', code: 'bike' },
    { index: 881, name: '独轮车', code: 'bike' },
    { index: 655, name: '小巴', code: 'bus' },
    { index: 780, name: '校车', code: 'bus' },
    { index: 738, name: '汽水瓶', code: 'plastic' },
    { index: 899, name: '水瓶', code: 'plastic' },
    { index: 729, name: '塑料袋', code: 'bag' },
    { index: 908, name: '酒瓶', code: 'glass' },
    { index: 701, name: '纸巾', code: 'paper_waste' },
    { index: 570, name: '垃圾车', code: 'classify' },
    { index: 763, name: '餐厅', code: 'clearplate' },
    { index: 960, name: '意面', code: 'clearplate' },
    { index: 808, name: '太阳能装置', code: 'elec' },
    { index: 505, name: '咖啡杯', code: 'cup' },
    { index: 969, name: '杯子', code: 'cup' },
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

  private static model: mindSporeLite.Model | undefined = undefined;
  private static loading: Promise<mindSporeLite.Model> | undefined = undefined;
  private static broken: boolean = false;
  private static brokenReason: string = '';

  /** 唤起系统相册选择器，返回选中图片的 uri，取消时返回空串 */
  static async pickPhoto(): Promise<string> {
    const picker = new photoAccessHelper.PhotoViewPicker();
    const result = await picker.select({
      MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
      maxSelectNumber: 1
    });
    if (result.photoUris.length === 0) return '';
    return result.photoUris[0];
  }

  /** 取模型实例：已加载直接返回，失败置 broken 标记 */
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

  /** 从 rawfile 读取模型 buffer 并创建 MindSpore Lite 推理实例 */
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
    // Uint8Array 可能带 byteOffset，裁剪有效区段
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
      // 模拟器不认线程亲和配置：退最小配置再试一次
      const minimal: mindSporeLite.Context = { target: ['cpu'] };
      return await mindSporeLite.loadModelFromBuffer(buf, minimal);
    }
  }

  /** 任意 throw 值 → 可读字符串 */
  private static errMsg(err: Object | undefined): string {
    if (err === undefined || err === null) return '未知错误';
    const e: Error = err as Error;
    if (e.message !== undefined && e.message.length > 0) return e.message;
    return '' + err;
  }

  /** 解码图片为 224×224 的 PixelMap：限长边 → scale → 居中裁剪 */
  private static async decodeForModel(uri: string): Promise<image.PixelMap> {
    const fd: number | undefined = await AiVisionRecognizer.openFd(uri);
    const source: image.ImageSource = fd !== undefined
      ? image.createImageSource(fd)
      : image.createImageSource(uri);
    if (source === undefined || source === null) {
      if (fd !== undefined) {
        try { fs.closeSync(fd); } catch (err) {}
      }
      if (uri.startsWith('content://')) {
        throw new Error('相册图片读取失败：请授予相册权限或改用演示样例');
      }
      throw new Error('图片解码失败：不支持的图片路径或格式');
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

      // 居中裁剪 224×224
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
      if (fd !== undefined) {
        try { fs.closeSync(fd); } catch (err) {}
      }
    }
  }

  /**
   * 打开只读文件描述符。
   * PhotoViewPicker 返回的 content:// URI 已通过选择器授予临时读取权限，
   * 直接用 fs.openSync 打开即可（无需 READ_MEDIA 等媒体库权限）。
   * file://、resource、绝对路径等同理。打不开返回 undefined。
   */
  private static async openFd(uri: string): Promise<number | undefined> {
    try {
      return fs.openSync(uri, fs.OpenMode.READ_ONLY).fd;
    } catch (err) {
      return undefined;
    }
  }

  /** PixelMap → 模型输入张量 [1,3,224,224] NCHW float32 */
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

  /** 跑一次端侧推理，返回 softmax 后的输出概率数组 */
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

  /** softmax：先减最大值再归一，防 exp 上溢 */
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

  /** 同一 code 的多个 ImageNet 类概率聚合，按概率降序返回 */
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
    // 组装并按分数降序排列（插入排序）
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

  /** Top 3 类别概率摘要，如「山地自行车 62% · 小巴 8%」 */
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

  /** 模型下标 → 中文展示名 */
  private static classNameOf(index: number): string {
    const table: ClassMapEntry[] = AiVisionRecognizer.CLASS_MAP;
    for (let i = 0; i < table.length; i++) {
      if (table[i].index === index) return table[i].name;
    }
    return '其他类别 #' + index;
  }

  /** 端侧识别主入口：图片 uri → 可入账记录，未命中返回 undefined */
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

  /** 预热：提前把模型加载好，失败静默 */
  static async warmUp(): Promise<void> {
    try {
      await AiVisionRecognizer.ensureModel();
    } catch (err) {
      // 无模型设备：标记后本次会话不再尝试
    }
  }

  /** 端侧引擎是否可用 */
  static usable(): boolean {
    return AiVisionRecognizer.model !== undefined;
  }

  /** 端侧引擎不可用的真实原因 */
  static unavailableReason(): string {
    return AiVisionRecognizer.broken ? AiVisionRecognizer.brokenReason : '';
  }

  private static today(): string {
    return AppClock.dateStr();
  }

  private static now(): string {
    return AppClock.dateTimeStr();
  }
}
