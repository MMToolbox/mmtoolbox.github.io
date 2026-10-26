// Progressive enhancement for {{< csv-table >}}: sortable columns and a
// row filter. Without JS the plain table is still fully usable.
(function () {
  "use strict";

  const collator = new Intl.Collator(undefined, { numeric: true, sensitivity: "base" });

  function cellText(row, index) {
    return row.cells[index] ? row.cells[index].textContent.trim() : "";
  }

  function isNumericColumn(rows, index) {
    let seen = false;
    for (const row of rows) {
      const text = cellText(row, index);
      if (text === "") continue;
      if (Number.isNaN(Number(text.replace(/,/g, "")))) return false;
      seen = true;
    }
    return seen;
  }

  function enhance(container, number) {
    const table = container.querySelector("table");
    const tbody = table.tBodies[0];
    const rows = Array.from(tbody.rows);
    const headers = Array.from(table.tHead.rows[0].cells);
    const total = rows.length;
    rows.forEach((row, i) => (row.dataset.order = i));

    // Filter box, with a live status so screen readers hear the result count.
    const toolbar = document.createElement("div");
    toolbar.className = "csv-table__toolbar";
    const inputId = "csv-table-filter-" + number;
    toolbar.innerHTML =
      '<label class="visually-hidden" for="' + inputId + '">Filter table rows</label>' +
      '<input type="search" class="form-control form-control-sm" id="' + inputId +
      '" placeholder="Filter rows…" autocomplete="off">' +
      '<p class="csv-table__status" role="status" aria-live="polite"></p>';
    container.insertBefore(toolbar, container.firstChild);
    const input = toolbar.querySelector("input");
    const status = toolbar.querySelector("[role=status]");
    input.setAttribute("aria-controls", table.id);

    function updateStatus(shown) {
      status.textContent = shown === total ? total + " rows" : "Showing " + shown + " of " + total + " rows";
    }
    updateStatus(total);

    input.addEventListener("input", () => {
      const terms = input.value.toLowerCase().split(/\s+/).filter(Boolean);
      let shown = 0;
      for (const row of rows) {
        const text = row.textContent.toLowerCase();
        const match = terms.every((t) => text.includes(t));
        row.hidden = !match;
        if (match) shown++;
      }
      updateStatus(shown);
    });

    // Sorting: header text becomes a button; aria-sort sits on the active <th>.
    headers.forEach((th, index) => {
      const button = document.createElement("button");
      button.type = "button";
      button.className = "csv-table__sort";
      button.innerHTML = th.innerHTML + '<span class="csv-table__sort-icon" aria-hidden="true"></span>';
      th.textContent = "";
      th.appendChild(button);

      button.addEventListener("click", () => {
        const current = th.getAttribute("aria-sort");
        const direction = current === "ascending" ? "descending" : current === "descending" ? "none" : "ascending";
        headers.forEach((h) => h.removeAttribute("aria-sort"));

        let sorted;
        if (direction === "none") {
          sorted = rows.slice().sort((a, b) => a.dataset.order - b.dataset.order);
        } else {
          th.setAttribute("aria-sort", direction);
          const numeric = isNumericColumn(rows, index);
          const sign = direction === "ascending" ? 1 : -1;
          sorted = rows.slice().sort((a, b) => {
            const x = cellText(a, index);
            const y = cellText(b, index);
            if (x === "" || y === "") return x === y ? a.dataset.order - b.dataset.order : x === "" ? 1 : -1;
            const cmp = numeric ? Number(x.replace(/,/g, "")) - Number(y.replace(/,/g, "")) : collator.compare(x, y);
            return cmp * sign || a.dataset.order - b.dataset.order;
          });
        }
        tbody.append(...sorted);
      });
    });
  }

  function init() {
    document.querySelectorAll("[data-csv-table]").forEach((el, i) => enhance(el, i + 1));
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
