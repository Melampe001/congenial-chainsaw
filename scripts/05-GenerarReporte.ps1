<#
.SYNOPSIS
    Script de generación de reporte final de mantenimiento.
    
.DESCRIPTION
    Este script genera un reporte completo de todas las acciones de mantenimiento
    realizadas, incluyendo organización de archivos, backup, limpieza y escaneo antivirus.
    El reporte se muestra en pantalla y se guarda como archivo .txt.
    
.PARAMETER RutaLog
    Ruta donde se encuentran los logs y resúmenes. Por defecto: $env:USERPROFILE\Respaldos\Logs
    
.PARAMETER RutaReporte
    Ruta donde se guardará el reporte. Por defecto: $env:USERPROFILE\Respaldos\Reportes
    
.PARAMETER MostrarEnPantalla
    Si se especifica, muestra el reporte completo en pantalla. Por defecto: $true
    
.PARAMETER AbrirReporte
    Si se especifica, abre el archivo de reporte después de generarlo.
    
.EXAMPLE
    .\05-GenerarReporte.ps1
    Genera el reporte con configuración por defecto.
    
.EXAMPLE
    .\05-GenerarReporte.ps1 -AbrirReporte
    Genera el reporte y lo abre con el editor de texto predeterminado.
    
.NOTES
    Autor: Suite de Mantenimiento Windows
    Versión: 1.0
    Requiere: PowerShell 5.1 o superior
    Ejecución recomendada: Al final del script maestro o manualmente
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$RutaLog = "$env:USERPROFILE\Respaldos\Logs",
    
    [Parameter()]
    [string]$RutaReporte = "$env:USERPROFILE\Respaldos\Reportes",
    
    [Parameter()]
    [bool]$MostrarEnPantalla = $true,
    
    [Parameter()]
    [switch]$AbrirReporte
)

#region Configuración
$ErrorActionPreference = "Continue"
$FechaEjecucion = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$FechaLegible = Get-Date -Format "dd/MM/yyyy HH:mm:ss"
$ArchivoReporte = "$RutaReporte\ReporteMantenimiento_$FechaEjecucion.txt"
#endregion

#region Funciones
function Format-Tamano {
    param([long]$Bytes)
    
    if ($null -eq $Bytes -or $Bytes -eq 0) { return "0 Bytes" }
    if ($Bytes -ge 1GB) { return "{0:N2} GB" -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return "{0:N2} MB" -f ($Bytes / 1MB) }
    if ($Bytes -ge 1KB) { return "{0:N2} KB" -f ($Bytes / 1KB) }
    return "$Bytes Bytes"
}

function Get-InfoSistema {
    $OS = Get-CimInstance -ClassName Win32_OperatingSystem
    $PC = Get-CimInstance -ClassName Win32_ComputerSystem
    $CPU = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1
    
    # Información de discos
    $Discos = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3" |
        ForEach-Object {
            @{
                Letra = $_.DeviceID
                Etiqueta = $_.VolumeName
                TamanoTotal = $_.Size
                EspacioLibre = $_.FreeSpace
                PorcentajeLibre = if ($_.Size -gt 0) { [math]::Round(($_.FreeSpace / $_.Size) * 100, 1) } else { 0 }
            }
        }
    
    return @{
        NombreEquipo = $env:COMPUTERNAME
        Usuario = $env:USERNAME
        SistemaOperativo = "$($OS.Caption) $($OS.Version)"
        Arquitectura = $OS.OSArchitecture
        RAM = Format-Tamano $PC.TotalPhysicalMemory
        Procesador = $CPU.Name
        Discos = $Discos
        FechaInstalacion = $OS.InstallDate
        UltimoInicio = $OS.LastBootUpTime
    }
}

function Import-ResumenSeguro {
    param(
        [string]$Ruta,
        [string]$Nombre
    )
    
    if (Test-Path $Ruta) {
        try {
            $Datos = Import-Clixml -Path $Ruta
            return $Datos
        }
        catch {
            Write-Host "No se pudo cargar el resumen de $Nombre" -ForegroundColor Yellow
            return $null
        }
    }
    return $null
}

function Get-LogsRecientes {
    param(
        [string]$Patron,
        [int]$MaxArchivos = 5
    )
    
    $Logs = Get-ChildItem -Path $RutaLog -Filter $Patron -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First $MaxArchivos
    
    return $Logs
}

function Crear-SeccionReporte {
    param(
        [string]$Titulo,
        [string]$Contenido
    )
    
    $Linea = "=" * 60
    $LineaMedia = "-" * 60
    
    return @"

$Linea
$Titulo
$LineaMedia
$Contenido
"@
}
#endregion

#region Construcción del Reporte
# Crear directorio de reportes si no existe
if (-not (Test-Path $RutaReporte)) {
    New-Item -ItemType Directory -Path $RutaReporte -Force | Out-Null
}

# Obtener información del sistema
$InfoSistema = Get-InfoSistema

