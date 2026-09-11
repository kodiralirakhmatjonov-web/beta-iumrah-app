import Foundation

// Intentionally kept as a compatibility shim.
//
// PackageTierComparisonOption and JourneyStore package-tier comparison methods
// are implemented in JourneyStore.swift in the current repository state.
// This file used to contain a second copy of those declarations, which caused
// `invalid redeclaration` / `ambiguous for type lookup` compiler errors.
//
// Keep this file source-compatible and declaration-free so existing project
// generation/source discovery can continue without introducing duplicates.
