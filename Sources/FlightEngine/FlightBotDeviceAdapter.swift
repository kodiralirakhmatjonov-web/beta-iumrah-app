import Foundation

/// Provider-specific device automation. Shared parsing and candidate validation are
/// common, but route entry/search submission are deliberately carrier-specific.
protocol FlightBotDeviceAdapting {
    var providerID: FlightBotProviderID { get }
    func prepareSearch(provider: FlightBotProvider, request: FlightBotSearchRequest) -> String?
    func finalizeSearch(provider: FlightBotProvider, request: FlightBotSearchRequest) -> String?
}

enum FlightBotDeviceAdapterRegistry {
    static func adapter(for provider: FlightBotProvider) -> any FlightBotDeviceAdapting {
        switch provider.executionProfile {
        case .uzbekistanBooking: return UzbekistanAirwaysDeviceAdapter()
        case .qanotWebSky: return QanotSharqDeviceAdapter()
        case .centrumIBEDevice: return CentrumAirDeviceAdapter()
        case .airSamarkandSessionDevice: return AirSamarkandDeviceAdapter()
        }
    }
}

private struct UzbekistanAirwaysDeviceAdapter: FlightBotDeviceAdapting {
    let providerID: FlightBotProviderID = .uzbekistanAirways

    func prepareSearch(provider: FlightBotProvider, request: FlightBotSearchRequest) -> String? {
        FlightBotScripts.prepareSearch(provider: provider, request: request)
    }

    func finalizeSearch(provider: FlightBotProvider, request: FlightBotSearchRequest) -> String? {
        FlightBotScripts.finalizeSearch(provider: provider, request: request)
    }
}

/// Qanot is driven by its documented first-party WebSky query parameters.
/// WKWebView executes the WebSky app; no generic DOM form is submitted.
private struct QanotSharqDeviceAdapter: FlightBotDeviceAdapting {
    let providerID: FlightBotProviderID = .qanotSharq
    func prepareSearch(provider: FlightBotProvider, request: FlightBotSearchRequest) -> String? { nil }
    func finalizeSearch(provider: FlightBotProvider, request: FlightBotSearchRequest) -> String? { nil }
}

/// Centrum Air first-party IBE adapter. It targets only route/date/passenger
/// controls on the C6 booking surface. A visible airline verification challenge
/// is handled outside this script in the exact same persistent WKWebView session.
private struct CentrumAirDeviceAdapter: FlightBotDeviceAdapting {
    let providerID: FlightBotProviderID = .centrumAir

