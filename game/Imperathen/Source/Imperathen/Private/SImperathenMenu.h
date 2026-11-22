#pragma once

#include "CoreMinimal.h"
#include "Widgets/SCompoundWidget.h"

class AImperathenGameMode;
class SEditableTextBox;
class SVerticalBox;

class SImperathenMenu final : public SCompoundWidget
{
public:
    SLATE_BEGIN_ARGS(SImperathenMenu) {}
        SLATE_ARGUMENT(TWeakObjectPtr<AImperathenGameMode>, Owner)
    SLATE_END_ARGS()

    void Construct(const FArguments& Args);
    virtual bool SupportsKeyboardFocus() const override { return true; }
    virtual FReply OnKeyDown(const FGeometry& Geometry, const FKeyEvent& Event) override;
    virtual void Tick(const FGeometry& Geometry, const double Time, const float DeltaTime) override;

private:
    enum class Page { Intro, Menu, NewLife, Saves, Settings, Village, Recover };
    void Build();
    void Show(Page Next);
    TSharedRef<SWidget> Button(const FString& Label, TFunction<void()> Action, bool bEnabled = true);
    void Text(const FString& Value, float Size = 18.0f);
    void Back();

    TWeakObjectPtr<AImperathenGameMode> Owner;
    Page CurrentPage = Page::Intro;
    float IntroSeconds = 0.0f;
    FString Error;
    FString EnteredName;
    bool bReplaceConfirmed = false;
    bool bFocusPending = false;
    TSharedPtr<SVerticalBox> Body;
    TSharedPtr<SEditableTextBox> NameInput;
    TSharedPtr<SWidget> FirstButton;
};
