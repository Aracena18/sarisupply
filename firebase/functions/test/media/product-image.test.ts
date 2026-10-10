import { createHash } from 'node:crypto';
import { describe, expect, it, vi } from 'vitest';
import { Cloudinary, cloudinarySignature, IMAGE_GRACE_MS, mediaFromEnvironment, ProductImage } from '../../src/media/cloudinary';
import { ProductImageService, cleanupProductImages, uploadKey } from '../../src/media/product-image-service';
import { saveCatalogProduct } from '../../src/catalog/catalog-service';

// Small transaction double: buffers writes and rejects reads after any write.
function fixture() {
  const records = new Map<string, any>();
  const snapshot = (path: string) => ({ exists: records.has(path), data: () => records.get(path),
    get: (key: string) => records.get(path)?.[key], ref: ref(path), id: path.split('/').at(-1) });
  const ref = (path: string): any => ({ path, get: async () => snapshot(path),
    update: async (value: any) => records.set(path, { ...records.get(path), ...value }) });
  const db: any = { doc: ref, runTransaction: async (callback: any) => {
    const writes: (() => void)[] = [];
    const tx = { get: async (reference: any) => { if (writes.length) throw Error('Read after write'); return snapshot(reference.path); },
      set: (reference: any, value: any, options?: any) => writes.push(() => records.set(reference.path,
        options?.merge ? { ...records.get(reference.path), ...value } : value)),
      update: (reference: any, value: any) => writes.push(() => records.set(reference.path, { ...records.get(reference.path), ...value })),
      create: (reference: any, value: any) => writes.push(() => records.set(reference.path, value)),
      delete: (reference: any) => writes.push(() => records.delete(reference.path)) };
    const result = await callback(tx); writes.forEach(write => write()); return result;
  }, collection: () => {
    let limit = 50;
    const query: any = { where: () => query, orderBy: () => query, limit: (n: number) => { limit = n; return query; },
      get: async () => { const docs = [...records].filter(([p, v]) => p.startsWith('productImageUploads/') &&
        typeof v.cleanupAfter === 'number' && v.cleanupAfter <= Date.now()).slice(0, limit).map(([p]) => snapshot(p));
        return { docs, size: docs.length }; } };
    return query;
  } };
  records.set('merchants/m', { status: 'active' });
  records.set('merchants/m/memberships/owner', { userId: 'owner', merchantId: 'm', role: 'owner', status: 'active', allBranches: true, branchIds: [] });
  records.set('merchants/m/memberships/manager', { userId: 'manager', merchantId: 'm', role: 'manager', status: 'active', allBranches: true, branchIds: [] });
  const image: ProductImage = { assetId: 'a', publicId: '', version: 1,
    secureUrl: 'https://res.cloudinary.com/test/image/upload/v1/photo.webp', thumbnailUrl: 'https://res.cloudinary.com/test/image/upload/v1/thumb.webp' };
  const provider = { cloudName: 'test', usage: vi.fn(async () => 0), parameters: vi.fn((publicId: string) => ({ public_id: publicId })),
    image: vi.fn(async (publicId: string) => ({ ...image, publicId })), destroy: vi.fn(async () => {}) };
  const service = new ProductImageService(db, 'dev', provider, true);
  const owner = { auth: { uid: 'owner', token: {} } };
  const input = { merchantId: 'm', productId: 'p', uploadId: 'u', bytes: 100, format: 'jpg' };
  const product = { id: 'p', sku: 'P', name: 'Product', active: true, baseUnit: 'piece', revision: 0,
    units: [{ name: 'piece', factor: 1, priceCentavos: 100, barcode: '' }] };
  return { db, records, service, owner, input, product, provider };
}

