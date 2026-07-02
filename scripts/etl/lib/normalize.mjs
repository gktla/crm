// Name normalization + matching helpers for the Coda <-> vibecoded org
// entity-resolution step. Conservative on purpose: strip accents, case,
// punctuation and the generic football-club suffixes (FC/AFC/CF/SC/...),
// but keep distinctive words (City, United, Town, Rovers, ...) so we never
// over-merge "Manchester City" with "Manchester United".

/** Generic club-type tokens that carry no distinguishing meaning. */
const GENERIC_TOKENS = new Set([
  "fc",
  "afc",
  "cf",
  "sc",
  "cfc",
  "ac",
  "bc",
  "ss",
  "us",
  "usg",
  "calcio",
  "club",
]);

/**
 * Canonical match key for an org name.
 * @param {string} raw
 * @returns {string}
 */
export function orgKey(raw) {
  if (!raw) return "";
  const s = String(raw)
    .normalize("NFKD")
    .replace(/[̀-ͯ]/g, "") // strip accents
    .toLowerCase()
    .replace(/&/g, " and ")
    .replace(/['’`.]/g, "") // drop apostrophes / dots
    .replace(/[^a-z0-9]+/g, " ") // non-alphanumeric -> space
    .trim();

  const tokens = s.split(" ").filter((t) => t && !GENERIC_TOKENS.has(t));
  return tokens.join(" ");
}

/**
 * Person-name key: accents/case/punctuation folded, spaces collapsed.
 * Kept separate from orgKey (which strips club suffixes) so we never mangle
 * a person's name.
 * @param {string} raw
 * @returns {string}
 */
export function nameKey(raw) {
  if (!raw) return "";
  return String(raw)
    .normalize("NFKD")
    .replace(/[̀-ͯ]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .trim();
}

/**
 * Group an array of records by their org key.
 * @template T
 * @param {T[]} rows
 * @param {(r: T) => string} nameOf
 * @returns {Map<string, T[]>}
 */
export function groupByKey(rows, nameOf) {
  const map = new Map();
  for (const r of rows) {
    const k = orgKey(nameOf(r));
    if (!k) continue;
    if (!map.has(k)) map.set(k, []);
    map.get(k).push(r);
  }
  return map;
}
