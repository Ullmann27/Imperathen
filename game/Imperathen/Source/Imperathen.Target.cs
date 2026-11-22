using UnrealBuildTool;

public class ImperathenTarget : TargetRules
{
    public ImperathenTarget(TargetInfo Target) : base(Target)
    {
        Type = TargetType.Game;
        DefaultBuildSettings = BuildSettingsVersion.V5;
        ExtraModuleNames.Add("Imperathen");
    }
}
