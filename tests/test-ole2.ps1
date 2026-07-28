param(
    [string]$BookPath
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrEmpty($BookPath)) {
    $BookPath = Join-Path $PSScriptRoot '..\testdata\test_large.xlsm'
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

function Assert-Bytes {
    param(
        [byte[]]$Actual,
        [byte[]]$Expected,
        [string]$Message
    )

    Assert-True ($Actual.Length -eq $Expected.Length) `
        ($Message + ' Length mismatch.')
    for ($index = 0; $index -lt $Expected.Length; $index++) {
        Assert-True ($Actual[$index] -eq $Expected[$index]) `
            ($Message + " Byte mismatch at $index.")
    }
}

function Assert-InvalidData {
    param(
        [ScriptBlock]$Action,
        [string]$Message
    )

    $threw = $false
    try {
        & $Action
    } catch [IO.InvalidDataException] {
        $threw = $true
    }
    Assert-True $threw $Message
}

function Write-UInt16 {
    param(
        [byte[]]$Data,
        [int]$Offset,
        [uint16]$Value
    )

    $valueBytes = [BitConverter]::GetBytes($Value)
    [Buffer]::BlockCopy($valueBytes, 0, $Data, $Offset, 2)
}

function Write-Int32 {
    param(
        [byte[]]$Data,
        [int]$Offset,
        [int]$Value
    )

    $valueBytes = [BitConverter]::GetBytes($Value)
    [Buffer]::BlockCopy($valueBytes, 0, $Data, $Offset, 4)
}

function Write-UInt32 {
    param(
        [byte[]]$Data,
        [int]$Offset,
        [uint32]$Value
    )

    $valueBytes = [BitConverter]::GetBytes($Value)
    [Buffer]::BlockCopy($valueBytes, 0, $Data, $Offset, 4)
}

function Write-UInt64 {
    param(
        [byte[]]$Data,
        [int]$Offset,
        [uint64]$Value
    )

    $valueBytes = [BitConverter]::GetBytes($Value)
    [Buffer]::BlockCopy($valueBytes, 0, $Data, $Offset, 8)
}

function Write-DirectoryEntry {
    param(
        [byte[]]$Data,
        [int]$Offset,
        [string]$Name,
        [byte]$ObjectType,
        [uint32]$LeftSibling,
        [uint32]$RightSibling,
        [uint32]$Child,
        [int]$StartSector,
        [uint64]$Size
    )

    $nameBytes = [Text.Encoding]::Unicode.GetBytes($Name + [char]0)
    if ($nameBytes.Length -gt 64) {
        throw 'Synthetic directory name is too long.'
    }

    [Buffer]::BlockCopy($nameBytes, 0, $Data, $Offset, $nameBytes.Length)
    Write-UInt16 $Data ($Offset + 64) ([uint16]$nameBytes.Length)
    $Data[$Offset + 66] = $ObjectType
    $Data[$Offset + 67] = 1
    Write-UInt32 $Data ($Offset + 68) $LeftSibling
    Write-UInt32 $Data ($Offset + 72) $RightSibling
    Write-UInt32 $Data ($Offset + 76) $Child
    Write-Int32 $Data ($Offset + 116) $StartSector
    Write-UInt64 $Data ($Offset + 120) $Size
}

function Initialize-Header {
    param(
        [byte[]]$Data,
        [uint16]$MajorVersion,
        [uint16]$SectorShift,
        [uint32]$DirectorySectorCount,
        [uint32]$FatSectorCount,
        [int]$FirstDirectorySector,
        [int]$FirstDifatSector,
        [uint32]$DifatSectorCount
    )

    [byte[]]$signature = 0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1
    [Buffer]::BlockCopy($signature, 0, $Data, 0, $signature.Length)
    Write-UInt16 $Data 24 0x003E
    Write-UInt16 $Data 26 $MajorVersion
    Write-UInt16 $Data 28 0xFFFE
    Write-UInt16 $Data 30 $SectorShift
    Write-UInt16 $Data 32 6
    Write-UInt32 $Data 40 $DirectorySectorCount
    Write-UInt32 $Data 44 $FatSectorCount
    Write-Int32 $Data 48 $FirstDirectorySector
    Write-UInt32 $Data 56 0x1000
    Write-Int32 $Data 60 -2
    Write-UInt32 $Data 64 0
    Write-Int32 $Data 68 $FirstDifatSector
    Write-UInt32 $Data 72 $DifatSectorCount

    for ($index = 0; $index -lt 109; $index++) {
        Write-Int32 $Data (76 + $index * 4) -1
    }
}

