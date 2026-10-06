import { HttpsError } from 'firebase-functions/v2/https';
import { GrantScope } from './cashier-grants';
export type Input = Record<string, unknown>;
export const invalid = () => new HttpsError('invalid-argument', 'Invalid checkout operation');
export function object(raw: unknown): Input {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) throw invalid();
  return raw as Input;
}
export function integer(raw: unknown, min = 0, max = 1e9): number {
  if (typeof raw !== 'number' || !Number.isSafeInteger(raw) || raw < min || raw > max) throw invalid();
  return raw;
}
export function text(raw: unknown, max: number, empty = false): string {
  if (typeof raw !== 'string' || raw.length > max || (!empty && !raw.trim())) throw invalid();
  return raw;
}
export function id(raw: unknown): string {
  if (typeof raw !== 'string' || !/^[A-Za-z0-9._-]{1,128}$/.test(raw) || raw === '.' || raw === '..') throw invalid();
  return raw;
}
export function keys(raw: Input, allowed: string[]) {
  if (Object.keys(raw).some(k => !allowed.includes(k)) || allowed.some(k => !Object.hasOwn(raw,k))) throw invalid();
}
export type Line = { productId: string; sku: string; name: string; unit: string; factor: number;
  priceCentavos: number; quantity: number; catalogSequence: number; catalogRevision: number };
export type Intent = { id: string; scope: GrantScope; shiftId: string; ordinal: number;
  occurredAt: string; kind: string; payload: Input };
