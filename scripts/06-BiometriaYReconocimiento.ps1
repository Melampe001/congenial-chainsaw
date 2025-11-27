<#
.SYNOPSIS
    Script para activar cámara, micrófono y preparar reconocimiento de voz y biometría.
    
.DESCRIPTION
    Este script configura y prepara los dispositivos de entrada para:
    - Activación de cámara (para Windows Hello facial)
    - Activación de micrófono (para reconocimiento de voz)
    - Verificación de Windows Hello (huella, iris, reconocimiento facial)
    - Preparación del servicio de reconocimiento de voz de Windows
    
.PARAMETER VerificarSolamente
    Si se especifica, solo verifica el estado de los dispositivos sin activarlos.
    
.PARAMETER HabilitarReconocimientoVoz
    Si se especifica, habilita y configura el reconocimiento de voz de Windows.
    
.PARAMETER MostrarConfiguracionHello
    Si se especifica, abre la configuración de Windows Hello.
    
.PARAMETER RutaLog
    Ruta donde se guardarán los logs. Por defecto: $env:USERPROFILE\Respaldos\Logs
    
.EXAMPLE
    .\06-BiometriaYReconocimiento.ps1
    Verifica y prepara todos los dispositivos biométricos.
    
.EXAMPLE
    .\06-BiometriaYReconocimiento.ps1 -HabilitarReconocimientoVoz
    Habilita el reconocimiento de voz además de preparar biometría.
    
.EXAMPLE
    .\06-BiometriaYReconocimiento.ps1 -MostrarConfiguracionHello
    Abre la configuración de Windows Hello para configuración manual.
    
.NOTES
    Autor: Suite de Mantenimiento Windows
    Versión: 1.0
    Requiere: PowerShell 5.1 o superior, Windows 10/11 con soporte para Windows Hello
    Algunos componentes requieren privilegios de administrador
    Ejecución recomendada: Manual o al inicio de sesión
#>

[CmdletBinding()]
param(
    [Parameter()]
    [switch]$VerificarSolamente,
    
    [Parameter()]
    [switch]$HabilitarReconocimientoVoz,
    
    [Parameter()]
    [switch]$MostrarConfiguracionHello,
    
    [Parameter()]
    [string]$RutaLog = "$env:USERPROFILE\Respaldos\Logs"
)

#region Configuración
$ErrorActionPreference = "Continue"
$FechaEjecucion = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$ArchivoLog = "$RutaLog\BiometriaReconocimiento_$FechaEjecucion.log"

# Verificar privilegios de administrador
$EsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
#endregion

#region Funciones
function Write-Log {
    param(
        [string]$Mensaje,
        [ValidateSet("INFO", "WARN", "ERROR", "SUCCESS")]
        [string]$Nivel = "INFO"
    )
    
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] [$Nivel] $Mensaje"
    
    $LogDir = Split-Path $ArchivoLog -Parent
    if (-not (Test-Path $LogDir)) {
        New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
    }
    
    Add-Content -Path $ArchivoLog -Value $LogEntry -Encoding UTF8
    
    switch ($Nivel) {
        "INFO"    { Write-Host $LogEntry -ForegroundColor Cyan }
        "WARN"    { Write-Host $LogEntry -ForegroundColor Yellow }
        "ERROR"   { Write-Host $LogEntry -ForegroundColor Red }
        "SUCCESS" { Write-Host $LogEntry -ForegroundColor Green }
    }
}

function Get-DispositivosCamara {
    Write-Log "Verificando dispositivos de cámara..."
    
    try {
        # Obtener dispositivos de imagen
        $Camaras = Get-PnpDevice -Class Camera -ErrorAction SilentlyContinue
        $CamarasImagen = Get-PnpDevice -Class Image -ErrorAction SilentlyContinue | 
                         Where-Object { $_.FriendlyName -match "Camera|Webcam|Cámara" }
        
        $TodasCamaras = @()
        
        if ($Camaras) {
            foreach ($Cam in $Camaras) {
                $TodasCamaras += @{
                    Nombre = $Cam.FriendlyName
                    Estado = $Cam.Status
                    Clase = "Camera"
                    InstanceId = $Cam.InstanceId
                    Habilitado = ($Cam.Status -eq "OK")
                }
            }
        }
        
        if ($CamarasImagen) {
            foreach ($Cam in $CamarasImagen) {
                if ($TodasCamaras.InstanceId -notcontains $Cam.InstanceId) {
                    $TodasCamaras += @{
                        Nombre = $Cam.FriendlyName
                        Estado = $Cam.Status
                        Clase = "Image"
                        InstanceId = $Cam.InstanceId
                        Habilitado = ($Cam.Status -eq "OK")
                    }
                }
            }
        }
        
        return @{
            Dispositivos = $TodasCamaras
            CantidadTotal = $TodasCamaras.Count
            CantidadActivas = ($TodasCamaras | Where-Object { $_.Habilitado }).Count
        }
    }
    catch {
        Write-Log "Error al verificar cámaras: $($_.Exception.Message)" -Nivel "ERROR"
        return @{
            Dispositivos = @()
            CantidadTotal = 0
            CantidadActivas = 0
            Error = $_.Exception.Message
        }
    }
}

