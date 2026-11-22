#pragma once

#include "CoreMinimal.h"
#include "GameFramework/GameModeBase.h"
#include "EntryProgress.h"
#include "ImperathenGameMode.generated.h"

class UImperathenSaveGame;
class SImperathenMenu;
class ACameraActor;
class UMaterialInstanceDynamic;
class UStaticMesh;

UCLASS()
class IMPERATHEN_API AImperathenGameMode : public AGameModeBase
{
    GENERATED_BODY()
public:
    AImperathenGameMode();
    virtual void BeginPlay() override;
    virtual void EndPlay(const EEndPlayReason::Type EndPlayReason) override;
    virtual void Tick(float DeltaSeconds) override;

    UImperathenSaveGame* InspectSave() const;
    bool HasSave() const;
    bool HasBackup() const;
    bool StartLife(const FString& Name, bool bReplace, FString& Error);
    bool ContinueLife(FString& Error);
    bool RestoreBackup(FString& Error);
    bool Perform(ImperathenEntry::Action Action, FString& Error);
    UImperathenSaveGame* GetLife() const { return ActiveLife; }
    void ReturnToMenu() { ActiveLife = nullptr; ExpectedSaveData.Reset(); }

private:
    bool SaveCandidate(UImperathenSaveGame* Candidate, FString& Error);
    void BuildBackdrop();
    void AddShape(UStaticMesh* Mesh, UMaterialInstanceDynamic* Material, FVector Location, FVector Scale);

    UPROPERTY() TObjectPtr<UImperathenSaveGame> ActiveLife;
    UPROPERTY() TObjectPtr<ACameraActor> SceneCamera;
    TSharedPtr<SImperathenMenu> Menu;
    TArray<uint8> ExpectedSaveData;
    double ScenicTime = 0.0;
};
