import Foundation

enum FlightBotScripts {
    static func prepareSearch(provider: FlightBotProvider, request: FlightBotSearchRequest) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let isoDate = dateFormatter.string(from: request.date)

        let displayDateFormatter = DateFormatter()
        displayDateFormatter.calendar = Calendar(identifier: .gregorian)
        displayDateFormatter.locale = Locale(identifier: "en_US_POSIX")
        displayDateFormatter.dateFormat = "dd.MM.yyyy"
        let displayDate = displayDateFormatter.string(from: request.date)

        let englishLongFormatter = DateFormatter()
        englishLongFormatter.calendar = Calendar(identifier: .gregorian)
        englishLongFormatter.locale = Locale(identifier: "en_US_POSIX")
        englishLongFormatter.dateFormat = "d MMMM yyyy"
        let englishLongDate = englishLongFormatter.string(from: request.date).lowercased()

        let russianLongFormatter = DateFormatter()
        russianLongFormatter.calendar = Calendar(identifier: .gregorian)
        russianLongFormatter.locale = Locale(identifier: "ru_RU")
        russianLongFormatter.dateFormat = "d MMMM yyyy"
        let russianLongDate = russianLongFormatter.string(from: request.date).lowercased()

        return """
        (() => {
          const origin = '\(jsEscape(request.origin))';
          const destination = '\(jsEscape(request.destination))';
          const isoDate = '\(jsEscape(isoDate))';
          const displayDate = '\(jsEscape(displayDate))';
          const englishLongDate = '\(jsEscape(englishLongDate))';
          const russianLongDate = '\(jsEscape(russianLongDate))';
          const adults = \(max(1, request.adults));
          const children = \(max(0, request.children));
          const infants = \(max(0, request.infants));

          const visible = el => {
            if (!el) return false;
            const r = el.getBoundingClientRect();
            const s = getComputedStyle(el);
            return r.width > 0 && r.height > 0 && s.visibility !== 'hidden' && s.display !== 'none';
          };
          const clean = value => (value || '').replace(/\\s+/g, ' ').trim();
          const descriptor = el => {
            const own = [el.getAttribute('aria-label'), el.getAttribute('placeholder'), el.getAttribute('name'), el.id, el.getAttribute('data-testid'), el.getAttribute('data-stid')].filter(Boolean).join(' ');
            const label = el.labels && el.labels.length ? Array.from(el.labels).map(x => x.innerText || x.textContent || '').join(' ') : '';
            const parent = clean(el.closest('label,.form-group,.field,.input-group,[class*=field],[class*=form]')?.innerText || '').slice(0, 180);
            return clean(own + ' ' + label + ' ' + parent).toLowerCase();
          };
          const setNativeValue = (el, value) => {
            if (!el) return false;
            try { el.focus(); } catch (_) {}
            try {
              const proto = Object.getPrototypeOf(el);
              const descriptor = Object.getOwnPropertyDescriptor(proto, 'value');
              if (descriptor && descriptor.set) descriptor.set.call(el, value); else el.value = value;
            } catch (_) { try { el.value = value; } catch (_) { return false; } }
            for (const type of ['input','change','blur']) el.dispatchEvent(new Event(type, {bubbles:true}));
            return true;
          };
          const setSelect = (el, value) => {
            if (!el || el.tagName !== 'SELECT') return false;
            const normalized = value.toUpperCase();
            const option = Array.from(el.options || []).find(o =>
              String(o.value || '').toUpperCase() === normalized ||
              clean(o.textContent || '').toUpperCase().includes(normalized)
            );
            if (!option) return false;
            el.value = option.value;
            el.dispatchEvent(new Event('input', {bubbles:true}));
            el.dispatchEvent(new Event('change', {bubbles:true}));
            return true;
          };

          // Force a one-way search. iumrah searches each direction separately so
          // every returned card corresponds to one concrete itinerary/date.
          const oneWayWords = ['one way','one-way','direct route','в одну сторону','только туда','bir tomonga','bir yo‘nalish','bir yonalish'];
          const clickable = Array.from(document.querySelectorAll('button,[role=button],label,input[type=radio],input[type=checkbox]')).filter(visible);
          for (const el of clickable) {
            const t = clean((el.innerText || el.textContent || el.getAttribute('aria-label') || '')).toLowerCase();
            if (oneWayWords.some(w => t.includes(w))) {
              try { el.click(); } catch (_) {}
              break;
            }
          }

          const controls = Array.from(document.querySelectorAll('input,select,textarea')).filter(visible);
          const find = words => controls.find(el => words.some(w => descriptor(el).includes(w)));
          const originWords = ['from','origin','departure airport','откуда','аэропорт вылета','qayerdan',"jo'nash",'uchish'];
          const destinationWords = ['to','destination','arrival airport','куда','аэропорт прилета','qayerga','yetib','borish'];
          const dateWords = ['departure date','depart date','date','вылет','дата вылета',"jo'nash sanasi",'uchish sanasi','ketish'];
          const passengerWords = /adult|child|infant|passenger|взрос|дет|млад|пассаж|kattalar|bolalar|chaqaloq|yo['’]?lovchi/;
          const routeControls = controls.filter(el => {
            const d = descriptor(el);
            if (passengerWords.test(d)) return false;
            if (el.type === 'date' || /date|calendar|дата|sana/.test(d)) return false;
            if (/from|origin|departure|airport|откуда|куда|destination|arrival|qayer|jo['’]?nash|uchish|borish|ketish/.test(d)) return true;
            if (el.tagName === 'SELECT') {
              const sample = Array.from(el.options || []).slice(0, 30).map(o => clean(o.textContent || '')).join(' ');
              return /\\b[A-Z]{3}\\b/.test(sample);
            }
            return el.getAttribute('role') === 'combobox';
          });

          const from = find(originWords) || routeControls[0];
          const to = controls.find(el => el !== from && destinationWords.some(w => descriptor(el).includes(w))) || routeControls.find(el => el !== from);
          const dateControl = controls.find(el => el.type === 'date') || find(dateWords);

          if (from) {
            if (!setSelect(from, origin)) setNativeValue(from, origin);
          }
          if (to) {
            if (!setSelect(to, destination)) setNativeValue(to, destination);
          }
          if (dateControl) {
            const hint = descriptor(dateControl);
            const value = dateControl.type === 'date' || /yyyy|year|date/.test(hint) ? isoDate : displayDate;
            setNativeValue(dateControl, value);
            // Booking engines often read a hidden ISO field next to the visible input.
            const hidden = dateControl.parentElement?.querySelector('input[type=hidden]');
            if (hidden) setNativeValue(hidden, isoDate);
            // Custom calendars are frequently readonly text controls. Open the
            // calendar after setting its backing value so finalizeSearch can click
            // the exact requested date if the SPA ignores synthetic input events.
            if (dateControl.type !== 'date') { try { dateControl.click(); } catch (_) {} }
          }

          const passengerValues = [
            [['adult','взрос','kattalar'], adults],
            [['child','children','дет','bolalar'], children],
            [['infant','млад','chaqaloq'], infants]
          ];
          for (const [words, value] of passengerValues) {
            const el = controls.find(c => words.some(w => descriptor(c).includes(w)));
            if (!el) continue;
            if (!setSelect(el, String(value))) setNativeValue(el, String(value));
          }

          return {ok:true, origin:!!from, destination:!!to, date:!!dateControl};
        })()
        """
    }

    static func finalizeSearch(provider: FlightBotProvider, request: FlightBotSearchRequest) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let isoDate = dateFormatter.string(from: request.date)

        let dayFormatter = DateFormatter()
        dayFormatter.calendar = Calendar(identifier: .gregorian)
        dayFormatter.locale = Locale(identifier: "en_US_POSIX")
        dayFormatter.dateFormat = "d"
        let day = dayFormatter.string(from: request.date)

        let monthFormatter = DateFormatter()
        monthFormatter.calendar = Calendar(identifier: .gregorian)
        monthFormatter.locale = Locale(identifier: "en_US_POSIX")
        monthFormatter.dateFormat = "MMMM yyyy"
        let englishMonthYear = monthFormatter.string(from: request.date).lowercased()
        monthFormatter.locale = Locale(identifier: "ru_RU")
        let russianMonthYear = monthFormatter.string(from: request.date).lowercased()

        let longFormatter = DateFormatter()
        longFormatter.calendar = Calendar(identifier: .gregorian)
        longFormatter.locale = Locale(identifier: "en_US_POSIX")
        longFormatter.dateFormat = "d MMMM yyyy"
        let englishLongDate = longFormatter.string(from: request.date).lowercased()
        longFormatter.locale = Locale(identifier: "ru_RU")
        let russianLongDate = longFormatter.string(from: request.date).lowercased()

        let numericFormatter = DateFormatter()
        numericFormatter.calendar = Calendar(identifier: .gregorian)
        numericFormatter.locale = Locale(identifier: "en_US_POSIX")
        numericFormatter.dateFormat = "dd.MM.yyyy"
        let numericDate = numericFormatter.string(from: request.date)

        return """
        (() => {
          const origin = '\(jsEscape(request.origin))';
          const destination = '\(jsEscape(request.destination))';
          const isoDate = '\(jsEscape(isoDate))';
          const day = '\(jsEscape(day))';
          const numericDate = '\(jsEscape(numericDate))';
          const englishLongDate = '\(jsEscape(englishLongDate))';
          const russianLongDate = '\(jsEscape(russianLongDate))';
          const englishMonthYear = '\(jsEscape(englishMonthYear))';
          const russianMonthYear = '\(jsEscape(russianMonthYear))';
          const clean = value => (value || '').replace(/\\s+/g,' ').trim();
          const visible = el => {
            if (!el) return false;
            const r = el.getBoundingClientRect();
            const s = getComputedStyle(el);
            return r.width > 0 && r.height > 0 && s.visibility !== 'hidden' && s.display !== 'none';
          };
          const descriptor = el => clean([
            el.getAttribute('aria-label'), el.getAttribute('placeholder'), el.getAttribute('name'), el.id,
            el.labels && el.labels.length ? Array.from(el.labels).map(x => x.innerText || '').join(' ') : '',
            el.closest('label,.form-group,.field,[class*=field]')?.innerText || ''
          ].filter(Boolean).join(' ')).toLowerCase();

          const controls = Array.from(document.querySelectorAll('input,select,textarea')).filter(visible);
          const passengerWords = /adult|child|infant|passenger|взрос|дет|млад|пассаж|kattalar|bolalar|chaqaloq|yo['’]?lovchi/;
          const routeControls = controls.filter(el => {
            const d = descriptor(el);
            if (passengerWords.test(d) || el.type === 'date' || /date|calendar|дата|sana/.test(d)) return false;
            if (/from|origin|departure|airport|откуда|куда|destination|arrival|qayer|jo['’]?nash|uchish|borish|ketish/.test(d)) return true;
            if (el.tagName === 'SELECT') {
              const sample = Array.from(el.options || []).slice(0, 30).map(o => clean(o.textContent || '')).join(' ');
              return /\\b[A-Z]{3}\\b/.test(sample);
            }
            return el.getAttribute('role') === 'combobox';
          });
          const from = controls.find(el => /from|origin|откуда|qayerdan|jo['’]?nash|uchish/.test(descriptor(el))) || routeControls[0];
          const to = controls.find(el => el !== from && /to|destination|куда|qayerga|borish|arrival/.test(descriptor(el))) || routeControls.find(el => el !== from);

          const acceptSuggestion = (el, value) => {
            if (!el) return false;
            const upper = value.toUpperCase();
            if (el.tagName === 'SELECT') {
              const selected = clean(el.selectedOptions?.[0]?.textContent || el.value || '').toUpperCase();
              return selected.includes(upper);
            }
            try { el.focus(); } catch (_) {}
            const options = Array.from(document.querySelectorAll('[role=option],[role=listbox] li,.autocomplete li,.suggestions li,.dropdown-menu li,[class*=suggest] li,[class*=option]')).filter(visible);
            const match = options.find(x => clean(x.innerText || x.textContent || x.getAttribute('aria-label') || '').toUpperCase().includes(upper));
            if (match) { try { match.click(); return true; } catch (_) {} }
            try {
              el.dispatchEvent(new KeyboardEvent('keydown', {bubbles:true, key:'ArrowDown'}));
              el.dispatchEvent(new KeyboardEvent('keydown', {bubbles:true, key:'Enter'}));
            } catch (_) {}
            return false;
          };
          acceptSuggestion(from, origin);
          acceptSuggestion(to, destination);

          // If a calendar popover is open, select only the requested calendar date.
          // A bare day number is never enough because two adjacent months can both
          // contain the same day in a dual-month airline calendar.
          const dateCandidates = Array.from(document.querySelectorAll('[data-date],[data-value],[datetime],[aria-label],[title],button,[role=button],[role=gridcell]')).filter(visible);
          const dateTokens = [isoDate, numericDate, englishLongDate, russianLongDate].map(x => x.toLowerCase());
          const normalizedDateText = el => clean([
            el.getAttribute('data-date'), el.getAttribute('data-value'), el.getAttribute('datetime'),
            el.getAttribute('aria-label'), el.getAttribute('title'), el.innerText || el.textContent || ''
          ].filter(Boolean).join(' ')).toLowerCase();
          const exactDate = dateCandidates.find(el => {
            const value = normalizedDateText(el);
            return dateTokens.some(token => value.includes(token));
          });
          if (exactDate) { try { exactDate.click(); } catch (_) {} }
          else {
            const dayCells = dateCandidates.filter(el => clean(el.innerText || el.textContent || '') === day);
            const dayCell = dayCells.find(el => {
              const calendar = el.closest('[role=dialog],[role=grid],.calendar,[class*=calendar],[class*=datepicker],[class*=date-picker],[class*=month]');
              const context = clean(calendar?.innerText || calendar?.textContent || '').toLowerCase();
              const attrs = normalizedDateText(el);
              return attrs.includes(englishMonthYear) || attrs.includes(russianMonthYear) ||
                     context.includes(englishMonthYear) || context.includes(russianMonthYear);
            });
            if (dayCell) { try { dayCell.click(); } catch (_) {} }
          }

          const searchWords = [
            'search flights','search flight','search tickets','ticket search','find flights',
            'поиск билетов','найти рейсы','поиск рейсов','chipta olish','reys qidirish','qidirish','izlash'
          ];
          const form = (to || from)?.closest('form');
          const allButtons = Array.from(document.querySelectorAll('button,input[type=submit],a,[role=button]')).filter(visible);
          const formButtons = form ? Array.from(form.querySelectorAll('button,input[type=submit],[role=button]')).filter(visible) : [];
          const buttonMatches = el => {
            const label = clean(el.innerText || el.value || el.getAttribute('aria-label') || '').toLowerCase();
            return searchWords.some(w => label === w || label.includes(w));
          };
          const search = formButtons.find(buttonMatches) || allButtons.find(buttonMatches);
          if (search) { try { search.click(); return {ok:true, clicked:true}; } catch (_) {} }

          // Final fallback: submitting the closest route form is safer than
          // clicking a generic site-search CTA elsewhere on an airline homepage.
          if (form) {
            try {
              if (form.requestSubmit) form.requestSubmit(); else form.submit();
              return {ok:true, submitted:true};
            } catch (_) {}
          }
          return {ok:false, clicked:false};
        })()
        """
    }

    static func verifySearchContext(request: FlightBotSearchRequest) -> String {
        let isoFormatter = DateFormatter()
        isoFormatter.calendar = Calendar(identifier: .gregorian)
        isoFormatter.locale = Locale(identifier: "en_US_POSIX")
        isoFormatter.dateFormat = "yyyy-MM-dd"
        let isoDate = isoFormatter.string(from: request.date)

        let numericFormatter = DateFormatter()
        numericFormatter.calendar = Calendar(identifier: .gregorian)
        numericFormatter.locale = Locale(identifier: "en_US_POSIX")
        numericFormatter.dateFormat = "dd.MM.yyyy"
        let numericDate = numericFormatter.string(from: request.date)

        let slashFormatter = DateFormatter()
        slashFormatter.calendar = Calendar(identifier: .gregorian)
        slashFormatter.locale = Locale(identifier: "en_US_POSIX")
        slashFormatter.dateFormat = "dd/MM/yyyy"
        let slashDate = slashFormatter.string(from: request.date)

        var humanTokens: [String] = []
        for localeID in ["en_US_POSIX", "ru_RU", "uz_Latn_UZ"] {
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: localeID)
            for format in ["d MMM yyyy", "d MMMM yyyy", "MMM d yyyy", "MMMM d yyyy"] {
                formatter.dateFormat = format
                humanTokens.append(formatter.string(from: request.date).lowercased())
            }
        }
        let encodedHuman = humanTokens.map { "'\(jsEscape($0))'" }.joined(separator: ",")

        return """
        (() => {
          const origin = '\(jsEscape(request.origin.uppercased()))';
          const destination = '\(jsEscape(request.destination.uppercased()))';
          const dateTokens = ['\(jsEscape(isoDate))','\(jsEscape(numericDate))','\(jsEscape(slashDate))',\(encodedHuman)].map(x => x.toLowerCase());
          const clean = value => String(value || '').replace(/[,_]/g, ' ').replace(/\\s+/g, ' ').trim();
          const pieces = [location.href, document.title, document.body?.innerText || ''];
          const controls = Array.from(document.querySelectorAll('input,select,[aria-label],[data-date],[data-value],[datetime]')).slice(0, 900);
          for (const el of controls) {
            pieces.push(el.value || '');
            pieces.push(el.getAttribute('aria-label') || '');
            pieces.push(el.getAttribute('data-date') || '');
            pieces.push(el.getAttribute('data-value') || '');
            pieces.push(el.getAttribute('datetime') || '');
            if (el.tagName === 'SELECT') pieces.push(el.selectedOptions?.[0]?.textContent || '');
          }
          const context = clean(pieces.join(' '));
          const upper = context.toUpperCase();
          const lower = context.toLowerCase();
          const routeOK = upper.includes(origin) && upper.includes(destination);
          const dateOK = dateTokens.some(token => lower.includes(token));
          return {ok: routeOK && dateOK, route: routeOK, date: dateOK};
        })()
        """
    }

    static let dismissNonSearchOverlays = #"""
    (() => {
      const visible = el => {
        const r = el.getBoundingClientRect();
        const st = getComputedStyle(el);
        return r.width > 0 && r.height > 0 && st.visibility !== 'hidden' && st.display !== 'none';
      };
      const clean = value => (value || '').replace(/\\s+/g, ' ').trim().toLowerCase();
      const exact = [
        'accept all','accept cookies','accept','i agree','agree','allow all','got it',
        'принять все','принять','согласен','разрешить все','хорошо',
        'barchasini qabul qilish','qabul qilish','roziman'
      ];
      let clicked = 0;
      const controls = Array.from(document.querySelectorAll('button,[role=button],input[type=button],input[type=submit]')).filter(visible);
      for (const el of controls) {
        if (clicked >= 3) break;
        const label = clean(el.innerText || el.value || el.getAttribute('aria-label') || el.getAttribute('title') || '');
        if (!label) continue;
        const cookieContext = /cookie|consent|privacy|куки|файл|конфиденц|rozilik/i.test(
          (el.closest('[role=dialog],dialog,[class*=cookie],[id*=cookie],[class*=consent],[id*=consent]')?.innerText || '')
        );
        if (exact.includes(label) || (cookieContext && /accept|agree|принять|соглас|qabul|rozi/.test(label))) {
          try { el.click(); clicked += 1; } catch (_) {}
        }
      }
      return clicked;
    })()
    """#

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
      const clean = value => (value || '').replace(/\\s+/g,' ').trim();
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
      const clean = value => (value || '').replace(/\\s+/g, ' ').trim();
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
        // Display candidates must contain an actual carrier flight number. Fare-only
        // blocks are handled by the separate pricing-reference extractor.
        if (!money.test(text) || !flight.test(text) || (text.match(time) || []).length < 2) return;
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

    /// Captures bounded JSON/text responses from airline booking engines. Many
    /// modern booking sites render only a simplified card in the DOM while the
    /// exact flight number, segment airports and fare live in XHR/fetch payloads.
    /// The capture is injected at document start and never sends data anywhere;
    /// Swift reads the buffer locally from this WKWebView only.
    static let networkCaptureBootstrap = #"""
    (() => {
      if (window.__iumrahNetworkCaptureInstalled) return;
      window.__iumrahNetworkCaptureInstalled = true;
      window.__iumrahFlightNetworkPayloads = [];

      const store = (url, body, contentType) => {
        try {
          if (!body || typeof body !== 'string') return;
          if (body.length < 20 || body.length > 450000) return;
          const hint = `${url || ''} ${contentType || ''} ${body.slice(0, 1800)}`.toLowerCase();
          if (!/(flight|segment|itinerary|journey|schedule|fare|price|airport|departure|arrival|route|booking|availability)/.test(hint)) return;
          const item = { url: String(url || ''), body: body.slice(0, 450000), at: Date.now() };
          const list = window.__iumrahFlightNetworkPayloads || [];
          list.push(item);
          while (list.length > 48) list.shift();
          window.__iumrahFlightNetworkPayloads = list;
        } catch (_) {}
      };

      try {
        const originalFetch = window.fetch;
        if (originalFetch) {
          window.fetch = async function(...args) {
            const response = await originalFetch.apply(this, args);
            try {
              const clone = response.clone();
              const type = clone.headers?.get?.('content-type') || '';
              clone.text().then(text => store(clone.url || args?.[0]?.url || args?.[0], text, type)).catch(() => {});
            } catch (_) {}
            return response;
          };
        }
      } catch (_) {}

      try {
        const originalOpen = XMLHttpRequest.prototype.open;
        const originalSend = XMLHttpRequest.prototype.send;
        XMLHttpRequest.prototype.open = function(method, url, ...rest) {
          this.__iumrahURL = url;
          return originalOpen.call(this, method, url, ...rest);
        };
        XMLHttpRequest.prototype.send = function(...args) {
          this.addEventListener('load', function() {
            try {
              const type = this.getResponseHeader?.('content-type') || '';
              if (this.responseType === '' || this.responseType === 'text') {
                store(this.responseURL || this.__iumrahURL, this.responseText || '', type);
              } else if (this.responseType === 'json' && this.response) {
                store(this.responseURL || this.__iumrahURL, JSON.stringify(this.response), type);
              }
            } catch (_) {}
          });
          return originalSend.apply(this, args);
        };
      } catch (_) {}
    })();
    """#

    static func extractNetworkCandidateBlocks(request: FlightBotSearchRequest) -> String {
        let origin = jsEscape(request.origin)
        let destination = jsEscape(request.destination)
        return """
        (() => {
          const origin = '\(origin)';
          const destination = '\(destination)';
          const entries = Array.isArray(window.__iumrahFlightNetworkPayloads) ? window.__iumrahFlightNetworkPayloads : [];
          const flight = /\\b(?:[A-Z][A-Z0-9]|[0-9][A-Z])[\\s-]?\\d{1,4}\\b/i;
          const money = /(?:USD|US\\$|\\$|UZS|EUR|€|RUB|₽|SAR|AED|TRY|KZT|GBP)[\\s:\\"']*[0-9]|[0-9][0-9\\s,.]*[\\s:\\"']*(?:USD|UZS|EUR|RUB|SAR|AED|TRY|KZT|GBP)/i;
          const time = /(?:[01]?\\d|2[0-3]):[0-5]\\d/;
          const clean = value => String(value || '').replace(/\\s+/g, ' ').trim();
          const out = [];
          const seen = new Set();
          for (const entry of entries.slice(-36)) {
            const raw = clean(entry?.body || '');
            if (!raw || raw.length > 450000) continue;
            const upper = raw.toUpperCase();
            if (!upper.includes(origin) || !upper.includes(destination)) continue;
            if (!flight.test(upper) || !money.test(raw) || !time.test(raw)) continue;

            const re = new RegExp(flight.source, 'ig');
            let match;
            let count = 0;
            while ((match = re.exec(raw)) && count++ < 28 && out.length < 56) {
              const snippetStart = Math.max(0, match.index - 2200);
              const snippetEnd = Math.min(raw.length, match.index + 3600);
              const snippet = clean(raw.slice(snippetStart, snippetEnd));
              const snippetUpper = snippet.toUpperCase();
              if (!snippetUpper.includes(origin) || !snippetUpper.includes(destination) || !money.test(snippet)) continue;
              const key = snippet.slice(0, 800);
              if (seen.has(key)) continue;
              seen.add(key);
              out.push(snippet);
            }
          }
          return out;
        })()
        """
    }

    private static func jsEscape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }
}
