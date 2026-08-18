const storageUrlPathMarkers = ['/o/'];

/**
 * Converte URLs geradas pelo Firebase Storage (ou gs://) no path do objeto.
 * Devolve null para URLs externas, valores vazios ou paths ambíguos.
 */
export function storagePathFromResource(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  const resource = value.trim();
  if (!resource) return null;

  if (resource.startsWith('gs://')) {
    const separator = resource.indexOf('/', 'gs://'.length);
    if (separator < 0) return null;
    return safeStoragePath(resource.slice(separator + 1));
  }

  let parsed: URL;
  try {
    parsed = new URL(resource);
  } catch (_) {
    return null;
  }
  if (parsed.protocol !== 'http:' && parsed.protocol !== 'https:') return null;

  const marker = storageUrlPathMarkers.find((candidate) =>
    parsed.pathname.includes(candidate),
  );
  if (!marker) return null;
  const encodedPath = parsed.pathname.split(marker)[1] ?? '';
  if (!encodedPath) return null;

  try {
    return safeStoragePath(decodeURIComponent(encodedPath));
  } catch (_) {
    return null;
  }
}

export function isLegacyStorageUrl(value: unknown): boolean {
  if (typeof value !== 'string') return false;
  const resource = value.trim();
  return resource.startsWith('gs://') ||
    resource.startsWith('http://') ||
    resource.startsWith('https://');
}

function safeStoragePath(value: string): string | null {
  const normalized = value.trim().replace(/^\/+/, '');
  if (!normalized || normalized.includes('..') || normalized.includes('?') ||
      normalized.includes('#')) {
    return null;
  }
  return normalized;
}
