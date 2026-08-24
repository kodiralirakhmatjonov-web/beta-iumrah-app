import Foundation

enum FlightBotScripts {
    static func submitSearch(provider: FlightBotProvider, request: FlightBotSearchRequest) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let isoDate = dateFormatter.string(from: request.date)

        let escapedOrigin = jsEscape(request.origin)
        let escapedDestination = jsEscape(request.destination)
        let escapedDate = jsEscape(isoDate)

        if provider.id == .googleFlights || provider.id == .skyscanner {
            return "({ok:true, reason:'deep-link-provider'})"
        }

        return """
        (() => {
          const origin = '\(escapedOrigin)';
          const destination = '\(escapedDestination)';
          const date = '\(escapedDate)';
          const adults = \(max(1, request.adults));
          const children = \(max(0, request.children));
          const infants = \(max(0, request.infants));

          const visible = el => {
            const r = el.getBoundingClientRect();
            const s = getComputedStyle(el);
            return r.width > 0 && r.height > 0 && s.visibility !== 'hidden' && s.display !== 'none';
          };
          const text = el => ((el.getAttribute('aria-label') || '') + ' ' + (el.getAttribute('placeholder') || '') + ' ' + (el.name || '') + ' ' + (el.id || '')).toLowerCase();
          const setNativeValue = (el, value) => {
            try {
              const proto = Object.getPrototypeOf(el);
              const descriptor = Object.getOwnPropertyDescriptor(proto, 'value');
              if (descriptor && descriptor.set) descriptor.set.call(el, value); else el.value = value;
            } catch (_) { el.value = value; }
            el.dispatchEvent(new Event('input', {bubbles:true}));
            el.dispatchEvent(new Event('change', {bubbles:true}));
          };

          const controls = Array.from(document.querySelectorAll('input, select, textarea')).filter(visible);
          const originWords = ['from','origin','departure','откуда','qayerdan','qayerda','город вылета'];
          const destWords = ['to','destination','arrival','куда','qayerga','город прилета'];
          const dateWords = ['date','depart','departure date','вылет','дата вылета','borish sanasi'];

          const findControl = words => controls.find(el => words.some(w => text(el).includes(w)));
          const setSelect = (el, value) => {
            if (!el || el.tagName !== 'SELECT') return false;
            const option = Array.from(el.options).find(o => (o.value || '').toUpperCase() === value || (o.textContent || '').toUpperCase().includes(value));
            if (!option) return false;
            el.value = option.value;
            el.dispatchEvent(new Event('change', {bubbles:true}));
            return true;
          };

          const from = findControl(originWords);
          const to = findControl(destWords);
          const depart = findControl(dateWords) || controls.find(el => el.type === 'date');

          if (from) { if (!setSelect(from, origin)) setNativeValue(from, origin); }
          if (to) { if (!setSelect(to, destination)) setNativeValue(to, destination); }
          if (depart) setNativeValue(depart, date);

          const passengerHints = [
            ['adult', adults], ['взрос', adults], ['child', children], ['дет', children], ['infant', infants], ['млад', infants]
          ];
          for (const [hint, value] of passengerHints) {
            const el = controls.find(c => text(c).includes(hint));
            if (el && ['INPUT','SELECT'].includes(el.tagName)) {
              if (!setSelect(el, String(value))) setNativeValue(el, String(value));
            }
          }

          const buttons = Array.from(document.querySelectorAll('button, input[type=submit], a')).filter(visible);
          const search = buttons.find(el => {
            const t = (el.innerText || el.value || el.getAttribute('aria-label') || '').trim().toLowerCase();
            return ['search','find','поиск','найти','излаш','izlash','search flight','search flights'].some(w => t.includes(w));
          });
          if (search) { search.click(); return {ok:true, clicked:true}; }
          return {ok:false, clicked:false, reason:'search-control-not-found'};
        })()
        """
    }

    static let detectChallenge = """
    (() => {
      const body = (document.body?.innerText || '').toLowerCase();
      const markers = ['captcha','not a robot','not robot','не робот','введите код','enter the code','robot verification','verify you are human'];
      return markers.some(m => body.includes(m));
    })()
    """

    static let extractCandidateBlocks = """
    (() => {
      const money = /(?:USD|US\\$|\\$|UZS|EUR|€|RUB|₽|SAR)\\s*[0-9][0-9\\s,.]*|[0-9][0-9\\s,.]*\\s*(?:USD|UZS|EUR|RUB|SAR|€|₽)/i;
      const time = /\\b(?:[01]?\\d|2[0-3]):[0-5]\\d\\b/g;
      const visible = el => {
        const r = el.getBoundingClientRect();
        const s = getComputedStyle(el);
        return r.width > 0 && r.height > 0 && s.visibility !== 'hidden' && s.display !== 'none';
      };
      const leaves = Array.from(document.querySelectorAll('body *')).filter(el => visible(el) && el.children.length === 0 && money.test((el.innerText || '').trim()));
      const output = [];
      const seen = new Set();
      for (const leaf of leaves) {
        let node = leaf;
        let chosen = null;
        for (let depth = 0; depth < 7 && node; depth++, node = node.parentElement) {
          const t = (node.innerText || '').replace(/\\s+/g, ' ').trim();
          const times = t.match(time) || [];
          if (t.length >= 25 && t.length <= 1800 && times.length >= 1 && money.test(t)) {
            chosen = t;
            if (times.length >= 2) break;
          }
        }
        if (chosen && !seen.has(chosen)) {
          seen.add(chosen);
          output.push(chosen);
        }
        if (output.length >= 24) break;
      }
      return output;
    })()
    """

    private static func jsEscape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }
}
