#pragma once

#include "CoreMinimal.h"
#include "UObject/Object.h"
#include "ImperathenSettings.generated.h"

UCLASS(Config=GameUserSettings)
class IMPERATHEN_API UImperathenSettings : public UObject
{
    GENERATED_BODY()
public:
    UPROPERTY(Config) float TextScale = 1.0f;
    UPROPERTY(Config) bool bReducedMotion = false;
    UPROPERTY(Config) bool bHighContrast = false;

    void Persist()
    {
        TextScale = FMath::IsFinite(TextScale) ? FMath::Clamp(TextScale, 1.0f, 1.25f) : 1.0f;
        SaveConfig();
    }
};
