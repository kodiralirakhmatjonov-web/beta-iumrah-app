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
        sourceIdentity: HotelPricingSourceIdentity?,
        checkInDate: String,
        checkOutDate: String
    ) -> String {
        let escapedName = jsEscape(hotelName)
        let escapedRoom = jsEscape(roomName ?? "")
        let providerID = provider.id.rawValue
        let expectedHotelID = jsEscape(sourceIdentity?.providerHotelID ?? "")
        let expectedURL = jsEscape(sourceIdentity?.canonicalURL ?? sourceIdentity?.sourceURL ?? "")
        let expectedCheckIn = jsEscape(checkInDate)
        let expectedCheckOut = jsEscape(checkOutDate)
        return #"""
        (() => {
          const provider = '\#(providerID)';
          const wanted = '\#(escapedName)';
          const wantedRoom = '\#(escapedRoom)';
          const expectedHotelID = '\#(expectedHotelID)'.toLowerCase();
          const expectedURL = '\#(expectedURL)'.toLowerCase();
          const expectedCheckIn = '\#(expectedCheckIn)';
          const expectedCheckOut = '\#(expectedCheckOut)';
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
          const currentURL = location.href || '';
          const inputValues = Array.from(document.querySelectorAll('input')).map(input => String(input.value || ''));
          const hasRequestedDate = value => currentURL.includes(value) || inputValues.some(input => input.includes(value));
          const dateEvidence = hasRequestedDate(expectedCheckIn) && hasRequestedDate(expectedCheckOut);
          const money = /(?:US\$|USD|\$|€|EUR|SAR|AED|GBP|£)\s*[0-9][0-9\s,.]*/i;
          const priceSelectors = provider === 'booking'
            ? [
                '[data-testid="price-and-discounted-price"]',
                '[data-testid="availability-rate-information"] [data-testid*="price"]',
                '.prco-valign-middle-helper',
                '[class*="price" i]'
              ]
            : [
                '[data-stid="price-lockup-text"]',
                '[data-stid="price-summary"]',
                '[data-stid*="price" i]',
                '[class*="price" i]'
              ];
          const metaSelectors = provider === 'booking'
            ? ['[data-testid="price-for-x-nights"]', '[data-testid="taxes-and-charges"]', '[data-testid="availability-rate-information"]']
            : ['[data-stid="price-summary"]', '[data-stid*="price-lockup" i]', '[data-stid*="tax" i]'];
          const textsFor = (root, selectors, max = 24) => {
            const seen = new Set();
            const output = [];
            for (const selector of selectors) {
              for (const node of Array.from(root.querySelectorAll(selector))) {
                if (!visible(node)) continue;
                const value = clean(node.innerText || node.textContent || '');
                if (!value || !money.test(value) || seen.has(value)) continue;
                seen.add(value);
                output.push(value);
                if (output.length >= max) return output;
              }
            }
            return output;
          };
          const titleFor = root => clean(
            root.querySelector('[data-testid="title"], [data-stid*="content-hotel-title"], h1, h2, h3')?.innerText ||
            root.querySelector('[data-testid="title"], [data-stid*="content-hotel-title"], h1, h2, h3')?.textContent || ''
          );
          const selector = provider === 'booking'
            ? '[data-testid="property-card"]'
            : '[data-stid*="property-listing"], article, li[data-stid], [role=listitem]';
          let cards = Array.from(document.querySelectorAll(selector)).filter(visible);
          if (!cards.length) cards = Array.from(document.querySelectorAll('article, [role=listitem], li')).filter(visible);

          let best = null;
          let bestScore = 0;
          for (const card of cards.slice(0, 120)) {
            const title = titleFor(card);
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

            let priceText = clean(textsFor(card, priceSelectors).join(' | '));
            let metaText = clean(textsFor(card, metaSelectors, 12).join(' | '));
            if (!priceText) {
              const candidates = (body.match(/(?:US\$|USD|\$|€|EUR|SAR|AED|GBP|£)\s*[0-9][0-9\s,.]*/ig) || []);
              priceText = clean(candidates.join(' | '));
            }

            if (!best || score > bestScore) {
              bestScore = score;
              best = { title, priceText, metaText, body: body.slice(0, 6000), url: currentURL, score, roomEvidence: true, dateEvidence };
            }
          }

          // A curated canonical URL opens the exact property page rather than a
          // list card. Read its visible availability/price surface as a second
          // shape while keeping the same strict hotel and requested-date checks.
          if (!best) {
            const root = document.querySelector('main') || document.body;
            const body = clean(root?.innerText || '');
            const title = titleFor(root || document);
            const exactIdentity = identityMatch(currentURL);
            const nameScore = Math.max(similarity(title), similarity(body) * 0.82);
            if ((exactIdentity || nameScore >= 0.82) && dateEvidence && money.test(body)) {
              const priceText = clean(textsFor(root, priceSelectors, 40).join(' | '));
              const metaText = clean(textsFor(root, metaSelectors, 20).join(' | '));
              if (priceText) {
                bestScore = Math.min(1, nameScore + (exactIdentity ? 0.28 : 0));
                best = { title, priceText, metaText, body: body.slice(0, 9000), url: currentURL, score: bestScore, roomEvidence: true, dateEvidence };
              }
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
