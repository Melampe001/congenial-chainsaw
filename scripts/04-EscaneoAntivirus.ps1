<#
.SYNOPSIS
    Script de escaneo antivirus automático con Windows Defender.
    
.DESCRIPTION
    Este script ejecuta escaneos antivirus utilizando Windows Defender (Microsoft Defender Antivirus).
    Permite realizar escaneos rápidos, completos o personalizados con generación de reportes.
    
.PARAMETER TipoEscaneo
    Tipo de escaneo a realizar:
    - Rapido: Escaneo rápido de áreas críticas (por defecto)
    - Completo: Escaneo completo del sistema
    - Personalizado: Escaneo de rutas específicas
    
.PARAMETER RutasPersonalizadas
    Array de rutas a escanear cuando TipoEscaneo es 'Personalizado'.
    
.PARAMETER ActualizarDefiniciones
    Si se especifica, actualiza las definiciones de virus antes del escaneo.
    
.PARAMETER RutaLog
    Ruta donde se guardarán los logs. Por defecto: $env:USERPROFILE\Respaldos\Logs
    
.EXAMPLE
    .\04-EscaneoAntivirus.ps1
    Ejecuta un escaneo rápido con Windows Defender.
    
.EXAMPLE
    .\04-EscaneoAntivirus.ps1 -TipoEscaneo Completo -ActualizarDefiniciones
    Actualiza definiciones y ejecuta escaneo completo.
    
.EXAMPLE
    .\04-EscaneoAntivirus.ps1 -TipoEscaneo Personalizado -RutasPersonalizadas "C:\Descargas","D:\Software"
    Escanea carpetas específicas.
    
.NOTES
    Autor: Suite de Mantenimiento Windows
    Versión: 1.0
    Requiere: PowerShell 5.1 o superior, Windows Defender habilitado
    Ejecución recomendada: Programador de Tareas (diario/semanal, como administrador)
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet("Rapido", "Completo", "Personalizado")]
    [string]$TipoEscaneo = "Rapido",
    
    [Parameter()]
    [string[]]$RutasPersonalizadas = @(),
    
    [Parameter()]
    [switch]$ActualizarDefiniciones,
    
    [Parameter()]
    [string]$RutaLog = "$env:USERPROFILE\Respaldos\Logs"
)

#region Configuración
$ErrorActionPreference = "Continue"
$FechaEjecucion = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$ArchivoLog = "$RutaLog\EscaneoAntivirus_$FechaEjecucion.log"

# Verificar privilegios de administrador
$EsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# Ruta de MpCmdRun.exe
$MpCmdRun = "$env:ProgramFiles\Windows Defender\MpCmdRun.exe"
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