function Fill-FreeSector {
    param(
        [byte[]]$Data,
        [int]$Offset,
        [int]$SectorSize
    )

    for ($index = 0; $index -lt $SectorSize; $index++) {
        $Data[$Offset + $index] = 0xFF
    }
}

function New-DifatFixture {
    $sectorSize = 512
    $sectorCount = 120
    [byte[]]$data = New-Object byte[] (($sectorCount + 1) * $sectorSize)

    Initialize-Header $data 3 9 0 110 111 110 1
    for ($index = 0; $index -lt 109; $index++) {
        Write-Int32 $data (76 + $index * 4) $index
    }

    for ($sectorId = 0; $sectorId -le 110; $sectorId++) {
        Fill-FreeSector $data (($sectorId + 1) * $sectorSize) $sectorSize
    }

    $firstFatOffset = $sectorSize
    for ($sectorId = 0; $sectorId -le 109; $sectorId++) {
        Write-Int32 $data ($firstFatOffset + $sectorId * 4) -3
    }
    Write-Int32 $data ($firstFatOffset + 110 * 4) -4
    Write-Int32 $data ($firstFatOffset + 111 * 4) -2
    for ($sectorId = 112; $sectorId -lt 119; $sectorId++) {
        Write-Int32 $data ($firstFatOffset + $sectorId * 4) ($sectorId + 1)
    }
    Write-Int32 $data ($firstFatOffset + 119 * 4) -2

    $difatOffset = (110 + 1) * $sectorSize
    Write-Int32 $data $difatOffset 109
    Write-Int32 $data ($difatOffset + $sectorSize - 4) -2

    $directoryOffset = (111 + 1) * $sectorSize
    Write-DirectoryEntry $data $directoryOffset 'Root Entry' 5 `
        ([uint32]::MaxValue) ([uint32]::MaxValue) 1 -2 0
    Write-DirectoryEntry $data ($directoryOffset + 128) 'Payload' 2 `
        ([uint32]::MaxValue) ([uint32]::MaxValue) ([uint32]::MaxValue) `
        112 4096

    for ($index = 0; $index -lt 4096; $index++) {
        $payloadSector = 112 + [int][Math]::Floor($index / $sectorSize)
        $payloadOffset = ($payloadSector + 1) * $sectorSize +
            ($index % $sectorSize)
        $data[$payloadOffset] = [byte]($index % 251)
    }

    return ,$data
}

function New-Version4Fixture {
    $sectorSize = 4096
    $sectorCount = 3
    [byte[]]$data = New-Object byte[] (($sectorCount + 1) * $sectorSize)

    Initialize-Header $data 4 12 1 1 1 -2 0
    Write-Int32 $data 76 0

    $fatOffset = $sectorSize
    Fill-FreeSector $data $fatOffset $sectorSize
    Write-Int32 $data ($fatOffset + 0 * 4) -3
    Write-Int32 $data ($fatOffset + 1 * 4) -2
    Write-Int32 $data ($fatOffset + 2 * 4) -2

    $directoryOffset = (1 + 1) * $sectorSize
    Write-DirectoryEntry $data $directoryOffset 'Root Entry' 5 `
        ([uint32]::MaxValue) ([uint32]::MaxValue) 1 -2 0
    Write-DirectoryEntry $data ($directoryOffset + 128) 'Payload' 2 `
        ([uint32]::MaxValue) ([uint32]::MaxValue) ([uint32]::MaxValue) `
        2 4096

    $payloadOffset = (2 + 1) * $sectorSize
    for ($index = 0; $index -lt 4096; $index++) {
        $data[$payloadOffset + $index] = [byte](255 - ($index % 251))
    }

    return ,$data
}

function Read-VbaProjectBytes {
    param([string]$Path)

    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [IO.Compression.ZipFile]::OpenRead($Path)
    try {
        $entry = $archive.Entries |
            Where-Object { $_.Name -eq 'vbaProject.bin' } |
            Select-Object -First 1
        if (-not $entry) {
            throw 'vbaProject.bin was not found.'
        }

        $input = $entry.Open()
        try {
            $memory = New-Object IO.MemoryStream
            try {
                $input.CopyTo($memory)
                return ,$memory.ToArray()
            } finally {
                $memory.Dispose()
            }
        } finally {
            $input.Dispose()
        }
    } finally {
        $archive.Dispose()
    }
}

$sourcePath = Join-Path $PSScriptRoot '..\src\05_Ole2.cs'
$source = [IO.File]::ReadAllText(
    (Resolve-Path -LiteralPath $sourcePath),
    [Text.Encoding]::UTF8)
Add-Type -TypeDefinition $source -Language CSharp

$testdataPath = (Resolve-Path (
    Join-Path $PSScriptRoot '..\testdata')).Path
