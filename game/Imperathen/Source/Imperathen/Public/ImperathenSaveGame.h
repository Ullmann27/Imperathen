#pragma once

#include "CoreMinimal.h"
#include "GameFramework/SaveGame.h"
#include "EntryProgress.h"
#include "ImperathenSaveGame.generated.h"

UCLASS()
class IMPERATHEN_API UImperathenSaveGame : public USaveGame
{
    GENERATED_BODY()
public:
    UPROPERTY(SaveGame) int32 FormatVersion = 1;
    UPROPERTY(SaveGame) FString PlayerName;
    UPROPERTY(SaveGame) int32 Day = 1;
    UPROPERTY(SaveGame) int32 Wood = 0;
    UPROPERTY(SaveGame) int32 Trust = 0;
    UPROPERTY(SaveGame) bool bGathered = false;
    UPROPERTY(SaveGame) bool bShelterBuilt = false;
    UPROPERTY(SaveGame) bool bHelped = false;
    UPROPERTY(SaveGame) FDateTime SavedAt;

    ImperathenEntry::Progress GetProgress() const
    {
        return { Day, Wood, Trust, bGathered, bShelterBuilt, bHelped };
    }
    void SetProgress(const ImperathenEntry::Progress& Value)
    {
        Day = Value.Day; Wood = Value.Wood; Trust = Value.Trust;
        bGathered = Value.Gathered; bShelterBuilt = Value.ShelterBuilt; bHelped = Value.Helped;
    }
    bool IsSupported() const
    {
        const FString Name = PlayerName.TrimStartAndEnd();
        if (FormatVersion != 1 || Name.Len() < 1 || Name.Len() > 32 || Name != PlayerName) return false;
        for (const TCHAR C : Name) if (C < 32) return false;
        return GetProgress().IsValid();
    }
};
