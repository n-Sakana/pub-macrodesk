param(
    [string]$TestdataPath
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrEmpty($TestdataPath)) {
    $TestdataPath = Join-Path $PSScriptRoot '..\testdata'
}

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Get-EngineSource {
    $names = @(
        '05_Ole2.cs',
        '06_VbaCompression.cs',
        '07_VbaProject.cs',
        '08_BookIO.cs'
    )
    $combined = ($names | ForEach-Object {
        $path = Join-Path (Join-Path $PSScriptRoot '..\src') $_
        [IO.File]::ReadAllText(
            (Resolve-Path -LiteralPath $path),
            [Text.Encoding]::UTF8)
    }) -join "`n"

    $usingPattern = '(?m)^\s*using\s+[\w][\w.]*\s*;'
    $usings = [regex]::Matches($combined, $usingPattern) |
        ForEach-Object { $_.Value.Trim() } |
        Sort-Object -Unique
    $body = $combined -replace $usingPattern, ''
    return ($usings -join "`n") + "`n`n" + $body
}

function Get-EntryPath {
    param(
        [MacroDesk.Ole2File]$File,
        [MacroDesk.Ole2DirectoryEntry]$Entry
    )

    if ($Entry.Id -eq 0) {
        return '\'
    }

    $parts = New-Object System.Collections.ArrayList
    $current = $Entry
    while ($current.Id -ne 0) {
        [void]$parts.Insert(0, $current.Name)
        Assert-True (
            $current.ParentId -ge 0 -and
            $current.ParentId -lt $File.Entries.Count) `
            "Entry has no valid parent: $($current.Name)"
        $current = $File.Entries[$current.ParentId]
    }
    return '\' + ($parts -join '\')
}

function Get-LogicalEntries {
    param([MacroDesk.Ole2File]$File)

    $result = @{}
    foreach ($entry in $File.Entries) {
        if ($entry.ObjectType -eq 0) {
            continue
        }
        $path = Get-EntryPath $File $entry
        Assert-True (-not $result.ContainsKey($path)) `
            "Duplicate logical entry path: $path"
        $result.Add($path, $entry)
    }
    return $result
}

