function ConvertTo-NetBoxSlug {
<#
.Synopsis
   Convert string to NetBox slug
.DESCRIPTION
   Convert string value to Digital Ocean NetBox compatible "slug"
.EXAMPLE
   'ProLiant DL360 G7' | ConvertTo-NetBoxSlug
   proliant-dl360-g7
.EXAMPLE
   ConvertTo-NetBoxSlug -Value 'X9DRFF-iG+/-7G+/-iTG+/-7TG+'
   x9drff-ig-7g-itg-7tg
.INPUTS
   String
.OUTPUTS
   String
.NOTES
This is direct translation of JS function in NetBox forms:
// Slugify
function slugify(s, num_chars) {
    s = s.replace(/[^\-\.\w\s]/g, '');          // Remove unneeded chars
    s = s.replace(/^[\s\.]+|[\s\.]+$/g, '');    // Trim leading/trailing spaces
    s = s.replace(/[\-\.\s]+/g, '-');           // Convert spaces and decimals to hyphens
    s = s.toLowerCase();                        // Convert to lowercase
    return s.substring(0, num_chars);           // Trim to first num_chars chars
}
.LINK
https://github.com/digitalocean/netbox/blob/master/netbox/project-static/js/forms.js
#>
[CmdletBinding()]
[Alias('Slugify')]
[OutputType([String])]
Param (
    # Value to convert to slug
    [Parameter(
        Mandatory=$true,
        ValueFromPipeline=$true
        )]
    $Value
    )

    Process
        {
        $Value = $Value -replace '[^\-\.\w\s]'
        $Value = $Value -replace '^[\s\.]+|[\s\.]+$'
        $Value = $Value -replace '[\-\.\s]+', '-'
        $Value.ToLower()        
        }
    } # End function ConvertTo-NetBoxSlug

function New-NetBoxRestHeaders {
<#
.Synopsis
    Create headers for REST request
.DESCRIPTION
    Create headers object for Invoke-RestMethod against NetBox
.EXAMPLE
    New-NetBoxRestHeaders
.EXAMPLE
    New-NetBoxRestHeaders -Token 'b547136ce8b9d8875f8e5327af0ae581be011dec'
#>
    [CmdletBinding()]
    [Alias()]
    [OutputType("System.Collections.Generic.Dictionary")]
    Param (
        #NetBox authorization token
        [Parameter(Mandatory=$false,
                    ValueFromPipeline=$true,
                    Position=0)]
        [string]$Token
 
    )
    
    End {
        $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        if ($Token) {
            $headers.Add('Authorization', $('Token ' + $Token))
            }
        $headers.Add('Content-Type', 'application/json')
        $headers.Add('Accept', 'application/json')
        $headers
        }
    } # End function New-NetBoxRestHeaders

function Get-NetBoxDevice {
    [CmdletBinding()]
    [Alias()]
    Param (
        #Get device by name
        [Parameter(Mandatory=$false)]          
        [String]$Name,
        [Parameter(Mandatory=$true)]
        [String]$URL,
        [Parameter(Mandatory=$false)]
        [String]$Token
        )

    Begin {
        $headers = New-NetBoxRestHeaders $Token
        }
    Process {
        if ($Name) {
            $URI = $URL + '/dcim/devices/?name=' + [uri]::EscapeDataString($Name)
            }
        else {
            $URI = $URL + '/dcim/devices/'
            }
        Write-Debug $URI
        $REST = Invoke-RestMethod -Uri $URI -Method Get -Headers $headers 
        $REST.results
        }
    }

