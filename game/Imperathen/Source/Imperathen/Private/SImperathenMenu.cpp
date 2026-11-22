#include "SImperathenMenu.h"
#include "ImperathenGameMode.h"
#include "ImperathenSaveGame.h"
#include "ImperathenSettings.h"
#include "Framework/Application/SlateApplication.h"
#include "Input/Events.h"
#include "InputCoreTypes.h"
#include "Styling/CoreStyle.h"
#include "Widgets/Input/SButton.h"
#include "Widgets/Input/SCheckBox.h"
#include "Widgets/Input/SEditableTextBox.h"
#include "Widgets/Layout/SBorder.h"
#include "Widgets/Layout/SBox.h"
#include "Widgets/Layout/SScrollBox.h"
#include "Widgets/SBoxPanel.h"
#include "Widgets/Text/STextBlock.h"

void SImperathenMenu::Construct(const FArguments& Args)
{
    Owner = Args._Owner;
    if (GetDefault<UImperathenSettings>()->bReducedMotion) CurrentPage = Page::Menu;
    Build();
}

void SImperathenMenu::Show(Page Next)
{
    CurrentPage = Next;
    Error.Empty();
    if (Next == Page::NewLife) { bReplaceConfirmed = false; EnteredName.Empty(); }
    Build();
}

void SImperathenMenu::Text(const FString& Value, float Size)
{
    const float Scale = FMath::Clamp(GetDefault<UImperathenSettings>()->TextScale, 1.0f, 1.25f);
    Body->AddSlot().AutoHeight().Padding(0, 7)
    [ SNew(STextBlock).Text(FText::FromString(Value)).AutoWrapText(true)
      .Font(FCoreStyle::GetDefaultFontStyle("Regular", FMath::RoundToInt(Size * Scale)))
      .ColorAndOpacity(FLinearColor(0.94f, 0.88f, 0.72f)) ];
}

TSharedRef<SWidget> SImperathenMenu::Button(const FString& Label, TFunction<void()> Action, bool bEnabled)
{
    const auto Widget = SNew(SButton).ContentPadding(FMargin(16, 12)).IsEnabled(bEnabled)
        .OnClicked_Lambda([Action = MoveTemp(Action)]() { Action(); return FReply::Handled(); })
        [ SNew(STextBlock).Text(FText::FromString(Label))
          .Font(FCoreStyle::GetDefaultFontStyle("Regular", FMath::RoundToInt(20.0f * FMath::Clamp(GetDefault<UImperathenSettings>()->TextScale, 1.0f, 1.25f)))) ];
    if (!FirstButton.IsValid() && bEnabled) FirstButton = Widget;
    return Widget;
}

