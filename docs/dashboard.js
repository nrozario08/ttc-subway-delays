// Draws the dashboard from the data in data.js (window.DASH).
// Colours come from the CSS variables in index.html so light/dark mode just works.

const D = window.DASH;

const css = (name) => getComputedStyle(document.documentElement).getPropertyValue(name).trim();
const fmt = (n) => Number(n).toLocaleString("en-CA");
const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
const WEEKDAYS = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];

function hourLabel(h) {
  const suffix = h < 12 ? "am" : "pm";
  const twelve = h % 12 === 0 ? 12 : h % 12;
  return `${twelve}${suffix}`;
}

// ---------- shared plotly styling ----------

function baseLayout(extra) {
  const ink2 = css("--ink-2");
  return Object.assign({
    paper_bgcolor: "rgba(0,0,0,0)",
    plot_bgcolor: "rgba(0,0,0,0)",
    font: { family: "system-ui, -apple-system, 'Segoe UI', sans-serif", color: ink2, size: 12 },
    margin: { l: 56, r: 16, t: 8, b: 44 },
    hoverlabel: {
      bgcolor: css("--surface"),
      bordercolor: css("--axis"),
      font: { color: css("--ink"), size: 12 },
    },
    xaxis: { gridcolor: css("--grid"), linecolor: css("--axis"), zeroline: false, tickfont: { color: css("--ink-3") } },
    yaxis: { gridcolor: css("--grid"), linecolor: css("--axis"), zeroline: false, tickfont: { color: css("--ink-3") } },
  }, extra);
}

const CONFIG = { displayModeBar: false, responsive: true };

function draw(id, traces, layout) {
  Plotly.react(id, traces, baseLayout(layout), CONFIG);
}

// ---------- KPI tiles ----------

function renderKpis() {
  const k = D.kpis[0];
  const tiles = [
    ["Incidents logged", fmt(k.incidents), `${k.first_date} to ${k.last_date}`],
    ["Total delay time", `${fmt(k.delay_hours)} hrs`, "sum of recorded delay minutes"],
    ["Average delay", `${k.avg_minutes_per_delay} min`, "only incidents that caused a delay"],
    ["Incidents with a delay", `${Math.round(100 * k.delayed_incidents / k.incidents)}%`, "the rest logged 0 minutes"],
  ];
  document.getElementById("kpis").innerHTML = tiles.map(([label, value, note]) =>
    `<div class="kpi"><div class="label">${label}</div><div class="value">${value}</div><div class="note">${note}</div></div>`
  ).join("");
}

// ---------- charts ----------

function renderYearly() {
  const rows = D.yearly;
  const full = rows.filter((r) => !r.partial_year);
  const peak = full.reduce((a, b) => (b.delay_hours > a.delay_hours ? b : a));
  const first = full[0];
  document.getElementById("t-yearly").textContent =
    `${peak.year} was the worst full year at ${fmt(peak.delay_hours)} hours, up ${Math.round(100 * (peak.delay_hours / first.delay_hours - 1))}% on ${first.year}. 2026 runs January to August only.`;

  draw("c-yearly", [{
    type: "bar",
    x: rows.map((r) => String(r.year)),
    y: rows.map((r) => r.delay_hours),
    marker: {
      color: rows.map((r) => css("--s1")),
      opacity: rows.map((r) => (r.partial_year ? 0.45 : 1)),
    },
    customdata: rows.map((r) => [fmt(r.incidents), r.partial_year ? " (Jan to Aug only)" : ""]),
    hovertemplate: "<b>%{x}</b>%{customdata[1]}<br>%{y:,.0f} delay hours<br>%{customdata[0]} incidents<extra></extra>",
  }], {
    // category axis so every year gets a label, not every other one
    xaxis: { type: "category", linecolor: css("--axis"), tickfont: { color: css("--ink-3") } },
    yaxis: { title: { text: "Delay hours" }, gridcolor: css("--grid"), zeroline: false, tickfont: { color: css("--ink-3") } },
    bargap: 0.35,
  });
}

function renderHourly() {
  const rows = D.hourly;
  const top = rows.reduce((a, b) => (b.delay_hours > a.delay_hours ? b : a));
  const total = rows.reduce((s, r) => s + r.delay_hours, 0);
  const rush = rows.filter((r) => (r.hour >= 15 && r.hour <= 18) || (r.hour >= 6 && r.hour <= 9))
                   .reduce((s, r) => s + r.delay_hours, 0);
  document.getElementById("t-hourly").textContent =
    `Peaks around ${hourLabel(top.hour)}. The two rush windows (6 to 9am, 3 to 6pm) hold ${Math.round(100 * rush / total)}% of all delay hours. Almost nothing is logged between 3 and 5am when the subway is closed.`;

  draw("c-hourly", [{
    type: "bar",
    x: rows.map((r) => r.hour),
    y: rows.map((r) => r.delay_hours),
    marker: { color: css("--s1") },
    customdata: rows.map((r) => [hourLabel(r.hour), fmt(r.incidents)]),
    hovertemplate: "<b>%{customdata[0]}</b><br>%{y:,.0f} delay hours<br>%{customdata[1]} incidents<extra></extra>",
  }], {
    xaxis: { tickmode: "array", tickvals: [0, 3, 6, 9, 12, 15, 18, 21], ticktext: ["12am", "3am", "6am", "9am", "12pm", "3pm", "6pm", "9pm"],
             linecolor: css("--axis"), tickfont: { color: css("--ink-3") } },
    yaxis: { title: { text: "Delay hours" }, gridcolor: css("--grid"), zeroline: false, tickfont: { color: css("--ink-3") } },
    bargap: 0.25,
  });
}

