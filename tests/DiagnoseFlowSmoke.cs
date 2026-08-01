namespace MacroStudio.Tests
{
    // Exercises the first-AI diagnosis and the second-AI request handoff
    // without importing a repair response.
    public static class DiagnoseFlowSmoke
    {
        public static string Run(
            string baseDir,
            string bookPath,
            string cacheDir,
            string lightScreenshot,
            string darkScreenshot)
        {
            return P10FlowSmoke.RunDiagnosisOnly(
                baseDir,
                bookPath,
                cacheDir,
                lightScreenshot,
                darkScreenshot);
        }
    }
}
