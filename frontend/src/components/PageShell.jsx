export default function PageShell({ title, subtitle, children, actions }) {
  return (
    <section className="page-shell">
      <div className="page-heading">
        <div>
          <p className="eyebrow">DeFi Super-App</p>
          <h1>{title}</h1>
          <p className="subtitle">{subtitle}</p>
        </div>
        {actions ? <div className="page-actions">{actions}</div> : null}
      </div>
      {children}
    </section>
  );
}