function renderHeatmap() {
  const rows = D.weekday_hour;
  const z = WEEKDAYS.map((day) =>
    Array.from({ length: 24 }, (_, h) => {
      const hit = rows.find((r) => r.weekday === day && r.hour === h);
      return hit ? hit.avg_incidents : 0;
    })
  );
  const peak = rows.reduce((a, b) => (b.avg_incidents > a.avg_incidents ? b : a));
  document.getElementById("t-heat").textContent =
    `The busiest single slot is ${peak.weekday} at ${hourLabel(peak.hour)} (${peak.avg_incidents.toFixed(1)} incidents on an average day), which looks like the start of Sunday service. Weekdays peak at the 6am start-up and again in the afternoon rush; Saturdays and the rest of Sunday are flatter.`;

  const dark = css("--surface") !== "#fcfcfb";
  const scale = dark
    ? [[0, "#16263a"], [0.5, "#256abf"], [1, "#9ec5f4"]]
    : [[0, "#e8f1fc"], [0.35, "#86b6ef"], [0.7, "#256abf"], [1, "#0d366b"]];

  draw("c-heat", [{
    type: "heatmap",
    x: Array.from({ length: 24 }, (_, h) => hourLabel(h)),
    y: WEEKDAYS,
    z: z,
    colorscale: scale,
    xgap: 2, ygap: 2,
    colorbar: { title: { text: "incidents" }, thickness: 12, len: 0.9, tickfont: { color: css("--ink-3") }, outlinewidth: 0 },
    hovertemplate: "<b>%{y}, %{x}</b><br>%{z:.1f} incidents on an average day<extra></extra>",
  }], {
    margin: { l: 90, r: 10, t: 8, b: 44 },
    yaxis: { autorange: "reversed", tickfont: { color: css("--ink-2") }, showgrid: false },
    xaxis: { tickfont: { color: css("--ink-3") }, showgrid: false, tickangle: 0, nticks: 12 },
  });
}

function renderMonthly() {
  const rows = D.monthly;
  const hi = rows.reduce((a, b) => (b.avg_delay_minutes_per_day > a.avg_delay_minutes_per_day ? b : a));
  const lo = rows.reduce((a, b) => (b.avg_delay_minutes_per_day < a.avg_delay_minutes_per_day ? b : a));
  document.getElementById("t-monthly").textContent =
    `${MONTHS[hi.month - 1]} is the worst month (${hi.avg_delay_minutes_per_day} min/day) and ${MONTHS[lo.month - 1]} the best (${lo.avg_delay_minutes_per_day}), a gap of ${Math.round(100 * (hi.avg_delay_minutes_per_day / lo.avg_delay_minutes_per_day - 1))}%. Winter months are consistently worse than late summer.`;

  draw("c-monthly", [{
    type: "scatter",
    mode: "lines+markers",
    x: rows.map((r) => MONTHS[r.month - 1]),
    y: rows.map((r) => r.avg_delay_minutes_per_day),
    line: { color: css("--s1"), width: 2 },
    marker: { color: css("--s1"), size: 8, line: { color: css("--surface"), width: 2 } },
    hovertemplate: "<b>%{x}</b><br>%{y:.1f} delay minutes per day<extra></extra>",
  }], {
    yaxis: { title: { text: "Avg delay min / day" }, gridcolor: css("--grid"), zeroline: false, rangemode: "tozero", tickfont: { color: css("--ink-3") } },
  });
}

// horizontal bar helper used by lines, stations and causes
function hbar(id, labels, values, hover, leftMargin) {
  draw(id, [{
    type: "bar",
    orientation: "h",
    y: labels,
    x: values,
    marker: { color: css("--s1") },
    customdata: hover,
    hovertemplate: "<b>%{y}</b><br>%{x:,.0f} delay hours<br>%{customdata}<extra></extra>",
    text: values.map((v) => fmt(v)),
    textposition: "outside",
    textfont: { color: css("--ink-2"), size: 11 },
    cliponaxis: false,
  }], {
    margin: { l: leftMargin, r: 48, t: 8, b: 36 },
    yaxis: { autorange: "reversed", tickfont: { color: css("--ink-2") }, showgrid: false, linecolor: css("--axis") },
    xaxis: { title: { text: "Delay hours" }, gridcolor: css("--grid"), zeroline: false, tickfont: { color: css("--ink-3") } },
    bargap: 0.3,
  });
}

