const tabButtons = document.querySelectorAll(".tab-button");
const tabPanels = document.querySelectorAll(".tab-panel");

tabButtons.forEach((button) => {
  button.addEventListener("click", () => {
    const target = button.dataset.tab;

    tabButtons.forEach((item) => item.classList.toggle("is-active", item === button));
    tabPanels.forEach((panel) => panel.classList.toggle("is-active", panel.dataset.panel === target));
  });
});

const yearNode = document.querySelector("#year");
if (yearNode) {
  yearNode.textContent = String(new Date().getFullYear());
}
