namespace MacroStudio.Tests
{
    // Runs the fixed-path template through its real screen-4 mapping UI,
    // product diff, copy build and read-back verification.
    public static class PathMapSmoke
    {
        public static string Run(
            string baseDir,
            string bookPath,
            string cacheDir,
            string lightScreenshot,
            string darkScreenshot)
        {
            return P10FlowSmoke.RunPathMap(
                baseDir,
                bookPath,
                cacheDir,
                lightScreenshot,
                darkScreenshot);
        }
    }
}
