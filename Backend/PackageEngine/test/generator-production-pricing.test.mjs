import assert from 'node:assert/strict';
import fs from 'node:fs';

const root = new URL('../../../', import.meta.url);
const hotelService = fs.readFileSync(new URL('Sources/HotelPricing/HotelLivePriceSearchService.swift', root), 'utf8');
const hotelBot = fs.readFileSync(new URL('Sources/HotelPricing/HotelPriceBotRunner.swift', root), 'utf8');
const coordinator = fs.readFileSync(new URL('Sources/Services/RealFlightPackageSearchService.swift', root), 'utf8');
const journey = fs.readFileSync(new URL('Sources/State/JourneyStore.swift', root), 'utf8');
const finalView = fs.readFileSync(new URL('Sources/Views/Package/FinalPackageView.swift', root), 'utf8');
const flightCard = fs.readFileSync(new URL('Sources/Views/Components/FlightCard.swift', root), 'utf8');
const outbound = fs.readFileSync(new URL('Sources/Views/Flights/OutboundFlightView.swift', root), 'utf8');
const inbound = fs.readFileSync(new URL('Sources/Views/Flights/ReturnFlightView.swift', root), 'utf8');

assert.match(hotelService, /forceRefresh:\s*Bool\s*=\s*false/);
assert.match(hotelService, /if isComplete \{\s*cache\[key\]/s);
assert.match(hotelService, /let isComplete = !snapshot\.makkah\.isEmpty/);
assert.match(hotelService, /resolvedRoomCount\(for: trip\)/);
assert.match(hotelBot, /roomName:\s*nil/);
assert.match(coordinator, /isCompleteHotelSnapshot/);
assert.match(coordinator, /hotelPriceService\.invalidateAll\(\)/);
assert.match(journey, /buildQuote\(forceHotelRefresh:\s*Bool\s*=\s*false\)/);
assert.match(journey, /normalizedRoomNightUsd\s*>?=\s*15/);
assert.match(journey, /cheapest\.totalUsd\s*\*\s*Decimal\(string:\s*"1\.50"\)!\s*<\s*highest\.totalUsd/);
assert.match(finalView, /recalculatePrice\(forceHotelRefresh:\s*true\)/);
assert.match(flightCard, /referenceOffer:\s*FlightOffer\?/);
assert.match(flightCard, /current\s*-\s*baseline/);
assert.match(flightCard, /return "\\\(sign\)\\\(absolute\) \\\(currency\)"/);
assert.match(outbound, /referenceOffer:\s*recommendedOffer/);
assert.match(outbound, /chooseOutboundFlight\(recommendedOffer\)/);
assert.match(inbound, /referenceOffer:\s*recommendedOffer/);
assert.match(inbound, /chooseInboundFlight\(recommendedOffer\)/);

console.log('production hotel verification + relative flight pricing contract OK');
