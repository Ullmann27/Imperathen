#include "ImperathenGameMode.h"
#include "ImperathenSaveGame.h"
#include "ImperathenSettings.h"
#include "SImperathenMenu.h"
#include "Camera/CameraActor.h"
#include "Camera/CameraComponent.h"
#include "Components/DirectionalLightComponent.h"
#include "Components/SkyLightComponent.h"
#include "Components/StaticMeshComponent.h"
#include "Engine/DirectionalLight.h"
#include "Engine/GameViewportClient.h"
#include "Engine/SkyLight.h"
#include "Engine/StaticMesh.h"
#include "Engine/StaticMeshActor.h"
#include "Engine/World.h"
#include "GameFramework/PlayerController.h"
#include "Kismet/GameplayStatics.h"
#include "Materials/Material.h"
#include "Materials/MaterialInstanceDynamic.h"
#include "UObject/UObjectGlobals.h"

namespace
{
const FString PrimarySlot = TEXT("ImperathenEntryV1");
const FString BackupSlot = TEXT("ImperathenEntryV1Backup");
}

AImperathenGameMode::AImperathenGameMode()
{
    PrimaryActorTick.bCanEverTick = true;
    DefaultPawnClass = nullptr;
}

void AImperathenGameMode::BeginPlay()
{
    Super::BeginPlay();
    BuildBackdrop();
    if (UGameViewportClient* Viewport = GetWorld()->GetGameViewport())
    {
        Menu = SNew(SImperathenMenu).Owner(this);
        Viewport->AddViewportWidgetContent(Menu.ToSharedRef(), 10);
        if (APlayerController* PC = GetWorld()->GetFirstPlayerController())
        {
            PC->bShowMouseCursor = true;
            if (SceneCamera) PC->SetViewTarget(SceneCamera);
            FInputModeUIOnly InputMode;
            InputMode.SetWidgetToFocus(Menu);
            InputMode.SetLockMouseToViewportBehavior(EMouseLockMode::DoNotLock);
            PC->SetInputMode(InputMode);
        }
    }
}

void AImperathenGameMode::EndPlay(const EEndPlayReason::Type Reason)
{
    if (Menu.IsValid())
    {
        if (UGameViewportClient* Viewport = GetWorld()->GetGameViewport())
            Viewport->RemoveViewportWidgetContent(Menu.ToSharedRef());
        Menu.Reset();
    }
    if (APlayerController* PC = GetWorld()->GetFirstPlayerController())
    {
        PC->SetInputMode(FInputModeGameOnly());
        PC->bShowMouseCursor = false;
    }
    Super::EndPlay(Reason);
}

void AImperathenGameMode::Tick(float DeltaSeconds)
{
    Super::Tick(DeltaSeconds);
    if (!SceneCamera || GetDefault<UImperathenSettings>()->bReducedMotion) return;
    ScenicTime += FMath::Min(DeltaSeconds, 0.1f);
    SceneCamera->SetActorLocation(FVector(-2200.0, -1800.0 + FMath::Sin(ScenicTime * 0.08) * 60.0, 1400.0));
    SceneCamera->SetActorRotation((FVector(600.0, 400.0, 150.0) - SceneCamera->GetActorLocation()).Rotation());
}

bool AImperathenGameMode::HasSave() const { return UGameplayStatics::DoesSaveGameExist(PrimarySlot, 0); }
UImperathenSaveGame* AImperathenGameMode::InspectSave() const
{
    UImperathenSaveGame* Save = Cast<UImperathenSaveGame>(UGameplayStatics::LoadGameFromSlot(PrimarySlot, 0));
    return Save && Save->IsSupported() ? Save : nullptr;
}
bool AImperathenGameMode::HasBackup() const
{
    UImperathenSaveGame* Save = Cast<UImperathenSaveGame>(UGameplayStatics::LoadGameFromSlot(BackupSlot, 0));
    return Save && Save->IsSupported();
}