function Get-DispositivosMicrofono {
    Write-Log "Verificando dispositivos de micrófono..."
    
    try {
        # Obtener dispositivos de audio (entrada)
        $Microfonos = Get-PnpDevice -Class AudioEndpoint -ErrorAction SilentlyContinue |
                      Where-Object { $_.FriendlyName -match "Microphone|Micrófono|Mic|Input" }
        
        # Alternativa: usar WMI para dispositivos de audio
        $MicWMI = Get-CimInstance -ClassName Win32_SoundDevice -ErrorAction SilentlyContinue
        
        $TodosMicrofonos = @()
        
        if ($Microfonos) {
            foreach ($Mic in $Microfonos) {
                $TodosMicrofonos += @{
                    Nombre = $Mic.FriendlyName
                    Estado = $Mic.Status
                    InstanceId = $Mic.InstanceId
                    Habilitado = ($Mic.Status -eq "OK")
                }
            }
        }
        
        return @{
            Dispositivos = $TodosMicrofonos
            CantidadTotal = $TodosMicrofonos.Count
            CantidadActivos = ($TodosMicrofonos | Where-Object { $_.Habilitado }).Count
            DispositivosAudio = $MicWMI
        }
    }
    catch {
        Write-Log "Error al verificar micrófonos: $($_.Exception.Message)" -Nivel "ERROR"
        return @{
            Dispositivos = @()
            CantidadTotal = 0
            CantidadActivos = 0
            Error = $_.Exception.Message
        }
    }
}

function Get-EstadoWindowsHello {
    Write-Log "Verificando estado de Windows Hello..."
    
    try {
        $HelloInfo = @{
            Disponible = $false
            ReconocimientoFacial = $false
            HuellaDigital = $false
            PIN = $false
            Iris = $false
        }
        
        # Verificar servicio de biometría
        $ServicioBiometria = Get-Service -Name "WbioSrvc" -ErrorAction SilentlyContinue
        if ($ServicioBiometria) {
            $HelloInfo.ServicioBiometria = $ServicioBiometria.Status
            $HelloInfo.Disponible = ($ServicioBiometria.Status -eq "Running")
        }
        
        # Verificar dispositivos biométricos
        $DispositivosBiometricos = Get-PnpDevice -Class Biometric -ErrorAction SilentlyContinue
        if ($DispositivosBiometricos) {
            $HelloInfo.DispositivosBiometricos = $DispositivosBiometricos.Count
            
            foreach ($Dispositivo in $DispositivosBiometricos) {
                if ($Dispositivo.FriendlyName -match "Fingerprint|Huella|Finger") {
                    $HelloInfo.HuellaDigital = $true
                }
                if ($Dispositivo.FriendlyName -match "Face|Facial|IR|Hello") {
                    $HelloInfo.ReconocimientoFacial = $true
                }
                if ($Dispositivo.FriendlyName -match "Iris") {
                    $HelloInfo.Iris = $true
                }
            }
        }
        
        # Verificar si hay cámara IR para Windows Hello Face
        $CamaraIR = Get-PnpDevice -Class Camera -ErrorAction SilentlyContinue |
                    Where-Object { $_.FriendlyName -match "IR|Infrared|Hello" }
        if ($CamaraIR) {
            $HelloInfo.ReconocimientoFacial = $true
            $HelloInfo.CamaraIR = $CamaraIR.FriendlyName
        }
        
        # Verificar configuración de credenciales
        $CredentialGuard = Get-CimInstance -ClassName Win32_DeviceGuard -Namespace root\Microsoft\Windows\DeviceGuard -ErrorAction SilentlyContinue
        if ($CredentialGuard) {
            $HelloInfo.CredentialGuard = $CredentialGuard.SecurityServicesRunning
        }
        
        return $HelloInfo
    }
    catch {
        Write-Log "Error al verificar Windows Hello: $($_.Exception.Message)" -Nivel "ERROR"
        return @{
            Disponible = $false
            Error = $_.Exception.Message
        }
    }
}