function Assert-LogicalRoundTrip {
    param(
        [byte[]]$SourceBytes,
        [string]$Label,
        [bool]$RequireDifat
    )

    $source = [MacroDesk.Ole2File]::Parse($SourceBytes)
    if ($RequireDifat) {
        Assert-True ($source.FatSectorIds.Count -gt 109) `
            "$Label does not require a DIFAT continuation."
        Assert-True ($source.DifatSectorIds.Count -gt 0) `
            "$Label has no input DIFAT continuation."
    }

    $rebuiltBytes = [MacroDesk.Ole2Writer]::Rebuild($source)
    $rebuilt = [MacroDesk.Ole2File]::Parse($rebuiltBytes)
    if ($RequireDifat) {
        Assert-True ($rebuilt.FatSectorIds.Count -gt 109) `
            "$Label writer output did not exceed the header DIFAT."
        Assert-True ($rebuilt.DifatSectorIds.Count -gt 0) `
            "$Label writer output has no DIFAT continuation."
    }

    $sourceEntries = Get-LogicalEntries $source
    $rebuiltEntries = Get-LogicalEntries $rebuilt
    Assert-True ($rebuiltEntries.Count -eq $sourceEntries.Count) `
        "$Label logical entry count mismatch."

    $streamCount = 0
    [long]$streamBytes = 0
    foreach ($path in $sourceEntries.Keys) {
        Assert-True ($rebuiltEntries.ContainsKey($path)) `
            "$Label missing logical entry: $path"
        $before = $sourceEntries[$path]
        $after = $rebuiltEntries[$path]
        Assert-True ($after.Name -ceq $before.Name) `
            "$Label name mismatch: $path"
        Assert-True ($after.ObjectType -eq $before.ObjectType) `
            "$Label object type mismatch: $path"
        Assert-True ($after.ClassId -eq $before.ClassId) `
            "$Label CLSID mismatch: $path"
        Assert-True ($after.StateBits -eq $before.StateBits) `
            "$Label state bits mismatch: $path"
        Assert-True (
            $after.CreationTimeRaw -eq $before.CreationTimeRaw) `
            "$Label creation time mismatch: $path"
        Assert-True (
            $after.ModifiedTimeRaw -eq $before.ModifiedTimeRaw) `
            "$Label modified time mismatch: $path"

        if ($before.ObjectType -eq 2) {
            $beforeBytes = $source.ReadStream($before)
            $afterBytes = $rebuilt.ReadStream($after)
            $difference = [MacroDesk.TestByteComparer]::FirstDifference(
                $beforeBytes,
                $afterBytes)
            Assert-True ($difference -eq -1) `
                "$Label stream byte mismatch: $path at $difference"
            $streamCount++
            $streamBytes += $beforeBytes.Length
        }
    }

    return [pscustomobject]@{
        Label = $Label
        SourceLength = $SourceBytes.Length
        RebuiltLength = $rebuiltBytes.Length
        Entries = $sourceEntries.Count
        Streams = $streamCount
        StreamBytes = $streamBytes
        Fat = $rebuilt.FatSectorIds.Count
        Difat = $rebuilt.DifatSectorIds.Count
    }
}

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$references = @(
    'System.IO.Compression',
    'System.IO.Compression.FileSystem'
)
Add-Type -TypeDefinition (Get-EngineSource) `
    -ReferencedAssemblies $references `
    -Language CSharp

$byteComparerSource = @'
using System;

namespace MacroDesk
{
    public static class TestByteComparer
    {
        public static int FirstDifference(byte[] left, byte[] right)
        {
            if (left == null)
            {
                throw new ArgumentNullException("left");
            }
            if (right == null)
            {
                throw new ArgumentNullException("right");
            }

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
    }
}
'@
Add-Type -TypeDefinition $byteComparerSource -Language CSharp

$resolvedTestdata = (Resolve-Path -LiteralPath $TestdataPath).Path
$bookFiles = @(
    Get-ChildItem -LiteralPath $resolvedTestdata -Recurse |
        Where-Object {
            -not $_.PSIsContainer -and
            @('.xlsm', '.xlam', '.xlsb') -contains
                $_.Extension.ToLowerInvariant()
        } |
        Sort-Object FullName
)
Assert-True ($bookFiles.Count -gt 0) `
    "No supported workbook fixtures were found: $resolvedTestdata"

$results = New-Object System.Collections.ArrayList
$stopwatch = [Diagnostics.Stopwatch]::StartNew()
foreach ($book in $bookFiles) {
    $content = [MacroDesk.BookIO]::ReadVbaProjectBytes($book.FullName)
    $result = Assert-LogicalRoundTrip `
        $content.VbaProjectBytes `
        $book.Name `
        $false
    [void]$results.Add($result)
}

$difatPath = Join-Path $resolvedTestdata 'synthetic_difat_v3.cfb'
Assert-True (Test-Path -LiteralPath $difatPath -PathType Leaf) `
    "DIFAT fixture was not found: $difatPath"
$difatResult = Assert-LogicalRoundTrip `
    ([IO.File]::ReadAllBytes($difatPath)) `
    'synthetic_difat_v3.cfb' `
    $true
[void]$results.Add($difatResult)
$stopwatch.Stop()

Write-Output 'test-roundtrip: PASS'
foreach ($result in $results) {
    $line = (
        '{0}: source={1}, rebuilt={2}, entries={3}, streams={4}, ' +
        'streamBytes={5}, fat={6}, difat={7}') -f `
        $result.Label,
        $result.SourceLength,
        $result.RebuiltLength,
        $result.Entries,
        $result.Streams,
        $result.StreamBytes,
        $result.Fat,
        $result.Difat
    Write-Output $line
}
Write-Output ('elapsedMs={0}' -f $stopwatch.ElapsedMilliseconds)
