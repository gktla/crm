// Tiny SQL literal helpers for the ETL SQL generators.

/** @param {unknown} s @returns {string} */
export function sqlStr(s) {
  if (s === null || s === undefined || s === "") return "null";
  return "'" + String(s).replace(/'/g, "''") + "'";
}

/** @param {unknown} n @returns {string} */
export function sqlInt(n) {
  if (n === null || n === undefined || n === "") return "null";
  const v = parseInt(String(n).replace(/[^0-9-]/g, ""), 10);
  return Number.isFinite(v) ? String(v) : "null";
}

/** @param {unknown} b @returns {string} */
export function sqlBool(b) {
  if (b === true || b === "true" || b === "TRUE") return "true";
  if (b === false || b === "false" || b === "FALSE" || b === "" || b == null)
    return "false";
  return "false";
}

/** URL-safe slug from an already-normalized key. */
export function slugify(key) {
  return String(key).trim().replace(/\s+/g, "-");
}
