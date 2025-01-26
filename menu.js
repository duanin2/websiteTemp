for (const menu of document.querySelectorAll("body .menu-container")) for (const toggle of menu.getElementsByClassName("menu-toggle")) {
	menu.classList.add("close");
	toggle.addEventListener("click", () => {
		if (menu.classList.contains("close")) menu.classList.remove("close");
		else menu.classList.add("close");
	});
}