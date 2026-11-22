#pragma once

#include <cstdint>

// Engine-independent native entry rules. No world simulation runs in the menu.
namespace ImperathenEntry
{
enum class Action { GatherWood, BuildShelter, HelpNeighbour };
enum class Outcome { Applied, AlreadyApplied, MissingPrerequisite, InvalidState };

struct Progress
{
    std::int32_t Day = 1;
    std::int32_t Wood = 0;
    std::int32_t Trust = 0;
    bool Gathered = false;
    bool ShelterBuilt = false;
    bool Helped = false;

    bool IsValid() const
    {
        if (ShelterBuilt && !Gathered) return false;
        if (Helped && !ShelterBuilt) return false;
        return Day == 1 && Wood == (Gathered ? 6 : 0) - (ShelterBuilt ? 4 : 0) - (Helped ? 2 : 0)
            && Trust == (Helped ? 10 : 0);
    }

    Outcome Apply(Action Value)
    {
        if (!IsValid()) return Outcome::InvalidState;
        switch (Value)
        {
        case Action::GatherWood:
            if (Gathered) return Outcome::AlreadyApplied;
            Gathered = true;
            Wood += 6;
            break;
        case Action::BuildShelter:
            if (ShelterBuilt) return Outcome::AlreadyApplied;
            if (!Gathered || Wood < 4) return Outcome::MissingPrerequisite;
            ShelterBuilt = true;
            Wood -= 4;
            break;
        case Action::HelpNeighbour:
            if (Helped) return Outcome::AlreadyApplied;
            if (!ShelterBuilt || Wood < 2) return Outcome::MissingPrerequisite;
            Helped = true;
            Wood -= 2;
            Trust = 10;
            break;
        default:
            return Outcome::InvalidState;
        }
        return Outcome::Applied;
    }
};
}