function Add-NetBoxDevice {
    [CmdletBinding()]
    [Alias()]
    Param (
        # Device name
        [Parameter(Mandatory=$true)]
        [String]$Name,
        # Device Role
        [Parameter(Mandatory=$true)]
        [String]$DeviceRole,
        # Device Manufacturer
        [Parameter(Mandatory=$true)]
        [String]$Manufacturer,
        # Device Type
        [Parameter(Mandatory=$false)]
        [String]$DeviceType,
        [Parameter(Mandatory=$false)]
        [string]$Site = 0,
        [Parameter(Mandatory=$true)]
        [String]$URL,
        [Parameter(Mandatory=$true)]
        [String]$Token
        )

    Begin {
        $NetBox = @{
            URL = $URL
            Token = $Token
            }
        $headers = New-NetBoxRestHeaders $Token
        }
        
    Process {
        $NBManufacturer = Get-NetBoxManufacturer -Name $Manufacturer @NetBox
        if (($NBManufacturer -eq $null) -and ($AutoCreateManufacturer -eq $true)) {
            Add-NetBoxManufacturer -Name $Manufacturer @NetBox
            $NBManufacturer = Get-NetBoxManufacturer -Name $Manufacturer @NetBox
            }

        $NBDeviceRole = Get-NetBoxDeviceRole -Name $DeviceRole @NetBox
        if (($NBDeviceRole -eq $null)) {
            Add-NetBoxDeviceRole -Name $DeviceRole @NetBox
            $NBDeviceRole = Get-NetBoxDeviceRole -Name $DeviceRole @NetBox
            }

        $NBDeviceType = Get-NetBoxDeviceType -Model $DeviceType @NetBox
        if (($NBDeviceType -eq $null)) {
            Add-NetBoxDeviceType -Model $DeviceType -Manufacturer $Manufacturer @NetBox
            $NBDeviceType = Get-NetBoxDeviceType -Model $DeviceType @NetBox
            }

        $NBSite = Get-NetBoxSite -Name $Site @NetBox
        if (($NBSite -eq $null)) {
            Add-NetBoxSite -Name $Site @NetBox
            $NBSite = Get-NetBoxSite -Name $Site @NetBox
            }

        $URI = $URL + '/dcim/devices/'
        $Payload = @{ 
            name = $Name
            device_role = $NBDeviceRole.id
            manufacturer = $NBManufacturer.id
            device_type = $NBDeviceType.id
            site = $NBSite.id
            } | ConvertTo-Json
        Write-Debug $URI
        Write-Debug $Payload
        $REST = Invoke-RestMethod -Uri $URI -Method Post -Headers $headers -Body $Payload
        $REST.result
        }
    } # End function Add-NetBoxDeviceType

###
function Get-NetBoxManufacturer {
    [CmdletBinding()]
    [Alias()]
    Param (
        #Get device by name
        [Parameter(Mandatory=$false)]          
        [String]$Name,
        [Parameter(Mandatory=$true)]
        [String]$URL,
        [Parameter(Mandatory=$false)]
        [String]$Token
        )

    Begin {
        $headers = New-NetBoxRestHeaders $Token
        }
    Process {
        if ($Name) {
            $URI = $URL + '/dcim/manufacturers/?name=' + [uri]::EscapeDataString($Name)
            }
        else {
            $URI = $URL + '/dcim/manufacturers/'
            }
        Write-Debug $URI
        $REST = Invoke-RestMethod -Uri $URI -Method Get -Headers $headers 
        $REST.results
        }
    }

###
function Add-NetBoxManufacturer {
    [CmdletBinding()]
    [Alias()]
    Param (
        #Get device by name
        [Parameter(Mandatory=$true)]
        [String]$Name,
        [Parameter(Mandatory=$true)]
        [String]$URL,
        [Parameter(Mandatory=$false)]
        [String]$Token
        )

    Begin {
        $headers = New-NetBoxRestHeaders $Token
        }
    Process {
        $URI = $URL + '/dcim/manufacturers/'
        $Payload = @{ 
            name = $Name
            slug = $(ConvertTo-NetBoxSlug -Value $Name)
            } | ConvertTo-Json
        Write-Debug $URI
        Write-Debug $Payload
        $REST = Invoke-RestMethod -Uri $URI -Method Post -Headers $headers -Body $Payload
        $REST.result
        }
    }
###

