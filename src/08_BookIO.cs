using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Compression;
using System.Text;

namespace MacroDesk
{
    public sealed class MacroDeskException : Exception
    {
        public string ErrorCode;

        public MacroDeskException(string errorCode, string message)
            : base(message)
        {
            ErrorCode = errorCode;
        }

        public MacroDeskException(
            string errorCode,
            string message,
            Exception innerException)
            : base(message, innerException)
        {
            ErrorCode = errorCode;
        }
    }

    public sealed class BookContent
    {
        public string FilePath;
        public string Extension;
        public bool IsZip;
        public byte[] VbaProjectBytes;

        public BookContent()
        {
            FilePath = string.Empty;
            Extension = string.Empty;
            VbaProjectBytes = new byte[0];
        }
    }

    public sealed class ModuleBuildResult
    {
        public string Name;
        public string Result;
        public string Message;

        public ModuleBuildResult()
        {
            Name = string.Empty;
            Result = string.Empty;
            Message = string.Empty;
        }
    }

    public sealed class BookBuildResult
    {
        public bool Success;
        public string OutputPath;
        public string ErrorCode;
        public string Message;
        public long ElapsedMilliseconds;
        public List<ModuleBuildResult> Results;

        public BookBuildResult()
        {
            OutputPath = string.Empty;
            ErrorCode = string.Empty;
            Message = string.Empty;
            Results = new List<ModuleBuildResult>();
        }
    }

    public static class BookIO
    {
        private sealed class BuildVerificationException : Exception
        {
            public BuildVerificationException(string message)
                : base(message)
            {
            }

            public BuildVerificationException(
                string message,
                Exception innerException)
                : base(message, innerException)
            {
            }
        }

        public static BookContent ReadVbaProjectBytes(string filePath)
        {
            string fullPath = GetFullPath(filePath);
            string extension = Path.GetExtension(fullPath).ToLowerInvariant();
            ValidateExtension(extension);

            byte[] bookBytes = ReadBookBytes(fullPath);
            try
            {
                byte[] vbaProjectBytes = ReadZipVbaProject(bookBytes);
                if (vbaProjectBytes == null)
                {
                    throw new MacroDeskException(
                        "E-ATTACH-03",
                        "vbaProject.bin was not found in the workbook.");
                }

                BookContent content = new BookContent();
                content.FilePath = fullPath;
                content.Extension = extension;
                content.IsZip = true;
                content.VbaProjectBytes = vbaProjectBytes;
                return content;
            }
            catch (MacroDeskException)
            {
                throw;
            }
            catch (InvalidDataException ex)
            {
                throw CreateStructureException(
                    extension,
                    "The workbook ZIP structure could not be read.",
                    ex);
            }
        }

        public static VbaProjectData ReadProject(string filePath)
        {
            BookContent content = ReadVbaProjectBytes(filePath);
            try
            {
                VbaProjectData project = VbaProjectReader.Read(
                    content.VbaProjectBytes);
                project.FilePath = content.FilePath;
                project.IsZip = content.IsZip;
                return project;
            }
            catch (MacroDeskException)
            {
                throw;
            }
            catch (Exception ex)
            {
                if (!(ex is InvalidDataException) &&
                    !(ex is ArgumentException) &&
                    !(ex is DecoderFallbackException))
                {
                    throw;
                }

                throw CreateStructureException(
                    content.Extension,
                    "The VBA project structure could not be read.",
                    ex);
            }
        }

        public static BookBuildResult BuildCopy(
            string sourcePath,
            string outputPath,
            IDictionary<string, string> moduleChanges)
        {
            return BuildCopy(
                sourcePath,
                outputPath,
                moduleChanges,
                new List<VbaModuleAddition>());
        }

