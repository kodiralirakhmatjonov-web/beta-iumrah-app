import Foundation

enum HotelPriceBotScripts {
    static let detectChallenge = """
    (() => {
      const body = (document.body?.innerText || '').toLowerCase();
      const markers = ['captcha','verify you are human','not a robot','robot verification','security check','unusual traffic'];
      return markers.some(m => body.includes(m));
    })()
    """

    static func extractExactHotel(provider: HotelPriceProvider, hotelName: String, roomName: String?) -> String {
        let escapedName = jsEscape(hotelName)
        let escapedRoom = jsEscape(roomName ?? "")
        let providerID = provider.id.rawValue
        return """
        (() => {
          const provider = '\(providerID)';
          const wanted = '\(escapedName)';
          const wantedRoom = '\(escapedRoom)';
          const clean = v => (v || '').replace(/\\s+/g,' ').trim();
          const normalize = v => clean(v).toLowerCase().normalize('NFD').replace(/[\\u0300-\\u036f]/g,'').replace(/[^a-z0-9]+/g,' ');
          const stop = new Set(['hotel','hotels','makkah','mecca','madinah','medina','the','al','by','and','resort','apartments','hotel']);
          const targetTokens = normalize(wanted).split(' ').filter(t => t.length > 2 && !stop.has(t));
          const normalizedWantedRoom = normalize(wantedRoom);
          const roomStop = new Set(['room','rooms','guest','guests','bed','beds']);
          const roomTokens = normalizedWantedRoom.split(' ').filter(t => t.length > 2 && !roomStop.has(t));
          const categoryTerms = ['single','double','triple','quadruple','family','suite','deluxe','executive','superior','standard','king','queen','twin'];
          const requiredCategoryTerms = categoryTerms.filter(t => normalizedWantedRoom.split(' ').includes(t));
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
          const money = /(?:US\\$|USD|\\$|€|EUR|SAR|AED|GBP|£)\\s*[0-9][0-9\\s,.]*/i;
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
            const score = Math.max(similarity(title), similarity(body) * 0.86);
            if (score < 0.62 || !money.test(body)) continue;
            let roomEvidence = true;
            if (wantedRoom) {
              const normalizedBody = normalize(body);
              // The internal iumrah room ID is not a Booking/Expedia inventory ID.
              // We only correlate it after the selected human-readable category is
              // actually visible on the priced provider card.
              const exactPhrase = normalizedWantedRoom.length > 0 && normalizedBody.includes(normalizedWantedRoom);
              const distinctiveMatch = roomTokens.length >= 2 && roomTokens.every(token => normalizedBody.includes(token));
              const categoryMatch = requiredCategoryTerms.length > 0 && requiredCategoryTerms.every(token => normalizedBody.includes(token));
              roomEvidence = exactPhrase || distinctiveMatch || categoryMatch;
              if (!roomEvidence) continue;
            }

            let priceText = '';
            let metaText = '';
            if (provider === 'booking') {
              priceText = clean(card.querySelector('[data-testid="price-and-discounted-price"]')?.innerText || '');
              metaText = clean(card.querySelector('[data-testid="price-for-x-nights"]')?.innerText || '');
            } else {
              const priceNodes = Array.from(card.querySelectorAll('[data-stid*="price"],[class*="price" i]')).filter(visible);
              priceText = clean(priceNodes.map(x => x.innerText).filter(Boolean).join(' '));
              const totalNode = Array.from(card.querySelectorAll('*')).find(el => /total|for \\d+ nights?/i.test(clean(el.innerText)) && money.test(clean(el.innerText)));
              metaText = clean(totalNode?.innerText || '');
            }
            if (!priceText) {
              const candidates = (body.match(/(?:US\\$|USD|\\$|€|EUR|SAR|AED|GBP|£)\\s*[0-9][0-9\\s,.]*/ig) || []);
              priceText = clean(candidates.join(' | '));
            }

            if (!best || score > bestScore) {
              bestScore = score;
              best = { title, priceText, metaText, body: body.slice(0, 4200), url: location.href, score, roomEvidence };
            }
          }
          return best ? JSON.stringify(best) : '';
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
