<#
.SYNOPSIS
    Script maestro de mantenimiento del sistema Windows.
    
.DESCRIPTION
    Este script coordina la ejecución de todos los scripts de mantenimiento:
    1. Organización y clasificación de archivos con respaldo
    2. Backup estructurado a nube privada
    3. Limpieza avanzada del sistema
    4. Escaneo antivirus con Windows Defender
    5. Generación de reporte final
    
    Puede ejecutar todos los scripts en secuencia o seleccionar scripts específicos.
    
.PARAMETER EjecutarTodo
    Ejecuta todos los scripts de mantenimiento en orden.
    
.PARAMETER Organizar
    Ejecuta solo el script de organización de archivos.
    
.PARAMETER Backup
    Ejecuta solo el script de backup a nube.
    
.PARAMETER Limpieza
    Ejecuta solo el script de limpieza del sistema.
    
.PARAMETER Antivirus
    Ejecuta solo el script de escaneo antivirus.
    
.PARAMETER Reporte
    Genera el reporte final.
    
.PARAMETER Biometria
    Ejecuta el script de biometría y reconocimiento.
    
.PARAMETER SoloSimular
    Pasa el parámetro de simulación a todos los scripts.
    
.PARAMETER RutaRespaldo
    Ruta personalizada para respaldos.
    
.PARAMETER RutaNube
    Ruta personalizada para backup de nube.
    
.PARAMETER TipoEscaneo
    Tipo de escaneo antivirus: Rapido, Completo, Personalizado.
    
.EXAMPLE
    .\ScriptMaestro.ps1 -EjecutarTodo
    Ejecuta todos los scripts de mantenimiento.
    
.EXAMPLE
    .\ScriptMaestro.ps1 -Organizar -Limpieza
    Ejecuta solo organización y limpieza.
    
.EXAMPLE
    .\ScriptMaestro.ps1 -EjecutarTodo -SoloSimular
    Simula la ejecución de todos los scripts sin realizar cambios.
    
.NOTES
    Autor: Suite de Mantenimiento Windows
    Versión: 1.0
    Requiere: PowerShell 5.1 o superior
    Para ejecución completa se recomienda: Ejecutar como administrador
    Ejecución recomendada: Programador de Tareas (semanal)
#>

[CmdletBinding(DefaultParameterSetName = "Selectivo")]
param(
    [Parameter(ParameterSetName = "Todo")]
    [switch]$EjecutarTodo,
    
    [Parameter(ParameterSetName = "Selectivo")]
    [switch]$Organizar,
    
    [Parameter(ParameterSetName = "Selectivo")]
    [switch]$Backup,
    
    [Parameter(ParameterSetName = "Selectivo")]
    [switch]$Limpieza,
    
    [Parameter(ParameterSetName = "Selectivo")]
    [switch]$Antivirus,
    
    [Parameter(ParameterSetName = "Selectivo")]
    [switch]$Reporte,
    
    [Parameter(ParameterSetName = "Selectivo")]
    [switch]$Biometria,
    
    [Parameter()]
    [switch]$SoloSimular,
    
    [Parameter()]
    [string]$RutaRespaldo = "$env:USERPROFILE\Respaldos",
    
    [Parameter()]
    [string]$RutaNube = "D:\NubePrivada\Backup",
    
    [Parameter()]
    [ValidateSet("Rapido", "Completo", "Personalizado")]
    [string]$TipoEscaneo = "Rapido",
    
    [Parameter()]
    [switch]$LimpiarNavegadores,
    
    [Parameter()]
    [switch]$VaciarPapelera,
    
    [Parameter()]
    [switch]$ActualizarDefiniciones
)

#region Configuración
$ErrorActionPreference = "Continue"
$FechaEjecucion = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$RutaScripts = $PSScriptRoot
$RutaLog = "$RutaRespaldo\Logs"
$ArchivoLogMaestro = "$RutaLog\ScriptMaestro_$FechaEjecucion.log"

