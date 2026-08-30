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
            try { el.focus(); } catch (_) {}
            try {
              const proto = Object.getPrototypeOf(el);
              const descriptor = Object.getOwnPropertyDescriptor(proto, 'value');
              if (descriptor && descriptor.set) descriptor.set.call(el, value); else el.value = value;
            } catch (_) { el.value = value; }
            el.dispatchEvent(new Event('input', {bubbles:true}));
            el.dispatchEvent(new KeyboardEvent('keyup', {bubbles:true, key:'a'}));
            el.dispatchEvent(new Event('change', {bubbles:true}));
          };
          const chooseVisibleSuggestion = value => {
            const options = Array.from(document.querySelectorAll('[role=option], [role=listbox] li, .autocomplete li, .suggestions li, .dropdown-menu li')).filter(visible);
            const match = options.find(el => (el.innerText || el.textContent || '').toUpperCase().includes(value.toUpperCase()));
            if (match) { match.click(); return true; }
            return false;
          };

          const controls = Array.from(document.querySelectorAll('input, select, textarea')).filter(visible);
          const originWords = ['from','origin','departure','откуда','qayerdan','qayerda','jo\'nash','город вылета','uchish'];
          const destWords = ['to','destination','arrival','куда','qayerga','yetib','город прилета','borish'];
          const dateWords = ['date','depart','departure date','вылет','дата вылета','borish sanasi','jo\'nash sanasi','uchish sanasi'];

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

          if (from) { if (!setSelect(from, origin)) { setNativeValue(from, origin); chooseVisibleSuggestion(origin); } }
          if (to) { if (!setSelect(to, destination)) { setNativeValue(to, destination); chooseVisibleSuggestion(destination); } }
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
            return ['search','find','поиск','найти','излаш','izlash','qidirish','search flight','search flights','find flights'].some(w => t.includes(w));
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

    static let expandCandidateDetails = """
    (() => {
      const visible = el => {
        const r = el.getBoundingClientRect();
        const s = getComputedStyle(el);
        return r.width > 0 && r.height > 0 && s.visibility !== 'hidden' && s.display !== 'none';
      };
      const labels = [
        'flight details','details','view details','show details','itinerary details',
        'подробнее о перелёте','подробнее','детали рейса','детали перелёта',
        'reys tafsilotlari','tafsilotlar'
      ];
      let clicked = 0;
      const controls = Array.from(document.querySelectorAll('button,[role=button],summary,a')).filter(visible);
      for (const el of controls) {
        if (clicked >= 12) break;
        const text = (el.innerText || el.getAttribute('aria-label') || '').replace(/\\s+/g,' ').trim().toLowerCase();
        if (!text || !labels.some(label => text === label || text.includes(label))) continue;
        if (el.tagName === 'A' && el.target === '_blank') continue;
        try { el.click(); clicked += 1; } catch (_) {}
      }
      return clicked;
    })()
    """

    static let extractCandidateBlocks = """
    (() => {
      const money = /(?:USD|US\\$|\\$|UZS|EUR|€|RUB|₽|SAR|AED|TRY|KZT|GBP)\\s*[0-9][0-9\\s,.]*|[0-9][0-9\\s,.]*\\s*(?:USD|UZS|EUR|RUB|SAR|AED|TRY|KZT|GBP|€|₽|so['’]?m|сум)/i;
      const time = /\\b(?:[01]?\\d|2[0-3]):[0-5]\\d\\b/g;
      const flight = /\\b(?:[A-Z][A-Z0-9]|[0-9][A-Z])[\\s-]?\\d{1,4}\\b/i;
      const airport = /\\b[A-Z]{3}\\b/g;
      const visible = el => {
        const r = el.getBoundingClientRect();
        const s = getComputedStyle(el);
        return r.width > 0 && r.height > 0 && s.visibility !== 'hidden' && s.display !== 'none';
      };
      const clean = value => (value || '').replace(/\\s+/g, ' ').trim();
      const score = text => {
        const times = text.match(time) || [];
        const airports = text.match(airport) || [];
        let value = times.length * 3 + airports.length * 2;
        if (flight.test(text)) value += 5;
        if (/terminal|терминал|airbus|boeing|atr|embraer|operated by|выполняется/i.test(text)) value += 3;
        return value;
      };

      const moneyNodes = Array.from(document.querySelectorAll('body *')).filter(el => {
        if (!visible(el) || el.children.length > 2) return false;
        return money.test(clean(el.innerText));
      });
      const output = [];
      const seen = new Set();

      for (const leaf of moneyNodes) {
        let node = leaf;
        let chosen = null;
        let chosenScore = -1;
        for (let depth = 0; depth < 9 && node; depth++, node = node.parentElement) {
          const text = clean(node.innerText);
          if (text.length < 25 || text.length > 3200 || !money.test(text)) continue;
          const times = text.match(time) || [];
          if (times.length < 2) continue;
          const currentScore = score(text);
          if (currentScore > chosenScore) {
            chosen = text;
            chosenScore = currentScore;
          }
          if (times.length >= 4 && flight.test(text) && (text.match(airport) || []).length >= 3) break;
        }
        if (chosen && !seen.has(chosen)) {
          seen.add(chosen);
          output.push(chosen);
        }
        if (output.length >= 36) break;
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