function Get-EstadoReconocimientoVoz {
    Write-Log "Verificando estado del reconocimiento de voz..."
    
    try {
        $VozInfo = @{
            Disponible = $false
            Habilitado = $false
            IdiomaActual = $null
        }
        
        # Verificar servicio de reconocimiento de voz
        $ServicioVoz = Get-Service -Name "TabletInputService" -ErrorAction SilentlyContinue
        if ($ServicioVoz) {
            $VozInfo.ServicioTableta = $ServicioVoz.Status
        }
        
        # Verificar servicio de voz de Windows
        $WindowsSpeech = Get-Service -Name "wscsvc" -ErrorAction SilentlyContinue
        
        # Verificar idiomas de reconocimiento instalados
        try {
            Add-Type -AssemblyName System.Speech -ErrorAction SilentlyContinue
            $Reconocedores = [System.Speech.Recognition.SpeechRecognitionEngine]::InstalledRecognizers()
            
            if ($Reconocedores.Count -gt 0) {
                $VozInfo.Disponible = $true
                $VozInfo.IdiomasInstalados = $Reconocedores | ForEach-Object { $_.Culture.DisplayName }
            }
        }
        catch {
            Write-Log "System.Speech no disponible: $($_.Exception.Message)" -Nivel "WARN"
        }
        
        # Verificar Cortana/Voice Assistant
        $Cortana = Get-AppxPackage -Name "*Cortana*" -ErrorAction SilentlyContinue
        if ($Cortana) {
            $VozInfo.CortanaInstalada = $true
        }
        
        return $VozInfo
    }
    catch {
        Write-Log "Error al verificar reconocimiento de voz: $($_.Exception.Message)" -Nivel "ERROR"
        return @{
            Disponible = $false
            Error = $_.Exception.Message
        }
    }
}

function Enable-ServicioBiometria {
    Write-Log "Habilitando servicio de biometría..."
    
    if (-not $EsAdmin) {
        Write-Log "Se requieren privilegios de administrador para habilitar servicios" -Nivel "WARN"
        return $false
    }
    
    try {
        $Servicio = Get-Service -Name "WbioSrvc" -ErrorAction Stop
        
        if ($Servicio.Status -ne "Running") {
            Set-Service -Name "WbioSrvc" -StartupType Automatic -ErrorAction Stop
            Start-Service -Name "WbioSrvc" -ErrorAction Stop
            Write-Log "Servicio de biometría iniciado correctamente" -Nivel "SUCCESS"
        }
        else {
            Write-Log "El servicio de biometría ya está en ejecución" -Nivel "INFO"
        }
        
        return $true
    }
    catch {
        Write-Log "Error al habilitar servicio de biometría: $($_.Exception.Message)" -Nivel "ERROR"
        return $false
    }
}

function Enable-ReconocimientoVoz {
    Write-Log "Configurando reconocimiento de voz..."
    
    try {
        # Habilitar servicio de entrada táctil (incluye voz)
        if ($EsAdmin) {
            $ServicioTablet = Get-Service -Name "TabletInputService" -ErrorAction SilentlyContinue
            if ($ServicioTablet -and $ServicioTablet.Status -ne "Running") {
                Set-Service -Name "TabletInputService" -StartupType Automatic
                Start-Service -Name "TabletInputService" -ErrorAction SilentlyContinue
            }
        }
        
        # Abrir configuración de voz
        Write-Log "Abriendo configuración de reconocimiento de voz..." -Nivel "INFO"
        Start-Process "ms-settings:speech" -ErrorAction SilentlyContinue
        
        Write-Log "Reconocimiento de voz configurado. Complete la configuración en la ventana abierta." -Nivel "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Error al configurar reconocimiento de voz: $($_.Exception.Message)" -Nivel "ERROR"
        return $false
    }
}

function Open-ConfiguracionHello {
    Write-Log "Abriendo configuración de Windows Hello..."
    
    try {
        # Abrir configuración de opciones de inicio de sesión
        Start-Process "ms-settings:signinoptions" -ErrorAction Stop
        Write-Log "Configuración de Windows Hello abierta" -Nivel "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Error al abrir configuración: $($_.Exception.Message)" -Nivel "ERROR"
        return $false
    }
}