        public static BookBuildResult BuildCopy(
            string sourcePath,
            string outputPath,
            IDictionary<string, string> moduleChanges,
            IList<VbaModuleAddition> newModules)
        {
            BookBuildResult result = new BookBuildResult();
            DateTime started = DateTime.UtcNow;
            bool outputCreated = false;

            try
            {
                if (moduleChanges == null)
                {
                    throw new ArgumentNullException("moduleChanges");
                }
                if (newModules == null)
                {
                    throw new ArgumentNullException("newModules");
                }

                VbaProjectData sourceProject = ReadProject(sourcePath);
                string fullOutputPath = GetBuildOutputPath(outputPath);
                result.OutputPath = fullOutputPath;
                if (string.Equals(
                    sourceProject.FilePath,
                    fullOutputPath,
                    StringComparison.OrdinalIgnoreCase))
                {
                    throw new IOException(
                        "The build output path is the source workbook.");
                }

                Dictionary<string, string> changedModules =
                    PrepareBuildChanges(
                        sourceProject,
                        moduleChanges,
                        result.Results);
                List<VbaModuleAddition> additions =
                    PrepareBuildAdditions(
                        sourceProject,
                        newModules,
                        result.Results);

                File.Copy(
                    sourceProject.FilePath,
                    fullOutputPath,
                    false);
                outputCreated = true;

                byte[] rebuiltProject =
                    VbaProjectWriter.RebuildProject(
                        sourceProject,
                        changedModules,
                        additions);
                WriteZipVbaProject(
                    fullOutputPath,
                    rebuiltProject);
                VerifyBuild(
                    sourceProject,
                    fullOutputPath,
                    changedModules,
                    additions);

                SetPendingResults(
                    result.Results,
                    "written",
                    string.Empty);
                result.Success = true;
                return FinishBuildResult(result, started);
            }
            catch (BuildVerificationException ex)
            {
                SetPendingResults(
                    result.Results,
                    "verify_failed",
                    ex.Message);
                result.ErrorCode = "E-BUILD-02";
                result.Message = ex.Message;
            }
            catch (MacroDeskException ex)
            {
                RemovePendingResults(result.Results);
                result.ErrorCode = ex.ErrorCode;
                result.Message = ex.Message;
            }
            catch (Exception ex)
            {
                if (IsBuildIoException(ex))
                {
                    SetPendingResults(
                        result.Results,
                        "io_error",
                        ex.Message);
                    result.ErrorCode = "E-BUILD-03";
                }
                else
                {
                    RemovePendingResults(result.Results);
                    result.ErrorCode = "E-BUILD-01";
                }
                result.Message = ex.Message;
            }

            if (outputCreated)
            {
                try
                {
                    if (File.Exists(result.OutputPath))
                    {
                        File.Delete(result.OutputPath);
                    }
                }
                catch (Exception cleanupException)
                {
                    result.ErrorCode = "E-BUILD-03";
                    result.Message =
                        result.Message +
                        " Output cleanup failed: " +
                        cleanupException.Message;
                }
            }

            result.Success = false;
            return FinishBuildResult(result, started);
        }

        private static BookBuildResult FinishBuildResult(
            BookBuildResult result,
            DateTime started)
        {
            result.ElapsedMilliseconds = (long)(
                DateTime.UtcNow - started).TotalMilliseconds;
            return result;
        }

        private static string GetBuildOutputPath(string outputPath)
        {
            if (string.IsNullOrEmpty(outputPath))
            {
                throw new IOException(
                    "The build output path is empty.");
            }

            try
            {
                return Path.GetFullPath(outputPath);
            }
            catch (Exception ex)
            {
                if (!(ex is ArgumentException) &&
                    !IsBuildIoException(ex))
                {
                    throw;
                }
                throw new IOException(
                    "The build output path is invalid.",
                    ex);
            }
        }