function Get-NetBoxDeviceType {
    [CmdletBinding()]
    [Alias()]
    Param (
        #Get device by name
        [Parameter(Mandatory=$false)]
        [String]$Model,
        [Parameter(Mandatory=$true)]
        [String]$URL,
        [Parameter(Mandatory=$true)]
        [String]$Token
        )

    Begin {
        $headers = New-NetBoxRestHeaders $Token
        }
    Process {
        $URI = $URL + '/dcim/device-types/'
        if ($Model) {
            $URI = $URL + '/dcim/device-types/?model=' + [uri]::EscapeDataString($Model)
            }
        else {
            $URI = $URL + '/dcim/device-types/'
            }
        Write-Debug $URI
        $REST = Invoke-RestMethod -Uri $URI -Method Get -Headers $headers 
        $REST.results
        }
    }
###

function Add-NetBoxDeviceType {
    [CmdletBinding()]
    [Alias()]
    Param (
        # Device Model
        [Parameter(Mandatory=$true)]
        [String]$Model,
        # Device Manufacturer
        [Parameter(Mandatory=$true)]
        [String]$Manufacturer,
        # Height of device in U
        [Parameter(Mandatory=$false)]
        [int]$Height = 0,
        [Parameter(Mandatory=$true)]
        [String]$URL,
        [Parameter(Mandatory=$true)]
        [String]$Token,
        # Create manufacturer if not exists
        [switch]$AutoCreateManufacturer = $true
        )

    Begin {
        $NetBox = @{
            URL = $URL
            Token = $Token
            }
        $headers = New-NetBoxRestHeaders $Token
        $NBManufacturer = Get-NetBoxManufacturer -Name $Manufacturer @NetBox
        if (($NBManufacturer -eq $null) -and ($AutoCreateManufacturer -eq $true)) {
            Add-NetBoxManufacturer -Name $Manufacturer @NetBox
            $NBManufacturer = Get-NetBoxManufacturer -Name $Manufacturer @NetBox
            }
        }
    Process {
        $URI = $URL + '/dcim/device-types/'
        $Payload = @{ 
            model = $Model
            slug = $(ConvertTo-NetBoxSlug -Value $Model)
            manufacturer = $NBManufacturer.id
            u_height = $Height
            } | ConvertTo-Json
        Write-Debug $URI
        Write-Debug $Payload
        $REST = Invoke-RestMethod -Uri $URI -Method Post -Headers $headers -Body $Payload
        $REST.result
        }
    } # End function Add-NetBoxDeviceType

function Get-NetBoxDeviceRole {
    [CmdletBinding()]
    [Alias()]
    Param (
        #Get Role by name
        [Parameter(Mandatory=$false)]
        [String]$Name,
        [Parameter(Mandatory=$false)]
        [String]$Slug,
        [Parameter(Mandatory=$true)]
        [String]$URL,
        [Parameter(Mandatory=$false)]
        [String]$Token
        )

    Begin {
        $headers = New-NetBoxRestHeaders $Token
        }
    Process {
        $URI = $URL + '/dcim/device-roles/'
        if ($Name) {
            $URI = $URI + '?name=' + [uri]::EscapeDataString($Name)
            }
        elseif ($Slug) {
            $URI = $URI + '?slug=' + ($Slug | ConvertTo-NetBoxSlug)
            }
        else {
            
            }
        Write-Debug $URI
        $REST = Invoke-RestMethod -Uri $URI -Method Get -Headers $headers 
        $REST.results
        }
    } # End function Get-NetBoxDeviceRole

function Add-NetBoxDeviceRole {
    [CmdletBinding()]
    [Alias()]
    Param (
        # Role name
        [Parameter(Mandatory=$true)]
        [String]$Name,
        # Role color
        [Parameter(Mandatory=$false)]
        [String]$Color = 'FF69B4',
        # VM Role: Virtual machines may be assigned to this role
        [Parameter(Mandatory=$false)]
        [boolean]$VMRole = $false,
        [Parameter(Mandatory=$true)]
        [String]$URL,
        [Parameter(Mandatory=$true)]
        [String]$Token
        )

    Begin {
        $NetBox = @{
            URL = $URL
            Token = $Token
            }
        $headers = New-NetBoxRestHeaders $Token
        }
    Process {
        $URI = $URL + '/dcim/device-roles/'
        $Payload = @{ 
            name = $Name
            slug = $(ConvertTo-NetBoxSlug -Value $Name)
            color = $Color.ToLower()
            vm_role = $VMRole
            } | ConvertTo-Json
        Write-Debug $URI
        Write-Debug $Payload
        $REST = Invoke-RestMethod -Uri $URI -Method Post -Headers $headers -Body $Payload
        $REST.result
        }
    } # End function Add-NetBoxDeviceRole