$difatFixturePath = Join-Path $testdataPath 'synthetic_difat_v3.cfb'
$fullDifatFixturePath = [IO.Path]::GetFullPath($difatFixturePath)
if (-not $fullDifatFixturePath.StartsWith(
    $testdataPath + [IO.Path]::DirectorySeparatorChar,
    [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Synthetic DIFAT fixture path is outside testdata.'
}

$difatSeed = [MacroDesk.Ole2File]::Parse((New-DifatFixture))
$difatSeedPayload = $difatSeed.FindChild(
    $difatSeed.RootEntry,
    'Payload',
    2)
[byte[]]$largePayload = New-Object byte[] 7200000
$largePayload[0] = 0x2A
$largePayload[$largePayload.Length - 1] = 0xA5
$difatChanges = New-Object `
    'System.Collections.Generic.Dictionary[int,byte[]]'
$difatChanges.Add($difatSeedPayload.Id, $largePayload)
$difatFixture = [MacroDesk.Ole2Writer]::Rebuild(
    $difatSeed,
    $difatChanges)
[IO.File]::WriteAllBytes($fullDifatFixturePath, $difatFixture)
$difatFile = [MacroDesk.Ole2File]::Parse(
    [IO.File]::ReadAllBytes($fullDifatFixturePath))
Assert-True ($difatFile.MajorVersion -eq 3) 'DIFAT fixture version mismatch.'
Assert-True ($difatFile.SectorSize -eq 512) 'DIFAT fixture sector size mismatch.'
Assert-True ($difatFile.FatSectorIds.Count -gt 109) 'DIFAT FAT count mismatch.'
Assert-True ($difatFile.DifatSectorIds.Count -eq 1) 'DIFAT continuation was not read.'
$difatPayloadEntry = $difatFile.FindChild($difatFile.RootEntry, 'Payload', 2)
Assert-True ($null -ne $difatPayloadEntry) 'DIFAT payload entry was not found.'
Assert-True ($difatPayloadEntry.ParentId -eq 0) 'DIFAT parent tree mismatch.'
$difatPayload = $difatFile.ReadStream($difatPayloadEntry)
Assert-True ($difatPayload.Length -eq 7200000) 'DIFAT payload length mismatch.'
Assert-True ($difatPayload[0] -eq 0x2A) 'DIFAT payload first byte mismatch.'
Assert-True ($difatPayload[$difatPayload.Length - 1] -eq 0xA5) `
    'DIFAT payload last byte mismatch.'

$version4File = [MacroDesk.Ole2File]::Parse((New-Version4Fixture))
Assert-True ($version4File.MajorVersion -eq 4) 'Version 4 fixture mismatch.'
Assert-True ($version4File.SectorSize -eq 4096) `
    'Version 4 sector size mismatch.'
$version4PayloadEntry = $version4File.FindChild(
    $version4File.RootEntry,
    'Payload',
    2)
$version4Payload = $version4File.ReadStream($version4PayloadEntry)
Assert-True ($version4Payload.Length -eq 4096) `
    'Version 4 payload length mismatch.'
Assert-True ($version4Payload[0] -eq 255) `
    'Version 4 payload first byte mismatch.'
Assert-InvalidData {
    [MacroDesk.Ole2Writer]::Rebuild($version4File)
} 'Version 4 reconstruction was accepted.'

if (-not (Test-Path -LiteralPath $BookPath -PathType Leaf)) {
    throw "Workbook fixture was not found: $BookPath"
}

$realBytes = Read-VbaProjectBytes (Resolve-Path -LiteralPath $BookPath)
$realFile = [MacroDesk.Ole2File]::Parse($realBytes)
$projectEntry = $realFile.FindChild($realFile.RootEntry, 'PROJECT', 2)
$vbaStorage = $realFile.FindChild($realFile.RootEntry, 'VBA', 1)
Assert-True ($null -ne $projectEntry) 'PROJECT stream was not found.'
Assert-True ($null -ne $vbaStorage) 'VBA storage was not found.'
Assert-True (($realFile.ReadStream($projectEntry)).Length -gt 0) `
    'PROJECT stream was empty.'
$dirEntry = $realFile.FindChild($vbaStorage, 'dir', 2)
Assert-True ($null -ne $dirEntry) 'dir stream was not found.'
Assert-True (($realFile.ReadStream($dirEntry)).Length -gt 0) `
    'dir stream was empty.'

$moduleNames = @(
    'AppController',
    'SystemInfo',
    'TimerUtils',
    'WindowUtils',
    'Sheet1',
    'ThisWorkbook'
)
foreach ($moduleName in $moduleNames) {
    $moduleEntry = $realFile.FindChild($vbaStorage, $moduleName, 2)
    Assert-True ($null -ne $moduleEntry) `
        "Module stream was not found: $moduleName"
    Assert-True (($realFile.ReadStream($moduleEntry)).Length -gt 0) `
        "Module stream was empty: $moduleName"
}

$rebuiltBytes = [MacroDesk.Ole2Writer]::Rebuild($realFile)
$rebuiltFile = [MacroDesk.Ole2File]::Parse($rebuiltBytes)
Assert-True ($rebuiltFile.MajorVersion -eq 3) `
    'Rebuilt real fixture version mismatch.'
Assert-True ($rebuiltFile.Entries.Count -eq $realFile.Entries.Count) `
    'Rebuilt real fixture entry count mismatch.'
for ($entryIndex = 0;
    $entryIndex -lt $realFile.Entries.Count;
    $entryIndex++) {
    $beforeEntry = $realFile.Entries[$entryIndex]
    $afterEntry = $rebuiltFile.Entries[$entryIndex]
    Assert-True ($afterEntry.Name -ceq $beforeEntry.Name) `
        "Entry name mismatch at $entryIndex."
    Assert-True ($afterEntry.ObjectType -eq $beforeEntry.ObjectType) `
        "Entry type mismatch at $entryIndex."
    Assert-True ($afterEntry.ClassId -eq $beforeEntry.ClassId) `
        "Entry CLSID mismatch at $entryIndex."
    Assert-True ($afterEntry.StateBits -eq $beforeEntry.StateBits) `
        "Entry state bits mismatch at $entryIndex."
    Assert-True (
        $afterEntry.CreationTimeRaw -eq $beforeEntry.CreationTimeRaw) `
        "Entry creation time mismatch at $entryIndex."
    Assert-True (
        $afterEntry.ModifiedTimeRaw -eq $beforeEntry.ModifiedTimeRaw) `
        "Entry modified time mismatch at $entryIndex."
    Assert-True ($afterEntry.ParentId -eq $beforeEntry.ParentId) `
        "Entry parent mismatch at $entryIndex."
    if ($beforeEntry.ObjectType -eq 2) {
        Assert-Bytes `
            ($rebuiltFile.ReadStream($afterEntry)) `
            ($realFile.ReadStream($beforeEntry)) `
            "Rebuilt stream $($beforeEntry.Name)"
    }
}

$projectEntry = $realFile.FindChild($realFile.RootEntry, 'PROJECT', 2)
[byte[]]$miniBoundary = New-Object byte[] 4095
$miniBoundary[0] = 0x31
$miniBoundary[$miniBoundary.Length - 1] = 0x32
$miniChanges = New-Object `
    'System.Collections.Generic.Dictionary[int,byte[]]'
$miniChanges.Add($projectEntry.Id, $miniBoundary)
$miniBoundaryFile = [MacroDesk.Ole2File]::Parse(
    [MacroDesk.Ole2Writer]::Rebuild($realFile, $miniChanges))
$miniBoundaryEntry = $miniBoundaryFile.Entries[$projectEntry.Id]
Assert-Bytes `
    ($miniBoundaryFile.ReadStream($miniBoundaryEntry)) `
    $miniBoundary `
    '4095-byte mini stream'

[byte[]]$regularBoundary = New-Object byte[] 4096
$regularBoundary[0] = 0x41
$regularBoundary[$regularBoundary.Length - 1] = 0x42
$regularChanges = New-Object `
    'System.Collections.Generic.Dictionary[int,byte[]]'
$regularChanges.Add($projectEntry.Id, $regularBoundary)
$regularBoundaryFile = [MacroDesk.Ole2File]::Parse(
    [MacroDesk.Ole2Writer]::Rebuild($realFile, $regularChanges))
$regularBoundaryEntry = $regularBoundaryFile.Entries[$projectEntry.Id]
Assert-Bytes `
    ($regularBoundaryFile.ReadStream($regularBoundaryEntry)) `
    $regularBoundary `
    '4096-byte regular stream'

Write-Output 'test-ole2: PASS'
Write-Output (
    'real fixture: sourceSectors={0}, rebuiltSectors={1}, entries={2}' -f `
    (($realBytes.Length / $realFile.SectorSize) - 1),
    (($rebuiltBytes.Length / $rebuiltFile.SectorSize) - 1),
    $realFile.Entries.Count)
Write-Output (
    'DIFAT fixture: {0} bytes, fat={1}, difat={2} at {3}' -f `
    (Get-Item -LiteralPath $fullDifatFixturePath).Length,
    $difatFile.FatSectorIds.Count,
    $difatFile.DifatSectorIds.Count,
    $fullDifatFixturePath)