describe('product photo authority and lifecycle', () => {
  it('denies devices, managers, other merchants and revoked owners before provider work', async () => {
    const f = fixture();
    await expect(f.service.prepare({}, f.input)).rejects.toMatchObject({ code: 'unauthenticated' });
    await expect(f.service.prepare({ auth: { uid: 'owner', token: { principalType: 'device' } } }, f.input)).rejects.toMatchObject({ code: 'unauthenticated' });
    await expect(f.service.prepare({ auth: { uid: 'manager', token: {} } }, f.input)).rejects.toMatchObject({ code: 'permission-denied' });
    await expect(f.service.prepare(f.owner, { ...f.input, merchantId: 'foreign' })).rejects.toMatchObject({ code: 'permission-denied' });
    f.records.get('merchants/m/memberships/owner').status = 'removed';
    await expect(f.service.prepare(f.owner, f.input)).rejects.toMatchObject({ code: 'permission-denied' });
    expect(f.provider.usage).not.toHaveBeenCalled();
  });
  it('reserves once, preserves retry identity, rejects payload reuse and blocked uploads', async () => {
    const f = fixture();
    expect(await f.service.prepare(f.owner, f.input)).toMatchObject({ uploadId: 'u' });
    await f.service.prepare(f.owner, f.input);
    expect([...f.records.values()].filter(r => r.count === 1)).toHaveLength(3);
    await expect(f.service.prepare(f.owner, { ...f.input, bytes: 101 })).rejects.toMatchObject({ code: 'already-exists' });
    f.provider.usage.mockResolvedValue(20);
    await expect(f.service.prepare(f.owner, { ...f.input, uploadId: 'u2' })).rejects.toMatchObject({ code: 'resource-exhausted' });
    f.provider.usage.mockRejectedValue(Error('usage outage'));
    await expect(f.service.prepare(f.owner, { ...f.input, uploadId: 'u2' })).rejects.toThrow();
    f.records.set('mediaSettings/cloudinary', { uploadsEnabled: false });
    await expect(f.service.prepare(f.owner, f.input)).rejects.toMatchObject({ code: 'failed-precondition' });
  });
  it('enforces file types, sizes, daily reservations and disabled defaults', async () => {
    const f = fixture();
    for (const change of [{ bytes: 0 }, { bytes: 5242881 }, { format: 'gif' }]) {
      await expect(f.service.prepare(f.owner, { ...f.input, ...change })).rejects.toMatchObject({ code: 'invalid-argument' });
    }
    await expect(new ProductImageService(f.db, 'dev', f.provider).prepare(f.owner, f.input)).rejects.toMatchObject({ code: 'failed-precondition' });
    const day = new Date().toISOString().slice(0, 10);
    f.records.set(`merchants/m/mediaDaily/${day}`, { count: 50 });
    await expect(f.service.prepare(f.owner, f.input)).rejects.toMatchObject({ code: 'resource-exhausted' });
    f.records.set(`merchants/m/mediaDaily/${day}`, { count: 0 });
    f.records.set(`mediaDaily/${day}`, { count: 200 });
    await expect(f.service.prepare(f.owner, f.input)).rejects.toMatchObject({ code: 'resource-exhausted' });
  });
  it('verifies provider data, saves atomically, replays, preserves photo on legacy edits and clears explicitly', async () => {
    const f = fixture();
    await f.service.prepare(f.owner, f.input);
    const completed = await f.service.complete(f.owner, { ...f.input, image: { assetId: 'forged' } });
    expect(completed.image.assetId).toBe('a');
    const save = { merchantId: 'm', operationId: 'save', expectedRevision: 0, product: f.product,
      imageChange: { action: 'set', uploadId: 'u' } };
    const saved = await saveCatalogProduct(f.db, f.owner, save);
    expect(saved.image?.assetId).toBe('a');
    expect((await saveCatalogProduct(f.db, f.owner, save)).revision).toBe(1);
    expect(f.records.get(`productImageUploads/${uploadKey('m', 'u')}`).status).toBe('attached');
    const edited = await saveCatalogProduct(f.db, f.owner, { ...save, operationId: 'edit', expectedRevision: 1,
      imageChange: undefined, product: { ...f.product, name: 'Edited' } });
    expect(edited.image).toEqual(saved.image);
    const removed = await saveCatalogProduct(f.db, f.owner, { ...save, operationId: 'remove', expectedRevision: 2,
      imageChange: { action: 'remove' } });
    expect(removed.imageUrl).toBeUndefined();
    expect(f.records.get(`productImageUploads/${uploadKey('m', 'u')}`).status).toBe('superseded');
  });
  it('preserves pre-image-contract idempotency receipts and rejects changed new image payloads', async () => {
    const f = fixture();
    const legacyProduct = { id: f.product.id, sku: f.product.sku, name: f.product.name, baseUnit: f.product.baseUnit, active: f.product.active, units: f.product.units, revision: 0 };
    f.records.set('merchants/m/catalogOperations/old', {
      fingerprint: createHash('sha256').update(JSON.stringify({ uid: 'owner', expected: 0, p: legacyProduct })).digest('hex'),
      product: { ...f.product, revision: 1 },
    });
    const saved = await saveCatalogProduct(f.db, f.owner, { merchantId: 'm', operationId: 'old', expectedRevision: 0,
      product: { ...f.product, imageUrl: 'https://example.com/previously-ignored.jpg' } });
    expect(saved.revision).toBe(1);
    await saveCatalogProduct(f.db, f.owner, { merchantId: 'm', operationId: 'new', expectedRevision: 0,
      product: { ...f.product, imageUrl: 'https://example.com/first.jpg' } });
    expect(f.records.get('merchants/m/products/p').imageUrl).toBe('https://example.com/first.jpg');
    await expect(saveCatalogProduct(f.db, f.owner, { merchantId: 'm', operationId: 'new', expectedRevision: 0,
      product: { ...f.product, imageUrl: 'https://example.com/second.jpg' } })).rejects.toMatchObject({ code: 'already-exists' });
  });
  it('keeps existing image on stale save; rejects unverified, foreign-product and deleting uploads', async () => {
    const f = fixture();
    f.records.set('merchants/m/products/p', { ...f.product, revision: 1, imageUrl: 'https://example.com/old.jpg' });
    await f.service.prepare(f.owner, f.input);
    const save = { merchantId: 'm', operationId: 'save', expectedRevision: 1, product: f.product, imageChange: { action: 'set', uploadId: 'u' } };
    await expect(saveCatalogProduct(f.db, f.owner, save)).rejects.toMatchObject({ code: 'failed-precondition' });
    await expect(f.service.complete(f.owner, { ...f.input, productId: 'other' })).rejects.toMatchObject({ code: 'failed-precondition' });
    await f.service.complete(f.owner, f.input);
    await expect(saveCatalogProduct(f.db, f.owner, { ...save, expectedRevision: 0 })).rejects.toMatchObject({ code: 'failed-precondition' });
    expect(f.records.get('merchants/m/products/p').imageUrl).toBe('https://example.com/old.jpg');
    f.records.get(`productImageUploads/${uploadKey('m', 'u')}`).status = 'deleting';
    await expect(saveCatalogProduct(f.db, f.owner, save)).rejects.toMatchObject({ code: 'failed-precondition' });
  });
  it('cleanup retains referenced and archived products, deletes abandoned uploads and retries provider failures', async () => {
    const f = fixture();
    const prepared = await f.service.prepare(f.owner, f.input);
    const row = f.records.get(`productImageUploads/${uploadKey('m', 'u')}`);
    row.cleanupAfter = Date.now() - IMAGE_GRACE_MS;
    f.records.set('merchants/m/products/p', { active: false, image: { publicId: prepared.publicId } });
    expect((await cleanupProductImages(f.db, f.provider)).retained).toBe(1);
    expect(f.provider.destroy).not.toHaveBeenCalled();
    Object.assign(f.records.get(`productImageUploads/${uploadKey('m', 'u')}`), { status: 'superseded', cleanupAfter: Date.now() - 1 });
    f.records.delete('merchants/m/products/p');
    f.provider.destroy.mockRejectedValueOnce(Error('outage'));
    expect((await cleanupProductImages(f.db, f.provider)).failed).toBe(1);
    expect(f.records.get(`productImageUploads/${uploadKey('m', 'u')}`).status).toBe('deleting');
    expect((await cleanupProductImages(f.db, f.provider)).deleted).toBe(1);
  });
});

