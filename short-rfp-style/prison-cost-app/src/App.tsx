import { useEffect, useMemo, useState } from 'react';
import {
  calculateEstimate,
  EstimateResult,
  unlockRates,
  availableStartQuarters,
  DEFAULT_START_QUARTER
} from './model';

const gbp0 = new Intl.NumberFormat('en-GB', {
  style: 'currency', currency: 'GBP', maximumFractionDigits: 0
});
const gbp2 = new Intl.NumberFormat('en-GB', {
  style: 'currency', currency: 'GBP', minimumFractionDigits: 2, maximumFractionDigits: 2
});
const num0 = new Intl.NumberFormat('en-GB', { maximumFractionDigits: 0 });
const num2 = new Intl.NumberFormat('en-GB', { minimumFractionDigits: 2, maximumFractionDigits: 2 });

// Site render images. Filenames end in `_<houseblocks>.jpg`.
// If no image exists for the given HB count, fall back to the _6 image.
const SITE_IMAGES: Record<number, string> = {
  4: '/pic/Houseblocks Layout_4.jpg',
  5: '/pic/Houseblocks Layout_5.jpg',
  6: '/pic/Houseblocks Layout_6.jpg',
  7: '/pic/Houseblocks Layout_7.jpg',
  8: '/pic/Houseblocks Layout_8.jpg',
  9: '/pic/Houseblocks Layout_9.jpg',
  10: '/pic/Houseblocks Layout_10.jpg',
  11: '/pic/Houseblocks Layout_11.jpg',
  12: '/pic/Houseblocks Layout_12.jpg'
};
const FALLBACK_IMAGE = SITE_IMAGES[6];

function siteImageFor(houseblocks: number): { src: string; matched: boolean } {
  const src = SITE_IMAGES[houseblocks];
  return src ? { src, matched: true } : { src: FALLBACK_IMAGE, matched: false };
}

function KierMark({ variant = 'dark' }: { variant?: 'dark' | 'light' }) {
  // Uses the licensed Kier Group logo from public/kiergroup.png.
  // On the navy topbar (variant='dark') the logo sits inside a small white
  // panel so the black KIER wordmark remains legible.
  return (
    <span className={`kier-mark kier-mark--${variant}`}>
      <img src="/kiergroup.png" alt="Kier Group" />
    </span>
  );
}

export default function App() {
  const [unlocked, setUnlocked] = useState<boolean>(false);
  const [input, setInput] = useState<string>('1440');
  const [startQuarter, setStartQuarter] = useState<string>(DEFAULT_START_QUARTER);
  const [result, setResult] = useState<EstimateResult | null>(null);
  const [error, setError] = useState<string>('');

  const quarters = useMemo(() => (unlocked ? availableStartQuarters() : []), [unlocked]);

  // Preload all site images once the app renders so they are in the browser
  // cache before the first Calculate click (fixes: image sometimes missing
  // on the first render because network fetch races the DOM insert).
  useEffect(() => {
    Object.values(SITE_IMAGES).forEach(src => {
      const img = new Image();
      img.src = src;
    });
  }, []);

  const handleCalculate = () => {
    const n = Number(input);
    if (!Number.isFinite(n) || n <= 0 || !Number.isInteger(n)) {
      setError('Enter a whole positive number of prisoners.');
      setResult(null);
      return;
    }
    if (n > 20000) {
      setError('Please enter a value between 1 and 20,000 prisoners.');
      setResult(null);
      return;
    }
    setError('');
    setResult(calculateEstimate(n, startQuarter));
  };

  const handleKey = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Enter') handleCalculate();
  };

  const handlePrint = () => window.print();

  if (!unlocked) {
    return <PasscodeGate onUnlock={() => setUnlocked(true)} />;
  }

  return (
    <div className="page">
      <header className="topbar">
        <div className="brand">
          <KierMark variant="dark" />
          <div>
            <div className="brand-name">Kier Group</div>
            <div className="brand-tag">Custodial Estate — Feasibility Estimator</div>
          </div>
        </div>
        <div className="meta">
          <div><strong>Benchmark:</strong> UK Gov new-build reference</div>
          <div>Prepared: {new Date().toLocaleDateString('en-GB')}</div>
          <div className="demo-only">For demo purpose only</div>
        </div>
      </header>

      <main>
        <section className="input-card">
          <h1>New prison capital cost estimate</h1>
          <p className="lead">
            Enter the planned prisoner capacity to generate an indicative capital cost,
            programme, land requirement and building schedule for a new establishment.
          </p>

          <div className="input-row">
            <div className="field">
              <label htmlFor="prisoners">Number of prisoners</label>
              <input
                id="prisoners"
                type="number"
                inputMode="numeric"
                min={1}
                step={1}
                value={input}
                onChange={e => setInput(e.target.value)}
                onKeyDown={handleKey}
                placeholder="e.g. 1440"
              />
            </div>
            <div className="field">
              <label htmlFor="startQuarter">Start on site</label>
              <select
                id="startQuarter"
                value={startQuarter}
                onChange={e => setStartQuarter(e.target.value)}
              >
                {quarters.map(q => (
                  <option key={q} value={q}>{q}</option>
                ))}
              </select>
            </div>
            <div className="actions">
              <button className="primary" onClick={handleCalculate}>Calculate</button>
              {result && (
                <button className="secondary" onClick={handlePrint}>Print / PDF</button>
              )}
            </div>
          </div>
          {error && <div className="error" role="alert">{error}</div>}
        </section>

        {result && <Results r={result} />}
      </main>

      <footer className="footnote">
        This core build cost estimate and indicative build programme have been
        produced in good faith, using sample data, and is not intended at this
        time to be a representation or warranty of any kind.
      </footer>
    </div>
  );
}