void SImperathenMenu::Build()
{
    FirstButton.Reset();
    const bool Contrast = GetDefault<UImperathenSettings>()->bHighContrast;
    ChildSlot.HAlign(HAlign_Left).VAlign(VAlign_Fill).Padding(32)
    [ SNew(SBox).WidthOverride(540)
      [ SNew(SBorder).Padding(28)
        .BorderImage(FCoreStyle::Get().GetBrush("WhiteBrush"))
        .BorderBackgroundColor(Contrast ? FLinearColor(0.015f, 0.015f, 0.015f, 1.0f) : FLinearColor(0.035f, 0.025f, 0.02f, 0.94f))
        [ SNew(SScrollBox)
          + SScrollBox::Slot()[ SAssignNew(Body, SVerticalBox) ] ] ] ];
    Text(TEXT("IMPERATHEN"), 38);
    Text(TEXT("Ein Leben. Deine Geschichte."), 15);
    const auto AddButton = [this](const FString& Label, TFunction<void()> Action, bool bEnabled = true)
    { Body->AddSlot().AutoHeight().Padding(0, 5)[Button(Label, MoveTemp(Action), bEnabled)]; };
    if (!Owner.IsValid()) { Text(TEXT("Die Spielwelt ist nicht mehr verfügbar.")); return; }

    switch (CurrentPage)
    {
    case Page::Intro:
        Body->AddSlot().AutoHeight().Padding(0, 38)
        [ SNew(STextBlock).AutoWrapText(true).Font(FCoreStyle::GetDefaultFontStyle("Regular", 24))
          .Text_Lambda([this]() { return FText::FromString(IntroSeconds < 3.0f
            ? TEXT("Jenseits der Mauern beginnt eine Geschichte.")
            : IntroSeconds < 6.0f ? TEXT("Ohne Titel. Ohne Krone. Mit einer Entscheidung.")
                                 : TEXT("Was du daraus machst, liegt bei dir.")); }) ];
        AddButton(TEXT("Vorspann überspringen"), [this]() { Show(Page::Menu); });
        break;
    case Page::Menu:
        Text(TEXT("Am Rand des Reiches"), 24);
        AddButton(TEXT("Neues Leben"), [this]() { Show(Page::NewLife); });
        AddButton(TEXT("Fortsetzen"), [this]() { if (Owner->ContinueLife(Error)) Show(Page::Village); else Build(); }, Owner->InspectSave() != nullptr);
        AddButton(TEXT("Spielstände"), [this]() { Show(Page::Saves); });
        AddButton(TEXT("Einstellungen"), [this]() { Show(Page::Settings); });
        AddButton(TEXT("Vorspann ansehen"), [this]() { IntroSeconds = 0; Show(Page::Intro); });
        Text(TEXT("Entwicklungsgrundlage · Dorfanfang"), 13);
        break;
    case Page::NewLife:
        Text(TEXT("Ein Name im Staub"), 26);
        Text(TEXT("Du kommst in ein kleines Grenzdorf. Dein erster Schritt ist ein Dach über dem Kopf."));
        Body->AddSlot().AutoHeight().Padding(0, 12)
        [ SAssignNew(NameInput, SEditableTextBox).HintText(FText::FromString(TEXT("Dein Name")))
          .Text(FText::FromString(EnteredName))
          .OnTextChanged_Lambda([this](const FText& Value) { EnteredName = Value.ToString(); }) ];
        if (Owner->HasSave())
        {
            Body->AddSlot().AutoHeight().Padding(0, 10)
            [ SNew(SCheckBox).IsChecked(bReplaceConfirmed ? ECheckBoxState::Checked : ECheckBoxState::Unchecked)
              .OnCheckStateChanged_Lambda([this](ECheckBoxState State) { bReplaceConfirmed = State == ECheckBoxState::Checked; })
              [ SNew(STextBlock).AutoWrapText(true).Text(FText::FromString(TEXT("Vorhandenes Leben ersetzen und als Sicherung behalten"))) ] ];
        }
        AddButton(TEXT("Das Dorf betreten"), [this]() { if (Owner->StartLife(EnteredName, bReplaceConfirmed, Error)) Show(Page::Village); else Build(); });
        AddButton(TEXT("Zurück"), [this]() { Show(Page::Menu); });
        break;
    case Page::Saves:
        Text(TEXT("Dein gespeichertes Leben"), 26);
        if (const auto* Save = Owner->InspectSave())
        {
            Text(FString::Printf(TEXT("%s · Tag %d · Holz %d"), *Save->PlayerName, Save->Day, Save->Wood));
            AddButton(TEXT("Leben fortsetzen"), [this]() { if (Owner->ContinueLife(Error)) Show(Page::Village); else Build(); });
        }
        else Text(Owner->HasSave() ? TEXT("Der Stand kann nicht gelesen werden. Er bleibt unverändert.") : TEXT("Noch kein gespeichertes Leben."));
        if (Owner->HasBackup()) AddButton(TEXT("Sicherung prüfen"), [this]() { Show(Page::Recover); });
        AddButton(TEXT("Zurück"), [this]() { Show(Page::Menu); });
        break;
    case Page::Recover:
        Text(TEXT("Sicherung wiederherstellen?"), 26);
        Text(TEXT("Die vorherige Sicherung wird zum aktiven Stand. Die aktuellen Daten werden zusätzlich für eine Wiederherstellung aufbewahrt."));
        AddButton(TEXT("Wiederherstellung bestätigen"), [this]() { if (Owner->RestoreBackup(Error)) Show(Page::Village); else Build(); });
        AddButton(TEXT("Abbrechen"), [this]() { Show(Page::Saves); });
        break;
    case Page::Settings:
        Text(TEXT("Einstellungen"), 26);
        AddButton(TEXT("Textgröße wechseln: 100 / 125 Prozent"), [this]()
        { auto* Settings = GetMutableDefault<UImperathenSettings>(); Settings->TextScale = Settings->TextScale > 1.1f ? 1.0f : 1.25f; Settings->Persist(); Build(); });
        AddButton(GetDefault<UImperathenSettings>()->bReducedMotion ? TEXT("Bewegung: reduziert") : TEXT("Bewegung: sanft"), [this]()
        { auto* Settings = GetMutableDefault<UImperathenSettings>(); Settings->bReducedMotion = !Settings->bReducedMotion; Settings->Persist(); Build(); });
        AddButton(Contrast ? TEXT("Kontrast: hoch") : TEXT("Kontrast: atmosphärisch"), [this]()
        { auto* Settings = GetMutableDefault<UImperathenSettings>(); Settings->bHighContrast = !Settings->bHighContrast; Settings->Persist(); Build(); });
        AddButton(TEXT("Zurück"), [this]() { Show(Page::Menu); });
        break;
    case Page::Village:
        if (const auto* Save = Owner->GetLife())
        {
            Text(TEXT("Valdora – das Grenzdorf"), 28);
            Text(FString::Printf(TEXT("%s · Tag %d\nHolz %d · Vertrauen %d"), *Save->PlayerName, Save->Day, Save->Wood, Save->Trust));
            Text(Save->bHelped ? TEXT("Ein Dach steht. Ein Nachbar kennt deinen Namen. Hier endet der erste Dorfabschnitt.")
                 : Save->bShelterBuilt ? TEXT("Dein Unterstand steht. Gib Marcus zwei Holz für sein undichtes Dach.")
                 : Save->bGathered ? TEXT("Der vorhandene Holzvorrat reicht für einen einfachen Unterstand.")
                 : TEXT("Du darfst das bereitliegende Holz am Dorfplatz für deinen Unterstand verwenden."));
            AddButton(Save->bGathered ? TEXT("Holz gesammelt") : TEXT("Holz sammeln (+6)"), [this]() { Owner->Perform(ImperathenEntry::Action::GatherWood, Error); Build(); }, !Save->bGathered);
            AddButton(Save->bShelterBuilt ? TEXT("Unterstand gebaut") : TEXT("Unterstand bauen (4 Holz)"), [this]() { Owner->Perform(ImperathenEntry::Action::BuildShelter, Error); Build(); }, Save->bGathered && !Save->bShelterBuilt);
            AddButton(Save->bHelped ? TEXT("Marcus geholfen") : TEXT("Marcus helfen (2 Holz)"), [this]() { Owner->Perform(ImperathenEntry::Action::HelpNeighbour, Error); Build(); }, Save->bShelterBuilt && !Save->bHelped);
        }
        AddButton(TEXT("Zum Hauptmenü"), [this]() { Owner->ReturnToMenu(); Show(Page::Menu); });
        break;
    }
    if (!Error.IsEmpty()) Text(Error, 18);
    bFocusPending = true;
}

