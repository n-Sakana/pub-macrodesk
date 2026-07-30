param(
    [string]$BookPath,
    [string]$EncryptedBookPath
)

# A workbook whose whole file is encrypted (a password is needed to open
# it) is an OLE2 container holding the real workbook as one encrypted
# stream. It used to be handed to the VBA reader, come back with nothing,
# and be reported as a workbook that was read completely and merely has no
# macros - which is both untrue and a dead end for the user.
#
# The containers below are built with the product's own OLE2 writer, so no
# copy of Excel is needed to run this. -EncryptedBookPath additionally
# points the same checks at a real Office-encrypted file when one is
# available.

$ErrorActionPreference = 'Stop'

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Assert-InsideDirectory {
    param(
        [string]$Path,
        [string]$Directory
    )

    $fullPath = [IO.Path]::GetFullPath($Path)
    $fullDirectory = [IO.Path]::GetFullPath($Directory).TrimEnd(
        [IO.Path]::DirectorySeparatorChar,
        [IO.Path]::AltDirectorySeparatorChar)
    $prefix = $fullDirectory + [IO.Path]::DirectorySeparatorChar
    Assert-True (
        $fullPath.StartsWith(
            $prefix,
            [StringComparison]::OrdinalIgnoreCase)) `
        "Test path is outside the expected directory: $fullPath"
}

if ([string]::IsNullOrEmpty($BookPath)) {
    $BookPath = Join-Path $PSScriptRoot '..\testdata\input_win32_sleep.xlsm'
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$testdataRoot = (Resolve-Path (
    Join-Path $PSScriptRoot '..\testdata')).Path
$resolvedBook = (Resolve-Path -LiteralPath $BookPath).Path
$workDir = Join-Path $testdataRoot (
    'encrypted-' + [Guid]::NewGuid().ToString('N'))
Assert-InsideDirectory $workDir $testdataRoot

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$names = @(
    '05_Ole2.cs',
    '06_VbaCompression.cs',
    '07_VbaProject.cs',
    '08_BookIO.cs'
)
$combined = ($names | ForEach-Object {
    [IO.File]::ReadAllText(
        (Join-Path $repoRoot "src\$_"),
        [Text.Encoding]::UTF8)
}) -join "`n"
$usingPattern = '(?m)^\s*using\s+[\w][\w.]*\s*;'
$usings = [regex]::Matches($combined, $usingPattern) |
    ForEach-Object { $_.Value.Trim() } |
    Sort-Object -Unique
$source = ($usings -join "`n") + "`n`n" +
    ($combined -replace $usingPattern, '')
Add-Type -TypeDefinition $source -ReferencedAssemblies @(
    'System.IO.Compression',
    'System.IO.Compression.FileSystem') -Language CSharp

function Get-AttachError {
    param([string]$Path)

    try {
        [void][MacroStudio.BookIO]::ReadProject($Path)
        return ''
    } catch [MacroStudio.MacroStudioException] {
        return $_.Exception.ErrorCode
    } catch {
        if ($_.Exception.InnerException -is
            [MacroStudio.MacroStudioException]) {
            return $_.Exception.InnerException.ErrorCode
        }
        return 'OTHER:' + $_.Exception.GetType().Name
    }
}

# A CFB with the named streams added directly under the root storage.
function New-Container {
    param(
        [byte[]]$Source,
        [string[]]$StreamNames,
        [string]$Path
    )

    $file = [MacroStudio.Ole2File]::Parse($Source)
    $additions = New-Object `
        "System.Collections.Generic.List[MacroStudio.Ole2StreamAddition]"
    foreach ($name in $StreamNames) {
        $payload = [Text.Encoding]::ASCII.GetBytes(
            'payload for ' + $name + ' ' + ('x' * 64))
        $additions.Add(
            (New-Object MacroStudio.Ole2StreamAddition(
                0, $name, $payload)))
    }
    $bytes = [MacroStudio.Ole2Writer]::Rebuild($file, $null, $additions)
    [IO.File]::WriteAllBytes($Path, $bytes)
}

try {
    [void][IO.Directory]::CreateDirectory($workDir)

    # The VBA container of a real workbook is itself an OLE2 file, so it
    # is the honest starting point for these containers: everything below
    # differs from a readable workbook only by the streams added to it.
    $content = [MacroStudio.BookIO]::ReadVbaProjectBytes($resolvedBook)
    $vbaBytes = $content.VbaProjectBytes
    Assert-True ($vbaBytes.Length -gt 0) `
        'The fixture workbook carries no VBA container.'

    $plainPath = Join-Path $workDir 'plain-container.xls'
    [IO.File]::WriteAllBytes($plainPath, $vbaBytes)
    $plainProject = [MacroStudio.BookIO]::ReadProject($plainPath)
    Assert-True ($plainProject.Modules.Count -gt 0) `
        'The unmodified OLE2 container must still read its modules.'
    $moduleCount = $plainProject.Modules.Count

    # Positive: both streams, the shape Office writes (MS-OFFCRYPTO).
    $encryptedPath = Join-Path $workDir 'encrypted-container.xlsm'
    New-Container $vbaBytes @('EncryptionInfo', 'EncryptedPackage') `
        $encryptedPath
    $encryptedCode = Get-AttachError $encryptedPath
    Assert-True ($encryptedCode -eq 'E-ATTACH-04') `
        ("An encrypted workbook must be refused by name: " +
            $encryptedCode)

    # Half a match is not a match. Neither stream on its own means the
    # file is encrypted, and both files still read their macros.
    foreach ($single in @('EncryptionInfo', 'EncryptedPackage')) {
        $singlePath = Join-Path $workDir ('only-' + $single + '.xls')
        New-Container $vbaBytes @($single) $singlePath
        Assert-True ((Get-AttachError $singlePath) -eq '') `
            ("A container with only " + $single +
                " must not be called encrypted.")
        Assert-True (
            [MacroStudio.BookIO]::ReadProject(
                $singlePath).Modules.Count -eq $moduleCount) `
            ("A container with only " + $single +
                " must still read its modules.")
    }

    # A VBA project locked for viewing is a different thing entirely: the
    # lock lives in the PROJECT stream inside vbaProject.bin (CMG / DPB /
    # GC) and the workbook file itself is not encrypted. It must keep
    # reading normally.
    $lockedPath = Join-Path $workDir 'locked-project.xls'
    $file = [MacroStudio.Ole2File]::Parse($vbaBytes)
    $projectEntry = $file.FindChild($file.RootEntry, 'PROJECT', 2)
    Assert-True ($projectEntry -ne $null) `
        'The VBA container has no PROJECT stream to lock.'
    $lockText = "`r`nCMG=`"0123456789ABCDEF`"`r`n" +
        "DPB=`"0123456789ABCDEF0123456789`"`r`n" +
        "GC=`"0123456789ABCDEF`"`r`n"
    $lockedProject = @($file.ReadStream($projectEntry)) +
        @([Text.Encoding]::ASCII.GetBytes($lockText))
    $changes = New-Object `
        "System.Collections.Generic.Dictionary[int,byte[]]"
    $changes.Add($projectEntry.Id, [byte[]]$lockedProject)
    [IO.File]::WriteAllBytes(
        $lockedPath,
        [MacroStudio.Ole2Writer]::Rebuild($file, $changes, $null))
    Assert-True (
        ([Text.Encoding]::ASCII.GetString(
            [IO.File]::ReadAllBytes($lockedPath))).IndexOf('DPB=') -ge 0) `
        'The lock markers were not written into the container.'
    Assert-True ((Get-AttachError $lockedPath) -eq '') `
        'A locked VBA project must not be called an encrypted file.'
    Assert-True (
        [MacroStudio.BookIO]::ReadProject(
            $lockedPath).Modules.Count -eq $moduleCount) `
        'A locked VBA project must still read its modules.'

    # Damaged and unsupported files are not encrypted either. Claiming so
    # would send the user off to remove a password that does not exist.
    $garbagePath = Join-Path $workDir 'garbage.xlsm'
    $garbage = New-Object byte[] 4096
    $index = 0
    while ($index -lt $garbage.Length) {
        $garbage[$index] = [byte](($index * 7) % 251)
        $index++
    }
    [IO.File]::WriteAllBytes($garbagePath, $garbage)
    Assert-True ((Get-AttachError $garbagePath) -ne 'E-ATTACH-04') `
        'A damaged file must not be reported as encrypted.'

    # An OLE2 header with nothing valid behind it: the directory cannot be
    # read, so nothing can be said about encryption.
    $stubPath = Join-Path $workDir 'header-only.xls'
    $stub = New-Object byte[] 512
    foreach ($pair in @(
        @(0, 0xD0), @(1, 0xCF), @(2, 0x11), @(3, 0xE0),
        @(4, 0xA1), @(5, 0xB1), @(6, 0x1A), @(7, 0xE1))) {
        $stub[$pair[0]] = [byte]$pair[1]
    }
    [IO.File]::WriteAllBytes($stubPath, $stub)
    Assert-True ((Get-AttachError $stubPath) -ne 'E-ATTACH-04') `
        'A truncated OLE2 header must not be reported as encrypted.'

    # Non-regression: the workbook this all started from is untouched.
    $again = [MacroStudio.BookIO]::ReadProject($resolvedBook)
    Assert-True ($again.Modules.Count -eq $moduleCount) `
        'The plain workbook stopped reading its modules.'
    Assert-True (-not $again.HasReadWarnings) `
        'The plain workbook gained a read warning.'

    # A real Office-encrypted file, when the caller supplies one.
    $realChecked = $false
    if (-not [string]::IsNullOrEmpty($EncryptedBookPath)) {
        $realPath = (Resolve-Path -LiteralPath $EncryptedBookPath).Path
        $realCode = Get-AttachError $realPath
        Assert-True ($realCode -eq 'E-ATTACH-04') `
            ("A real encrypted workbook was not refused: " + $realCode)
        $realChecked = $true
    }

    Write-Output 'test-encrypted-book: PASS'
    Write-Output (
        ('modules={0}, encrypted=E-ATTACH-04, partial matches read, ' +
            'locked project reads, damaged not encrypted, ' +
            'real file={1}') -f `
        $moduleCount,
        $(if ($realChecked) { 'checked' } else { 'not supplied' }))
} finally {
    if ([IO.Directory]::Exists($workDir)) {
        Assert-InsideDirectory $workDir $testdataRoot
        [IO.Directory]::Delete($workDir, $true)
    }
}
