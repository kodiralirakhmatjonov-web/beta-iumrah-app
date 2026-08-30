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

    static let expandCandidateDetails = #"""
    (() => {
      const visible = el => {
        const r = el.getBoundingClientRect();
        const s = getComputedStyle(el);
        return r.width > 0 && r.height > 0 && s.visibility !== 'hidden' && s.display !== 'none';
      };
      const clean = value => (value || '').replace(/\s+/g,' ').trim();
      const labels = [
        'flight details','details','view details','show details','itinerary details',
        'подробнее о перелёте','подробнее','детали рейса','детали перелёта',
        'reys tafsilotlari','tafsilotlar'
      ];
      const money = /(?:USD|US\$|\$|UZS|EUR|€|RUB|₽|SAR|AED|TRY|KZT|GBP)\s*[0-9]/i;
      const time = /\b(?:(?:[01]?\d|2[0-3]):[0-5]\d|(?:0?[1-9]|1[0-2]):[0-5]\d\s*(?:AM|PM))\b/gi;
      let clicked = 0;
      const controls = Array.from(document.querySelectorAll('button,[role=button],summary,[aria-expanded],[aria-controls]')).filter(visible);

      // First open explicit detail controls.
      for (const el of controls) {
        if (clicked >= 10) break;
        const label = clean(el.innerText || el.getAttribute('aria-label') || '').toLowerCase();
        if (!label || !labels.some(value => label === value || label.includes(value))) continue;
        try { el.click(); clicked += 1; } catch (_) {}
      }

      // Some aggregators make the whole itinerary row expandable and expose no
      // “details” label. Only click controls that advertise expansion semantics
      // and already look like a flight result; never click purchase/select CTAs.
      for (const el of controls) {
        if (clicked >= 10) break;
        const expanded = el.getAttribute('aria-expanded');
        if (expanded === 'true') continue;
        const testid = clean((el.getAttribute('data-testid') || '') + ' ' + (el.getAttribute('data-stid') || '')).toLowerCase();
        const hasExpansionContract = expanded === 'false' || el.hasAttribute('aria-controls') || /flight|itinerary/.test(testid);
        if (!hasExpansionContract) continue;
        const label = clean(el.innerText || el.textContent || el.getAttribute('aria-label') || '');
        const lower = label.toLowerCase();
        if (/select|choose|book|buy|continue|выбрать|забронировать/.test(lower)) continue;
        if (!money.test(label) || (label.match(time) || []).length < 2) continue;
        try { el.click(); clicked += 1; } catch (_) {}
      }
      return clicked;
    })()
    """#

    static let extractCandidateBlocks = #"""
    (() => {
      const money = /(?:USD|US\$|\$|UZS|EUR|€|RUB|₽|SAR|AED|TRY|KZT|GBP)\s*[0-9][0-9\s,.]*|[0-9][0-9\s,.]*\s*(?:USD|UZS|EUR|RUB|SAR|AED|TRY|KZT|GBP|€|₽|so['’]?m|сум)/i;
      const time = /\b(?:(?:[01]?\d|2[0-3]):[0-5]\d|(?:0?[1-9]|1[0-2]):[0-5]\d\s*(?:AM|PM))\b/gi;
      const flight = /\b(?:[A-Z][A-Z0-9]|[0-9][A-Z])[\s-]?\d{1,4}\b/i;
      const airport = /\b[A-Z]{3}\b/g;
      const visible = el => {
        const r = el.getBoundingClientRect();
        const st = getComputedStyle(el);
        return r.width > 0 && r.height > 0 && st.visibility !== 'hidden' && st.display !== 'none';
      };
      const clean = value => (value || '').replace(/\s+/g, ' ').trim();
      const semanticText = node => {
        const parts = [node.innerText || '', node.textContent || ''];
        const descendants = Array.from(node.querySelectorAll('[aria-label],[title],[alt],[data-testid],[data-stid],[data-flight-number],[data-flight]')).slice(0, 520);
        for (const el of descendants) {
          for (const attr of ['aria-label','title','alt','data-testid','data-stid','data-flight-number','data-flight']) {
            const value = el.getAttribute(attr);
            if (value) parts.push(value);
          }
          if (el.dataset) {
            for (const [key, value] of Object.entries(el.dataset).slice(0, 12)) {
              if (value && /flight|airline|airport|route|time|price|fare|segment/i.test(key)) parts.push(String(value));
            }
          }
        }
        return clean(parts.join(' ')).slice(0, 7200);
      };
      const score = text => {
        const times = text.match(time) || [];
        const airports = text.match(airport) || [];
        const flights = text.match(new RegExp(flight.source, 'ig')) || [];
        let value = times.length * 3 + airports.length * 2 + flights.length * 7;
        if (/nonstop|non-stop|direct|stop|layover|пересад|без пересад/i.test(text)) value += 4;
        if (/terminal|терминал|airbus|boeing|atr|embraer|operated by|выполняется/i.test(text)) value += 3;
        return value;
      };

      const output = [];
      const seen = new Set();
      const push = value => {
        const text = clean(value);
        if (text.length < 20 || text.length > 7600 || seen.has(text)) return;
        if (!money.test(text) || (text.match(time) || []).length < 2) return;
        seen.add(text);
        output.push(text);
      };

      const candidates = Array.from(document.querySelectorAll(
        '[data-testid="flight-card"],[data-testid*="itinerary"],[data-testid*="flight"],[data-stid*="flight"],[aria-expanded="true"],article,li,[role=listitem]'
      )).filter(el => {
        if (!visible(el)) return false;
        if (el.children.length > 70) return false;
        const t = clean(el.innerText || el.textContent || '');
        return t.length >= 20 && t.length <= 5200 && money.test(t) && (t.match(time) || []).length >= 2;
      });

      for (const leaf of candidates) {
        let node = leaf;
        let chosen = null;
        let chosenScore = -1;
        for (let depth = 0; depth < 7 && node; depth++, node = node.parentElement) {
          const text = semanticText(node);
          if (text.length < 25 || text.length > 7200 || !money.test(text)) continue;
          if ((text.match(time) || []).length < 2) continue;
          const currentScore = score(text);
          if (currentScore > chosenScore) {
            chosen = text;
            chosenScore = currentScore;
          }
          if (currentScore >= 20 && flight.test(text)) break;
        }
        if (chosen) push(chosen);
        if (output.length >= 48) break;
      }

      // Aggregators often keep exact flight numbers in collapsed/hidden DOM text.
      // Recover a bounded context around each real-looking flight number and let
      // the native parser validate the requested route, airline code and stops.
      const full = clean(document.body?.textContent || '');
      const globalFlight = new RegExp(flight.source, 'ig');
      let match;
      let guard = 0;
      while ((match = globalFlight.exec(full)) && guard++ < 120 && output.length < 64) {
        const from = Math.max(0, match.index - 1800);
        const to = Math.min(full.length, match.index + 2600);
        push(full.slice(from, to));
      }

      // JSON-LD / app-state payloads sometimes contain the only exact flight
      // number. Do not parse the JSON in Swift; extract small source snippets here.
      const scripts = Array.from(document.querySelectorAll('script[type="application/ld+json"],script[type="application/json"],script#__NEXT_DATA__')).slice(0, 30);
      for (const script of scripts) {
        const raw = clean(script.textContent || '');
        if (!raw || raw.length > 800000) continue;
        const re = new RegExp(flight.source, 'ig');
        let m;
        let count = 0;
        while ((m = re.exec(raw)) && count++ < 20 && output.length < 72) {
          const from = Math.max(0, m.index - 1600);
          const to = Math.min(raw.length, m.index + 2200);
          push(raw.slice(from, to));
        }
      }
      return output;
    })()
    """#

    private static func jsEscape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }
}