function Get-NetBoxSite {
    [CmdletBinding()]
    [Alias()]
    Param (
        #Get Site by name
        [Parameter(Mandatory=$false)]
        [String]$Name,
        #Get Site by slug
        [Parameter(Mandatory=$false)]
        [String]$Slug,
        [Parameter(Mandatory=$true)]
        [String]$URL,
        [Parameter(Mandatory=$false)]
        [String]$Token
        )

    Begin {
        $headers = New-NetBoxRestHeaders $Token
        }
    Process {
        $URI = $URL + '/dcim/sites/'
        if ($Name) {
            $URI = $URI + '?name=' + [uri]::EscapeDataString($Name)
            }
        elseif ($Slug) {
            $URI = $URI + '?slug=' + ($Slug | ConvertTo-NetBoxSlug)
            }
        else {
            
            }
        Write-Debug $URI
        $REST = Invoke-RestMethod -Uri $URI -Method Get -Headers $headers 
        $REST.results
        }
    } # End function Get-NetBoxSite

function Get-NetBoxInterface {
    [CmdletBinding()]
    [Alias()]
    Param (
        #Get device by name
        [Parameter(Mandatory=$false)]
        [String]$DeviceName,
        [Parameter(Mandatory=$false)]
        [String]$Interface,
        [Parameter(Mandatory=$true)]
        [String]$URL,
        [Parameter(Mandatory=$true)]
        [String]$Token
        )

    Begin {
        $headers = New-NetBoxRestHeaders $Token
        }
    Process {
        $NBDevice = Get-NetBoxDevice -Name $DeviceName @NetBox
        if (($NBDevice -eq $null)) {
            break
            }
        $URI = $URL + '/dcim/interfaces/'
        if ($NBDevice -and $Interface) {
            'nbdevice and interface' | Write-Debug
            $URI = $URL + '/dcim/interfaces/?device_id=' + $NBDevice.id + '&name=' + $Interface
            }
        if ($NBDevice -and (!($Interface))) {
            'nbdevice' | Write-Debug
            $URI = $URL + '/dcim/interfaces/?device_id=' + $NBDevice.id
            }
        else {
            #'else' | Write-Debug
            #$URI = $URL + '/dcim/interfaces/'
            }
        Write-Debug $URI
        $REST = Invoke-RestMethod -Uri $URI -Method Get -Headers $headers 
        $REST.results
        }
    } # End function Get-NetBoxInterface

function Add-NetBoxInterface {
    [CmdletBinding()]
    [Alias()]
    Param (
        #Get device by name
        [Parameter(Mandatory=$true)]
        [String]$DeviceName,
        #Port Name
        [Parameter(Mandatory=$true)]
        [String]$Name,
        [Parameter(Mandatory=$false)]
        [String]$MAC,
        [Parameter(Mandatory=$false)]
        [String]$Description,
        [Parameter(Mandatory=$false)]
        [String]$FormFactor,
        [Parameter(Mandatory=$false)]
        [String]$MTU,
        [Parameter(Mandatory=$false)]
        [String]$Enabled,
        [Parameter(Mandatory=$true)]
        [String]$URL,
        [Parameter(Mandatory=$true)]
        [String]$Token
        )

    Begin {
        $headers = New-NetBoxRestHeaders $Token
        }
    Process {
        $NBDevice = Get-NetBoxDevice -Name $DeviceName @NetBox
        if (($NBDevice -eq $null)) {
            break
            }
        $URI = $URL + '/dcim/interfaces/'
        if ($NBDevice) {
            $URI = $URL + '/dcim/interfaces/?device_id=' + $NBDevice.id
            }
        
        $Payload = @{ 
            device = $NBDevice.id
            name = $name
            } 
        if ($MAC) {
            $Payload += @{
                mac_address = $Mac
                }
            }
        if ($Description) {
            $Payload += @{
                description = $Description
                }
            }
        if ($FormFactor) {
            $Payload += @{
                form_factor = $FormFactor
                }
            }

        if ($MTU) {
            $Payload += @{
                mtu = $MTU
                }
            }

        if ($enabled) {
            $Payload += @{
                enabled = $enabled
                }
            }
              
        Write-Debug $URI
        Write-Debug $Payload
        $REST = Invoke-RestMethod -Uri $URI -Method Post -Headers $headers -Body ( $Payload | ConvertTo-Json )
        $REST.results
        }
    } # End function Add-NetBoxInterface