function Test-DispositivoEnUso {
    param([string]$TipoDispositivo)
    
    # Verificar si hay aplicaciones usando el dispositivo
    try {
        switch ($TipoDispositivo) {
            "Camara" {
                # Verificar acceso a cámara en configuración de privacidad
                $AccesoCamara = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\webcam" -ErrorAction SilentlyContinue
                return @{
                    AccesoPermitido = ($AccesoCamara.Value -eq "Allow")
                }
            }
            "Microfono" {
                $AccesoMic = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone" -ErrorAction SilentlyContinue
                return @{
                    AccesoPermitido = ($AccesoMic.Value -eq "Allow")
                }
            }
        }
    }
    catch {
        return @{
            AccesoPermitido = $null
            Error = $_.Exception.Message
        }
    }
}

function Enable-AccesoDispositivo {
    param(
        [ValidateSet("webcam", "microphone")]
        [string]$Dispositivo
    )
    
    Write-Log "Habilitando acceso a $Dispositivo..."
    
    try {
        $RutaRegistro = "HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\$Dispositivo"
        
        if (-not (Test-Path $RutaRegistro)) {
            New-Item -Path $RutaRegistro -Force | Out-Null
        }
        
        Set-ItemProperty -Path $RutaRegistro -Name "Value" -Value "Allow" -Type String
        Write-Log "Acceso a $Dispositivo habilitado" -Nivel "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Error al habilitar acceso a $Dispositivo : $($_.Exception.Message)" -Nivel "ERROR"
        return $false
    }
}
#endregion

#region Ejecución Principal
Write-Log "====== INICIO DE CONFIGURACIÓN DE BIOMETRÍA Y RECONOCIMIENTO ======" -Nivel "INFO"
Write-Log "Fecha de ejecución: $FechaEjecucion"
Write-Log "Ejecutando como administrador: $EsAdmin"
Write-Log "Modo verificación solamente: $VerificarSolamente"

$ResumenTotal = @{
    FechaEjecucion = $FechaEjecucion
    Camaras = $null
    Microfonos = $null
    WindowsHello = $null
    ReconocimientoVoz = $null
    AccionesRealizadas = @()
}

# Verificar cámaras
Write-Log "---------- Verificando Cámaras ----------"
$InfoCamaras = Get-DispositivosCamara
$ResumenTotal.Camaras = $InfoCamaras

if ($InfoCamaras.CantidadTotal -gt 0) {
    Write-Log "Cámaras detectadas: $($InfoCamaras.CantidadTotal)" -Nivel "SUCCESS"
    foreach ($Cam in $InfoCamaras.Dispositivos) {
        $EstadoTexto = if ($Cam.Habilitado) { "ACTIVA" } else { "INACTIVA" }
        Write-Log "  - $($Cam.Nombre): $EstadoTexto"
    }
}
else {
    Write-Log "No se detectaron cámaras en el sistema" -Nivel "WARN"
}

# Verificar micrófonos
Write-Log "---------- Verificando Micrófonos ----------"
$InfoMicrofonos = Get-DispositivosMicrofono
$ResumenTotal.Microfonos = $InfoMicrofonos

if ($InfoMicrofonos.CantidadTotal -gt 0) {
    Write-Log "Micrófonos detectados: $($InfoMicrofonos.CantidadTotal)" -Nivel "SUCCESS"
    foreach ($Mic in $InfoMicrofonos.Dispositivos) {
        $EstadoTexto = if ($Mic.Habilitado) { "ACTIVO" } else { "INACTIVO" }
        Write-Log "  - $($Mic.Nombre): $EstadoTexto"
    }
}
else {
    Write-Log "No se detectaron micrófonos en el sistema" -Nivel "WARN"
}

# Verificar Windows Hello
Write-Log "---------- Verificando Windows Hello ----------"
$InfoHello = Get-EstadoWindowsHello
$ResumenTotal.WindowsHello = $InfoHello

Write-Log "Windows Hello disponible: $($InfoHello.Disponible)"
Write-Log "  - Reconocimiento facial: $($InfoHello.ReconocimientoFacial)"
Write-Log "  - Huella digital: $($InfoHello.HuellaDigital)"
Write-Log "  - Iris: $($InfoHello.Iris)"
if ($InfoHello.CamaraIR) {
    Write-Log "  - Cámara IR detectada: $($InfoHello.CamaraIR)" -Nivel "SUCCESS"
}

