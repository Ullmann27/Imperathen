#include "EntryProgress.h"
#include <cassert>
#include <iostream>

using namespace ImperathenEntry;
int main()
{
    Progress Value;
    assert(Value.IsValid());
    assert(Value.Apply(Action::BuildShelter) == Outcome::MissingPrerequisite);
    assert(Value.Apply(Action::HelpNeighbour) == Outcome::MissingPrerequisite);
    assert(Value.Day == 1 && Value.Wood == 0);
    assert(Value.Apply(Action::GatherWood) == Outcome::Applied);
    for (int i = 0; i < 100; ++i) assert(Value.Apply(Action::GatherWood) == Outcome::AlreadyApplied);
    assert(Value.Wood == 6 && Value.Day == 1);
    assert(Value.Apply(Action::BuildShelter) == Outcome::Applied);
    assert(Value.Wood == 2 && Value.Day == 1);
    assert(Value.Apply(Action::BuildShelter) == Outcome::AlreadyApplied);
    assert(Value.Apply(Action::HelpNeighbour) == Outcome::Applied);
    assert(Value.Apply(Action::HelpNeighbour) == Outcome::AlreadyApplied);
    assert(Value.Day == 1 && Value.Wood == 0 && Value.Trust == 10 && Value.IsValid());
    Progress Invalid = Value;
    Invalid.Wood = -1;
    assert(!Invalid.IsValid());
    assert(Invalid.Apply(Action::GatherWood) == Outcome::InvalidState);
    assert(Invalid.Wood == -1);
    for (int flags = 0; flags < 8; ++flags)
    {
        Progress Candidate;
        Candidate.Gathered = (flags & 1) != 0;
        Candidate.ShelterBuilt = (flags & 2) != 0;
        Candidate.Helped = (flags & 4) != 0;
        Candidate.Day = 1;
        Candidate.Wood = (Candidate.Gathered ? 6 : 0) - (Candidate.ShelterBuilt ? 4 : 0) - (Candidate.Helped ? 2 : 0);
        Candidate.Trust = Candidate.Helped ? 10 : 0;
        assert(Candidate.IsValid() == (flags == 0 || flags == 1 || flags == 3 || flags == 7));
    }
    Progress UnknownAction;
    assert(UnknownAction.Apply(static_cast<Action>(123)) == Outcome::InvalidState);
    assert(UnknownAction.IsValid());
    std::cout << "Native entry rules: prerequisites, idempotency, transitions and invalid states passed.\n";
}
