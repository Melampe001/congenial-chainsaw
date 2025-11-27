<#
.SYNOPSIS
    Script de copia estructurada hacia carpeta de nube privada local.
    
.DESCRIPTION
    Este script realiza una copia estructurada de los archivos importantes hacia una 
    carpeta destinada a la sincronización con servicios de nube privada como Tresorit, 
    Proton Drive, Nextcloud, etc.
    
    La estructura de destino es: D:\NubePrivada\Backup\FECHA
    
.PARAMETER RutaDestino
    Ruta base de la nube privada. Por defecto: D:\NubePrivada\Backup
    
.PARAMETER RutaOrigen
    Ruta de los respaldos a copiar. Por defecto: $env:USERPROFILE\Respaldos
    
.PARAMETER IncluirCarpetas
    Lista de carpetas adicionales a incluir en el backup.
    
.PARAMETER ExcluirExtensiones
    Lista de extensiones de archivo a excluir.
    
.PARAMETER SoloSimular
    Si se especifica, solo muestra qué se haría sin realizar cambios.
    
.EXAMPLE
    .\02-BackupNube.ps1
    Ejecuta el backup con configuración por defecto.
    
.EXAMPLE
    .\02-BackupNube.ps1 -RutaDestino "E:\MiNube\Backup" -SoloSimular
    Simula el backup usando ruta de destino personalizada.
    
.NOTES
    Autor: Suite de Mantenimiento Windows
    Versión: 1.0
    Requiere: PowerShell 5.1 o superior
    Ejecución recomendada: Programador de Tareas (diario o después de organización)
    Compatible con: Tresorit, Proton Drive, Nextcloud, Syncthing, OneDrive, Google Drive
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$RutaDestino = "D:\NubePrivada\Backup",
    
    [Parameter()]
    [string]$RutaOrigen = "$env:USERPROFILE\Respaldos",
    
    [Parameter()]
    [string[]]$IncluirCarpetas = @(),
    
    [Parameter()]
    [string[]]$ExcluirExtensiones = @(".tmp", ".temp", ".cache", ".log"),
    
    [Parameter()]
    [switch]$SoloSimular
)

#region Configuración
$ErrorActionPreference = "Continue"
$FechaEjecucion = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$FechaBackup = Get-Date -Format "yyyy-MM-dd"
$ArchivoLog = "$RutaOrigen\Logs\BackupNube_$FechaEjecucion.log"
$RutaBackupFinal = Join-Path $RutaDestino $FechaBackup

# Carpetas del usuario a incluir por defecto
$CarpetasUsuarioDefecto = @{
    "Documentos"  = [Environment]::GetFolderPath("MyDocuments")
    "Imagenes"    = [Environment]::GetFolderPath("MyPictures")
    "Escritorio"  = [Environment]::GetFolderPath("Desktop")
}
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

function Test-RutaDisponible {
    param([string]$Ruta)
    
    # Verificar si la unidad existe
    $Unidad = Split-Path $Ruta -Qualifier -ErrorAction SilentlyContinue
    if ($Unidad) {
        $DriveInfo = Get-PSDrive -Name $Unidad.TrimEnd(':') -ErrorAction SilentlyContinue
        if (-not $DriveInfo) {
            return $false
        }
    }
    
    return $true
}

function Get-EspacioDisponible {
    param([string]$Ruta)
    
    try {
        $Unidad = Split-Path $Ruta -Qualifier
        $Drive = Get-PSDrive -Name $Unidad.TrimEnd(':')
        return $Drive.Free
    }
    catch {
        return 0
    }
}

function Format-Tamano {
    param([long]$Bytes)
    
    if ($Bytes -ge 1GB) { return "{0:N2} GB" -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return "{0:N2} MB" -f ($Bytes / 1MB) }
    if ($Bytes -ge 1KB) { return "{0:N2} KB" -f ($Bytes / 1KB) }
    return "$Bytes Bytes"
}