# Verificar privilegios de administrador
$EsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# Definir scripts disponibles
$Scripts = @{
    "01-OrganizarArchivos" = @{
        Archivo = "01-OrganizarArchivos.ps1"
        Descripcion = "Organización y clasificación de archivos"
        RequiereAdmin = $false
    }
    "02-BackupNube" = @{
        Archivo = "02-BackupNube.ps1"
        Descripcion = "Backup estructurado a nube privada"
        RequiereAdmin = $false
    }
    "03-LimpiezaSistema" = @{
        Archivo = "03-LimpiezaSistema.ps1"
        Descripcion = "Limpieza avanzada del sistema"
        RequiereAdmin = $true
    }
    "04-EscaneoAntivirus" = @{
        Archivo = "04-EscaneoAntivirus.ps1"
        Descripcion = "Escaneo antivirus con Windows Defender"
        RequiereAdmin = $true
    }
    "05-GenerarReporte" = @{
        Archivo = "05-GenerarReporte.ps1"
        Descripcion = "Generación de reporte final"
        RequiereAdmin = $false
    }
    "06-BiometriaYReconocimiento" = @{
        Archivo = "06-BiometriaYReconocimiento.ps1"
        Descripcion = "Configuración de biometría y reconocimiento"
        RequiereAdmin = $false
    }
}
#endregion

#region Funciones
function Write-Log {
    param(
        [string]$Mensaje,
        [ValidateSet("INFO", "WARN", "ERROR", "SUCCESS", "HEADER")]
        [string]$Nivel = "INFO"
    )
    
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] [$Nivel] $Mensaje"
    
    $LogDir = Split-Path $ArchivoLogMaestro -Parent
    if (-not (Test-Path $LogDir)) {
        New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
    }
    
    Add-Content -Path $ArchivoLogMaestro -Value $LogEntry -Encoding UTF8
    
    switch ($Nivel) {
        "INFO"    { Write-Host $LogEntry -ForegroundColor Cyan }
        "WARN"    { Write-Host $LogEntry -ForegroundColor Yellow }
        "ERROR"   { Write-Host $LogEntry -ForegroundColor Red }
        "SUCCESS" { Write-Host $LogEntry -ForegroundColor Green }
        "HEADER"  { 
            Write-Host ""
            Write-Host ("=" * 70) -ForegroundColor Magenta
            Write-Host $Mensaje -ForegroundColor Magenta
            Write-Host ("=" * 70) -ForegroundColor Magenta
        }
    }
}

function Show-Banner {
    $Banner = @"
    
================================================================================
    ____  __  ________  ______   __  ______    _   __________________   ________
   / __ \/ / / /  _/ / / / __ \ /  |/  /   |  / | / /_  __/ ____/ | / /_  __/ __ \
  / /_/ / / / // // / / / /_/ / / /|_/ / /| | /  |/ / / / / __/ /  |/ / / / / / / /
 / ____/ /_/ // // /_/ / ____/ / /  / / ___ |/ /|  / / / / /___/ /|  / / / / /_/ / 
/_/    \____/___/\____/_/     /_/  /_/_/  |_/_/ |_/ /_/ /_____/_/ |_/ /_/  \____/  
                                                                                   
                    SUITE DE MANTENIMIENTO WINDOWS v1.0
================================================================================
"@
    Write-Host $Banner -ForegroundColor Cyan
}

function Test-ScriptDisponible {
    param([string]$NombreScript)
    
    $RutaCompleta = Join-Path $RutaScripts $Scripts[$NombreScript].Archivo
    return Test-Path $RutaCompleta
}

function Invoke-ScriptMantenimiento {
    param(
        [string]$NombreScript,
        [hashtable]$Parametros = @{}
    )
    
    $InfoScript = $Scripts[$NombreScript]
    $RutaScript = Join-Path $RutaScripts $InfoScript.Archivo
    
    Write-Log "EJECUTANDO: $($InfoScript.Descripcion)" -Nivel "HEADER"
    Write-Log "Script: $($InfoScript.Archivo)"
    
    if (-not (Test-Path $RutaScript)) {
        Write-Log "ERROR: Script no encontrado: $RutaScript" -Nivel "ERROR"
        return @{ Exito = $false; Error = "Script no encontrado" }
    }
    
    if ($InfoScript.RequiereAdmin -and -not $EsAdmin) {
        Write-Log "ADVERTENCIA: Este script requiere privilegios de administrador" -Nivel "WARN"
        Write-Log "Algunas funciones pueden no estar disponibles" -Nivel "WARN"
    }
    
    try {
        $InicioEjecucion = Get-Date
        
        # Construir argumentos
        $Argumentos = @{}
        foreach ($Key in $Parametros.Keys) {
            $Argumentos[$Key] = $Parametros[$Key]
        }
        
        # Ejecutar script
        $Resultado = & $RutaScript @Argumentos
        
        $FinEjecucion = Get-Date
        $Duracion = $FinEjecucion - $InicioEjecucion
        
        Write-Log "Completado en $($Duracion.ToString('hh\:mm\:ss'))" -Nivel "SUCCESS"
        
        return @{
            Exito = $true
            Resultado = $Resultado
            Duracion = $Duracion
        }
    }
    catch {
        Write-Log "ERROR ejecutando script: $($_.Exception.Message)" -Nivel "ERROR"
        return @{
            Exito = $false
            Error = $_.Exception.Message
        }
    }
}

