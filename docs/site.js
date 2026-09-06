/* Static, dependency-free enhancements. The demo never uses storage or a network API. */
const tabs = [...document.querySelectorAll('[role="tab"]')];
function activateTab(tab) {
  for (const item of tabs) {
    const active = item === tab;
    item.setAttribute("aria-selected", String(active));
    item.tabIndex = active ? 0 : -1;
    document.getElementById(item.getAttribute("aria-controls")).hidden =
      !active;
  }
}
for (const tab of tabs) {
  tab.addEventListener("click", () => activateTab(tab));
  tab.addEventListener("keydown", (event) => {
    const index = tabs.indexOf(tab);
    const destinations = {
      ArrowRight: (index + 1) % tabs.length,
      ArrowLeft: (index + tabs.length - 1) % tabs.length,
      Home: 0,
      End: tabs.length - 1,
    };
    if (!(event.key in destinations)) return;
    event.preventDefault();
    const destination = tabs[destinations[event.key]];
    activateTab(destination);
    destination.focus();
  });
}

const initialTasks = [
  { id: 1, title: "Pick up fresh flowers", list: "Weekend", date: "today" },
  {
    id: 2,
    title: "Book the ceramics workshop",
    list: "Weekend",
    date: "next-week",
  },
  { id: 3, title: "Return library books", list: "Weekend", date: "overdue" },
  { id: 4, title: "Take the long way home", list: "Weekend", date: "none" },
  { id: 5, title: "Review café moodboard", list: "Studio", date: "today" },
  {
    id: 6,
    title: "Sketch the autumn collection",
    list: "Studio",
    date: "today",
  },
];
let tasks = initialTasks.map((task) => ({ ...task }));
let nextId = 7;
let lastCompleted = null;
const app = document.getElementById("demo-app");
const scope = document.getElementById("demo-scope");
const search = document.getElementById("demo-search");
const taskList = document.getElementById("demo-tasks");
const status = document.getElementById("demo-status");
const undo = document.getElementById("demo-undo");
const composer = document.getElementById("demo-composer");
const titleInput = document.getElementById("demo-title");
const notchToggle = document.getElementById("notch-toggle");
const content = document.getElementById("demo-content");
const dialog = document.getElementById("capture-dialog");
const captureForm = document.getElementById("capture-form");
const captureInput = document.getElementById("capture-input");
const captureDate = document.getElementById("capture-date");
const customDate = document.getElementById("capture-custom-date");
const captureList = document.getElementById("capture-list");
let captureOpener = null;
const normalize = (value) =>
  value
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLocaleLowerCase();
const isList = () => ["Weekend", "Studio"].includes(scope.value);
// Relative examples keep this demo useful on any day, without changing actual reminders.
function dateKind(task) {
  if (!task.customDate) return task.date;
  const today = new Date();
  const todayKey = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, "0")}-${String(today.getDate()).padStart(2, "0")}`;
  return task.customDate === todayKey
    ? "today"
    : task.customDate < todayKey
      ? "overdue"
      : "future";
}
function matchesScope(task) {
  if (isList()) return task.list === scope.value;
  const kind = dateKind(task);
  if (scope.value === "Today") return kind === "today";
  if (scope.value === "Overdue") return kind === "overdue";
  if (scope.value === "Scheduled") return kind !== "none";
  return true;
}
function dateLabel(task) {
  if (task.customDate) {
    const [year, month, day] = task.customDate.split("-").map(Number);
    return new Intl.DateTimeFormat(undefined, {
      month: "short",
      day: "numeric",
      year: "numeric",
    }).format(new Date(year, month - 1, day));
  }
  return {
    today: "Today",
    tomorrow: "Tomorrow",
    "next-week": "Next Week",
    overdue: "Overdue",
    none: "No date",
  }[task.date];
}
function renderTasks() {
  const scopedTasks = tasks.filter(
    (task) => !task.completed && matchesScope(task),
  );
  const visibleTasks = scopedTasks.filter((task) =>
    normalize(task.title).includes(normalize(search.value.trim())),
  );
  taskList.replaceChildren();
  for (const task of visibleTasks) {
    const row = document.createElement("li");
    row.className = task.list.toLowerCase();
    const button = document.createElement("button");
    button.type = "button";
    button.className = "complete-task";
    button.dataset.taskId = task.id;
    button.setAttribute("aria-label", `Complete ${task.title}`);
    button.addEventListener("click", () => {
      const index = visibleTasks.indexOf(task);
      task.completed = true;
      lastCompleted = task;
      status.textContent = `Completed “${task.title}”.`;
      renderTasks();
      const nextButtons = taskList.querySelectorAll("button");
      (nextButtons[Math.min(index, nextButtons.length - 1)] || undo).focus({
        preventScroll: true,
      });
    });
    const body = document.createElement("div");
    body.className = "task-body";
    const title = document.createElement("p");
    title.className = "task-title";
    title.textContent = task.title;
    const meta = document.createElement("p");
    meta.className = `task-meta${dateKind(task) === "overdue" ? " overdue" : ""}`;
    meta.textContent = `${dateLabel(task)}${isList() ? "" : ` · ${task.list}`}`;
    body.append(title, meta);
    if (task.notes) {
      const notes = document.createElement("p");
      notes.className = "task-notes";
      notes.textContent = task.notes;
      body.append(notes);
    }
    row.append(button, body);
    taskList.append(row);
  }
  const count = document.getElementById("task-count");
  count.textContent = scopedTasks.length;
  count.setAttribute("aria-label", `${scopedTasks.length} open reminders`);
  document.getElementById("demo-empty").hidden = visibleTasks.length > 0;
  composer.hidden = !isList();
  document.getElementById("scope-capture").hidden = isList();
  undo.hidden = !lastCompleted;
}
function setExpanded(expanded) {
  content.hidden = !expanded;
  notchToggle.setAttribute("aria-expanded", String(expanded));
  notchToggle.querySelector(".sr-only").textContent = expanded
    ? "Collapse demo notch"
    : "Expand demo notch";
  app.classList.toggle("is-collapsed", !expanded);
}
notchToggle.addEventListener("click", () => setExpanded(content.hidden));
search.addEventListener("input", () => {
  renderTasks();
  status.textContent = `${taskList.children.length} matching reminder${taskList.children.length === 1 ? "" : "s"}.`;
});
scope.addEventListener("change", () => {
  renderTasks();
  status.textContent = `${taskList.children.length} reminder${taskList.children.length === 1 ? "" : "s"} in ${scope.value}.`;
});
app.addEventListener("keydown", (event) => {
  if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "f") {
    event.preventDefault();
    setExpanded(true);
    search.focus();
  }
  if (event.key === "Escape" && event.target === search) {
    search.value = "";
    renderTasks();
    scope.focus();
  }
});
undo.addEventListener("click", () => {
  if (!lastCompleted) return;
  const restored = lastCompleted;
  restored.completed = false;
  lastCompleted = null;
  status.textContent = `Restored “${restored.title}”.`;
  renderTasks();
  (taskList.querySelector(`[data-task-id="${restored.id}"]`) || scope).focus({
    preventScroll: true,
  });
});
function addTask({ title, list, date = "none", notes = "", customDate = "" }) {
  const task = { id: nextId++, title, list, date, notes, customDate };
  tasks.push(task);
  scope.value = list;
  search.value = "";
  setExpanded(true);
  status.textContent = `Added “${title}” to ${list}.`;
  renderTasks();
  taskList.lastElementChild?.scrollIntoView({
    block: "nearest",
    behavior: "instant",
  });
}
function validateTitle(input) {
  input.setCustomValidity(input.value.trim() ? "" : "Enter a reminder title.");
  return input.reportValidity();
}
for (const input of [titleInput, captureInput])
  input.addEventListener("input", () => input.setCustomValidity(""));
composer.addEventListener("submit", (event) => {
  event.preventDefault();
  if (!validateTitle(titleInput)) return;
  addTask({ title: titleInput.value.trim(), list: scope.value });
  composer.reset();
  titleInput.focus({ preventScroll: true });
});
document.getElementById("reset-demo").addEventListener("click", () => {
  tasks = initialTasks.map((task) => ({ ...task }));
  nextId = 7;
  lastCompleted = null;
  scope.value = "Weekend";
  search.value = "";
  composer.reset();
  captureForm.reset();
  updateCustomDate();
  setExpanded(true);
  status.textContent = "Demo reset. Try checking off a reminder.";
  renderTasks();
});
for (const opener of document.querySelectorAll("[data-open-capture]")) {
  opener.addEventListener("click", () => {
    captureOpener = opener;
    if (isList()) captureList.value = scope.value;
    dialog.showModal();
    captureInput.focus();
  });
}
function closeCapture() {
  dialog.close();
}
document
  .getElementById("close-capture")
  .addEventListener("click", closeCapture);
dialog.addEventListener("click", (event) => {
  if (event.target !== dialog) return;
  const rect = dialog.getBoundingClientRect();
  if (
    event.clientX < rect.left ||
    event.clientX > rect.right ||
    event.clientY < rect.top ||
    event.clientY > rect.bottom
  )
    closeCapture();
});
dialog.addEventListener("close", () => {
  // Saving can hide a scope-specific opener, so choose a visible focus destination.
  if (captureOpener?.getClientRects().length)
    captureOpener.focus({ preventScroll: true });
  else scope.focus({ preventScroll: true });
});
// Keep Tab at the dialog's ends inside the form, including in browsers that
// otherwise move focus to their chrome before wrapping a native dialog.
dialog.addEventListener("keydown", (event) => {
  if (event.key !== "Tab") return;
  const controls = [
    ...dialog.querySelectorAll("button, input, select, textarea"),
  ].filter((control) => !control.disabled && control.getClientRects().length);
  const first = controls[0];
  const last = controls[controls.length - 1];
  if (event.shiftKey && document.activeElement === first) {
    event.preventDefault();
    last.focus();
  } else if (!event.shiftKey && document.activeElement === last) {
    event.preventDefault();
    first.focus();
  }
});
function updateCustomDate() {
  const custom = captureDate.value === "custom";
  document.getElementById("custom-date-field").hidden = !custom;
  customDate.required = custom;
}
captureDate.addEventListener("change", updateCustomDate);
captureForm.addEventListener("submit", (event) => {
  event.preventDefault();
  if (!validateTitle(captureInput)) return;
  const fields = new FormData(captureForm);
  addTask({
    title: fields.get("title").trim(),
    notes: fields.get("notes").trim(),
    list: fields.get("list"),
    date: fields.get("date"),
    customDate: fields.get("date") === "custom" ? fields.get("customDate") : "",
  });
  captureForm.reset();
  updateCustomDate();
  closeCapture();
});
renderTasks();

// The source keeps every feature visible if this script cannot initialize.
activateTab(tabs[0]);

// Reveal interactive controls only after every handler is ready.
for (const element of document.querySelectorAll("[data-enhanced]"))
  element.hidden = false;