        private static Dictionary<string, string> PrepareBuildChanges(
            VbaProjectData project,
            IDictionary<string, string> requestedChanges,
            List<ModuleBuildResult> results)
        {
            Dictionary<string, VbaModule> modules =
                new Dictionary<string, VbaModule>(
                    StringComparer.OrdinalIgnoreCase);
            int index;
            for (index = 0; index < project.Modules.Count; index++)
            {
                modules.Add(
                    project.Modules[index].Name,
                    project.Modules[index]);
            }

            Dictionary<string, string> changed =
                new Dictionary<string, string>(
                    StringComparer.OrdinalIgnoreCase);
            HashSet<string> seen =
                new HashSet<string>(
                    StringComparer.OrdinalIgnoreCase);
            foreach (KeyValuePair<string, string> requested
                in requestedChanges)
            {
                VbaModule module;
                if (!modules.TryGetValue(requested.Key, out module))
                {
                    throw new InvalidDataException(
                        "VBA module was not found: " + requested.Key);
                }
                if (requested.Value == null)
                {
                    throw new ArgumentException(
                        "A VBA module change is null.",
                        "requestedChanges");
                }
                if (!seen.Add(module.Name))
                {
                    throw new InvalidDataException(
                        "Duplicate VBA module change: " + module.Name);
                }

                ModuleBuildResult item = new ModuleBuildResult();
                item.Name = module.Name;
                if (string.Equals(
                    requested.Value,
                    module.FullCode,
                    StringComparison.Ordinal))
                {
                    item.Result = "skipped_no_change";
                }
                else
                {
                    changed.Add(module.Name, requested.Value);
                }
                results.Add(item);
            }

            return changed;
        }

        private static List<VbaModuleAddition> PrepareBuildAdditions(
            VbaProjectData project,
            IList<VbaModuleAddition> requestedAdditions,
            List<ModuleBuildResult> results)
        {
            HashSet<string> names = new HashSet<string>(
                StringComparer.OrdinalIgnoreCase);
            int index;
            for (index = 0; index < project.Modules.Count; index++)
            {
                names.Add(project.Modules[index].Name);
            }

            List<VbaModuleAddition> additions =
                new List<VbaModuleAddition>();
            for (index = 0;
                index < requestedAdditions.Count;
                index++)
            {
                VbaModuleAddition requested =
                    requestedAdditions[index];
                if (requested == null)
                {
                    throw new ArgumentException(
                        "A VBA module addition is null.",
                        "requestedAdditions");
                }
                VbaProjectWriter.ValidateNewModuleName(
                    requested.Name);
                if (requested.Code == null)
                {
                    throw new ArgumentException(
                        "A VBA module addition code is null.",
                        "requestedAdditions");
                }
                if (!names.Add(requested.Name))
                {
                    throw new InvalidDataException(
                        "Duplicate VBA module name: " +
                        requested.Name);
                }

                additions.Add(
                    new VbaModuleAddition(
                        requested.Name,
                        requested.Code));
                ModuleBuildResult item =
                    new ModuleBuildResult();
                item.Name = requested.Name;
                results.Add(item);
            }
            return additions;
        }

        private static void SetPendingResults(
            List<ModuleBuildResult> results,
            string status,
            string message)
        {
            int index;
            for (index = 0; index < results.Count; index++)
            {
                if (results[index].Result.Length == 0)
                {
                    results[index].Result = status;
                    results[index].Message = message;
                }
            }
        }

        private static void RemovePendingResults(
            List<ModuleBuildResult> results)
        {
            int index;
            for (index = results.Count - 1; index >= 0; index--)
            {
                if (results[index].Result.Length == 0)
                {
                    results.RemoveAt(index);
                }
            }
        }

        private static void WriteZipVbaProject(
            string outputPath,
            byte[] projectBytes)
        {
            using (FileStream file = new FileStream(
                outputPath,
                FileMode.Open,
                FileAccess.ReadWrite,
                FileShare.None))
            using (ZipArchive archive = new ZipArchive(
                file,
                ZipArchiveMode.Update,
                false))
            {
                ZipArchiveEntry found = null;
                int index;
                for (index = 0; index < archive.Entries.Count; index++)
                {
                    if (archive.Entries[index].Name == "vbaProject.bin")
                    {
                        found = archive.Entries[index];
                        break;
                    }
                }
                if (found == null)
                {
                    throw new InvalidDataException(
                        "vbaProject.bin was not found in the output.");
                }

                using (Stream output = found.Open())
                {
                    output.SetLength(0);
                    output.Write(
                        projectBytes,
                        0,
                        projectBytes.Length);
                    output.Flush();
                }
            }
        }

