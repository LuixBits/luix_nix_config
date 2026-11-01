// Native Neorg cells, read by the shared neorg-view.nvim presentation layer.
// Keep each row together for cell navigation in reading mode.
export function norgTable(headers, rows) {
  if (!rows.length) return "";
  if (!headers.length || headers.length > 12)
    throw new Error("Neorg tables support 1–12 columns");
  if (rows.some((row) => row.length !== headers.length))
    throw new Error("Neorg table rows must match their headers");
  // The reader supports A1–L256; split large indexes without dropping entries.
  const tables = [];
  for (let start = 0; start < rows.length; start += 255) {
    tables.push(
      [headers, ...rows.slice(start, start + 255)]
        .flatMap((row, index) =>
          row.map((cell, column) => {
            const address = `${String.fromCharCode(65 + column)}${index + 1}`;
            const value =
              String(cell ?? "—")
                .replace(/[\r\n]+/g, " ")
                .trim() || "—";
            // A short ranged-cell anchor avoids wrapping the concealed link path.
            return /\{[^}]+\}\[[^\]]+\]/.test(value)
              ? `:: ${address}\n${value}\n::`
              : `: ${address} : ${value}`;
          }),
        )
        .join("\n"),
    );
  }
  return tables.join("\n\n");
}

// Navigation is ordinary source text: one entry per physical line.
export function norgLinks(_headers, rows) {
  return rows.map((row) => "- " + row.map((value) =>
    String(value ?? "—").replace(/[\r\n]+/g, " ").trim()).join(" · ")).join("\n");
}