bool AImperathenGameMode::SaveCandidate(UImperathenSaveGame* Candidate, FString& Error)
{
    if (!Candidate || !Candidate->IsSupported())
    {
        Error = TEXT("Dieser Spielstand ist ungültig. Es wurde nichts übernommen.");
        return false;
    }
    TArray<uint8> Previous;
    if (HasSave() && !UGameplayStatics::LoadDataFromSlot(Previous, PrimarySlot, 0))
    { Error = TEXT("Der bisherige Spielstand konnte nicht gelesen werden."); return false; }
    if (Previous != ExpectedSaveData)
    { Error = TEXT("Der Spielstand wurde zwischenzeitlich geändert. Lade ihn erneut."); return false; }
    if (HasSave())
    {
        if (UGameplayStatics::DoesSaveGameExist(BackupSlot, 0) && !HasBackup())
        { Error = TEXT("Die vorhandene Sicherung kann nicht sicher ersetzt werden. Sie bleibt unverändert."); return false; }
        if (!InspectSave() || !UGameplayStatics::SaveDataToSlot(Previous, BackupSlot, 0))
        {
            Error = TEXT("Der bisherige Stand konnte nicht gesichert werden. Er bleibt erhalten.");
            return false;
        }
    }
    Candidate->SavedAt = FDateTime::UtcNow();
    TArray<uint8> NewData;
    if (!UGameplayStatics::SaveGameToMemory(Candidate, NewData)
        || !UGameplayStatics::SaveDataToSlot(NewData, PrimarySlot, 0))
    {
        Error = TEXT("Speichern fehlgeschlagen. Die Aktion wurde nicht übernommen. Eine vorhandene Sicherung bleibt erhalten.");
        return false;
    }
    ExpectedSaveData = MoveTemp(NewData);
    ActiveLife = Candidate;
    return true;
}

bool AImperathenGameMode::StartLife(const FString& Name, bool bReplace, FString& Error)
{
    Error.Empty();
    if (HasSave() && !bReplace)
    {
        Error = TEXT("Bitte bestätige ausdrücklich den Beginn eines neuen Lebens.");
        return false;
    }
    UImperathenSaveGame* Candidate = Cast<UImperathenSaveGame>(UGameplayStatics::CreateSaveGameObject(UImperathenSaveGame::StaticClass()));
    if (!Candidate) { Error = TEXT("Das neue Leben konnte nicht vorbereitet werden."); return false; }
    Candidate->PlayerName = Name.TrimStartAndEnd();
    if (!Candidate->IsSupported()) { Error = TEXT("Gib einen Namen mit 1 bis 32 Zeichen ein."); return false; }
    ExpectedSaveData.Reset();
    if (HasSave() && !UGameplayStatics::LoadDataFromSlot(ExpectedSaveData, PrimarySlot, 0))
    { Error = TEXT("Der bisherige Spielstand konnte nicht gelesen werden."); return false; }
    return SaveCandidate(Candidate, Error);
}

bool AImperathenGameMode::ContinueLife(FString& Error)
{
    Error.Empty();
    TArray<uint8> Data;
    UImperathenSaveGame* Save = UGameplayStatics::LoadDataFromSlot(Data, PrimarySlot, 0)
        ? Cast<UImperathenSaveGame>(UGameplayStatics::LoadGameFromMemory(Data)) : nullptr;
    if (!Save || !Save->IsSupported())
    {
        Error = HasSave() ? TEXT("Der Spielstand ist beschädigt oder verwendet ein anderes Format. Er bleibt unverändert.")
                          : TEXT("Es gibt noch kein gespeichertes Leben.");
        return false;
    }
    ExpectedSaveData = MoveTemp(Data);
    ActiveLife = Save;
    return true;
}