        private static void VerifyBuild(
            VbaProjectData sourceProject,
            string outputPath,
            Dictionary<string, string> changedModules,
            IList<VbaModuleAddition> newModules)
        {
            VbaProjectData outputProject;
            try
            {
                outputProject = ReadProject(outputPath);
            }
            catch (Exception ex)
            {
                throw new BuildVerificationException(
                    "The output VBA project could not be read.",
                    ex);
            }

            Dictionary<string, VbaModule> sourceModules =
                BuildModuleMap(sourceProject);
            Dictionary<string, VbaModule> outputModules =
                BuildModuleMap(outputProject);
            if (outputModules.Count !=
                sourceModules.Count + newModules.Count)
            {
                throw new BuildVerificationException(
                    "The output VBA module count is incorrect.");
            }

            HashSet<string> changedPaths =
                new HashSet<string>(StringComparer.Ordinal);
            HashSet<string> addedPaths =
                new HashSet<string>(StringComparer.Ordinal);

            foreach (KeyValuePair<string, string> change
                in changedModules)
            {
                VbaModule sourceModule;
                VbaModule outputModule;
                if (!sourceModules.TryGetValue(
                    change.Key,
                    out sourceModule) ||
                    !outputModules.TryGetValue(
                        change.Key,
                        out outputModule))
                {
                    throw new BuildVerificationException(
                        "A changed VBA module is missing: " +
                        change.Key);
                }

                if (!string.Equals(
                    NormalizeCrLf(outputModule.FullCode),
                    NormalizeCrLf(change.Value),
                    StringComparison.Ordinal))
                {
                    throw new BuildVerificationException(
                        "Changed VBA source mismatch: " +
                        change.Key);
                }

                changedPaths.Add(
                    GetEntryPath(
                        sourceProject.Ole2,
                        sourceModule.StreamEntry));
            }

            int index;
            for (index = 0; index < newModules.Count; index++)
            {
                VbaModuleAddition addition = newModules[index];
                VbaModule outputModule;
                if (sourceModules.ContainsKey(addition.Name) ||
                    !outputModules.TryGetValue(
                        addition.Name,
                        out outputModule))
                {
                    throw new BuildVerificationException(
                        "An added VBA module is missing: " +
                        addition.Name);
                }
                if (outputModule.Kind !=
                        VbaModuleKind.Standard ||
                    outputModule.SourceOffset != 0 ||
                    !string.Equals(
                        NormalizeCrLf(outputModule.FullCode),
                        NormalizeCrLf(
                            VbaProjectWriter.
                                CreateNewModuleFullCode(
                                    addition.Name,
                                    addition.Code)),
                        StringComparison.Ordinal))
                {
                    throw new BuildVerificationException(
                        "Added VBA module mismatch: " +
                        addition.Name);
                }

                addedPaths.Add(
                    GetEntryPath(
                        outputProject.Ole2,
                        outputModule.StreamEntry));
            }

            if (newModules.Count > 0)
            {
                if (sourceProject.ProjectEntry == null ||
                    sourceProject.ProjectWmEntry == null ||
                    sourceProject.DirEntry == null)
                {
                    throw new BuildVerificationException(
                        "VBA project metadata streams are missing.");
                }
                changedPaths.Add(
                    GetEntryPath(
                        sourceProject.Ole2,
                        sourceProject.ProjectEntry));
                changedPaths.Add(
                    GetEntryPath(
                        sourceProject.Ole2,
                        sourceProject.ProjectWmEntry));
                changedPaths.Add(
                    GetEntryPath(
                        sourceProject.Ole2,
                        sourceProject.DirEntry));
            }

            VerifyLogicalEntries(
                sourceProject.Ole2,
                outputProject.Ole2,
                changedPaths,
                addedPaths);
        }

        private static Dictionary<string, VbaModule> BuildModuleMap(
            VbaProjectData project)
        {
            Dictionary<string, VbaModule> result =
                new Dictionary<string, VbaModule>(
                    StringComparer.OrdinalIgnoreCase);
            int index;
            for (index = 0; index < project.Modules.Count; index++)
            {
                VbaModule module = project.Modules[index];
                if (result.ContainsKey(module.Name))
                {
                    throw new BuildVerificationException(
                        "Duplicate VBA module after build: " +
                        module.Name);
                }
                result.Add(module.Name, module);
            }
            return result;
        }