function Get-NetBoxConnection {
    [CmdletBinding()]
    [Alias()]
    Param (
        #Get device by name
        [Parameter(Mandatory=$false)]
        [String]$DeviceName,
        [Parameter(Mandatory=$false)]
        [String]$Interface,
        [Parameter(Mandatory=$true)]
        [String]$URL,
        [Parameter(Mandatory=$true)]
        [String]$Token
        )

    Begin {
        $headers = New-NetBoxRestHeaders $Token
        }
    Process {
        $NBDevice = Get-NetBoxDevice -Name $DeviceName @NetBox
        if (($NBDevice -eq $null)) {
            break
            }
        $URI = $URL + '/dcim/interface-connections/'
        if ($NBDevice) {
            $URI = $URL + '/dcim/interface-connections/?device_id=' + $NBDevice.id
            }
        else {
            $URI = $URL + '/dcim/interface-connections/'
            }
        Write-Debug $URI
        $REST = Invoke-RestMethod -Uri $URI -Method Get -Headers $headers 
        $REST.results
        }
    } # End function Get-NetBoxInterface

function Add-NetBoxConnection {
    [CmdletBinding()]
    [Alias()]
    Param (
        [Parameter(Mandatory=$true)]
        [String]$Device_A,
        [Parameter(Mandatory=$true)]
        [String]$Interface_A,
        
        [Parameter(Mandatory=$true)]
        [String]$Device_B,
        [Parameter(Mandatory=$true)]
        [String]$Interface_B,
        
        [Parameter(Mandatory=$true)]
        [String]$URL,
        [Parameter(Mandatory=$true)]
        [String]$Token
        )

    Begin {
        $NetBox = @{
            URL = $URL
            Token = $Token
            }
        $headers = New-NetBoxRestHeaders $Token
        }
    Process {
        $URI = $URL + '/dcim/interface-connections/'
        
        $IntA = Get-NetBoxInterface -DeviceName $Device_A -Interface $Interface_A @NetBox
        $IntB = Get-NetBoxInterface -DeviceName $Device_B -Interface $Interface_B @NetBox

        $Payload = @{ 
            interface_a = $IntA.id
            interface_b = $intB.id
            } | ConvertTo-Json
        Write-Debug $URI
        Write-Debug $Payload
        $REST = Invoke-RestMethod -Uri $URI -Method Post -Headers $headers -Body $Payload
        $REST.result
        }
    } # End function Add-NetBoxConnection

function Get-NetBoxIpAddress {
    [CmdletBinding()]
    [Alias()]
    Param (
        #Get Site by name
        [Parameter(Mandatory=$false)]
        [String]$Name,
        #Get Site by slug
        [Parameter(Mandatory=$false)]
        [String]$Slug,
        [Parameter(Mandatory=$true)]
        [String]$URL,
        [Parameter(Mandatory=$false)]
        [String]$Token
        )

    Begin {
        $headers = New-NetBoxRestHeaders $Token
        }
    Process {
        $URI = $URL + '/ipam/ip-addresses/'
        if ($Name) {
            #$URI = $URI + '?name=' + [uri]::EscapeDataString($Name)
            }
        else {
            
            }
        Write-Debug $URI
        $REST = Invoke-RestMethod -Uri $URI -Method Get -Headers $headers 
        $REST.results
        }
    } # End function Get-NetBoxIpAddress