# Cargar resúmenes de otros scripts
$ResumenOrganizacion = Import-ResumenSeguro -Ruta "$RutaLog\UltimoResumen_Organizacion.xml" -Nombre "Organización"
$ResumenBackup = Import-ResumenSeguro -Ruta "$RutaLog\UltimoResumen_BackupNube.xml" -Nombre "Backup"
$ResumenLimpieza = Import-ResumenSeguro -Ruta "$RutaLog\UltimoResumen_Limpieza.xml" -Nombre "Limpieza"
$ResumenAntivirus = Import-ResumenSeguro -Ruta "$RutaLog\UltimoResumen_Antivirus.xml" -Nombre "Antivirus"

# Construir el reporte
$Reporte = @"
================================================================================
                    REPORTE DE MANTENIMIENTO DEL SISTEMA
================================================================================
Fecha de generación: $FechaLegible
Equipo: $($InfoSistema.NombreEquipo)
Usuario: $($InfoSistema.Usuario)
================================================================================

"@

# Sección: Información del Sistema
$InfoSistemaTexto = @"
Sistema Operativo: $($InfoSistema.SistemaOperativo)
Arquitectura: $($InfoSistema.Arquitectura)
Procesador: $($InfoSistema.Procesador)
RAM Total: $($InfoSistema.RAM)
Último inicio: $($InfoSistema.UltimoInicio)

ESTADO DE DISCOS:
"@

foreach ($Disco in $InfoSistema.Discos) {
    $InfoSistemaTexto += @"

  [$($Disco.Letra)] $($Disco.Etiqueta)
    - Tamaño total: $(Format-Tamano $Disco.TamanoTotal)
    - Espacio libre: $(Format-Tamano $Disco.EspacioLibre) ($($Disco.PorcentajeLibre)%)
"@
}

$Reporte += Crear-SeccionReporte -Titulo "INFORMACIÓN DEL SISTEMA" -Contenido $InfoSistemaTexto

# Sección: Organización de Archivos
if ($ResumenOrganizacion) {
    $OrganizacionTexto = @"
Estado: COMPLETADO
Archivos respaldados: $($ResumenOrganizacion.TotalArchivosRespaldados)
Archivos organizados: $($ResumenOrganizacion.TotalArchivosOrganizados)
Tamaño respaldado: $(Format-Tamano $ResumenOrganizacion.TamanoTotalRespaldado)
Carpetas procesadas: $($ResumenOrganizacion.CarpetasProcesadas -join ', ')
"@
}
else {
    $OrganizacionTexto = @"
Estado: NO EJECUTADO o SIN DATOS
Ejecute el script 01-OrganizarArchivos.ps1 para organizar sus archivos.
"@
}

$Reporte += Crear-SeccionReporte -Titulo "ORGANIZACIÓN DE ARCHIVOS" -Contenido $OrganizacionTexto

# Sección: Backup a Nube
if ($ResumenBackup) {
    $BackupTexto = @"
Estado: COMPLETADO
Archivos copiados: $($ResumenBackup.TotalArchivosCopados)
Tamaño total copiado: $(Format-Tamano $ResumenBackup.TamanoTotalCopiado)
Errores: $($ResumenBackup.TotalErrores)
Carpetas procesadas: $($ResumenBackup.CarpetasProcesadas -join ', ')
"@
}
else {
    $BackupTexto = @"
Estado: NO EJECUTADO o SIN DATOS
Ejecute el script 02-BackupNube.ps1 para realizar backup a la nube privada.
"@
}

$Reporte += Crear-SeccionReporte -Titulo "BACKUP A NUBE PRIVADA" -Contenido $BackupTexto

# Sección: Limpieza del Sistema
if ($ResumenLimpieza) {
    $LimpiezaTexto = @"
Estado: COMPLETADO
Archivos eliminados: $($ResumenLimpieza.TotalArchivosEliminados)
Espacio liberado: $(Format-Tamano $ResumenLimpieza.TotalEspacioLiberado)
Errores: $($ResumenLimpieza.TotalErrores)
Áreas limpiadas: $($ResumenLimpieza.AreasLimpiadas -join ', ')
"@
}
else {
    $LimpiezaTexto = @"
Estado: NO EJECUTADO o SIN DATOS
Ejecute el script 03-LimpiezaSistema.ps1 para limpiar archivos temporales.
"@
}

$Reporte += Crear-SeccionReporte -Titulo "LIMPIEZA DEL SISTEMA" -Contenido $LimpiezaTexto

