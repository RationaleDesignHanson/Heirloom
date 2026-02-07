export type TeamMember = {
  name: string;
  role: string;
  bio: string;
  skills?: string[];
};

export default function TeamSection({
  title,
  subtitle,
  members,
}: {
  title: string;
  subtitle?: string;
  members: TeamMember[];
}) {
  return (
    <div>
      <h2 className="text-2xl font-semibold tracking-tight">{title}</h2>
      {subtitle && (
        <p className="mt-2 max-w-2xl text-sm text-black/60">{subtitle}</p>
      )}
      <div className="mt-8 grid gap-6 sm:grid-cols-1 lg:grid-cols-2">
        {members.map((member, idx) => (
          <div
            key={idx}
            className="rounded-2xl border border-black/10 bg-white/80 p-6 shadow-sm backdrop-blur"
          >
            <div className="flex items-start gap-4">
              <div className="flex h-14 w-14 shrink-0 items-center justify-center rounded-2xl border border-black/10 bg-[var(--cream)] text-xl font-semibold text-black/40">
                {member.name
                  .split(" ")
                  .map((n) => n[0])
                  .join("")}
              </div>
              <div>
                <div className="text-base font-semibold">{member.name}</div>
                <div className="text-sm text-black/60">{member.role}</div>
              </div>
            </div>
            <p className="mt-4 text-sm leading-relaxed text-black/70">
              {member.bio}
            </p>
            {member.skills && member.skills.length > 0 && (
              <div className="mt-4 flex flex-wrap gap-2">
                {member.skills.map((skill, sidx) => (
                  <span
                    key={sidx}
                    className="inline-block rounded-full border border-black/10 bg-[var(--cream)] px-2.5 py-0.5 text-xs text-black/60"
                  >
                    {skill}
                  </span>
                ))}
              </div>
            )}
          </div>
        ))}
      </div>
    </div>
  );
}
