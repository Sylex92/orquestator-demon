using Quartz;

namespace DaemonPlatform.Quartz;

public static class QuartzKeys
{
    public const string DemoGroup = "demo";
    public const string FastJobName = "JobDemoRapido";
    public const string SlowJobName = "JobDemoLento";

    public static readonly JobKey FastJobKey = new(FastJobName, DemoGroup);
    public static readonly JobKey SlowJobKey = new(SlowJobName, DemoGroup);
    public static readonly TriggerKey FastTriggerKey = new($"{FastJobName}.trigger", DemoGroup);
    public static readonly TriggerKey SlowTriggerKey = new($"{SlowJobName}.trigger", DemoGroup);
}