function PasscodeGate({ onUnlock }: { onUnlock: () => void }) {
  const [pass, setPass] = useState('');
  const [err, setErr] = useState('');
  const [busy, setBusy] = useState(false);

  const submit = async () => {
    if (busy) return;
    setBusy(true);
    setErr('');
    const ok = await unlockRates(pass);
    setBusy(false);
    if (ok) {
      onUnlock();
    } else {
      setErr('Incorrect passcode.');
      setPass('');
    }
  };

  const onKey = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Enter') submit();
  };

  return (
    <div className="gate">
      <div className="gate-card">
        <KierMark variant="light" />
        <h1>Kier Group</h1>
        <p className="gate-tag">Custodial Estate — Feasibility Estimator</p>
        <p className="gate-lead">Restricted access. Enter the passcode to continue.</p>
        <input
          type="password"
          autoFocus
          value={pass}
          onChange={e => setPass(e.target.value)}
          onKeyDown={onKey}
          placeholder="Passcode"
          aria-label="Passcode"
        />
        <button className="primary" onClick={submit} disabled={busy || !pass}>
          {busy ? 'Unlocking…' : 'Unlock'}
        </button>
        {err && <div className="error" role="alert">{err}</div>}
      </div>
    </div>
  );
}

function Results({ r }: { r: EstimateResult }) {
  const img = siteImageFor(r.houseblocks);
  return (
    <>
      <section className="kpis" aria-label="Key metrics">
        <Kpi label="Prisoners" value={num0.format(r.prisoners)} />
        <Kpi label="Required GIFA" value={`${num0.format(r.requiredGIFA)} m²`} />
        <Kpi label="Houseblocks" value={num0.format(r.houseblocks)} />
        <Kpi label="Site area" value={`${num0.format(r.requiredAcres)} acres`} />
        <Kpi label="Build Programme" value={`${num0.format(r.programmeWeeks)} weeks`} />
        <Kpi label="Start on site" value={r.startQuarter} />
        <Kpi label="Core Build Cost Estimate" value={gbp0.format(r.total)} highlight />
      </section>

      <section className="tables">
        <div className="table-card">
          <h2>Accommodation schedule</h2>
          <table>
            <thead>
              <tr>
                <th>Building</th>
                <th className="num">GIFA (m²)</th>
              </tr>
            </thead>
            <tbody>
              {r.buildings.map(b => (
                <tr key={b.name}>
                  <td>{b.name}</td>
                  <td className="num">{num0.format(b.gifa)}</td>
                </tr>
              ))}
            </tbody>
            <tfoot>
              <tr>
                <th>Total GIFA</th>
                <th className="num">{num0.format(r.requiredGIFA)}</th>
              </tr>
            </tfoot>
          </table>
        </div>

        <div className="table-card">
          <h2>Cost plan</h2>
          <table>
            <thead>
              <tr>
                <th>Description</th>
                <th className="num">Rate £/m²</th>
                <th className="num">Cost</th>
              </tr>
            </thead>
            <tbody>
              {r.costs.map(c => {
                const excluded = c.effectiveRate === 0;
                return (
                  <tr key={c.description}>
                    <td>{c.description}</td>
                    <td className="num">{excluded ? 'Excluded' : num2.format(c.effectiveRate)}</td>
                    <td className="num">{excluded ? 'Excluded' : gbp2.format(c.cost)}</td>
                  </tr>
                );
              })}
              <tr>
                <td>Abnormal, Site Influences &amp; Specific Requirements</td>
                <td className="num">Excluded</td>
                <td className="num">Excluded</td>
              </tr>
            </tbody>
            <tfoot>
              <tr>
                <th colSpan={2}>TOTAL</th>
                <th className="num">{gbp2.format(r.total)}</th>
              </tr>
            </tfoot>
          </table>
        </div>
      </section>

      <section className="site-visual">
        <h2>Indicative site layout — {num0.format(r.houseblocks)} houseblock{r.houseblocks === 1 ? '' : 's'}</h2>
        <img
          src={img.src}
          alt={`Site visualisation for a prison with ${r.houseblocks} houseblocks`}
          loading="eager"
          decoding="sync"
        />
        {!img.matched && (
          <p className="visual-note">
            No dedicated visualisation is available for {num0.format(r.houseblocks)} houseblocks —
            showing the 6-houseblock reference layout for illustration.
          </p>
        )}
      </section>
    </>
  );
}

function Kpi({ label, value, highlight }: { label: string; value: string; highlight?: boolean }) {
  return (
    <div className={`kpi${highlight ? ' kpi-highlight' : ''}`}>
      <div className="kpi-label">{label}</div>
      <div className="kpi-value">{value}</div>
    </div>
  );
}
