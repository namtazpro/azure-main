// Prison cost model — reconstruction of Prison Framework.xlsx (Outputs +
// Calculation sheets). Building areas come from the Calculation sheet. Cost
// rates, on-cost fees and quarterly indices are NOT stored in this file —
// they live encrypted in encryptedRates.ts and are decrypted at runtime with
// a user-supplied passphrase (see unlockRates below).

import { ENCRYPTED_RATES } from './encryptedRates';

export interface BuildingRow {
  name: string;
  gifa: number; // m²
}

export interface CostRow {
  description: string;
  ratePerM2: number;       // £ / m² (base build rate)
  effectiveRate: number;   // £ / m² (after on-cost factor + quarterly index)
  cost: number;            // £
}

export interface EstimateResult {
  prisoners: number;
  requiredGIFA: number;     // m²
  houseblocks: number;
  requiredAcres: number;
  programmeWeeks: number;
  startQuarter: string;
  midpointQuarter: string;  // quarter the index was picked from
  indexAdjustment: number;  // e.g. 1.045 = +4.5% inflation to midpoint
  onCostFactor: number;
  buildings: BuildingRow[];
  costs: CostRow[];
  total: number;
}

// --- Background sheet constants -------------------------------------------

const PRISONERS_PER_HB = 240;              // Background!C3

// Site area coefficient: Excel uses  acres = (prisoners × 143.5) / 4046.86
// where 143.5 (Background!C5) is site m² per prisoner and 4046.86 is
// square metres per acre.
const SITE_M2_PER_PRISONER = 143.5;
const M2_PER_ACRE = 4046.86;

// Programme durations (weeks) from Background sheet
const PROG_HB_WEEKS = 122;                 // Background!C7
const PROG_STAGGER_WEEKS = 4;              // Background!C8
const PROG_COMMISSIONING_WEEKS = 12;       // Background!C9

// Per-prisoner areas for buildings that scale linearly with capacity
// (Outputs sheet formulas =$B$2*Background!E<n>).
const ERH_OFFICES_PER_PRISONER    = 200  / 1440;   // E13
const ERH_VISITS_PER_PRISONER     = 1400 / 1440;   // E14
const CS_EDUCATION_PER_PRISONER   = 1500 / 1440;   // E17
const CS_GYM_PER_PRISONER         =  300 / 1440;   // E18

// Fixed-size buildings (independent of prisoner count)
const ERH_CORE_M2       = 3059;  // Background!C12
const SUPPORT_M2        =  770;  // C15
const CS_CORE_M2        = 3130;  // C16
const KITCHEN_M2        = 1926;  // C19
const CASU_M2           =  648;  // C21
const OPU_M2            = 6086;  // C23

// Workshop: 7257 m² baseline (at 6 HBs), +1200 m² per additional HB.
// Outputs!B19 = Background!C20 + ((B7 - 6) * 1200)
const WORKSHOP_BASE_M2         = 7257;   // C20
const WORKSHOP_BASELINE_HBS    = 6;
const WORKSHOP_M2_PER_EXTRA_HB = 1200;   // E20

// Houseblock: Outputs!B21 = (HBs - 1) × 6086
const HOUSEBLOCK_M2 = 6086;    // C22

// --- Encrypted-rate unlocking --------------------------------------------

interface OutputRate {
  description: string;
  ratePerM2: number;
  applyOnCost: boolean;
  applyIndex: boolean;
}
interface OnCostComponent { description: string; ratePerM2: number }
interface QuarterlyIndex  { quarter: string; index: number }

interface RateBundle {
  outputRates: OutputRate[];
  onCostComponents: OnCostComponent[];
  quarterlyIndices: QuarterlyIndex[];
  benchmarkQuarter?: string;
}

let CACHED_BUNDLE: RateBundle | null = null;

function base64ToBytes(b64: string): ArrayBuffer {
  const bin = atob(b64);
  const arr = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) arr[i] = bin.charCodeAt(i);
  return arr.buffer;
}

export async function unlockRates(passphrase: string): Promise<boolean> {
  try {
    const salt = base64ToBytes(ENCRYPTED_RATES.salt);
    const iv = base64ToBytes(ENCRYPTED_RATES.iv);
    const ciphertext = base64ToBytes(ENCRYPTED_RATES.ciphertext);

    const keyMaterial = await crypto.subtle.importKey(
      'raw',
      new TextEncoder().encode(passphrase),
      'PBKDF2',
      false,
      ['deriveKey']
    );
    const key = await crypto.subtle.deriveKey(
      { name: 'PBKDF2', salt, iterations: 100_000, hash: 'SHA-256' },
      keyMaterial,
      { name: 'AES-GCM', length: 256 },
      false,
      ['decrypt']
    );
    const plainBuf = await crypto.subtle.decrypt({ name: 'AES-GCM', iv }, key, ciphertext);
    const json = new TextDecoder().decode(plainBuf);
    const parsed = JSON.parse(json) as RateBundle;
    if (
      !Array.isArray(parsed.outputRates) ||
      !Array.isArray(parsed.onCostComponents) ||
      !Array.isArray(parsed.quarterlyIndices)
    ) {
      return false;
    }
    CACHED_BUNDLE = parsed;
    return true;
  } catch {
    return false;
  }
}

export function isUnlocked(): boolean {
  return CACHED_BUNDLE !== null;
}

