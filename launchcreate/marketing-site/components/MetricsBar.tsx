export type Metric = {
  value: string;
  label: string;
};

export default function MetricsBar({
  items,
}: {
  items: Metric[];
}) {
  return (
    <div className="rounded-2xl border border-black/10 bg-white/80 p-6 shadow-sm backdrop-blur">
      <div
        className={`grid gap-6 ${
          items.length === 4
            ? "grid-cols-2 sm:grid-cols-4"
            : items.length === 3
              ? "grid-cols-1 sm:grid-cols-3"
              : "grid-cols-2"
        }`}
      >
        {items.map((metric, idx) => (
          <div key={idx} className="text-center">
            <div className="text-2xl font-semibold tracking-tight sm:text-3xl">
              {metric.value}
            </div>
            <div className="mt-1 text-xs text-black/60">{metric.label}</div>
          </div>
        ))}
      </div>
    </div>
  );
}
