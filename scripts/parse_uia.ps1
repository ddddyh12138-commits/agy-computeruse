param(
    [Parameter(Mandatory = $true)][string]$JsonPath,
    [int]$XMin = -5000,
    [int]$XMax = 10000,
    [int]$YMin = -5000,
    [int]$YMax = 10000,
    [string]$RoleFilter = "",
    [string]$NameFilter = "",
    [ValidateSet("all", "panel", "dialog", "taskbar")][string]$Mode = "all",
    [switch]$OnlyInteractive,
    [switch]$BatchClick,
    [int]$Limit = 0
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$raw = [System.IO.File]::ReadAllText($JsonPath, [System.Text.Encoding]::UTF8)
$doc = $raw | ConvertFrom-Json
$script:count = 0

$interactiveRoles = @("button", "textfield", "checkbox", "combobox", "radiobutton", "tab", "menuitem", "scrollbar", "slider", "listbox")
$dialogRoles = @("button", "textfield", "checkbox", "combobox", "radiobutton", "text", "label", "static")

if ($Mode -eq "panel") {
    $OnlyInteractive = $true
} elseif ($Mode -eq "taskbar" -and $RoleFilter -eq "") {
    $RoleFilter = "^(button|menuitem)$"
}

function Walk-Tree {
    param($Node, [string]$ParentName = "", [int]$Depth = 0)
    if ($null -eq $Node) { return }
    if ($Limit -gt 0 -and $script:count -ge $Limit) { return }

    $b = $Node.bounds
    $role = [string]$Node.role
    $name = [string]$Node.name
    $val  = [string]$Node.value
    $ref  = [string]$Node.ref_id

    if ($null -ne $b -and $b.width -gt 0 -and $b.height -gt 0) {
        $x = [int][Math]::Round($b.x)
        $y = [int][Math]::Round($b.y)
        $w = [int][Math]::Round($b.width)
        $h = [int][Math]::Round($b.height)
        $cx = [int][Math]::Round($b.x + $b.width / 2.0)
        $cy = [int][Math]::Round($b.y + $b.height / 2.0)

        $inRegion = ($cx -ge $XMin -and $cx -le $XMax -and $cy -ge $YMin -and $cy -le $YMax)
        $roleOk = ($RoleFilter -eq "" -or $role -match $RoleFilter)
        if ($Mode -eq "dialog" -and $RoleFilter -eq "") {
            $roleOk = ($dialogRoles -contains $role)
        }
        $interOk = (-not $OnlyInteractive -or ($interactiveRoles -contains $role) -or $ref -ne "")
        $searchBlob = "$name $ParentName $val"
        $nameOk = ($NameFilter -eq "" -or $searchBlob -imatch $NameFilter)

        if ($inRegion -and $roleOk -and $interOk -and $nameOk -and ($ref -ne "" -or $name -ne "" -or $val -ne "")) {
            $indent = "  " * [Math]::Min($Depth, 6)
            $pTag = if ($ParentName -ne "" -and $name -eq "") { "[$ParentName] " } else { "" }
            $line = ("{0}{1} {2}name={3} val={4} xy=({5},{6}) box=({7},{8},{9},{10}) ref={11}" -f `
                $indent, $role, $pTag, ($name -replace "`r|`n"," "), ($val -replace "`r|`n"," "), $cx, $cy, $x, $y, $w, $h, $ref)
            if ($BatchClick) {
                $line += (' batch={"command":"mouse-click","args":{"xy":"' + $cx + ',' + $cy + '"}}')
            }
            Write-Output $line
            $script:count++
            if ($Limit -gt 0 -and $script:count -ge $Limit) { return }
        }
    }

    $nextParent = if ($name -ne "") { $name } else { $ParentName }
    if ($null -ne $Node.children) {
        $idx = 0
        foreach ($c in $Node.children) {
            $childParent = if ($c.name -eq "" -and $nextParent -ne "") { "${nextParent}#${idx}" } else { $nextParent }
            Walk-Tree -Node $c -ParentName $childParent -Depth ($Depth + 1)
            $idx++
        }
    }
}

Walk-Tree -Node $doc.data.tree