    func prepareSearch(provider: FlightBotProvider, request: FlightBotSearchRequest) -> String? {
        let iso = AdapterSupport.date(request.date, "yyyy-MM-dd")
        let numeric = AdapterSupport.date(request.date, "dd/MM/yyyy")
        return """
        (() => {
          const origin = '\(AdapterSupport.escape(request.origin))';
          const destination = '\(AdapterSupport.escape(request.destination))';
          const isoDate = '\(iso)';
          const numericDate = '\(numeric)';
          const adults = \(max(1, request.adults));
          const children = \(max(0, request.children));
          const infants = \(max(0, request.infants));
          const visible = el => {
            if (!el) return false;
            const r = el.getBoundingClientRect();
            const st = getComputedStyle(el);
            return r.width > 0 && r.height > 0 && st.visibility !== 'hidden' && st.display !== 'none';
          };
          const clean = value => String(value || '').replace(/\\s+/g, ' ').trim();
          const descriptor = el => clean([
            el.name, el.id, el.placeholder, el.getAttribute('aria-label'), el.getAttribute('data-testid'),
            el.labels && el.labels.length ? Array.from(el.labels).map(x => x.innerText || '').join(' ') : '',
            el.closest('label,.form-group,.field,[class*=field]')?.innerText || ''
          ].filter(Boolean).join(' ')).toLowerCase();
          const setValue = (el, value) => {
            if (!el) return false;
            if (el.tagName === 'SELECT') {
              const upper = String(value).toUpperCase();
              const option = Array.from(el.options || []).find(o => String(o.value || '').toUpperCase() === upper || clean(o.textContent).toUpperCase().includes(upper));
              if (!option) return false;
              el.value = option.value;
            } else {
              try {
                const proto = Object.getPrototypeOf(el);
                const setter = Object.getOwnPropertyDescriptor(proto, 'value')?.set;
                if (setter) setter.call(el, value); else el.value = value;
              } catch (_) { el.value = value; }
            }
            for (const eventName of ['input','change','blur']) el.dispatchEvent(new Event(eventName, {bubbles:true}));
            return true;
          };
          const controls = Array.from(document.querySelectorAll('input,select')).filter(visible);
          const from = controls.find(el => /(^|\\b)(from|origin|departure)(\\b|$)/.test(descriptor(el)) && !/date/.test(descriptor(el)));
          const to = controls.find(el => el !== from && /(^|\\b)(to|destination|arrival)(\\b|$)/.test(descriptor(el)) && !/date/.test(descriptor(el)));
          const date = controls.find(el => /departure.*date|depart.*date|journey.*date|(^|\\b)date(\\b|$)/.test(descriptor(el)) && !/return/.test(descriptor(el)));
          if (!from || !to || !date) return {ok:false, reason:'centrum-controls-not-found'};

          const oneWay = Array.from(document.querySelectorAll('button,label,[role=button],input[type=radio]')).filter(visible).find(el => {
            const text = clean(el.innerText || el.textContent || el.getAttribute('aria-label') || el.value).toLowerCase();
            return text === 'one way' || text === 'one-way';
          });
          if (oneWay) { try { oneWay.click(); } catch (_) {} }

          const routeOK = setValue(from, origin) && setValue(to, destination);
          const dateValue = date.type === 'date' ? isoDate : numericDate;
          const dateOK = setValue(date, dateValue);

          const setPassenger = (pattern, value, required) => {
            const control = controls.find(el => pattern.test(descriptor(el)));
            if (!control) return !required;
            return setValue(control, String(value));
          };
          const adultsOK = setPassenger(/adult/, adults, adults !== 1);
          const childrenOK = setPassenger(/child|children/, children, children !== 0);
          const infantsOK = setPassenger(/infant/, infants, infants !== 0);
          return {ok:routeOK && dateOK && adultsOK && childrenOK && infantsOK};
        })()
        """
    }

