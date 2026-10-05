// ============================================================
//  Digital-VLSI Innovation Hub - settings (edit only this file)
// ============================================================

// 1) Supabase: the SAME project as Digital Design Explorer (copied from its supabase-config.js),
//    so students and teachers use their Explorer accounts here.
const SUPABASE_URL      = "https://ibtjvvjfgladbjsovcdv.supabase.co";
const SUPABASE_ANON_KEY = "sb_publishable_KOZ3cU73b5rU2Ren5I6MRQ_tAnC6zuD";

// 2) Digital Design Explorer (one-way links only)
const EXPLORER_BASE = "https://padmarmysuru.github.io/DigitalDesignExplorer/";

// 3) Team rules (also enforced in Supabase - change both if you edit)
const TEAM_MIN = 2;
const TEAM_MAX = 4;

// 4) Learning topics -> Explorer pages (checked against the Explorer files).
//    level: the Explorer level the page belongs to. Lock badges are read LIVE from
//           Explorer's access-control.js, so releasing a level there updates the Hub too.
//    alt:   an always-open Level 1 lab section, used while the main level is locked.
const EXPLORER_TOPICS = {
  "Logic Gates":            { page: "logic-gates.html",              level: 1 },
  "Boolean Algebra":        { page: "digital-logic-lab.html#exp1",   level: 1 },
  "K-Maps":                 { page: "kmap.html",                     level: 1 },
  "Adders":                 { page: "full-adder.html",               level: 1 },
  "MUX":                    { page: "digital-logic-lab.html#exp5",   level: 1 },
  "Encoder":                { page: "digital-logic-lab.html#exp5",   level: 1 },
  "Priority Encoder":       { page: "digital-logic-lab.html#exp5",   level: 1 },
  "Decoder":                { page: "digital-logic-lab.html#exp6",   level: 1 },
  "Comparator":             { page: "digital-logic-lab.html#exp6",   level: 1 },
  "Digital Logic Lab":      { page: "digital-logic-lab.html",        level: 1 },
  "Verilog":                { page: "verilog.html",                  level: 1 },
  "Flip-Flops":             { page: "sequential-circuits.html",      level: 2, alt: "digital-logic-lab.html#exp7" },
  "Counters":               { page: "counters.html",                 level: 2, alt: "digital-logic-lab.html#exp8" },
  "Registers":              { page: "registers.html",                level: 2 },
  "FSM":                    { page: "state-machines.html",           level: 2 },
  "VLSI Testing":           { page: "level5-dashboard.html",         level: 5 },
  "DFT & BIST":             { page: "level5-module6.html",           level: 5 },
  "SystemVerilog":          { page: "level6.html",                   level: 6 },
  "VLSI Arithmetic":        { page: "level7-module2.html",           level: 7 },
  "VLSI Memory":            { page: "level7-module4.html",           level: 7 },
  "Low-Power Design":       { page: "level8-module8.html",           level: 8 },
  "RTL Design":             { page: "level9.html",                   level: 9 },
  "Verification":           { page: "level11.html",                  level: 11 },
  "Processor Architecture": { page: "level13.html",                  level: 13 },
  "Pipelining":             { page: "level13-module2.html",          level: 13 },
  "Branch Prediction":      { page: "level13-module3.html",          level: 13 },
  "Cache Architecture":     { page: "level13-module7.html",          level: 13 },
  "AI/ML for VLSI":         { page: "level14.html",                  level: 14 }
};
// Used only if Explorer's access-control.js cannot be read (levels released right now)
const EXPLORER_RELEASED_FALLBACK = [1];

// 5) Milestones every team follows (keep 7 items; the database stores 7)
const MILESTONES = [
  "Problem definition & objectives",
  "Prerequisite learning",
  "Architecture & block design",
  "RTL implementation",
  "Simulation & verification",
  "Testing / results",
  "Documentation & final review"
];