        private static void VerifyLogicalEntries(
            Ole2File source,
            Ole2File output,
            HashSet<string> changedPaths,
            HashSet<string> addedPaths)
        {
            Dictionary<string, Ole2DirectoryEntry> sourceEntries =
                BuildEntryMap(source);
            Dictionary<string, Ole2DirectoryEntry> outputEntries =
                BuildEntryMap(output);
            if (outputEntries.Count !=
                sourceEntries.Count + addedPaths.Count)
            {
                throw new BuildVerificationException(
                    "OLE2 logical entry count changed.");
            }

            foreach (KeyValuePair<string, Ole2DirectoryEntry> pair
                in sourceEntries)
            {
                Ole2DirectoryEntry after;
                if (!outputEntries.TryGetValue(pair.Key, out after))
                {
                    throw new BuildVerificationException(
                        "OLE2 logical entry is missing: " + pair.Key);
                }

                Ole2DirectoryEntry before = pair.Value;
                if (!string.Equals(
                    before.Name,
                    after.Name,
                    StringComparison.Ordinal) ||
                    before.ObjectType != after.ObjectType ||
                    before.ClassId != after.ClassId ||
                    before.StateBits != after.StateBits ||
                    before.CreationTimeRaw != after.CreationTimeRaw ||
                    before.ModifiedTimeRaw != after.ModifiedTimeRaw)
                {
                    throw new BuildVerificationException(
                        "OLE2 logical metadata changed: " + pair.Key);
                }

                if (before.ObjectType == 2 &&
                    !changedPaths.Contains(pair.Key))
                {
                    byte[] beforeBytes = source.ReadStream(before);
                    byte[] afterBytes = output.ReadStream(after);
                    int difference = FirstByteDifference(
                        beforeBytes,
                        afterBytes);
                    if (difference != -1)
                    {
                        throw new BuildVerificationException(
                            "OLE2 stream changed: " +
                            pair.Key +
                            " at byte " +
                            difference);
                    }
                }
            }

            foreach (KeyValuePair<string, Ole2DirectoryEntry> pair
                in outputEntries)
            {
                if (sourceEntries.ContainsKey(pair.Key))
                {
                    continue;
                }
                if (!addedPaths.Contains(pair.Key) ||
                    pair.Value.ObjectType != 2)
                {
                    throw new BuildVerificationException(
                        "Unexpected OLE2 logical entry: " +
                        pair.Key);
                }
            }
        }

        private static Dictionary<string, Ole2DirectoryEntry> BuildEntryMap(
            Ole2File file)
        {
            Dictionary<string, Ole2DirectoryEntry> result =
                new Dictionary<string, Ole2DirectoryEntry>(
                    StringComparer.Ordinal);
            int index;
            for (index = 0; index < file.Entries.Count; index++)
            {
                Ole2DirectoryEntry entry = file.Entries[index];
                if (entry.ObjectType == 0)
                {
                    continue;
                }

                string path = GetEntryPath(file, entry);
                if (result.ContainsKey(path))
                {
                    throw new BuildVerificationException(
                        "Duplicate OLE2 logical path: " + path);
                }
                result.Add(path, entry);
            }
            return result;
        }

        private static string GetEntryPath(
            Ole2File file,
            Ole2DirectoryEntry entry)
        {
            if (entry.Id == 0)
            {
                return "\\";
            }

            List<string> parts = new List<string>();
            HashSet<int> visited = new HashSet<int>();
            Ole2DirectoryEntry current = entry;
            while (current.Id != 0)
            {
                if (!visited.Add(current.Id) ||
                    current.ParentId < 0 ||
                    current.ParentId >= file.Entries.Count)
                {
                    throw new BuildVerificationException(
                        "Invalid OLE2 parent chain: " + entry.Name);
                }

                parts.Insert(0, current.Name);
                current = file.Entries[current.ParentId];
            }

            return "\\" + string.Join("\\", parts.ToArray());
        }

