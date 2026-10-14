import { Controller } from "@hotwired/stimulus";

// Restaure les images distantes d'un message a la demande.
//
// Un message de 2008 chargeait des dizaines d'images hebergees chez des tiers
// aujourd'hui disparus, et chaque lecture previendrait ces tiers de la
// consultation. Elles restent donc bloquees tant que l'utilisateur ne le demande
// pas explicitement.
export default class extends Controller {
  static targets = ["container", "button"];
  static values = { count: Number };

  reveal() {
    const blocked = this.containerTarget.querySelectorAll("img[data-src-bloquee]");

    blocked.forEach((image) => {
      const original = image.getAttribute("data-src-original");
      if (!original) return;

      image.src = original;
      image.removeAttribute("data-src-bloquee");
      image.classList.remove("remote-blocked");
      image.removeAttribute("data-src-original");
    });

    this.buttonTargets.forEach((button) => button.remove());
  }
}