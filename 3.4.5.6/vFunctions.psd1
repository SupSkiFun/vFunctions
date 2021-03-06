#
# Module manifest for module 'vFunctions'
#
# Generated by: Joe Acosta
#
# Generated on: 03/09/2020
#

@{

# Script module or binary module file associated with this manifest.
RootModule = 'vFunctions.psm1'

# Version number of this module.
ModuleVersion = '3.4.5.6'

# Supported PSEditions
# CompatiblePSEditions = @()

# ID used to uniquely identify this module
GUID = 'a2a44999-f9c8-43f4-a85e-6fef8ef3aa28'

# Author of this module
Author = 'Joe Acosta'

# Company or vendor of this module
CompanyName = 'SupSkiFun'

# Copyright statement for this module
Copyright = '(c) 2020 Joe Acosta. All rights reserved.'

# Description of the functionality provided by this module
Description = 'Various functions for extending the functionality of PowerCLI (VMware).'

# Minimum version of the Windows PowerShell engine required by this module
# PowerShellVersion = ''

# Name of the Windows PowerShell host required by this module
# PowerShellHostName = ''

# Minimum version of the Windows PowerShell host required by this module
# PowerShellHostVersion = ''

# Minimum version of Microsoft .NET Framework required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
# DotNetFrameworkVersion = ''

# Minimum version of the common language runtime (CLR) required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
# CLRVersion = ''

# Processor architecture (None, X86, Amd64) required by this module
# ProcessorArchitecture = ''

# Modules that must be imported into the global environment prior to importing this module
RequiredModules = @('VMware.VimAutomation.Core')

# Assemblies that must be loaded prior to importing this module
# RequiredAssemblies = @()

# Script files (.ps1) that are run in the caller's environment prior to importing this module.
# ScriptsToProcess = @()

# Type files (.ps1xml) to be loaded when importing this module
# TypesToProcess = @()

# Format files (.ps1xml) to be loaded when importing this module
# FormatsToProcess = @()

# Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
# NestedModules = @()

# Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
FunctionsToExport = 'Clear-VSphereAlarm' , 'Find-VMByIP' , 'Format-VMHostPercentage' , 'Get-DataStoreLunID' , 'Get-DataStorePercentageFree' , 'Get-ESXiInfo' ,
'Get-ESXiHyperVisorFS' ,'Get-Info650' , 'Get-PathSelectionPolicy' , 'Get-PereniallyReserved' , 'Get-SnapShotData' ,  'Get-TagInfo' ,
'Get-VAMIHealth' , 'Get-VIB' , 'Get-VMHostHA' , 'Get-VMHostScsiPath' , 'Get-VMHostUpTime' , 'Get-VMHostWWN' , 'Get-VMIP' , 'Get-VMpid' , 'Get-VMToolOutdated' , 'Get-VMTotalSize' ,
'Get-VSphereAlarm' , 'Get-VSphereAlarmConfig' , 'Get-VSphereLicense' , 'Get-VSphereSession' , 'Get-VSphereStatus' , 'Get-WBEMState' ,
'Install-ESXi' , 'Install-VIB' , 'Invoke-VMConsolidation' , 'Invoke-VMHostHBARescan' , 'Open-Console' , 'Reset-VMHostHA' ,
'Restart-EsxLogging' , 'Set-PathSelectionPolicy' , 'Set-PereniallyReserved' , 'Set-VSphereAlarmConfig' , 'Set-WBEMState' ,
'Show-ConnectedCD' , 'Show-DrsRule' , 'Show-FolderContent' , 'Show-FolderPath' , 'Show-RDM' , 'Show-SS' , 'Show-TaskInfo' ,
'Show-USBController' , 'Show-VIPermission' , 'Show-VMHostNetworkInfo' , 'Show-VMHostVirtualPortGroup' , 'Show-VMResource' ,
'Show-VMStat' , 'Start-SSH' , 'Stop-SSH' , 'Stop-VMpid' , 'Stop-VSphereSession' , 'UnInstall-VIB' , 'Update-VIB'

# Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
CmdletsToExport = '*'

# Variables to export from this module
VariablesToExport = '*'

# Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
AliasesToExport = '*'

# DSC resources to export from this module
# DscResourcesToExport = @()

# List of all modules packaged with this module
# ModuleList = @()

# List of all files packaged with this module
FileList = @('vFunctions.psd1' , 'vFunctions.psm1' , 'vClass.psm1')

# Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
PrivateData = @{

    PSData = @{

        # Tags applied to this module. These help with module discovery in online galleries.
        Tags = @('650' , '650FLB' , 'Alarm' , 'Code' , 'Console' , 'ESX' , 'ESXi' , 'Folder' , 'HA' , 'HyperVisor'
        'Permission' , 'pid' , 'PowerCLI' , 'RDM' , 'Stat' , 'Tag' , 'Task' ,
        'USB' , 'VAMI' , 'VCSA' , 'VIB' , 'VMHost' , 'VMware' , 'vSphere' , 'WBEM')

        # A URL to the license for this module.
        # LicenseUri = ''

        # A URL to the main website for this project
        ProjectUri = 'https://github.com/SupSkiFun/vFunctions'

        # A URL to an icon representing this module.
        # IconUri = ''

        # ReleaseNotes of this module
        ReleaseNotes = 'Read examples for function use.
        Refactored Get-VAMIHealth to terminate if CIS Server connection is not detected.
        Added Advanced Function Clear-VSphereAlarm
        Added Advanced Function Get-VMHostHA
        Added Advanced Function Reset-VMHostHA
        This module has been tested against Virtual Center (VCSA) 6.7 U3b / Build 15129973 , VCSA 6.7.0.42000 / Build 1513721'

    } # End of PSData hashtable

} # End of PrivateData hashtable

# HelpInfo URI of this module
# HelpInfoURI = ''

# Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
# DefaultCommandPrefix = ''

}

