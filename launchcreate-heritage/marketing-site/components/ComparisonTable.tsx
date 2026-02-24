export type ComparisonRow = {
  feature: string;
  heirloom: boolean | string;
  others: boolean | string;
};

export default function ComparisonTable({
  title,
  subtitle,
  rows,
}: {
  title: string;
  subtitle?: string;
  rows: ComparisonRow[];
}) {
  function renderCell(value: boolean | string) {
    if (typeof value === "boolean") {
      return value ? (
        <span className="inline-flex h-5 w-5 items-center justify-center rounded-full bg-green-100 text-xs text-green-700">
          &#10003;
        </span>
      ) : (
        <span className="inline-flex h-5 w-5 items-center justify-center rounded-full bg-black/5 text-xs text-black/30">
          &mdash;
        </span>
      );
    }
    return <span className="text-xs text-black/70">{value}</span>;
  }

  return (
    <div>
      <h2 className="text-2xl font-semibold tracking-tight">{title}</h2>
      {subtitle && (
        <p className="mt-2 text-sm text-black/60">{subtitle}</p>
      )}
      <div className="mt-6 overflow-hidden rounded-2xl border border-black/10 bg-white shadow-sm">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-black/10 bg-[var(--cream)]">
              <th className="px-4 py-3 text-left font-medium text-black/60">
                Feature
              </th>
              <th className="px-4 py-3 text-center font-semibold">Heirloom</th>
              <th className="px-4 py-3 text-center font-medium text-black/60">
                Other apps
              </th>
            </tr>
          </thead>
          <tbody>
            {rows.map((row, idx) => (
              <tr
                key={idx}
                className={idx < rows.length - 1 ? "border-b border-black/5" : ""}
              >
                <td className="px-4 py-3 text-black/80">{row.feature}</td>
                <td className="px-4 py-3 text-center">
                  {renderCell(row.heirloom)}
                </td>
                <td className="px-4 py-3 text-center">
                  {renderCell(row.others)}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
