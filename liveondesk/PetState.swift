//
//  PetState.swift
//  liveondesk
//

/// All possible behavioral states of the desktop pet.
///
/// The state machine transitions are:
///
///     falling → walking (on landing contact)
///     walking → idle    (after 5-10s random)
///     walking → jumping (near a square window)
///     idle    → sleeping (after 4-8s random)
///     idle    → dancing  (music app detected)
///     sleeping → walking (after 6-14s random)
///     jumping  → walking (on landing)
///     dancing  → idle    (music app deactivated / timeout)
///     hiding   → walking (after random duration)
///     any      → falling (when platform disappears)
///
enum PetState: Equatable {
    case falling
    case walking
    case idle
    case sleeping
    case jumping
    case dancing
    case hiding
}
