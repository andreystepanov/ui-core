import { format, formatDistance, parseISO } from "date-fns";
// formats a datetime. Expects the raw datetime to be in the ISO 8601 format.
// example:
//   <date-time format="shortDate">
//     2023-03-28T18:16:20.375Z
//   </date-time>
//
//   ⧨
//
//   Mar 28, 2023
//
class FormatDateTime extends HTMLElement {
  FORMATS = {
    shortDate: (d) => format(d, "MMM d, yyyy"),
    longDate: (d) => format(d, "MMMM d, yyyy"),
    distance: (d) => formatDistance(d, new Date()),
  };

  constructor() {
    super();
  }

  connectedCallback() {
    const formatName = this.getAttribute("format");
    const raw = this.innerText.trim();
    const d = parseISO(raw);
    const formatter = this.FORMATS[formatName] || this.FORMATS.shortDate;
    console.log(d, this.FORMATS, formatName, formatter, formatter(d));
    this.innerHTML = "";
    this.appendChild(formatter(d));
  }
}

customElements.define("format-date-time", FormatDateTime);