        private static int FirstByteDifference(
            byte[] left,
            byte[] right)
        {
            int length = Math.Min(left.Length, right.Length);
            int index;
            for (index = 0; index < length; index++)
            {
                if (left[index] != right[index])
                {
                    return index;
                }
            }
            return left.Length == right.Length ? -1 : length;
        }

        private static string NormalizeCrLf(string value)
        {
            return value.Replace("\r\n", "\n")
                .Replace("\r", "\n")
                .Replace("\n", "\r\n");
        }

        private static bool IsBuildIoException(Exception ex)
        {
            return ex is IOException ||
                ex is UnauthorizedAccessException ||
                ex is NotSupportedException ||
                ex is PathTooLongException;
        }

        private static string GetFullPath(string filePath)
        {
            if (string.IsNullOrEmpty(filePath))
            {
                throw new MacroDeskException(
                    "E-ATTACH-02",
                    "The workbook path is empty.");
            }

            try
            {
                return Path.GetFullPath(filePath);
            }
            catch (Exception ex)
            {
                if (!(ex is ArgumentException) &&
                    !(ex is NotSupportedException) &&
                    !(ex is PathTooLongException))
                {
                    throw;
                }

                throw new MacroDeskException(
                    "E-ATTACH-02",
                    "The workbook path is invalid.",
                    ex);
            }
        }

        private static void ValidateExtension(string extension)
        {
            if (extension == ".xls")
            {
                throw new MacroDeskException(
                    "E-ATTACH-01",
                    "The .xls format is not supported in MacroDesk v1.");
            }
            if (extension != ".xlsm" &&
                extension != ".xlam" &&
                extension != ".xlsb")
            {
                throw new MacroDeskException(
                    "E-ATTACH-01",
                    "The file extension is not supported.");
            }
        }

        private static byte[] ReadBookBytes(string fullPath)
        {
            try
            {
                using (FileStream input = new FileStream(
                    fullPath,
                    FileMode.Open,
                    FileAccess.Read,
                    FileShare.ReadWrite | FileShare.Delete))
                {
                    if (input.Length > int.MaxValue)
                    {
                        throw new MacroDeskException(
                            "E-ATTACH-02",
                            "The workbook is too large to read.");
                    }

                    using (MemoryStream memory = new MemoryStream(
                        (int)input.Length))
                    {
                        input.CopyTo(memory);
                        return memory.ToArray();
                    }
                }
            }
            catch (MacroDeskException)
            {
                throw;
            }
            catch (Exception ex)
            {
                if (!(ex is IOException) &&
                    !(ex is UnauthorizedAccessException) &&
                    !(ex is NotSupportedException))
                {
                    throw;
                }

                throw new MacroDeskException(
                    "E-ATTACH-02",
                    "The workbook could not be opened.",
                    ex);
            }
        }

        private static byte[] ReadZipVbaProject(byte[] bookBytes)
        {
            using (MemoryStream memory = new MemoryStream(
                bookBytes,
                false))
            using (ZipArchive archive = new ZipArchive(
                memory,
                ZipArchiveMode.Read,
                false))
            {
                ZipArchiveEntry found = null;
                int index;
                for (index = 0; index < archive.Entries.Count; index++)
                {
                    ZipArchiveEntry entry = archive.Entries[index];
                    if (entry.Name == "vbaProject.bin")
                    {
                        found = entry;
                        break;
                    }
                }

                if (found == null)
                {
                    return null;
                }
                if (found.Length > int.MaxValue)
                {
                    throw new InvalidDataException(
                        "vbaProject.bin is too large to read.");
                }

                using (Stream input = found.Open())
                using (MemoryStream output = new MemoryStream(
                    (int)found.Length))
                {
                    input.CopyTo(output);
                    return output.ToArray();
                }
            }
        }

        private static MacroDeskException CreateStructureException(
            string extension,
            string message,
            Exception innerException)
        {
            string code =
                extension == ".xlsb" ?
                "E-ATTACH-05" :
                "E-ATTACH-04";
            return new MacroDeskException(code, message, innerException);
        }
    }
}