function Show-Resumen {
    param([hashtable]$Resultados)
    
    Write-Log "RESUMEN DE EJECUCIÓN" -Nivel "HEADER"
    
    $ScriptsExitosos = 0
    $ScriptsConError = 0
    $DuracionTotal = [TimeSpan]::Zero
    
    foreach ($Script in $Resultados.Keys) {
        $Info = $Resultados[$Script]
        $Estado = if ($Info.Exito) { "[OK]" } else { "[ERROR]" }
        $Color = if ($Info.Exito) { "SUCCESS" } else { "ERROR" }
        
        if ($Info.Exito) {
            $ScriptsExitosos++
            if ($Info.Duracion) {
                $DuracionTotal += $Info.Duracion
            }
        }
        else {
            $ScriptsConError++
        }
        
        Write-Log "$Estado $Script" -Nivel $Color
        if (-not $Info.Exito -and $Info.Error) {
            Write-Log "    Error: $($Info.Error)" -Nivel "ERROR"
        }
    }
    
    Write-Log ""
    Write-Log "Scripts ejecutados exitosamente: $ScriptsExitosos"
    Write-Log "Scripts con errores: $ScriptsConError"
    Write-Log "Tiempo total de ejecución: $($DuracionTotal.ToString('hh\:mm\:ss'))"
}

function Show-Menu {
    Write-Host ""
    Write-Host "MENÚ DE MANTENIMIENTO" -ForegroundColor Yellow
    Write-Host "=====================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "1. Ejecutar TODO el mantenimiento"
    Write-Host "2. Organizar archivos"
    Write-Host "3. Backup a nube privada"
    Write-Host "4. Limpieza del sistema"
    Write-Host "5. Escaneo antivirus"
    Write-Host "6. Generar reporte"
    Write-Host "7. Configurar biometría"
    Write-Host "8. Salir"
    Write-Host ""
    
    $Opcion = Read-Host "Seleccione una opción (1-8)"
    return $Opcion
}
#endregion

#region Ejecución Principal
Show-Banner

Write-Log "====== INICIO DEL SCRIPT MAESTRO DE MANTENIMIENTO ======" -Nivel "INFO"
Write-Log "Fecha de ejecución: $FechaEjecucion"
Write-Log "Ejecutando como administrador: $EsAdmin"
Write-Log "Modo simulación: $SoloSimular"
Write-Log "Ruta de respaldos: $RutaRespaldo"
Write-Log "Ruta de nube: $RutaNube"

# Crear directorios necesarios
if (-not (Test-Path $RutaLog)) {
    New-Item -ItemType Directory -Path $RutaLog -Force | Out-Null
}

$ResultadosEjecucion = @{}

# Determinar qué scripts ejecutar
$ScriptsAEjecutar = @()