function titleCase(s) {
  return s.toLowerCase().replace(/(^|[\s\-'(/])([a-z])/g, (m, a, b) => a + b.toUpperCase());
}

function renderLines() {
  const rows = D.lines;
  const total = rows.reduce((s, r) => s + r.delay_hours, 0);
  document.getElementById("t-lines").textContent =
    `${rows[0].line.split(" ").slice(0, 2).join(" ")} accounts for ${Math.round(100 * rows[0].delay_hours / total)}% of delay hours. The Scarborough RT has few incidents but the longest average delay (${rows.find((r) => r.line.includes("Scarborough")).avg_minutes_per_delay} min).`;
  hbar("c-lines", rows.map((r) => r.line), rows.map((r) => r.delay_hours),
       rows.map((r) => `${fmt(r.incidents)} incidents, ${r.avg_minutes_per_delay} min avg delay`), 190);
}

function renderStations() {
  const rows = D.top_stations;
  document.getElementById("t-stations").textContent =
    `${titleCase(rows[0].station)} leads with ${fmt(rows[0].delay_hours)} hours. Delays are spread out, though: the top 10 stations make up under a third of station delay time.`;
  hbar("c-stations", rows.map((r) => titleCase(r.station)), rows.map((r) => r.delay_hours),
       rows.map((r) => `${fmt(r.incidents)} incidents`), 150);
}

function renderCauses() {
  const rows = D.top_causes;
  document.getElementById("t-causes").textContent =
    `${titleCase(rows[0].cause)} is the single biggest cause at ${fmt(rows[0].delay_hours)} hours.`;
  // long descriptions need wrapping or they eat the whole chart
  const wrap = (s) => {
    const words = titleCase(s).split(" ");
    const lines = [""];
    words.forEach((w) => {
      if ((lines[lines.length - 1] + " " + w).trim().length > 26) lines.push(w);
      else lines[lines.length - 1] = (lines[lines.length - 1] + " " + w).trim();
    });
    return lines.join("<br>");
  };
  hbar("c-causes", rows.map((r) => wrap(r.cause)), rows.map((r) => r.delay_hours),
       rows.map((r) => `${fmt(r.incidents)} incidents`), 190);
}

function renderCategories() {
  const rows = D.causes_by_year;
  const years = [...new Set(rows.map((r) => r.year))];
  const order = [
    "Medical, weather and miscellaneous",
    "Security and disorderly passengers",
    "Infrastructure (signals, track, power)",
    "Operator / transportation",
    "Vehicle / equipment",
  ];
  const colors = [css("--s1"), css("--s2"), css("--s3"), css("--s4"), css("--s5")];

  const yearTotals = {};
  rows.forEach((r) => { yearTotals[r.year] = (yearTotals[r.year] || 0) + r.delay_hours; });
  const share = (cat, y) => {
    const hit = rows.find((r) => r.year === y && r.category === cat);
    return hit ? hit.delay_hours : 0;
  };
  const secShare = (y) => 100 * share(order[1], y) / yearTotals[y];
  const first = years[0];
  const last = years[years.length - 1];
  const peakYear = years.reduce((a, b) => (secShare(b) > secShare(a) ? b : a));
  const equip = years.map((y) => share(order[4], y));
  document.getElementById("t-cats").textContent =
    `Security incidents and disorderly passengers went from ${Math.round(secShare(first))}% of delay hours in ${first} to ${Math.round(secShare(peakYear))}% in ${peakYear}, then eased to ${Math.round(secShare(last))}% in ${last}. Equipment delays stayed flat at ${Math.min(...equip)} to ${Math.max(...equip)} hours a year.`;

  const traces = order.map((cat, i) => ({
    type: "bar",
    name: cat,
    x: years.map(String),
    y: years.map((y) => share(cat, y)),
    marker: { color: colors[i], line: { color: css("--surface"), width: 2 } },
    customdata: years.map((y) => Math.round(100 * share(cat, y) / yearTotals[y])),
    hovertemplate: `<b>${cat}</b><br>%{x}: %{y:,.0f} hours (%{customdata}% of the year)<extra></extra>`,
  }));

  draw("c-cats", traces, {
    barmode: "stack",
    bargap: 0.3,
    margin: { l: 56, r: 16, t: 8, b: 110 },
    xaxis: { type: "category", linecolor: css("--axis"), tickfont: { color: css("--ink-3") } },
    yaxis: { title: { text: "Delay hours" }, gridcolor: css("--grid"), zeroline: false, tickfont: { color: css("--ink-3") } },
    legend: { orientation: "h", yanchor: "top", y: -0.16, x: 0, font: { color: css("--ink-2"), size: 12 } },
  });
}

function renderAll() {
  renderKpis();
  renderYearly();
  renderHourly();
  renderHeatmap();
  renderMonthly();
  renderLines();
  renderStations();
  renderCauses();
  renderCategories();
}

renderAll();

// redraw if the viewer switches between light and dark
window.matchMedia("(prefers-color-scheme: dark)").addEventListener("change", renderAll);