export function parseIntent(raw: unknown): Intent {
  const i = object(raw); keys(i,['id','scope','shiftId','ordinal','occurredAt','kind','payload']);
  const scope = object(i.scope); keys(scope,['merchantId','branchId','deviceId','cashierId','grantId','credentialVersion']);
  const binding: GrantScope = { merchantId:id(scope.merchantId),branchId:id(scope.branchId),deviceId:id(scope.deviceId),
    cashierId:id(scope.cashierId),grantId:id(scope.grantId),credentialVersion:integer(scope.credentialVersion,1) };
  const occurredAt = text(i.occurredAt,40);
  if (!Number.isFinite(Date.parse(occurredAt))) throw invalid();
  const kind = text(i.kind,20);
  if (!['openShift','sale','cashIn','cashOut','closeShift','refund','voidSale','debtRepayment'].includes(kind)) throw invalid();
  const payload=object(i.payload);
  if(kind==='sale') parseSale(payload);
  else if(kind==='refund') parseRefund(payload);
  else if(kind==='voidSale') parseVoid(payload);
  else if(kind==='debtRepayment') {keys(payload,['customerId','amountCentavos','tenderKind','reference','notes']);text(payload.notes??'',200,true);id(payload.customerId);integer(payload.amountCentavos,1);if(!['cash','qr'].includes(text(payload.tenderKind,10))) throw invalid();text(payload.reference,80,true);}
  else if(kind==='openShift') {keys(payload,['floatCentavos']);integer(payload.floatCentavos);}
  else if(kind==='closeShift') {keys(payload,['countedCentavos','reason']);integer(payload.countedCentavos);text(payload.reason,160,true);}
  else {keys(payload,['amountCentavos','reason']);integer(payload.amountCentavos,1);text(payload.reason,160);}
  return {id:id(i.id),scope:binding,shiftId:id(i.shiftId),ordinal:integer(i.ordinal,1,Number.MAX_SAFE_INTEGER),
    occurredAt,kind,payload:object(i.payload)};
}
export function parseSale(payload: Input) {
  keys(payload,['merchantName','branchName','lines','tender']);
  text(payload.merchantName,300); text(payload.branchName,300);
  if (!Array.isArray(payload.lines) || !payload.lines.length || payload.lines.length > 50) throw invalid();
  const quantities = new Map<string,number>(), products = new Map<string,Line>();
  let total = 0;
  const lines = payload.lines.map(raw => {
    const l = object(raw); keys(l,['productId','sku','name','unit','factor','priceCentavos','quantity','catalogSequence','catalogRevision']);
    const line: Line = {productId:id(l.productId),sku:text(l.sku,40),name:text(l.name,120),unit:text(l.unit,30),
      factor:integer(l.factor,1,1e6),priceCentavos:integer(l.priceCentavos),quantity:integer(l.quantity,1),
      catalogSequence:integer(l.catalogSequence,1),catalogRevision:integer(l.catalogRevision,1)};
    if (line.quantity > Math.floor(1e9 / line.factor) ||
        (line.priceCentavos > 0 && line.quantity > Math.floor(1e9 / line.priceCentavos))) throw invalid();
    total += line.quantity * line.priceCentavos; if (total > 1e9) throw invalid();
    const base = (quantities.get(line.productId) ?? 0) + line.quantity * line.factor;
    if (base > 1e9) throw invalid(); quantities.set(line.productId,base);
    const other = products.get(line.productId);
    if (other && (other.catalogSequence !== line.catalogSequence || other.catalogRevision !== line.catalogRevision ||
        other.sku !== line.sku || other.name !== line.name)) throw invalid();
    products.set(line.productId,line); return line;
  });
  if (products.size > 20) throw invalid();
  const tender = object(payload.tender); keys(tender,tender.kind === 'credit' ? ['kind','receivedCentavos','reference','confirmed','creditGrantId'] : ['kind','receivedCentavos','reference','confirmed']);
  const received = integer(tender.receivedCentavos);
  if (tender.kind === 'cash') {
    if (received < total || tender.reference !== '' || tender.confirmed !== false) throw invalid();
  } else if (tender.kind === 'qr') {
    text(tender.reference,80); if (total === 0 || received !== 0 || tender.confirmed !== true) throw invalid();
  } else if (tender.kind === 'credit') {
    id(tender.reference); id(tender.creditGrantId);
    if (total === 0 || received !== 0 || tender.confirmed !== true) throw invalid();
  } else throw invalid();
  return {lines,quantities,products,total,change: tender.kind === 'cash' ? received-total : 0,
    netCash:tender.kind === 'cash' ? total : 0};
}
export function canonical(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map(canonical).join(',')}]`;
  if (value && typeof value === 'object') {
    const o=value as Input; return `{${Object.keys(o).sort().map(k=>`${JSON.stringify(k)}:${canonical(o[k])}`).join(',')}}`;
  }
  return JSON.stringify(value);
}

export type RefundLine = { productId: string; sku: string; name: string; unit: string; factor: number;
  priceCentavos: number; quantity: number; refundCentavos: number };

export function parseRefund(payload: Input) {
  const originalSaleId = id(payload.originalSaleId);
  const reason = text(payload.reason, 160);
  const authorizedByCashierId = id(payload.authorizedByCashierId);
  const tenderKind = text(payload.tenderKind, 20);
  if (!['cash', 'qr', 'credit'].includes(tenderKind)) throw invalid();
  if (!Array.isArray(payload.lines) || !payload.lines.length || payload.lines.length > 50) throw invalid();
  const quantities = new Map<string, number>();
  let total = 0;
  const lines = payload.lines.map((raw) => {
    const l = object(raw);
    const line: RefundLine = {
      productId: id(l.productId),
      sku: text(l.sku, 40),
      name: text(l.name, 120),
      unit: text(l.unit, 30),
      factor: integer(l.factor, 1, 1e6),
      priceCentavos: integer(l.priceCentavos),
      quantity: integer(l.quantity, 1),
      refundCentavos: integer(l.refundCentavos),
    };
    if (line.refundCentavos > line.quantity * line.priceCentavos) throw invalid();
    total += line.refundCentavos;
    if (total > 1e9) throw invalid();
    const base = (quantities.get(line.productId) ?? 0) + line.quantity * line.factor;
    if (base > 1e9) throw invalid();
    quantities.set(line.productId, base);
    return line;
  });
  return { originalSaleId, reason, authorizedByCashierId, tenderKind, lines, quantities, totalRefundCentavos: total };
}

export function parseVoid(payload: Input) {
  const originalSaleId = id(payload.originalSaleId);
  const reason = text(payload.reason, 160);
  const authorizedByCashierId = id(payload.authorizedByCashierId);
  const voidCentavos = integer(payload.voidCentavos);
  const tenderKind = text(payload.tenderKind ?? 'cash', 20);
  return { originalSaleId, reason, authorizedByCashierId, voidCentavos, tenderKind };
}