bool AImperathenGameMode::RestoreBackup(FString& Error)
{
    Error.Empty();
    TArray<uint8> Data;
    UImperathenSaveGame* Backup = UGameplayStatics::LoadDataFromSlot(Data, BackupSlot, 0)
        ? Cast<UImperathenSaveGame>(UGameplayStatics::LoadGameFromMemory(Data)) : nullptr;
    if (!Backup || !Backup->IsSupported())
    {
        Error = TEXT("Keine gültige Sicherung verfügbar.");
        return false;
    }
    // Keep the current bytes as a separate recovery file before explicit replacement.
    if (HasSave())
    {
        TArray<uint8> Original;
        if (!UGameplayStatics::LoadDataFromSlot(Original, PrimarySlot, 0))
        { Error = TEXT("Der bestehende Spielstand konnte nicht vor der Wiederherstellung gesichert werden."); return false; }
        USaveGame* OriginalObject = UGameplayStatics::LoadGameFromMemory(Original);
        const auto* OriginalSave = Cast<UImperathenSaveGame>(OriginalObject);
        if (OriginalObject && (!OriginalSave || OriginalSave->FormatVersion != 1))
        { Error = TEXT("Der bestehende Spielstand verwendet ein anderes Format und bleibt unverändert."); return false; }
        const FString RecoverySlot = TEXT("ImperathenEntryV1BeforeRecovery");
        TArray<uint8> Recovery;
        if (UGameplayStatics::DoesSaveGameExist(RecoverySlot, 0))
        {
            if (!UGameplayStatics::LoadDataFromSlot(Recovery, RecoverySlot, 0) || Recovery != Original)
            { Error = TEXT("Ein früheres Original ist bereits aufbewahrt. Sichere es separat, bevor du erneut wiederherstellst."); return false; }
        }
        else if (!UGameplayStatics::SaveDataToSlot(Original, RecoverySlot, 0))
        { Error = TEXT("Der bisherige Inhalt konnte nicht aufbewahrt werden. Wiederherstellung abgebrochen."); return false; }
        TArray<uint8> Latest;
        if (!UGameplayStatics::LoadDataFromSlot(Latest, PrimarySlot, 0) || Latest != Original)
        { Error = TEXT("Der Spielstand wurde zwischenzeitlich geändert. Wiederherstellung abgebrochen."); return false; }
    }
    if (!UGameplayStatics::SaveDataToSlot(Data, PrimarySlot, 0))
    { Error = TEXT("Wiederherstellen fehlgeschlagen. Die Sicherung ist weiterhin vorhanden."); return false; }
    return ContinueLife(Error);
}

bool AImperathenGameMode::Perform(ImperathenEntry::Action Action, FString& Error)
{
    Error.Empty();
    if (!ActiveLife) { Error = TEXT("Lade zuerst ein Leben."); return false; }
    auto Progress = ActiveLife->GetProgress();
    const auto Outcome = Progress.Apply(Action);
    if (Outcome == ImperathenEntry::Outcome::AlreadyApplied) return true;
    if (Outcome != ImperathenEntry::Outcome::Applied)
    { Error = TEXT("Dafür ist zuerst der vorherige Schritt erforderlich."); return false; }
    UImperathenSaveGame* Candidate = DuplicateObject<UImperathenSaveGame>(ActiveLife, this);
    Candidate->SetProgress(Progress);
    return SaveCandidate(Candidate, Error);
}

void AImperathenGameMode::AddShape(UStaticMesh* Mesh, UMaterialInstanceDynamic* Material, FVector Location, FVector Scale)
{
    if (!Mesh) return;
    AStaticMeshActor* Shape = GetWorld()->SpawnActor<AStaticMeshActor>(Location, FRotator::ZeroRotator);
    if (!Shape) return;
    UStaticMeshComponent* Component = Shape->GetStaticMeshComponent();
    Component->SetMobility(EComponentMobility::Movable);
    Component->SetStaticMesh(Mesh);
    Component->SetCollisionEnabled(ECollisionEnabled::NoCollision);
    if (Material) Component->SetMaterial(0, Material);
    Shape->SetActorScale3D(Scale);
}

