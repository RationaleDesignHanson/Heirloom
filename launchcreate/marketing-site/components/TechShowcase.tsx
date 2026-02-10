export type TechPillar = {
  title: string;
  body: string;
  detail: string;
  icon: string;
};

export default function TechShowcase({
  title,
  subtitle,
  items,
}: {
  title: string;
  subtitle?: string;
  items: TechPillar[];
}) {
  return (
    <div>
      <h2 className="text-2xl font-semibold tracking-tight">{title}</h2>
      {subtitle && (
        <p className="mt-2 max-w-2xl text-sm text-black/60">{subtitle}</p>
      )}
      <div className="mt-8 grid gap-6 sm:grid-cols-2">
        {items.map((pillar, idx) => (
          <div
            key={idx}
            className="group rounded-2xl border border-black/10 bg-white/80 p-6 shadow-sm backdrop-blur transition-shadow hover:shadow-md"
          >
            <div className="flex items-start gap-4">
              <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl border border-black/10 bg-[var(--cream)] text-lg">
                {pillar.icon}
              </div>
              <div>
                <div className="text-base font-semibold">{pillar.title}</div>
                <p className="mt-1 text-sm text-black/70">{pillar.body}</p>
                <p className="mt-3 text-xs leading-relaxed text-black/50">
                  {pillar.detail}
                </p>
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