void SImperathenMenu::Back()
{
    if (!Owner.IsValid()) return;
    if (CurrentPage == Page::Recover) { Show(Page::Saves); return; }
    if (CurrentPage == Page::Village) Owner->ReturnToMenu();
    if (CurrentPage != Page::Menu) Show(Page::Menu);
}

FReply SImperathenMenu::OnKeyDown(const FGeometry& Geometry, const FKeyEvent& Event)
{
    if (Event.GetKey() == EKeys::Escape || Event.GetKey() == EKeys::Gamepad_FaceButton_Right)
    { Back(); return FReply::Handled(); }
    return SCompoundWidget::OnKeyDown(Geometry, Event);
}

void SImperathenMenu::Tick(const FGeometry& Geometry, const double Time, const float DeltaTime)
{
    SCompoundWidget::Tick(Geometry, Time, DeltaTime);
    if (bFocusPending && FirstButton.IsValid() && FSlateApplication::IsInitialized())
    {
        FSlateApplication::Get().SetKeyboardFocus(FirstButton, EFocusCause::SetDirectly);
        bFocusPending = false;
    }
    if (CurrentPage != Page::Intro) return;
    IntroSeconds += FMath::Max(0.0f, DeltaTime);
    if (IntroSeconds >= 9.0f) Show(Page::Menu);
}