function Copy-ConProgreso {
    param(
        [string]$Origen,
        [string]$Destino,
        [string]$NombreTarea
    )
    
    if (-not (Test-Path $Origen)) {
        Write-Log "El origen '$Origen' no existe. Omitiendo." -Nivel "WARN"
        return @{
            Exito = $false
            ArchivosCopados = 0
            TamanoCopiado = 0
            Errores = @("Origen no existe")
        }
    }
    
    $Archivos = Get-ChildItem -Path $Origen -Recurse -File -ErrorAction SilentlyContinue | 
                Where-Object { $_.Extension -notin $ExcluirExtensiones }
    
    if ($Archivos.Count -eq 0) {
        Write-Log "No hay archivos para copiar en '$Origen'." -Nivel "INFO"
        return @{
            Exito = $true
            ArchivosCopados = 0
            TamanoCopiado = 0
            Errores = @()
        }
    }
    
    $ArchivosCopados = 0
    $TamanoCopiado = 0
    $Errores = @()
    $TotalArchivos = $Archivos.Count
    
    Write-Log "Iniciando copia de $TotalArchivos archivos para '$NombreTarea'..."
    
    foreach ($Archivo in $Archivos) {
        $RutaRelativa = $Archivo.FullName.Substring($Origen.Length).TrimStart('\')
        $DestinoArchivo = Join-Path $Destino $RutaRelativa
        $CarpetaDestino = Split-Path $DestinoArchivo -Parent
        
        if (-not $SoloSimular) {
            try {
                if (-not (Test-Path $CarpetaDestino)) {
                    New-Item -ItemType Directory -Path $CarpetaDestino -Force | Out-Null
                }
                
                Copy-Item -Path $Archivo.FullName -Destination $DestinoArchivo -Force
                $ArchivosCopados++
                $TamanoCopiado += $Archivo.Length
                
                # Mostrar progreso cada 10 archivos
                if ($ArchivosCopados % 10 -eq 0) {
                    $Porcentaje = [math]::Round(($ArchivosCopados / $TotalArchivos) * 100, 1)
                    Write-Progress -Activity "Copiando $NombreTarea" -Status "$Porcentaje% completado" -PercentComplete $Porcentaje
                }
            }
            catch {
                $Errores += "Error copiando '$($Archivo.Name)': $($_.Exception.Message)"
                Write-Log "Error copiando '$($Archivo.Name)': $($_.Exception.Message)" -Nivel "ERROR"
            }
        }
        else {
            Write-Log "[SIMULACIÓN] Copiaría: $($Archivo.Name) -> $DestinoArchivo" -Nivel "INFO"
            $ArchivosCopados++
            $TamanoCopiado += $Archivo.Length
        }
    }
    
    Write-Progress -Activity "Copiando $NombreTarea" -Completed
    
    return @{
        Exito = ($Errores.Count -eq 0)
        ArchivosCopados = $ArchivosCopados
        TamanoCopiado = $TamanoCopiado
        Errores = $Errores
    }
}

function Crear-ArchivoManifiesto {
    param(
        [string]$RutaBackup,
        [hashtable]$Resumen
    )
    
    $Manifiesto = @"
====================================================
MANIFIESTO DE BACKUP - NUBE PRIVADA
====================================================
Fecha de creación: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Equipo origen: $env:COMPUTERNAME
Usuario: $env:USERNAME
Ruta de backup: $RutaBackup
====================================================

RESUMEN DE ARCHIVOS COPIADOS:
-----------------------------
Total de archivos: $($Resumen.TotalArchivosCopados)
Tamaño total: $(Format-Tamano $Resumen.TamanoTotalCopiado)
Carpetas procesadas: $($Resumen.CarpetasProcesadas -join ', ')

INTEGRIDAD:
-----------
Errores encontrados: $($Resumen.TotalErrores)

COMPATIBILIDAD:
---------------
Este backup está estructurado para ser compatible con:
- Tresorit
- Proton Drive
- Nextcloud
- Syncthing
- OneDrive
- Google Drive
- Cualquier otro servicio de sincronización de carpetas

RESTAURACIÓN:
-------------
Para restaurar, copie el contenido de cada subcarpeta
a su ubicación original en el sistema.

====================================================
"@
    
    if (-not $SoloSimular) {
        $Manifiesto | Out-File -FilePath (Join-Path $RutaBackup "MANIFIESTO_BACKUP.txt") -Encoding UTF8
    }
}
#endregion

#region Ejecución Principal
Write-Log "====== INICIO DE BACKUP A NUBE PRIVADA ======" -Nivel "INFO"
Write-Log "Fecha de ejecución: $FechaEjecucion"
Write-Log "Ruta de destino: $RutaBackupFinal"
Write-Log "Modo simulación: $SoloSimular"

# Verificar disponibilidad de la ruta de destino
if (-not (Test-RutaDisponible $RutaDestino)) {
    Write-Log "La ruta de destino '$RutaDestino' no está disponible. Verificar que la unidad esté montada." -Nivel "ERROR"
    Write-Log "Intentando crear en ruta alternativa: $env:USERPROFILE\NubePrivada\Backup" -Nivel "WARN"
    $RutaDestino = "$env:USERPROFILE\NubePrivada\Backup"
    $RutaBackupFinal = Join-Path $RutaDestino $FechaBackup
}

# Verificar espacio disponible
$EspacioDisponible = Get-EspacioDisponible $RutaDestino
Write-Log "Espacio disponible en destino: $(Format-Tamano $EspacioDisponible)"

# Crear estructura de backup
if (-not $SoloSimular) {
    if (-not (Test-Path $RutaBackupFinal)) {
        New-Item -ItemType Directory -Path $RutaBackupFinal -Force | Out-Null
        Write-Log "Creada carpeta de backup: $RutaBackupFinal" -Nivel "SUCCESS"
    }
}

$ResumenTotal = @{
    TotalArchivosCopados = 0
    TamanoTotalCopiado = 0
    TotalErrores = 0
    CarpetasProcesadas = @()
}

# Copiar respaldos existentes del script de organización
if (Test-Path $RutaOrigen) {
    Write-Log "---------- Copiando respaldos existentes ----------"
    $DestinoRespaldos = Join-Path $RutaBackupFinal "Respaldos_Organizacion"
    $Resultado = Copy-ConProgreso -Origen $RutaOrigen -Destino $DestinoRespaldos -NombreTarea "Respaldos de Organización"
    $ResumenTotal.TotalArchivosCopados += $Resultado.ArchivosCopados
    $ResumenTotal.TamanoTotalCopiado += $Resultado.TamanoCopiado
    $ResumenTotal.TotalErrores += $Resultado.Errores.Count
    $ResumenTotal.CarpetasProcesadas += "Respaldos_Organizacion"
}

# Copiar carpetas de usuario
foreach ($NombreCarpeta in $CarpetasUsuarioDefecto.Keys) {
    $RutaCarpeta = $CarpetasUsuarioDefecto[$NombreCarpeta]
    
    if (Test-Path $RutaCarpeta) {
        Write-Log "---------- Procesando: $NombreCarpeta ----------"
        $DestinoUsuario = Join-Path $RutaBackupFinal "Usuario\$NombreCarpeta"
        $Resultado = Copy-ConProgreso -Origen $RutaCarpeta -Destino $DestinoUsuario -NombreTarea $NombreCarpeta
        $ResumenTotal.TotalArchivosCopados += $Resultado.ArchivosCopados
        $ResumenTotal.TamanoTotalCopiado += $Resultado.TamanoCopiado
        $ResumenTotal.TotalErrores += $Resultado.Errores.Count
        $ResumenTotal.CarpetasProcesadas += $NombreCarpeta
    }
}

# Copiar carpetas adicionales especificadas
foreach ($CarpetaAdicional in $IncluirCarpetas) {
    if (Test-Path $CarpetaAdicional) {
        $NombreCarpeta = Split-Path $CarpetaAdicional -Leaf
        Write-Log "---------- Procesando carpeta adicional: $NombreCarpeta ----------"
        $DestinoAdicional = Join-Path $RutaBackupFinal "Adicional\$NombreCarpeta"
        $Resultado = Copy-ConProgreso -Origen $CarpetaAdicional -Destino $DestinoAdicional -NombreTarea $NombreCarpeta
        $ResumenTotal.TotalArchivosCopados += $Resultado.ArchivosCopados
        $ResumenTotal.TamanoTotalCopiado += $Resultado.TamanoCopiado
        $ResumenTotal.TotalErrores += $Resultado.Errores.Count
        $ResumenTotal.CarpetasProcesadas += "Adicional_$NombreCarpeta"
    }
}

# Crear manifiesto
Crear-ArchivoManifiesto -RutaBackup $RutaBackupFinal -Resumen $ResumenTotal

Write-Log "====== RESUMEN DE BACKUP A NUBE ======"
Write-Log "Carpetas procesadas: $($ResumenTotal.CarpetasProcesadas -join ', ')"
Write-Log "Total archivos copiados: $($ResumenTotal.TotalArchivosCopados)"
Write-Log "Tamaño total copiado: $(Format-Tamano $ResumenTotal.TamanoTotalCopiado)"
Write-Log "Errores totales: $($ResumenTotal.TotalErrores)"
Write-Log "Ubicación del backup: $RutaBackupFinal"
Write-Log "Archivo de log: $ArchivoLog"
Write-Log "====== FIN DE BACKUP A NUBE PRIVADA ======" -Nivel "SUCCESS"

# Exportar resumen para uso por otros scripts
$ResumenTotal | Export-Clixml -Path "$RutaOrigen\Logs\UltimoResumen_BackupNube.xml" -Force

return $ResumenTotal
#endregion