void AImperathenGameMode::BuildBackdrop()
{
    UStaticMesh* Cube = LoadObject<UStaticMesh>(nullptr, TEXT("/Engine/BasicShapes/Cube.Cube"));
    UStaticMesh* Column = LoadObject<UStaticMesh>(nullptr, TEXT("/Engine/BasicShapes/Cylinder.Cylinder"));
    UMaterial* Base = LoadObject<UMaterial>(nullptr, TEXT("/Engine/BasicShapes/BasicShapeMaterial.BasicShapeMaterial"));
    const auto MakeMaterial = [this, Base](FLinearColor Color) -> UMaterialInstanceDynamic*
    {
        if (!Base) return nullptr;
        auto* Material = UMaterialInstanceDynamic::Create(Base, this);
        Material->SetVectorParameterValue(TEXT("Color"), Color);
        return Material;
    };
    auto* Stone = MakeMaterial(FLinearColor(0.55f, 0.42f, 0.26f));
    auto* Roof = MakeMaterial(FLinearColor(0.22f, 0.055f, 0.025f));
    auto* Earth = MakeMaterial(FLinearColor(0.12f, 0.15f, 0.09f));
    AddShape(Cube, Earth, FVector(500, 500, -70), FVector(85, 65, 1));
    for (int Row = 0; Row < 5; ++Row)
    {
        for (int Col = 0; Col < 7; ++Col)
        {
            const FVector Position(Col * 400.0 - 200.0, Row * 470.0 - 300.0, 100.0);
            const double Height = 1.7 + ((Row + Col * 3) % 4) * 0.4;
            AddShape(Cube, Stone, Position, FVector(2.7, 3.0, Height));
            AddShape(Cube, Roof, Position + FVector(0, 0, Height * 50.0 + 15.0), FVector(3.0, 3.3, 0.30));
        }
    }
    AddShape(Cube, Stone, FVector(900, 2600, 110), FVector(32, 0.8, 2.7));
    for (int Tower = 0; Tower < 7; ++Tower)
        AddShape(Cube, Stone, FVector(-550 + Tower * 500, 2600, 220), FVector(1.7, 1.7, 4.5));
    AddShape(Cube, Stone, FVector(1500, 1200, 300), FVector(8, 5, 0.6));
    for (int Pillar = 0; Pillar < 6; ++Pillar)
        AddShape(Column, Stone, FVector(1150 + Pillar * 140, 1000, 150), FVector(0.5, 0.5, 3));
    ADirectionalLight* Sun = GetWorld()->SpawnActor<ADirectionalLight>(FVector(0, 0, 2000), FRotator(-25, -35, 0));
    if (Sun)
    {
        Sun->GetLightComponent()->SetMobility(EComponentMobility::Movable);
        Sun->GetLightComponent()->SetIntensity(5.0f);
        Sun->GetLightComponent()->SetLightColor(FLinearColor(1.0f, 0.78f, 0.50f));
    }
    ASkyLight* Sky = GetWorld()->SpawnActor<ASkyLight>();
    if (Sky)
    {
        Sky->GetLightComponent()->SetMobility(EComponentMobility::Movable);
        Sky->GetLightComponent()->SetIntensity(1.4f);
        Sky->GetLightComponent()->SetLowerHemisphereColor(FLinearColor(0.18f, 0.21f, 0.25f));
        Sky->GetLightComponent()->RecaptureSky();
    }
    SceneCamera = GetWorld()->SpawnActor<ACameraActor>(FVector(-2200, -1800, 1400), FRotator(-22, 36, 0));
    if (SceneCamera)
    {
        SceneCamera->GetCameraComponent()->SetFieldOfView(65.0f);
        SceneCamera->SetActorRotation((FVector(600, 400, 150) - SceneCamera->GetActorLocation()).Rotation());
    }
}