/** Public list of start-on-site quarter labels, in order. */
export function availableStartQuarters(): string[] {
  if (!CACHED_BUNDLE) return [];
  return CACHED_BUNDLE.quarterlyIndices.map(q => q.quarter);
}

/** Default start quarter shown in the UI. */
export const DEFAULT_START_QUARTER = 'Q3 (2026)';

// --- Calculation ----------------------------------------------------------

export function calculateEstimate(
  prisoners: number,
  startQuarter: string = DEFAULT_START_QUARTER
): EstimateResult {
  if (!CACHED_BUNDLE) {
    throw new Error('Cost rates locked — call unlockRates() with the correct passphrase first.');
  }
  const bundle = CACHED_BUNDLE;

  const houseblocks = Math.max(1, Math.ceil(prisoners / PRISONERS_PER_HB));

  // Building GIFAs — direct port of Outputs!B11:B22 formulas.
  // CASU and OPU each add a second cluster once HBs ≥ 12 (Excel: *IF(HB>=12,2,1)).
  const casuOpuMultiplier = houseblocks >= 12 ? 2 : 1;
  const buildings: BuildingRow[] = [
    { name: 'ERH (core)',                   gifa: ERH_CORE_M2 },
    { name: 'ERH (offices)',                gifa: prisoners * ERH_OFFICES_PER_PRISONER },
    { name: 'ERH (visits hall)',            gifa: prisoners * ERH_VISITS_PER_PRISONER },
    { name: 'Support',                      gifa: SUPPORT_M2 },
    { name: 'Central services (core)',      gifa: CS_CORE_M2 },
    { name: 'Central services (education)', gifa: prisoners * CS_EDUCATION_PER_PRISONER },
    { name: 'Central services (gym)',       gifa: prisoners * CS_GYM_PER_PRISONER },
    { name: 'Kitchen',                      gifa: KITCHEN_M2 },
    { name: 'Workshop',                     gifa: WORKSHOP_BASE_M2 + (houseblocks - WORKSHOP_BASELINE_HBS) * WORKSHOP_M2_PER_EXTRA_HB },
    { name: 'CASU',                         gifa: CASU_M2 * casuOpuMultiplier },
    { name: 'Houseblock',                   gifa: (houseblocks - 1) * HOUSEBLOCK_M2 },
    { name: 'OPU',                          gifa: OPU_M2 * casuOpuMultiplier }
  ];

  const requiredGIFA = buildings.reduce((sum, b) => sum + b.gifa, 0);
  const requiredAcres = (prisoners * SITE_M2_PER_PRISONER) / M2_PER_ACRE;
  const programmeWeeks =
    PROG_HB_WEEKS +
    Math.max(0, houseblocks - 1) * PROG_STAGGER_WEEKS +
    PROG_COMMISSIONING_WEEKS;

  // On-cost factor = SUM(onCostComponents) / SUM(outputRates where applyOnCost) + 1
  // (Excel: C47 = C45/C46 + 1)
  const onCostSum = bundle.onCostComponents.reduce((s, c) => s + c.ratePerM2, 0);
  const buildRateSum = bundle.outputRates
    .filter(r => r.applyOnCost)
    .reduce((s, r) => s + r.ratePerM2, 0);
  const onCostFactor = buildRateSum > 0 ? onCostSum / buildRateSum + 1 : 1;

  // Quarterly indices adjustment — Excel:
  //   INDEX($D$51:$D$84, MATCH(startQ, $B$51:$B$84, 0) + ROUND(programme/2/13, 0))
  // The MATCH is 1-indexed, so a 0-based offset is (matchIndex + roundedQtrs) - 1.
  // If the offset overshoots the table, clamp to the last quarter (defensive).
  // Base index = benchmarkQuarter (validated datum, e.g. Q2 (2023) = 383);
  // falls back to the first quarter if no benchmark supplied.
  const qList = bundle.quarterlyIndices;
  const benchmarkIdx = bundle.benchmarkQuarter
    ? qList.findIndex(q => q.quarter === bundle.benchmarkQuarter)
    : 0;
  const baseIndexValue = qList[benchmarkIdx >= 0 ? benchmarkIdx : 0]?.index ?? 1;
  const startIdx = qList.findIndex(q => q.quarter === startQuarter);
  const startMatch = startIdx >= 0 ? startIdx : 0;
  const midpointQuarters = Math.round(programmeWeeks / 2 / 13);
  const rawOffset = startMatch + midpointQuarters;
  const lookupIdx = Math.min(Math.max(0, rawOffset), qList.length - 1);
  const midpointQuarter = qList[lookupIdx]?.quarter ?? startQuarter;
  const indexAdjustment = baseIndexValue > 0
    ? (qList[lookupIdx].index / baseIndexValue)
    : 1;

  const costs: CostRow[] = bundle.outputRates.map(r => {
    const oc = r.applyOnCost ? onCostFactor : 1;
    const idx = r.applyIndex ? indexAdjustment : 1;
    const effectiveRate = r.ratePerM2 * oc * idx;
    return {
      description: r.description,
      ratePerM2: r.ratePerM2,
      effectiveRate,
      cost: effectiveRate * requiredGIFA
    };
  });

  const total = costs.reduce((sum, c) => sum + c.cost, 0);

  return {
    prisoners,
    requiredGIFA,
    houseblocks,
    requiredAcres,
    programmeWeeks,
    startQuarter,
    midpointQuarter,
    indexAdjustment,
    onCostFactor,
    buildings,
    costs,
    total
  };
}