# Verificar reconocimiento de voz
Write-Log "---------- Verificando Reconocimiento de Voz ----------"
$InfoVoz = Get-EstadoReconocimientoVoz
$ResumenTotal.ReconocimientoVoz = $InfoVoz

Write-Log "Reconocimiento de voz disponible: $($InfoVoz.Disponible)"
if ($InfoVoz.IdiomasInstalados) {
    Write-Log "  - Idiomas instalados: $($InfoVoz.IdiomasInstalados -join ', ')"
}

# Realizar acciones si no es solo verificación
if (-not $VerificarSolamente) {
    Write-Log "---------- Realizando Configuraciones ----------"
    
    # Habilitar acceso a cámara
    $AccesoCamara = Test-DispositivoEnUso -TipoDispositivo "Camara"
    if (-not $AccesoCamara.AccesoPermitido) {
        if (Enable-AccesoDispositivo -Dispositivo "webcam") {
            $ResumenTotal.AccionesRealizadas += "Acceso a cámara habilitado"
        }
    }
    else {
        Write-Log "Acceso a cámara ya está habilitado" -Nivel "INFO"
    }
    
    # Habilitar acceso a micrófono
    $AccesoMic = Test-DispositivoEnUso -TipoDispositivo "Microfono"
    if (-not $AccesoMic.AccesoPermitido) {
        if (Enable-AccesoDispositivo -Dispositivo "microphone") {
            $ResumenTotal.AccionesRealizadas += "Acceso a micrófono habilitado"
        }
    }
    else {
        Write-Log "Acceso a micrófono ya está habilitado" -Nivel "INFO"
    }
    
    # Habilitar servicio de biometría
    if ($InfoHello.Disponible -eq $false -or $InfoHello.ServicioBiometria -ne "Running") {
        if (Enable-ServicioBiometria) {
            $ResumenTotal.AccionesRealizadas += "Servicio de biometría habilitado"
        }
    }
}

# Habilitar reconocimiento de voz si se solicitó
if ($HabilitarReconocimientoVoz) {
    if (Enable-ReconocimientoVoz) {
        $ResumenTotal.AccionesRealizadas += "Configuración de reconocimiento de voz iniciada"
    }
}

# Mostrar configuración de Windows Hello si se solicitó
if ($MostrarConfiguracionHello) {
    if (Open-ConfiguracionHello) {
        $ResumenTotal.AccionesRealizadas += "Configuración de Windows Hello abierta"
    }
}

# Resumen final
Write-Log "====== RESUMEN DE BIOMETRÍA Y RECONOCIMIENTO ======" -Nivel "INFO"
Write-Log "Cámaras detectadas: $($ResumenTotal.Camaras.CantidadTotal) (Activas: $($ResumenTotal.Camaras.CantidadActivas))"
Write-Log "Micrófonos detectados: $($ResumenTotal.Microfonos.CantidadTotal) (Activos: $($ResumenTotal.Microfonos.CantidadActivos))"
Write-Log "Windows Hello: $(if ($ResumenTotal.WindowsHello.Disponible) { 'DISPONIBLE' } else { 'NO DISPONIBLE' })"
Write-Log "Reconocimiento de voz: $(if ($ResumenTotal.ReconocimientoVoz.Disponible) { 'DISPONIBLE' } else { 'NO DISPONIBLE' })"

if ($ResumenTotal.AccionesRealizadas.Count -gt 0) {
    Write-Log "Acciones realizadas:"
    foreach ($Accion in $ResumenTotal.AccionesRealizadas) {
        Write-Log "  - $Accion" -Nivel "SUCCESS"
    }
}

Write-Log "Archivo de log: $ArchivoLog"
Write-Log "====== FIN DE CONFIGURACIÓN ======" -Nivel "SUCCESS"

# Instrucciones adicionales
Write-Log ""
Write-Log "PASOS ADICIONALES RECOMENDADOS:" -Nivel "INFO"
Write-Log "1. Para configurar Windows Hello Face/Huella:"
Write-Log "   Ejecute: ms-settings:signinoptions"
Write-Log "2. Para configurar reconocimiento de voz:"
Write-Log "   Ejecute: ms-settings:speech"
Write-Log "3. Para verificar privacidad de cámara/micrófono:"
Write-Log "   Ejecute: ms-settings:privacy-webcam"
Write-Log ""

# Exportar resumen para uso por otros scripts
$ResumenTotal | Export-Clixml -Path "$RutaLog\UltimoResumen_Biometria.xml" -Force

return $ResumenTotal
#endregion
