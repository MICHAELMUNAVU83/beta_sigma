// Extracts the discovery question bank from the PRD prototype HTML into JSON
// consumed by priv/repo/seeds/discovery.exs.
//
//   node scripts/extract_discovery_bank.mjs
//
// Re-run this whenever project-docs/html/prd-discovery-workspace.html changes.
import { readFileSync, writeFileSync } from "node:fs";

const HTML = "project-docs/html/prd-discovery-workspace.html";
const OUT = "priv/discovery/question_bank.json";

const html = readFileSync(HTML, "utf8");
const start = html.indexOf("const yesNo = ");
const end = html.indexOf('const storageKey = "betasigma');

if (start === -1 || end === -1) {
  throw new Error("Could not locate the question bank in " + HTML);
}

// The slice covers q(), the `data` literal, systemProfiles,
// systemDiscoveryModules() and the loop that prepends/appends the
// system-discovery modules to every department.
const source = html.slice(start, end);
const bank = new Function(`${source}\nreturn data;`)();

const scopes = Object.entries(bank).map(([scope, departments]) => ({
  scope,
  departments: departments.map((department, departmentIndex) => ({
    slug: department.id,
    name: department.name,
    summary: department.summary,
    position: departmentIndex,
    modules: department.modules.map((module, moduleIndex) => ({
      slug: module.id,
      name: module.name,
      intro: module.intro ?? null,
      position: moduleIndex,
      questions: module.questions.map((question, questionIndex) => ({
        slug: question.id,
        label: question.label,
        hint: question.hint || null,
        type: question.type,
        options: question.options ?? [],
        placeholder: question.placeholder || null,
        position: questionIndex,
      })),
    })),
  })),
}));

const questions = scopes.flatMap((s) =>
  s.departments.flatMap((d) => d.modules.flatMap((m) => m.questions)),
);

writeFileSync(OUT, JSON.stringify({ scopes }, null, 2) + "\n");

console.log(
  `${OUT}: ${scopes.length} scopes, ` +
    `${scopes.reduce((n, s) => n + s.departments.length, 0)} departments, ` +
    `${questions.length} questions`,
);
console.log("question types:", [...new Set(questions.map((q) => q.type))].join(", "));