    func finalizeSearch(provider: FlightBotProvider, request: FlightBotSearchRequest) -> String? {
        #"""
        (() => {
          const visible = el => {
            const r = el.getBoundingClientRect();
            const st = getComputedStyle(el);
            return r.width > 0 && r.height > 0 && st.visibility !== 'hidden' && st.display !== 'none';
          };
          const clean = value => String(value || '').replace(/\s+/g, ' ').trim().toLowerCase();
          const allowed = ['search','search flights','find flights','find flight'];
          const buttons = Array.from(document.querySelectorAll('button,input[type=submit],[role=button]')).filter(visible);
          const search = buttons.find(el => {
            const label = clean(el.innerText || el.value || el.getAttribute('aria-label') || '');
            return allowed.includes(label);
          });
          if (!search) return {ok:false, reason:'centrum-search-button-not-found'};
          try { search.click(); return {ok:true, clicked:true}; } catch (_) { return {ok:false, reason:'centrum-search-click-failed'}; }
        })()
        """#
    }
}

/// Air Samarkand's first-party Travelshop session exposes Route type, from/to,
/// calendar, Adults/Children/Infants and Search controls. The adapter requires
/// that exact surface and never falls back to an unrelated form.
private struct AirSamarkandDeviceAdapter: FlightBotDeviceAdapting {
    let providerID: FlightBotProviderID = .airSamarkand

    func prepareSearch(provider: FlightBotProvider, request: FlightBotSearchRequest) -> String? {
        let iso = AdapterSupport.date(request.date, "yyyy-MM-dd")
        let short = AdapterSupport.date(request.date, "d MMM")
        let long = AdapterSupport.date(request.date, "d MMMM yyyy")
        let day = AdapterSupport.date(request.date, "d")
        let monthYear = AdapterSupport.date(request.date, "MMMM yyyy")
        return """
        (() => {
          const origin = '\(AdapterSupport.escape(request.origin))';
          const destination = '\(AdapterSupport.escape(request.destination))';
          const isoDate = '\(iso)';
          const shortDate = '\(short.lowercased())';
          const longDate = '\(long.lowercased())';
          const day = '\(day)';
          const monthYear = '\(monthYear.lowercased())';
          const adults = \(max(1, request.adults));
          const children = \(max(0, request.children));
          const infants = \(max(0, request.infants));
          const visible = el => {
            if (!el) return false;
            const r = el.getBoundingClientRect();
            const st = getComputedStyle(el);
            return r.width > 0 && r.height > 0 && st.visibility !== 'hidden' && st.display !== 'none';
          };
          const clean = value => String(value || '').replace(/\\s+/g, ' ').trim();
          const page = clean(document.body?.innerText || '').toLowerCase();
          const surfaceOK = (page.includes('route type') && page.includes('one way') && page.includes('adults')) ||
                            (page.includes('тип маршрута') && page.includes('в одну сторону') && page.includes('взрос'));
          if (!surfaceOK) return {ok:false, reason:'air-samarkand-surface-mismatch'};

          const descriptor = el => clean([
            el.name, el.id, el.placeholder, el.getAttribute('aria-label'),
            el.labels && el.labels.length ? Array.from(el.labels).map(x => x.innerText || '').join(' ') : '',
            el.closest('label,.field,.form-group,[class*=field]')?.innerText || ''
          ].filter(Boolean).join(' ')).toLowerCase();
          const setNative = (el, value) => {
            if (!el) return false;
            if (el.tagName === 'SELECT') {
              const upper = String(value).toUpperCase();
              const option = Array.from(el.options || []).find(o => String(o.value || '').toUpperCase() === upper || clean(o.textContent).toUpperCase().includes(upper));
              if (!option) return false;
              el.value = option.value;
            } else {
              try {
                const proto = Object.getPrototypeOf(el);
                const setter = Object.getOwnPropertyDescriptor(proto, 'value')?.set;
                if (setter) setter.call(el, value); else el.value = value;
              } catch (_) { el.value = value; }
            }
            for (const e of ['input','change','blur']) el.dispatchEvent(new Event(e, {bubbles:true}));
            return true;
          };

          const allClickable = Array.from(document.querySelectorAll('button,label,[role=button],input[type=radio]')).filter(visible);
          const oneWay = allClickable.find(el => {
            const t = clean(el.innerText || el.textContent || el.getAttribute('aria-label') || el.value).toLowerCase();
            return t === 'one way' || t === "i'm flying one way" || t === 'в одну сторону';
          });
          if (oneWay) { try { oneWay.click(); } catch (_) {} }

          const selects = Array.from(document.querySelectorAll('select')).filter(visible);
          const routeSelects = selects.filter(el => {
            const options = Array.from(el.options || []).slice(0, 80).map(o => clean(o.textContent || o.value)).join(' ');
            return /\\b[A-Z]{3}\\b/.test(options);
          });
          const from = selects.find(el => /from|origin|откуда/.test(descriptor(el))) || routeSelects[0];
          const to = selects.find(el => el !== from && /to|destination|куда/.test(descriptor(el))) || routeSelects.find(el => el !== from);
          if (!from || !to || !setNative(from, origin) || !setNative(to, destination)) return {ok:false, reason:'air-samarkand-route-controls'};

          const dateControls = Array.from(document.querySelectorAll('input,button,[role=button]')).filter(visible).filter(el => /date|depart|вылет|туда/.test(descriptor(el)) || /\\b\\d{1,2}\\s+[a-zа-я]{3,}\\b/i.test(clean(el.value || el.innerText || '')));
          const dateControl = dateControls.find(el => !/return|обратно/.test(descriptor(el))) || dateControls[0];
          if (!dateControl) return {ok:false, reason:'air-samarkand-date-control'};
          try { dateControl.click(); } catch (_) {}
          if (dateControl.tagName === 'INPUT') setNative(dateControl, shortDate);

          const calendarNodes = Array.from(document.querySelectorAll('[data-date],[data-value],[datetime],[aria-label],[title],button,[role=gridcell]')).filter(visible);
          const dateNode = calendarNodes.find(el => {
            const text = clean([el.getAttribute('data-date'),el.getAttribute('data-value'),el.getAttribute('datetime'),el.getAttribute('aria-label'),el.getAttribute('title'),el.innerText].filter(Boolean).join(' ')).toLowerCase();
            return text.includes(isoDate.toLowerCase()) || text.includes(longDate) || text.includes(shortDate);
          }) || calendarNodes.find(el => {
            if (clean(el.innerText || '') !== day) return false;
            const parent = el.closest('[role=dialog],[role=grid],[class*=calendar],[class*=month],[class*=datepicker]');
            return clean(parent?.innerText || '').toLowerCase().includes(monthYear);
          });
          if (dateNode) { try { dateNode.click(); } catch (_) {} }

          const passengerButton = allClickable.find(el => /passenger|пассажир|yo['’]?lovchi/.test(clean(el.innerText || el.textContent || '').toLowerCase()));
          if (passengerButton) { try { passengerButton.click(); } catch (_) {} }

          const chooseCount = (tokens, value, required) => {
            const containers = Array.from(document.querySelectorAll('fieldset,section,div,li')).filter(visible).filter(el => {
              const text = clean(el.innerText || '').toLowerCase();
              return tokens.some(token => text.includes(token)) && text.length < 900;
            }).sort((a,b) => clean(a.innerText).length - clean(b.innerText).length);
            const container = containers[0];
            if (!container) return !required;
            const controls = Array.from(container.querySelectorAll('input,button,label,[role=button]')).filter(visible);
            const expected = String(value);
            const option = controls.find(el => {
              const text = clean(el.value || el.innerText || el.textContent || el.getAttribute('aria-label') || '').toLowerCase();
              return text === expected || (value === 0 && (text === 'no' || text === 'нет'));
            });
            if (!option) return !required;
            try { option.click(); return true; } catch (_) { return false; }
          };
          const adultsOK = chooseCount(['adults','взрос'], adults, adults !== 1);
          const childrenOK = chooseCount(['children up to 12','children','дет'], children, children !== 0);
          const infantsOK = chooseCount(['infants up to 2','infants','млад'], infants, infants !== 0);
          return {ok:adultsOK && childrenOK && infantsOK, route:true, date:!!dateNode || dateControl.tagName === 'INPUT'};
        })()
        """
    }

    func finalizeSearch(provider: FlightBotProvider, request: FlightBotSearchRequest) -> String? {
        #"""
        (() => {
          const visible = el => {
            const r = el.getBoundingClientRect();
            const st = getComputedStyle(el);
            return r.width > 0 && r.height > 0 && st.visibility !== 'hidden' && st.display !== 'none';
          };
          const clean = value => String(value || '').replace(/\s+/g, ' ').trim().toLowerCase();
          const buttons = Array.from(document.querySelectorAll('button,input[type=submit],[role=button]')).filter(visible);
          const search = buttons.find(el => {
            const label = clean(el.innerText || el.value || el.getAttribute('aria-label') || '');
            return label === 'search' || label === 'поиск' || label === 'izlash';
          });
          if (!search) return {ok:false, reason:'air-samarkand-search-button-not-found'};
          try { search.click(); return {ok:true, clicked:true}; } catch (_) { return {ok:false, reason:'air-samarkand-search-click-failed'}; }
        })()
        """#
    }
}

private enum AdapterSupport {
    static func date(_ value: Date, _ format: String) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = format
        return formatter.string(from: value)
    }

    static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }
}