if ($EjecutarTodo) {
    $ScriptsAEjecutar = @(
        "01-OrganizarArchivos",
        "02-BackupNube",
        "03-LimpiezaSistema",
        "04-EscaneoAntivirus",
        "05-GenerarReporte"
    )
    Write-Log "Modo: Ejecución completa de mantenimiento"
}
else {
    if ($Organizar) { $ScriptsAEjecutar += "01-OrganizarArchivos" }
    if ($Backup) { $ScriptsAEjecutar += "02-BackupNube" }
    if ($Limpieza) { $ScriptsAEjecutar += "03-LimpiezaSistema" }
    if ($Antivirus) { $ScriptsAEjecutar += "04-EscaneoAntivirus" }
    if ($Reporte) { $ScriptsAEjecutar += "05-GenerarReporte" }
    if ($Biometria) { $ScriptsAEjecutar += "06-BiometriaYReconocimiento" }
    
    if ($ScriptsAEjecutar.Count -eq 0) {
        Write-Log "No se especificaron scripts a ejecutar. Use -EjecutarTodo o seleccione scripts específicos." -Nivel "WARN"
        Write-Log "Ejecutando menú interactivo..." -Nivel "INFO"
        
        do {
            $Opcion = Show-Menu
            
            switch ($Opcion) {
                "1" { 
                    $ScriptsAEjecutar = @(
                        "01-OrganizarArchivos",
                        "02-BackupNube",
                        "03-LimpiezaSistema",
                        "04-EscaneoAntivirus",
                        "05-GenerarReporte"
                    )
                }
                "2" { $ScriptsAEjecutar = @("01-OrganizarArchivos") }
                "3" { $ScriptsAEjecutar = @("02-BackupNube") }
                "4" { $ScriptsAEjecutar = @("03-LimpiezaSistema") }
                "5" { $ScriptsAEjecutar = @("04-EscaneoAntivirus") }
                "6" { $ScriptsAEjecutar = @("05-GenerarReporte") }
                "7" { $ScriptsAEjecutar = @("06-BiometriaYReconocimiento") }
                "8" { 
                    Write-Log "Saliendo..." -Nivel "INFO"
                    exit 0
                }
                default {
                    Write-Host "Opción no válida. Intente de nuevo." -ForegroundColor Red
                }
            }
        } while ($ScriptsAEjecutar.Count -eq 0)
    }
}

Write-Log "Scripts a ejecutar: $($ScriptsAEjecutar -join ', ')"

# Ejecutar scripts seleccionados
foreach ($NombreScript in $ScriptsAEjecutar) {
    $Parametros = @{}
    
    # Configurar parámetros según el script
    switch ($NombreScript) {
        "01-OrganizarArchivos" {
            $Parametros["RutaRespaldo"] = $RutaRespaldo
            if ($SoloSimular) { $Parametros["SoloSimular"] = $true }
        }
        "02-BackupNube" {
            $Parametros["RutaDestino"] = $RutaNube
            $Parametros["RutaOrigen"] = $RutaRespaldo
            if ($SoloSimular) { $Parametros["SoloSimular"] = $true }
        }
        "03-LimpiezaSistema" {
            $Parametros["RutaLog"] = $RutaLog
            if ($SoloSimular) { $Parametros["SoloSimular"] = $true }
            if ($LimpiarNavegadores) { $Parametros["LimpiarNavegadores"] = $true }
            if ($VaciarPapelera) { $Parametros["VaciarPapelera"] = $true }
        }
        "04-EscaneoAntivirus" {
            $Parametros["RutaLog"] = $RutaLog
            $Parametros["TipoEscaneo"] = $TipoEscaneo
            if ($ActualizarDefiniciones) { $Parametros["ActualizarDefiniciones"] = $true }
        }
        "05-GenerarReporte" {
            $Parametros["RutaLog"] = $RutaLog
            $Parametros["RutaReporte"] = "$RutaRespaldo\Reportes"
        }
        "06-BiometriaYReconocimiento" {
            $Parametros["RutaLog"] = $RutaLog
        }
    }
    
    $Resultado = Invoke-ScriptMantenimiento -NombreScript $NombreScript -Parametros $Parametros
    $ResultadosEjecucion[$NombreScript] = $Resultado
    
    # Pequeña pausa entre scripts
    Start-Sleep -Seconds 2
}

# Mostrar resumen
Show-Resumen -Resultados $ResultadosEjecucion

Write-Log ""
Write-Log "Archivo de log maestro: $ArchivoLogMaestro"
Write-Log "====== FIN DEL SCRIPT MAESTRO DE MANTENIMIENTO ======" -Nivel "SUCCESS"

# Retornar resultados para uso programático
return @{
    FechaEjecucion = $FechaEjecucion
    ResultadosEjecucion = $ResultadosEjecucion
    ArchivoLog = $ArchivoLogMaestro
}
#endregion
