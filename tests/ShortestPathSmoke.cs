namespace MacroStudio.Tests
{
    // The shortest valid beta-2 route is the ordinary two-AI route with
    // no optional evidence expansion, questions or split output.
    public static class ShortestPathSmoke
    {
        public static string Run(
            string baseDir,
            string bookPath,
            string cacheDir,
            string lightScreenshot,
            string darkScreenshot)
        {
            return P10FlowSmoke.Run(
                baseDir,
                bookPath,
                cacheDir,
                lightScreenshot,
                darkScreenshot);
        }
    }
}