describe('Cloudinary adapter', () => {
  it('signs only fixed options without exposing the secret and defaults off', () => {
    const p = new Cloudinary('cloud', 'key', 'secret', 'preset');
    const params = p.parameters('sarisupply/dev/m/p', 100);
    const { signature, api_key, ...signed } = params;
    expect(api_key).toBe('key'); expect(JSON.stringify(params)).not.toContain('secret');
    expect(signature).toBe(cloudinarySignature(signed, 'secret'));
    expect(cloudinarySignature({ b: '2', a: '1' }, 'x')).toBe(createHash('sha256').update('a=1&b=2x').digest('hex'));
    expect(params.overwrite).toBe('false'); expect(params.backup).toBe('false');
    expect(mediaFromEnvironment({})).toBeUndefined();
    expect(() => mediaFromEnvironment({ CLOUDINARY_UPLOADS_ENABLED: 'true' })).toThrow();
  });
  it('caches usage, fails closed, rejects oversized/animated/foreign assets and generates fixed URLs', async () => {
    const asset = { asset_id: 'asset', public_id: 'sarisupply/dev/photo', version: 2, resource_type: 'image', type: 'upload',
      format: 'jpg', bytes: 500, width: 100, height: 100, pages: 1 };
    const fetcher = vi.fn(async () => Response.json({ credits: { usage: 5 } }));
    const provider = new Cloudinary('cloud', 'key', 'secret', 'preset', fetcher);
    expect(await provider.usage()).toBe(5); expect(await provider.usage()).toBe(5); expect(fetcher).toHaveBeenCalledTimes(1);
    for (const change of [{ bytes: 5242881 }, { pages: 2 }, { public_id: 'foreign' }, { width: 1025 }]) {
      fetcher.mockResolvedValueOnce(Response.json({ ...asset, ...change }));
      await expect(provider.image(asset.public_id)).rejects.toMatchObject({ code: 'invalid-argument' });
    }
    fetcher.mockResolvedValueOnce(Response.json(asset));
    expect(await provider.image(asset.public_id)).toMatchObject({ secureUrl: expect.stringContaining('h_640'), thumbnailUrl: expect.stringContaining('h_160') });
    fetcher.mockResolvedValueOnce(Response.json({}));
    await expect(new Cloudinary('cloud', 'key', 'secret', 'preset', fetcher).usage()).rejects.toMatchObject({ code: 'unavailable' });
  });
});
