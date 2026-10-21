/**
 * The credit line a library video must show.
 *
 * Discover's STEM library is built from public-domain and Creative Commons
 * videos. Creative Commons terms are met only when the credit, the licence and
 * a link to the source travel with the video, so the reel shows them whenever
 * the API reports any. A learner's own clip has no attribution and shows none.
 *
 * Links are only ever https: the fields come from the source's own metadata,
 * and a `javascript:` URL in an anchor would run on tap.
 */

function safeLink(value) {
  if (typeof value !== 'string') return null;
  try {
    const url = new URL(value);
    return url.protocol === 'https:' ? url.href : null;
  } catch {
    return null;
  }
}

function clean(value) {
  return typeof value === 'string' ? value.trim() : '';
}

export function attributionFor(raw) {
  const source = raw && typeof raw === 'object' ? raw.attribution : null;
  if (!source || typeof source !== 'object') return null;
  const credit = clean(source.credit);
  const license = clean(source.license);
  const sourceName = clean(source.sourceName);
  // The server's credit already reads "creator · licence"; only add the
  // licence when it is not in there.
  const text = credit
    ? credit.includes(license) ? credit : [credit, license].filter(Boolean).join(' · ')
    : [sourceName, license].filter(Boolean).join(' · ');
  if (!text) return null;
  return {
    text,
    sourceName: sourceName || null,
    sourceHref: safeLink(source.sourceURL),
    licenseHref: safeLink(source.licenseURL),
  };
}
