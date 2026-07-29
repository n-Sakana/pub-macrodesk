using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Compression;
using System.Text;

namespace MacroStudio
{
    public sealed class MacroStudioException : Exception
    {
        public string ErrorCode;

        public MacroStudioException(string errorCode, string message)
            : base(message)
        {
            ErrorCode = errorCode;
        }

        public MacroStudioException(
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
        public string VbaEntryName;
        public byte[] VbaProjectBytes;
        public bool HasReadWarnings;
        public VbaProjectData SalvagedProject;

        public BookContent()
        {
            FilePath = string.Empty;
            Extension = string.Empty;
            VbaEntryName = string.Empty;
            VbaProjectBytes = new byte[0];
            HasReadWarnings = false;
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

            byte[] bookBytes = ReadBookBytes(fullPath);
            BookContent content = new BookContent();
            content.FilePath = fullPath;
            content.Extension = extension;
            content.IsZip = false;

            // The extension never blocks the attach: the container kind is
            // decided by the file content. ZIP-based books (xlsm, xlam,
            // xlsb) carry vbaProject.bin inside the archive; OLE2-based
            // books (xls) are themselves the VBA host container.
            bool looksOle2 = HasOle2Signature(bookBytes);
            byte[] vbaBytes = null;
            bool hadWarnings = false;
            string entryName = null;
            if (!looksOle2)
            {
                vbaBytes = TryReadZipVbaProject(
                    bookBytes,
                    out entryName,
                    ref hadWarnings);
                if (vbaBytes != null)
                {
                    content.IsZip = true;
                    content.VbaEntryName =
                        entryName == null ? string.Empty : entryName;
                }
            }
            if (vbaBytes == null && looksOle2)
            {
                vbaBytes = bookBytes;
            }
            if (vbaBytes == null)
            {
                // An OLE2 container embedded at some offset, e.g. a stored
                // ZIP member reachable even when both the archive and its
                // directory are unusable.
                vbaBytes = TryFindEmbeddedVbaContainer(bookBytes);
                if (vbaBytes != null)
                {
                    hadWarnings = true;
                }
            }
            if (vbaBytes == null)
            {
                // No container structure survived. If VBA source is still
                // physically present, hand the whole file to the salvage
                // reader instead of reporting a macro-free workbook.
                VbaProjectData salvaged = SalvageProject(bookBytes);
                if (salvaged.Modules.Count > 0)
                {
                    vbaBytes = bookBytes;
                    hadWarnings = true;
                    content.SalvagedProject = salvaged;
                }
            }
            if (vbaBytes == null)
            {
                throw new MacroStudioException(
                    "E-ATTACH-03",
                    "vbaProject.bin was not found in the workbook.");
            }

            content.VbaProjectBytes = vbaBytes;
            content.HasReadWarnings = hadWarnings;
            return content;
        }

        public static VbaProjectData ReadProject(string filePath)
        {
            BookContent content = ReadVbaProjectBytes(filePath);
            VbaProjectData project = null;
            if (content.VbaProjectBytes.Length > 0)
            {
                try
                {
                    project = VbaProjectReader.Read(
                        content.VbaProjectBytes);
                }
                catch (OutOfMemoryException)
                {
                    throw;
                }
                catch (Exception)
                {
                    project = null;
                }
            }

            // When the structured readers fail or come back empty, scan
            // the raw container bytes for compressed source containers so
            // the modules that are physically present stay readable.
            if (project == null || project.Modules.Count == 0)
            {
                VbaProjectData salvaged =
                    content.SalvagedProject != null ?
                    content.SalvagedProject :
                    SalvageProject(content.VbaProjectBytes);
                if (project == null)
                {
                    project = salvaged;
                }
                else if (salvaged.Modules.Count > 0)
                {
                    project.Modules = salvaged.Modules;
                    project.CodePage = salvaged.CodePage;
                    project.Encoding = salvaged.Encoding;
                    project.HasReadWarnings = true;
                }
            }

            project.FilePath = content.FilePath;
            project.IsZip = content.IsZip;
            project.VbaEntryName = content.VbaEntryName;
            project.HasReadWarnings =
                project.HasReadWarnings || content.HasReadWarnings;
            return project;
        }

        public static VbaProjectData SalvageProject(byte[] bytes)
        {
            VbaProjectData project = new VbaProjectData();
            project.Ole2Bytes = bytes == null ? new byte[0] : bytes;
            project.HasReadWarnings = true;
            if (bytes == null || bytes.Length < 3)
            {
                project.CodePage = 932;
                project.Encoding = VbaProjectReader.ResolveEncoding(932);
                return project;
            }

            List<int> offsets = new List<int>();
            List<byte[]> payloads = new List<byte[]>();
            List<bool> isSource = new List<bool>();
            byte[] marker = Encoding.ASCII.GetBytes("Attribute VB_Name");
            int codePage = 0;
            List<VbaDirModule> dirRecords = null;
            int position;
            for (position = 0; position + 3 <= bytes.Length; position++)
            {
                if (bytes[position] != 0x01)
                {
                    continue;
                }
                ushort header = BitConverter.ToUInt16(
                    bytes,
                    position + 1);
                if (((header >> 12) & 0x0007) != 3)
                {
                    continue;
                }

                // Cheap pre-check: decompress only the first chunk and
                // look for the module marker before spending time on the
                // full container.
                int firstChunkEnd;
                byte[] firstChunk = VbaCompression.DecompressUntilInvalid(
                    bytes,
                    position,
                    4096,
                    out firstChunkEnd);
                if (firstChunk.Length == 0)
                {
                    continue;
                }

                bool sourceCandidate =
                    IndexOfBytes(firstChunk, marker) >= 0;
                bool dirCandidate = false;
                if (!sourceCandidate)
                {
                    int foundCodePage;
                    dirCandidate = VbaProjectReader.TryFindCodePage(
                        firstChunk,
                        out foundCodePage);
                }
                if (!sourceCandidate && !dirCandidate)
                {
                    continue;
                }

                int containerEnd;
                byte[] payload = VbaCompression.DecompressUntilInvalid(
                    bytes,
                    position,
                    0,
                    out containerEnd);
                if (payload.Length == 0)
                {
                    continue;
                }
                if (containerEnd > position)
                {
                    // Do not rediscover chunks inside a container that
                    // was already read.
                    position = containerEnd - 1;
                }

                if (sourceCandidate)
                {
                    offsets.Add(position);
                    payloads.Add(payload);
                    isSource.Add(true);
                }
                else
                {
                    int foundCodePage;
                    if (codePage == 0 &&
                        VbaProjectReader.TryFindCodePage(
                            payload,
                            out foundCodePage))
                    {
                        codePage = foundCodePage;
                        try
                        {
                            int dirCodePage;
                            dirRecords = VbaProjectReader.ReadDirModules(
                                payload,
                                out dirCodePage);
                        }
                        catch (Exception)
                        {
                            dirRecords = null;
                        }
                    }
                }
            }

            if (codePage == 0)
            {
                codePage = 932;
            }
            project.Encoding = VbaProjectReader.ResolveEncoding(codePage);
            project.CodePage = project.Encoding.CodePage;

            Dictionary<string, ushort> dirTypes =
                new Dictionary<string, ushort>(
                    StringComparer.OrdinalIgnoreCase);
            if (dirRecords != null)
            {
                int recordIndex;
                for (recordIndex = 0;
                    recordIndex < dirRecords.Count;
                    recordIndex++)
                {
                    VbaDirModule record = dirRecords[recordIndex];
                    if (!dirTypes.ContainsKey(record.Name))
                    {
                        dirTypes.Add(record.Name, record.TypeId);
                    }
                }
            }

            Dictionary<string, int> byName =
                new Dictionary<string, int>(
                    StringComparer.OrdinalIgnoreCase);
            int index;
            for (index = 0; index < payloads.Count; index++)
            {
                if (!isSource[index])
                {
                    continue;
                }

                byte[] payload = payloads[index];
                string fullCode = project.Encoding.GetString(payload);
                string moduleName = ExtractModuleName(fullCode);
                if (moduleName == null || moduleName.Length == 0)
                {
                    moduleName = "Module" + (project.Modules.Count + 1)
                        .ToString();
                }

                int existingIndex;
                if (byName.TryGetValue(moduleName, out existingIndex))
                {
                    // Keep the longest recovered source per module name.
                    if (project.Modules[existingIndex]
                        .FullSourceBytes.Length >= payload.Length)
                    {
                        continue;
                    }
                    FillSalvagedModule(
                        project.Modules[existingIndex],
                        payload,
                        fullCode,
                        offsets[index],
                        dirTypes);
                    continue;
                }

                VbaModule module = new VbaModule();
                module.Name = moduleName;
                module.StreamName = moduleName;
                FillSalvagedModule(
                    module,
                    payload,
                    fullCode,
                    offsets[index],
                    dirTypes);
                byName.Add(moduleName, project.Modules.Count);
                project.Modules.Add(module);
            }

            project.Modules.Sort(delegate(VbaModule left, VbaModule right)
            {
                int typeResult =
                    ((int)left.Kind).CompareTo((int)right.Kind);
                if (typeResult != 0)
                {
                    return typeResult;
                }

                return StringComparer.OrdinalIgnoreCase.Compare(
                    left.Name,
                    right.Name);
            });
            return project;
        }

        private static void FillSalvagedModule(
            VbaModule module,
            byte[] payload,
            string fullCode,
            int sourceOffset,
            Dictionary<string, ushort> dirTypes)
        {
            string attributeHeader;
            string code;
            VbaProjectReader.SplitAttributeHeader(
                fullCode,
                out attributeHeader,
                out code);

            ushort typeId;
            if (!dirTypes.TryGetValue(module.Name, out typeId))
            {
                typeId = 0;
            }
            module.Kind = GuessModuleKind(attributeHeader, typeId);
            module.Extension = GetSalvageExtension(module.Kind);
            module.SourceOffset = (uint)sourceOffset;
            module.FullSourceBytes = payload;
            module.FullCode = fullCode;
            module.AttributeHeader = attributeHeader;
            module.Code = code;
        }

        private static VbaModuleKind GuessModuleKind(
            string attributeHeader,
            ushort typeId)
        {
            if (typeId == 0x0021)
            {
                return VbaModuleKind.Standard;
            }
            if (attributeHeader.IndexOf(
                "VB_Base",
                StringComparison.OrdinalIgnoreCase) >= 0)
            {
                return VbaModuleKind.Document;
            }
            if (attributeHeader.IndexOf(
                "VB_PredeclaredId",
                StringComparison.OrdinalIgnoreCase) >= 0 ||
                attributeHeader.IndexOf(
                    "VB_Exposed",
                    StringComparison.OrdinalIgnoreCase) >= 0 ||
                attributeHeader.IndexOf(
                    "VB_Creatable",
                    StringComparison.OrdinalIgnoreCase) >= 0)
            {
                return VbaModuleKind.Class;
            }

            return VbaModuleKind.Standard;
        }

        private static string GetSalvageExtension(VbaModuleKind kind)
        {
            if (kind == VbaModuleKind.Standard)
            {
                return "bas";
            }
            if (kind == VbaModuleKind.Form)
            {
                return "frm";
            }

            return "cls";
        }

        private static string ExtractModuleName(string fullCode)
        {
            int markerIndex = fullCode.IndexOf(
                "Attribute VB_Name",
                StringComparison.OrdinalIgnoreCase);
            if (markerIndex < 0)
            {
                return null;
            }

            int quoteStart = fullCode.IndexOf('"', markerIndex);
            if (quoteStart < 0)
            {
                return null;
            }
            int quoteEnd = fullCode.IndexOf('"', quoteStart + 1);
            if (quoteEnd < 0)
            {
                return null;
            }

            return fullCode.Substring(
                quoteStart + 1,
                quoteEnd - quoteStart - 1).Trim();
        }

        private static int IndexOfBytes(byte[] data, byte[] pattern)
        {
            return IndexOfBytesFrom(data, pattern, 0);
        }

        private static int IndexOfBytesFrom(
            byte[] data,
            byte[] pattern,
            int start)
        {
            int limit = data.Length - pattern.Length;
            int index;
            for (index = start; index <= limit; index++)
            {
                int patternIndex = 0;
                while (patternIndex < pattern.Length &&
                    data[index + patternIndex] == pattern[patternIndex])
                {
                    patternIndex++;
                }
                if (patternIndex == pattern.Length)
                {
                    return index;
                }
            }

            return -1;
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
                if (sourceProject.Ole2 == null)
                {
                    throw new MacroStudioException(
                        "E-BUILD-01",
                        "The workbook structure could not be parsed " +
                        "for build.");
                }

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
                    rebuiltProject,
                    sourceProject.IsZip,
                    sourceProject.VbaEntryName);
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
            catch (MacroStudioException ex)
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
            byte[] projectBytes,
            bool isZip,
            string entryName)
        {
            if (!isZip)
            {
                File.WriteAllBytes(outputPath, projectBytes);
                return;
            }

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
                string target =
                    string.IsNullOrEmpty(entryName) ?
                    "vbaProject.bin" :
                    entryName;
                ZipArchiveEntry found = null;
                int index;
                for (index = 0; index < archive.Entries.Count; index++)
                {
                    if (string.Equals(
                        archive.Entries[index].Name,
                        target,
                        StringComparison.OrdinalIgnoreCase))
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
                throw new MacroStudioException(
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

                throw new MacroStudioException(
                    "E-ATTACH-02",
                    "The workbook path is invalid.",
                    ex);
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
                        throw new MacroStudioException(
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
            catch (MacroStudioException)
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

                throw new MacroStudioException(
                    "E-ATTACH-02",
                    "The workbook could not be opened.",
                    ex);
            }
        }


        private static bool HasOle2Signature(byte[] bytes)
        {
            byte[] signature = new byte[]
            {
                0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1
            };
            if (bytes.Length < signature.Length)
            {
                return false;
            }

            int index;
            for (index = 0; index < signature.Length; index++)
            {
                if (bytes[index] != signature[index])
                {
                    return false;
                }
            }
            return true;
        }

        private static byte[] TryFindEmbeddedVbaContainer(byte[] bytes)
        {
            byte[] signature = new byte[]
            {
                0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1
            };
            int position = 0;
            while (position + signature.Length <= bytes.Length)
            {
                int found = IndexOfBytesFrom(bytes, signature, position);
                if (found < 0)
                {
                    return null;
                }

                int length = bytes.Length - found;
                byte[] slice = new byte[length];
                Buffer.BlockCopy(bytes, found, slice, 0, length);
                if (LooksLikeVbaProject(slice))
                {
                    return slice;
                }
                position = found + 1;
            }

            return null;
        }

        private static bool LooksLikeVbaProject(byte[] bytes)
        {
            if (!HasOle2Signature(bytes))
            {
                return false;
            }

            // A VBA project container names its "VBA" storage in UTF-16
            // inside the directory sectors.
            byte[] marker = new byte[]
            {
                0x56, 0x00, 0x42, 0x00, 0x41, 0x00
            };
            return IndexOfBytes(bytes, marker) >= 0;
        }

        private static int GetVbaEntryRank(string name)
        {
            if (name == null)
            {
                return -1;
            }
            if (string.Equals(name, "vbaProject.bin", StringComparison.Ordinal))
            {
                return 0;
            }
            if (string.Equals(
                name,
                "vbaProject.bin",
                StringComparison.OrdinalIgnoreCase))
            {
                return 1;
            }
            if (name.EndsWith(".bin", StringComparison.OrdinalIgnoreCase))
            {
                return 2;
            }

            return -1;
        }

        private static string GetZipFileName(string fullName)
        {
            if (fullName == null)
            {
                return string.Empty;
            }

            int cut = fullName.LastIndexOfAny(
                new char[] { '/', '\\' });
            return cut < 0 ? fullName : fullName.Substring(cut + 1);
        }

        private static string DecodeZipName(
            byte[] bytes,
            int offset,
            int length)
        {
            try
            {
                return Encoding.UTF8.GetString(bytes, offset, length);
            }
            catch (ArgumentException)
            {
                return string.Empty;
            }
        }

        private static int ReadZipUInt16(byte[] bytes, long offset)
        {
            if (offset < 0 || offset + 2 > bytes.Length)
            {
                throw new InvalidDataException(
                    "Unexpected end of ZIP data.");
            }

            return BitConverter.ToUInt16(bytes, (int)offset);
        }

        private static long ReadZipUInt32(byte[] bytes, long offset)
        {
            if (offset < 0 || offset + 4 > bytes.Length)
            {
                throw new InvalidDataException(
                    "Unexpected end of ZIP data.");
            }

            return BitConverter.ToUInt32(bytes, (int)offset);
        }

        private static byte[] TryReadZipVbaProject(
            byte[] bookBytes,
            out string entryName,
            ref bool hadWarnings)
        {
            bool enumerated;
            byte[] result = TryReadZipVbaProjectArchive(
                bookBytes,
                out enumerated,
                out entryName,
                ref hadWarnings);
            if (result != null)
            {
                return result;
            }
            if (enumerated)
            {
                // The archive was fully readable and holds no VBA part.
                return null;
            }

            // The standard ZIP reader could not enumerate the archive.
            // Retry via the central directory, then via a raw scan for
            // local file headers, so damaged-but-recoverable archives
            // still yield their VBA project.
            result = TryReadZipVbaProjectCentral(bookBytes, out entryName);
            if (result != null)
            {
                hadWarnings = true;
                return result;
            }

            result = TryReadZipVbaProjectScan(bookBytes, out entryName);
            if (result != null)
            {
                hadWarnings = true;
            }
            return result;
        }

        private static byte[] TryReadZipVbaProjectArchive(
            byte[] bookBytes,
            out bool enumerated,
            out string entryName,
            ref bool hadWarnings)
        {
            enumerated = false;
            entryName = null;
            try
            {
                using (MemoryStream memory = new MemoryStream(
                    bookBytes,
                    false))
                using (ZipArchive archive = new ZipArchive(
                    memory,
                    ZipArchiveMode.Read,
                    false))
                {
                    List<ZipArchiveEntry> entries =
                        new List<ZipArchiveEntry>();
                    int index;
                    for (index = 0;
                        index < archive.Entries.Count;
                        index++)
                    {
                        entries.Add(archive.Entries[index]);
                    }
                    enumerated = true;

                    int rank;
                    for (rank = 0; rank <= 2; rank++)
                    {
                        for (index = 0; index < entries.Count; index++)
                        {
                            ZipArchiveEntry entry = entries[index];
                            if (GetVbaEntryRank(entry.Name) != rank)
                            {
                                continue;
                            }

                            byte[] data;
                            try
                            {
                                data = ReadZipEntry(entry);
                            }
                            catch (InvalidDataException)
                            {
                                hadWarnings = true;
                                enumerated = false;
                                continue;
                            }

                            if (rank == 0 || LooksLikeVbaProject(data))
                            {
                                if (rank > 0)
                                {
                                    hadWarnings = true;
                                }
                                entryName = entry.Name;
                                return data;
                            }
                        }
                    }
                }
            }
            catch (InvalidDataException)
            {
                hadWarnings = true;
            }
            catch (NotSupportedException)
            {
                hadWarnings = true;
            }
            catch (IOException)
            {
                hadWarnings = true;
            }
            return null;
        }

        private static byte[] ReadZipEntry(ZipArchiveEntry entry)
        {
            if (entry.Length > int.MaxValue)
            {
                throw new InvalidDataException(
                    "vbaProject.bin is too large to read.");
            }

            using (Stream input = entry.Open())
            using (MemoryStream output = new MemoryStream())
            {
                input.CopyTo(output);
                return output.ToArray();
            }
        }

        private static long FindZipEndOfCentralDirectory(byte[] bytes)
        {
            long lowest = (long)bytes.Length - 22L - 65557L;
            if (lowest < 0)
            {
                lowest = 0;
            }

            long position;
            for (position = (long)bytes.Length - 22L;
                position >= lowest;
                position--)
            {
                if (bytes[position] == 0x50 &&
                    bytes[position + 1] == 0x4B &&
                    bytes[position + 2] == 0x05 &&
                    bytes[position + 3] == 0x06)
                {
                    return position;
                }
            }

            return -1;
        }

        private static byte[] TryReadZipVbaProjectCentral(
            byte[] bytes,
            out string entryName)
        {
            entryName = null;
            try
            {
                long endOfDirectory =
                    FindZipEndOfCentralDirectory(bytes);
                if (endOfDirectory < 0)
                {
                    return null;
                }

                int entryCount = ReadZipUInt16(
                    bytes,
                    endOfDirectory + 10);
                long position = ReadZipUInt32(
                    bytes,
                    endOfDirectory + 16);
                List<string> names = new List<string>();
                List<int> methods = new List<int>();
                List<long> compressedSizes = new List<long>();
                List<long> localOffsets = new List<long>();
                int parsed = 0;
                while (parsed < entryCount &&
                    position + 46 <= bytes.Length &&
                    ReadZipUInt32(bytes, position) == 0x02014B50L)
                {
                    int method = ReadZipUInt16(bytes, position + 10);
                    long compressedSize = ReadZipUInt32(
                        bytes,
                        position + 20);
                    int nameLength = ReadZipUInt16(bytes, position + 28);
                    int extraLength = ReadZipUInt16(bytes, position + 30);
                    int commentLength = ReadZipUInt16(
                        bytes,
                        position + 32);
                    long localOffset = ReadZipUInt32(
                        bytes,
                        position + 42);
                    if (position + 46 + nameLength > bytes.Length)
                    {
                        break;
                    }

                    names.Add(GetZipFileName(DecodeZipName(
                        bytes,
                        (int)(position + 46),
                        nameLength)));
                    methods.Add(method);
                    compressedSizes.Add(compressedSize);
                    localOffsets.Add(localOffset);
                    position += 46 + nameLength + extraLength +
                        commentLength;
                    parsed++;
                }

                int rank;
                for (rank = 0; rank <= 2; rank++)
                {
                    int index;
                    for (index = 0; index < names.Count; index++)
                    {
                        if (GetVbaEntryRank(names[index]) != rank)
                        {
                            continue;
                        }

                        byte[] data = ReadZipLocalData(
                            bytes,
                            localOffsets[index],
                            methods[index],
                            compressedSizes[index]);
                        if (data == null)
                        {
                            continue;
                        }
                        if (rank == 0 || LooksLikeVbaProject(data))
                        {
                            entryName = names[index];
                            return data;
                        }
                    }
                }
            }
            catch (OutOfMemoryException)
            {
                throw;
            }
            catch (Exception)
            {
            }
            return null;
        }

        private static byte[] TryReadZipVbaProjectScan(
            byte[] bytes,
            out string entryName)
        {
            entryName = null;
            byte[] best = null;
            int bestRank = 3;
            try
            {
                long position;
                for (position = 0;
                    position + 30 <= bytes.Length;
                    position++)
                {
                    if (bytes[position] != 0x50 ||
                        bytes[position + 1] != 0x4B ||
                        bytes[position + 2] != 0x03 ||
                        bytes[position + 3] != 0x04)
                    {
                        continue;
                    }

                    int flags = ReadZipUInt16(bytes, position + 6);
                    int method = ReadZipUInt16(bytes, position + 8);
                    long compressedSize = ReadZipUInt32(
                        bytes,
                        position + 18);
                    int nameLength = ReadZipUInt16(bytes, position + 26);
                    if (position + 30 + nameLength > bytes.Length)
                    {
                        continue;
                    }

                    string name = GetZipFileName(DecodeZipName(
                        bytes,
                        (int)(position + 30),
                        nameLength));
                    int rank = GetVbaEntryRank(name);
                    if (rank < 0 || rank >= bestRank)
                    {
                        continue;
                    }

                    if ((flags & 0x0008) != 0)
                    {
                        // A data descriptor hides the sizes: inflate to
                        // the end of the deflate stream instead.
                        compressedSize = 0;
                    }
                    byte[] data = ReadZipLocalDataAt(
                        bytes,
                        position,
                        method,
                        compressedSize);
                    if (data == null)
                    {
                        continue;
                    }
                    if (rank > 0 && !LooksLikeVbaProject(data))
                    {
                        continue;
                    }

                    best = data;
                    bestRank = rank;
                    entryName = name;
                    if (rank == 0)
                    {
                        break;
                    }
                }
            }
            catch (OutOfMemoryException)
            {
                throw;
            }
            catch (Exception)
            {
            }
            return best;
        }

        private static byte[] ReadZipLocalData(
            byte[] bytes,
            long localOffset,
            int method,
            long compressedSize)
        {
            if (localOffset < 0 ||
                localOffset + 30 > bytes.Length ||
                ReadZipUInt32(bytes, localOffset) != 0x04034B50L)
            {
                return null;
            }

            return ReadZipLocalDataAt(
                bytes,
                localOffset,
                method,
                compressedSize);
        }

        private static byte[] ReadZipLocalDataAt(
            byte[] bytes,
            long headerPosition,
            int method,
            long compressedSize)
        {
            int nameLength = ReadZipUInt16(bytes, headerPosition + 26);
            int extraLength = ReadZipUInt16(bytes, headerPosition + 28);
            long dataStart = headerPosition + 30 + nameLength +
                extraLength;
            if (dataStart < 0 || dataStart > bytes.Length)
            {
                return null;
            }

            long available = (long)bytes.Length - dataStart;
            if (method == 0)
            {
                if (compressedSize <= 0 || compressedSize > available)
                {
                    return null;
                }

                byte[] stored = new byte[(int)compressedSize];
                Buffer.BlockCopy(
                    bytes,
                    (int)dataStart,
                    stored,
                    0,
                    stored.Length);
                return stored;
            }
            if (method != 8)
            {
                return null;
            }

            long inputLength =
                compressedSize > 0 && compressedSize <= available ?
                compressedSize :
                available;
            if (inputLength <= 0)
            {
                return null;
            }

            try
            {
                using (MemoryStream input = new MemoryStream(
                    bytes,
                    (int)dataStart,
                    (int)inputLength,
                    false))
                using (DeflateStream inflater = new DeflateStream(
                    input,
                    CompressionMode.Decompress))
                using (MemoryStream output = new MemoryStream())
                {
                    byte[] buffer = new byte[65536];
                    long total = 0;
                    while (true)
                    {
                        int read = inflater.Read(
                            buffer,
                            0,
                            buffer.Length);
                        if (read <= 0)
                        {
                            break;
                        }

                        total += read;
                        if (total > 268435456L)
                        {
                            return null;
                        }
                        output.Write(buffer, 0, read);
                    }
                    return output.ToArray();
                }
            }
            catch (InvalidDataException)
            {
                return null;
            }
        }
    }
}