function Test-DefenderDisponible {
    try {
        $Defender = Get-MpComputerStatus -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

function Get-EstadoDefender {
    try {
        $Estado = Get-MpComputerStatus
        return @{
            AntivirusHabilitado = $Estado.AntivirusEnabled
            ProteccionTiempoReal = $Estado.RealTimeProtectionEnabled
            DefinicionesVersion = $Estado.AntivirusSignatureVersion
            DefinicionesFecha = $Estado.AntivirusSignatureLastUpdated
            UltimoEscaneoRapido = $Estado.QuickScanEndTime
            UltimoEscaneoCompleto = $Estado.FullScanEndTime
        }
    }
    catch {
        return $null
    }
}

function Update-Definiciones {
    Write-Log "Actualizando definiciones de virus..."
    
    try {
        # Método 1: Usando Update-MpSignature
        Update-MpSignature -ErrorAction Stop
        Write-Log "Definiciones actualizadas exitosamente" -Nivel "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Error con Update-MpSignature: $($_.Exception.Message)" -Nivel "WARN"
        
        # Método 2: Usando MpCmdRun.exe
        if (Test-Path $MpCmdRun) {
            try {
                $Proceso = Start-Process -FilePath $MpCmdRun -ArgumentList "-SignatureUpdate" -Wait -PassThru -NoNewWindow
                if ($Proceso.ExitCode -eq 0) {
                    Write-Log "Definiciones actualizadas usando MpCmdRun" -Nivel "SUCCESS"
                    return $true
                }
            }
            catch {
                Write-Log "Error usando MpCmdRun: $($_.Exception.Message)" -Nivel "ERROR"
            }
        }
        
        return $false
    }
}

function Start-EscaneoRapido {
    Write-Log "Iniciando escaneo rápido..."
    $InicioEscaneo = Get-Date
    
    try {
        Start-MpScan -ScanType QuickScan -ErrorAction Stop
        $FinEscaneo = Get-Date
        $Duracion = $FinEscaneo - $InicioEscaneo
        
        Write-Log "Escaneo rápido completado en $($Duracion.ToString('hh\:mm\:ss'))" -Nivel "SUCCESS"
        
        return @{
            Exito = $true
            TipoEscaneo = "Rápido"
            Duracion = $Duracion
            Inicio = $InicioEscaneo
            Fin = $FinEscaneo
        }
    }
    catch {
        Write-Log "Error en escaneo rápido: $($_.Exception.Message)" -Nivel "ERROR"
        return @{
            Exito = $false
            TipoEscaneo = "Rápido"
            Error = $_.Exception.Message
        }
    }
}

function Start-EscaneoCompleto {
    Write-Log "Iniciando escaneo completo del sistema..."
    Write-Log "NOTA: El escaneo completo puede tardar varias horas dependiendo del sistema." -Nivel "WARN"
    $InicioEscaneo = Get-Date
    
    try {
        Start-MpScan -ScanType FullScan -ErrorAction Stop
        $FinEscaneo = Get-Date
        $Duracion = $FinEscaneo - $InicioEscaneo
        
        Write-Log "Escaneo completo terminado en $($Duracion.ToString('hh\:mm\:ss'))" -Nivel "SUCCESS"
        
        return @{
            Exito = $true
            TipoEscaneo = "Completo"
            Duracion = $Duracion
            Inicio = $InicioEscaneo
            Fin = $FinEscaneo
        }
    }
    catch {
        Write-Log "Error en escaneo completo: $($_.Exception.Message)" -Nivel "ERROR"
        return @{
            Exito = $false
            TipoEscaneo = "Completo"
            Error = $_.Exception.Message
        }
    }
}

function Start-EscaneoPersonalizado {
    param([string[]]$Rutas)
    
    Write-Log "Iniciando escaneo personalizado..."
    $InicioEscaneo = Get-Date
    $ResultadosRutas = @()
    
    foreach ($Ruta in $Rutas) {
        if (-not (Test-Path $Ruta)) {
            Write-Log "Ruta no encontrada: $Ruta" -Nivel "WARN"
            continue
        }
        
        Write-Log "Escaneando: $Ruta"
        
        try {
            Start-MpScan -ScanType CustomScan -ScanPath $Ruta -ErrorAction Stop
            $ResultadosRutas += @{
                Ruta = $Ruta
                Exito = $true
            }
            Write-Log "Completado escaneo de: $Ruta" -Nivel "SUCCESS"
        }
        catch {
            $ResultadosRutas += @{
                Ruta = $Ruta
                Exito = $false
                Error = $_.Exception.Message
            }
            Write-Log "Error escaneando '$Ruta': $($_.Exception.Message)" -Nivel "ERROR"
        }
    }
    
    $FinEscaneo = Get-Date
    $Duracion = $FinEscaneo - $InicioEscaneo
    
    return @{
        Exito = ($ResultadosRutas | Where-Object { $_.Exito }).Count -eq $ResultadosRutas.Count
        TipoEscaneo = "Personalizado"
        Duracion = $Duracion
        Inicio = $InicioEscaneo
        Fin = $FinEscaneo
        DetalleRutas = $ResultadosRutas
    }
}

function Get-AmenazasDetectadas {
    try {
        $Amenazas = Get-MpThreatDetection -ErrorAction SilentlyContinue
        $AmenazasActivas = Get-MpThreat -ErrorAction SilentlyContinue
        
        $ListaAmenazas = @()
        
        if ($Amenazas) {
            foreach ($Amenaza in $Amenazas) {
                $ListaAmenazas += @{
                    ID = $Amenaza.ThreatID
                    FechaDeteccion = $Amenaza.InitialDetectionTime
                    Recurso = $Amenaza.Resources -join ", "
                }
            }
        }
        
        return @{
            TotalDetecciones = if ($Amenazas) { $Amenazas.Count } else { 0 }
            AmenazasActivas = if ($AmenazasActivas) { $AmenazasActivas.Count } else { 0 }
            Detalle = $ListaAmenazas
        }
    }
    catch {
        Write-Log "Error obteniendo amenazas: $($_.Exception.Message)" -Nivel "WARN"
        return @{
            TotalDetecciones = 0
            AmenazasActivas = 0
            Detalle = @()
        }
    }
}

function Get-HistorialProteccion {
    try {
        # Obtener eventos recientes del historial de protección
        $EventosDefender = Get-WinEvent -LogName "Microsoft-Windows-Windows Defender/Operational" -MaxEvents 50 -ErrorAction SilentlyContinue |
            Where-Object { $_.Id -in @(1116, 1117, 1118, 1119) } |
            Select-Object TimeCreated, Id, Message -First 10
        
        return $EventosDefender
    }
    catch {
        return @()
    }
}
#endregion

#region Ejecución Principal
Write-Log "====== INICIO DE ESCANEO ANTIVIRUS ======" -Nivel "INFO"
Write-Log "Fecha de ejecución: $FechaEjecucion"
Write-Log "Tipo de escaneo: $TipoEscaneo"
Write-Log "Ejecutando como administrador: $EsAdmin"

# Verificar disponibilidad de Windows Defender
if (-not (Test-DefenderDisponible)) {
    Write-Log "Windows Defender no está disponible o está deshabilitado." -Nivel "ERROR"
    Write-Log "Verifique que Windows Defender esté habilitado y que no haya otro antivirus activo." -Nivel "ERROR"
    return @{
        Exito = $false
        Error = "Windows Defender no disponible"
    }
}

# Obtener estado actual
$EstadoDefender = Get-EstadoDefender
Write-Log "Estado de Windows Defender:"
Write-Log "  - Antivirus habilitado: $($EstadoDefender.AntivirusHabilitado)"
Write-Log "  - Protección en tiempo real: $($EstadoDefender.ProteccionTiempoReal)"
Write-Log "  - Versión de definiciones: $($EstadoDefender.DefinicionesVersion)"
Write-Log "  - Fecha definiciones: $($EstadoDefender.DefinicionesFecha)"

# Actualizar definiciones si se solicitó
if ($ActualizarDefiniciones) {
    Write-Log "---------- Actualizando definiciones ----------"
    $ActualizacionExitosa = Update-Definiciones
    if (-not $ActualizacionExitosa) {
        Write-Log "Continuando con definiciones existentes..." -Nivel "WARN"
    }
}

# Ejecutar escaneo según tipo
Write-Log "---------- Ejecutando escaneo ----------"
$ResultadoEscaneo = $null

switch ($TipoEscaneo) {
    "Rapido" {
        $ResultadoEscaneo = Start-EscaneoRapido
    }
    "Completo" {
        $ResultadoEscaneo = Start-EscaneoCompleto
    }
    "Personalizado" {
        if ($RutasPersonalizadas.Count -eq 0) {
            Write-Log "No se especificaron rutas para escaneo personalizado. Usando rutas por defecto." -Nivel "WARN"
            $RutasPersonalizadas = @(
                [Environment]::GetFolderPath("Desktop"),
                (New-Object -ComObject Shell.Application).NameSpace('shell:Downloads').Self.Path
            )
        }
        $ResultadoEscaneo = Start-EscaneoPersonalizado -Rutas $RutasPersonalizadas
    }
}

# Obtener amenazas detectadas
Write-Log "---------- Verificando amenazas detectadas ----------"
$Amenazas = Get-AmenazasDetectadas

$ResumenTotal = @{
    FechaEjecucion = $FechaEjecucion
    TipoEscaneo = $TipoEscaneo
    ResultadoEscaneo = $ResultadoEscaneo
    EstadoDefender = $EstadoDefender
    Amenazas = $Amenazas
    DefinicionesActualizadas = $ActualizarDefiniciones -and $ActualizacionExitosa
}

# Mostrar resumen
Write-Log "====== RESUMEN DE ESCANEO ANTIVIRUS ======"
Write-Log "Tipo de escaneo: $TipoEscaneo"
Write-Log "Resultado: $(if ($ResultadoEscaneo.Exito) { 'EXITOSO' } else { 'CON ERRORES' })"
if ($ResultadoEscaneo.Duracion) {
    Write-Log "Duración: $($ResultadoEscaneo.Duracion.ToString('hh\:mm\:ss'))"
}
Write-Log "Amenazas detectadas (historial): $($Amenazas.TotalDetecciones)"
Write-Log "Amenazas activas: $($Amenazas.AmenazasActivas)"

if ($Amenazas.AmenazasActivas -gt 0) {
    Write-Log "¡ADVERTENCIA! Hay amenazas activas que requieren atención." -Nivel "ERROR"
    Write-Log "Ejecute Windows Security para revisar y tomar acción." -Nivel "ERROR"
}
else {
    Write-Log "No se encontraron amenazas activas." -Nivel "SUCCESS"
}

Write-Log "Archivo de log: $ArchivoLog"
Write-Log "====== FIN DE ESCANEO ANTIVIRUS ======" -Nivel "SUCCESS"

# Exportar resumen para uso por otros scripts
$ResumenTotal | Export-Clixml -Path "$RutaLog\UltimoResumen_Antivirus.xml" -Force

return $ResumenTotal
#endregion
