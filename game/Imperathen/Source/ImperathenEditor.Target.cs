using UnrealBuildTool;

public class ImperathenEditorTarget : TargetRules
{
    public ImperathenEditorTarget(TargetInfo Target) : base(Target)
    {
        Type = TargetType.Editor;
        DefaultBuildSettings = BuildSettingsVersion.V5;
        ExtraModuleNames.Add("Imperathen");
    }
}
