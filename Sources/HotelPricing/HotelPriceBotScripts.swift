import Foundation

enum HotelPriceBotScripts {
    static let detectChallenge = """
    (() => {
      const body = (document.body?.innerText || '').toLowerCase();
      const markers = ['captcha','verify you are human','not a robot','robot verification','security check','unusual traffic'];
      return markers.some(m => body.includes(m));
    })()
    """

    static func extractExactHotel(
        provider: HotelPriceProvider,
        hotelName: String,
        roomName: String?,
        sourceIdentity: HotelPricingSourceIdentity?
    ) -> String {
        let escapedName = jsEscape(hotelName)
        let escapedRoom = jsEscape(roomName ?? "")
        let providerID = provider.id.rawValue
        let expectedHotelID = jsEscape(sourceIdentity?.providerHotelID ?? "")
        let expectedURL = jsEscape(sourceIdentity?.canonicalURL ?? sourceIdentity?.sourceURL ?? "")
        return #"""
        (() => {
          const provider = '\#(providerID)';
          const wanted = '\#(escapedName)';
          const wantedRoom = '\#(escapedRoom)';
          const expectedHotelID = '\#(expectedHotelID)'.toLowerCase();
          const expectedURL = '\#(expectedURL)'.toLowerCase();
          const clean = v => (v || '').replace(/\s+/g,' ').trim();
          const normalize = v => clean(v).toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g,'').replace(/[^a-z0-9]+/g,' ');
          const stop = new Set(['hotel','hotels','makkah','mecca','madinah','medina','the','al','by','and','resort','apartments']);
          const targetTokens = normalize(wanted).split(' ').filter(t => t.length > 2 && !stop.has(t));
          const visible = el => {
            const r = el.getBoundingClientRect();
            const s = getComputedStyle(el);
            return r.width > 0 && r.height > 0 && s.visibility !== 'hidden' && s.display !== 'none';
          };
          const similarity = value => {
            const n = normalize(value);
            if (!targetTokens.length) return 0;
            return targetTokens.filter(t => n.includes(t)).length / targetTokens.length;
          };
          const identityMatch = href => {
            const h = (href || '').toLowerCase();
            if (!h) return false;
            if (expectedHotelID && h.includes(expectedHotelID)) return true;
            if (expectedURL) {
              try {
                const expected = new URL(expectedURL);
                const actual = new URL(href, location.href);
                const ep = expected.pathname.replace(/\/$/, '');
                const ap = actual.pathname.replace(/\/$/, '');
                if (ep && ap && (ap === ep || ap.includes(ep) || ep.includes(ap))) return true;
              } catch (_) {}
            }
            return false;
          };
          const money = /(?:US\$|USD|\$|€|EUR|SAR|AED|GBP|£)\s*[0-9][0-9\s,.]*/i;
          const selector = provider === 'booking'
            ? '[data-testid="property-card"]'
            : '[data-stid*="property-listing"], article, li[data-stid], [role=listitem]';
          let cards = Array.from(document.querySelectorAll(selector)).filter(visible);
          if (!cards.length) cards = Array.from(document.querySelectorAll('article, [role=listitem], li')).filter(visible);

          let best = null;
          let bestScore = 0;
          for (const card of cards.slice(0, 120)) {
            const titleEl = card.querySelector('[data-testid="title"],h2,h3,[data-stid*="content-hotel-title"],[aria-label*="hotel" i]');
            const title = clean(titleEl?.innerText || titleEl?.textContent || '');
            const body = clean(card.innerText || '');
            const anchor = card.querySelector('a[href]');
            const href = anchor?.href || '';
            const exactIdentity = identityMatch(href);
            const nameScore = Math.max(similarity(title), similarity(body) * 0.86);
            const score = Math.min(1, nameScore + (exactIdentity ? 0.28 : 0));
            // A known Business-side property identity is preferred, while a very
            // strong exact-name match remains a safe fallback if a provider changed URL format.
            if (expectedURL || expectedHotelID) {
              if (!exactIdentity && nameScore < 0.82) continue;
            } else if (nameScore < 0.62) continue;
            if (!money.test(body)) continue;

            let priceText = '';
            let metaText = '';
            if (provider === 'booking') {
              priceText = clean(card.querySelector('[data-testid="price-and-discounted-price"]')?.innerText || '');
              metaText = clean(card.querySelector('[data-testid="price-for-x-nights"]')?.innerText || '');
            } else {
              const priceNodes = Array.from(card.querySelectorAll('[data-stid*="price"],[class*="price" i]')).filter(visible);
              priceText = clean(priceNodes.map(x => x.innerText).filter(Boolean).join(' '));
              const totalNode = Array.from(card.querySelectorAll('*')).find(el => /total|for \d+ nights?/i.test(clean(el.innerText)) && money.test(clean(el.innerText)));
              metaText = clean(totalNode?.innerText || '');
            }
            if (!priceText) {
              const candidates = (body.match(/(?:US\$|USD|\$|€|EUR|SAR|AED|GBP|£)\s*[0-9][0-9\s,.]*/ig) || []);
              priceText = clean(candidates.join(' | '));
            }

            if (!best || score > bestScore) {
              bestScore = score;
              let absoluteURL = location.href;
              try { if (href) absoluteURL = new URL(href, location.href).href; } catch (_) {}
              best = { title, priceText, metaText, body: body.slice(0, 4200), url: absoluteURL, score, roomEvidence: true };
            }
          }
          return best ? JSON.stringify(best) : '';
        })()
        """#
    }

    private static func jsEscape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }
}