# Sección: Escaneo Antivirus
if ($ResumenAntivirus) {
    $AntivirusTexto = @"
Estado: $(if ($ResumenAntivirus.ResultadoEscaneo.Exito) { 'COMPLETADO' } else { 'CON ERRORES' })
Tipo de escaneo: $($ResumenAntivirus.TipoEscaneo)
Definiciones actualizadas: $($ResumenAntivirus.DefinicionesActualizadas)

ESTADO DE WINDOWS DEFENDER:
  - Antivirus habilitado: $($ResumenAntivirus.EstadoDefender.AntivirusHabilitado)
  - Protección en tiempo real: $($ResumenAntivirus.EstadoDefender.ProteccionTiempoReal)
  - Versión definiciones: $($ResumenAntivirus.EstadoDefender.DefinicionesVersion)

AMENAZAS:
  - Detecciones en historial: $($ResumenAntivirus.Amenazas.TotalDetecciones)
  - Amenazas activas: $($ResumenAntivirus.Amenazas.AmenazasActivas)
"@
    
    if ($ResumenAntivirus.Amenazas.AmenazasActivas -gt 0) {
        $AntivirusTexto += @"

  ¡¡¡ ATENCIÓN: HAY AMENAZAS ACTIVAS QUE REQUIEREN ACCIÓN !!!
  Abra Windows Security para revisar y tomar las medidas necesarias.
"@
    }
}
else {
    $AntivirusTexto = @"
Estado: NO EJECUTADO o SIN DATOS
Ejecute el script 04-EscaneoAntivirus.ps1 para realizar un escaneo.
"@
}

$Reporte += Crear-SeccionReporte -Titulo "ESCANEO ANTIVIRUS" -Contenido $AntivirusTexto

# Sección: Archivos de Log Generados
$LogsOrganizacion = Get-LogsRecientes -Patron "OrganizacionArchivos_*.log" -MaxArchivos 3
$LogsBackup = Get-LogsRecientes -Patron "BackupNube_*.log" -MaxArchivos 3
$LogsLimpieza = Get-LogsRecientes -Patron "LimpiezaSistema_*.log" -MaxArchivos 3
$LogsAntivirus = Get-LogsRecientes -Patron "EscaneoAntivirus_*.log" -MaxArchivos 3

$LogsTexto = @"
Ubicación de logs: $RutaLog

Logs recientes de Organización:
"@
foreach ($Log in $LogsOrganizacion) {
    $LogsTexto += "`n  - $($Log.Name) ($($Log.LastWriteTime))"
}

$LogsTexto += @"

Logs recientes de Backup:
"@
foreach ($Log in $LogsBackup) {
    $LogsTexto += "`n  - $($Log.Name) ($($Log.LastWriteTime))"
}

$LogsTexto += @"

Logs recientes de Limpieza:
"@
foreach ($Log in $LogsLimpieza) {
    $LogsTexto += "`n  - $($Log.Name) ($($Log.LastWriteTime))"
}

$LogsTexto += @"

Logs recientes de Antivirus:
"@
foreach ($Log in $LogsAntivirus) {
    $LogsTexto += "`n  - $($Log.Name) ($($Log.LastWriteTime))"
}

$Reporte += Crear-SeccionReporte -Titulo "ARCHIVOS DE LOG" -Contenido $LogsTexto

# Sección: Recomendaciones
$Recomendaciones = @"
RECOMENDACIONES PARA EL MANTENIMIENTO:

1. FRECUENCIA DE EJECUCIÓN:
   - Organización de archivos: Semanal
   - Backup a nube: Diario o después de cambios importantes
   - Limpieza del sistema: Semanal
   - Escaneo antivirus rápido: Diario
   - Escaneo antivirus completo: Mensual

2. PROGRAMADOR DE TAREAS:
   Configure estos scripts en el Programador de Tareas de Windows para
   ejecución automática. Consulte la documentación README.md para más detalles.

3. BUENAS PRÁCTICAS:
   - Revise los logs periódicamente
   - Mantenga Windows Defender actualizado
   - Verifique que los backups se sincronicen correctamente con su nube
   - Ejecute el script maestro para mantenimiento completo

4. EN CASO DE PROBLEMAS:
   - Revise los archivos de log para diagnóstico
   - Ejecute los scripts con -SoloSimular para verificar acciones
   - Asegúrese de tener privilegios de administrador cuando sea necesario
"@

$Reporte += Crear-SeccionReporte -Titulo "RECOMENDACIONES" -Contenido $Recomendaciones

# Pie del reporte
$Reporte += @"

================================================================================
                         FIN DEL REPORTE DE MANTENIMIENTO
================================================================================
Reporte generado por: Suite de Mantenimiento Windows
Versión: 1.0
Ubicación del reporte: $ArchivoReporte
================================================================================
"@

#endregion

#region Salida del Reporte
# Guardar reporte en archivo
$Reporte | Out-File -FilePath $ArchivoReporte -Encoding UTF8
Write-Host "`n[ÉXITO] Reporte guardado en: $ArchivoReporte" -ForegroundColor Green

# Mostrar en pantalla si se solicitó
if ($MostrarEnPantalla) {
    Write-Host $Reporte
}

# Abrir reporte si se solicitó
if ($AbrirReporte) {
    Start-Process notepad.exe -ArgumentList $ArchivoReporte
}

# Exportar objeto de resumen para uso programático
$ResumenCompleto = @{
    FechaGeneracion = $FechaEjecucion
    ArchivoReporte = $ArchivoReporte
    InfoSistema = $InfoSistema
    Organizacion = $ResumenOrganizacion
    Backup = $ResumenBackup
    Limpieza = $ResumenLimpieza
    Antivirus = $ResumenAntivirus
}

return $ResumenCompleto
#endregion
