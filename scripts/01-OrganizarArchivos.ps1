<#
.SYNOPSIS
    Script de organización y clasificación automática de archivos con respaldo.
    
.DESCRIPTION
    Este script organiza archivos en carpetas del usuario (Escritorio, Descargas, 
    Documentos, Imágenes, Música, Videos) clasificándolos por tipo y creando 
    respaldos categorizados antes de cualquier limpieza.
    
.PARAMETER RutaRespaldo
    Ruta donde se guardarán los respaldos. Por defecto: $env:USERPROFILE\Respaldos
    
.PARAMETER SoloSimular
    Si se especifica, solo muestra qué se haría sin realizar cambios.
    
.EXAMPLE
    .\01-OrganizarArchivos.ps1
    Ejecuta la organización con configuración por defecto.
    
.EXAMPLE
    .\01-OrganizarArchivos.ps1 -RutaRespaldo "E:\MisRespaldos" -SoloSimular
    Simula la organización usando ruta de respaldo personalizada.
    
.NOTES
    Autor: Suite de Mantenimiento Windows
    Versión: 1.0
    Requiere: PowerShell 5.1 o superior
    Ejecución recomendada: Programador de Tareas (semanal)
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$RutaRespaldo = "$env:USERPROFILE\Respaldos",
    
    [Parameter()]
    [switch]$SoloSimular
)

#region Configuración
$ErrorActionPreference = "Continue"
$FechaEjecucion = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$ArchivoLog = "$RutaRespaldo\Logs\OrganizacionArchivos_$FechaEjecucion.log"

# Carpetas a organizar
$CarpetasUsuario = @{
    "Escritorio"  = [Environment]::GetFolderPath("Desktop")
    "Descargas"   = (New-Object -ComObject Shell.Application).NameSpace('shell:Downloads').Self.Path
    "Documentos"  = [Environment]::GetFolderPath("MyDocuments")
    "Imagenes"    = [Environment]::GetFolderPath("MyPictures")
    "Musica"      = [Environment]::GetFolderPath("MyMusic")
    "Videos"      = [Environment]::GetFolderPath("MyVideos")
}

# Clasificación de extensiones por categoría
$ClasificacionExtensiones = @{
    "Documentos"    = @(".doc", ".docx", ".pdf", ".txt", ".rtf", ".odt", ".xls", ".xlsx", ".ppt", ".pptx", ".csv", ".md")
    "Imagenes"      = @(".jpg", ".jpeg", ".png", ".gif", ".bmp", ".svg", ".webp", ".ico", ".tiff", ".raw", ".psd")
    "Videos"        = @(".mp4", ".avi", ".mkv", ".mov", ".wmv", ".flv", ".webm", ".m4v", ".mpeg", ".mpg")
    "Musica"        = @(".mp3", ".wav", ".flac", ".aac", ".ogg", ".wma", ".m4a", ".aiff")
    "Comprimidos"   = @(".zip", ".rar", ".7z", ".tar", ".gz", ".bz2", ".xz")
    "Ejecutables"   = @(".exe", ".msi", ".bat", ".cmd", ".ps1", ".vbs", ".jar")
    "Codigo"        = @(".js", ".py", ".java", ".cs", ".cpp", ".c", ".h", ".html", ".css", ".json", ".xml", ".sql", ".php", ".rb")
    "Otros"         = @()
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
    
    # Crear directorio de logs si no existe
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

function Get-CategoriaArchivo {
    param([string]$Extension)
    
    $Extension = $Extension.ToLower()
    
    foreach ($Categoria in $ClasificacionExtensiones.Keys) {
        if ($ClasificacionExtensiones[$Categoria] -contains $Extension) {
            return $Categoria
        }
    }
    
    return "Otros"
}

function Backup-Archivos {
    param(
        [string]$CarpetaOrigen,
        [string]$NombreCarpeta
    )
    
    $CarpetaRespaldo = Join-Path $RutaRespaldo "$FechaEjecucion\$NombreCarpeta"
    
    Write-Log "Iniciando respaldo de '$NombreCarpeta' hacia '$CarpetaRespaldo'"
    
    if (-not (Test-Path $CarpetaOrigen)) {
        Write-Log "La carpeta '$CarpetaOrigen' no existe. Omitiendo." -Nivel "WARN"
        return @{
            Exito = $false
            ArchivosRespaldados = 0
            TamanoTotal = 0
        }
    }
    
    $Archivos = Get-ChildItem -Path $CarpetaOrigen -File -ErrorAction SilentlyContinue
    
    if ($Archivos.Count -eq 0) {
        Write-Log "No hay archivos en '$NombreCarpeta' para respaldar." -Nivel "INFO"
        return @{
            Exito = $true
            ArchivosRespaldados = 0
            TamanoTotal = 0
        }
    }
    
    $ArchivosRespaldados = 0
    $TamanoTotal = 0
    
    foreach ($Archivo in $Archivos) {
        $Categoria = Get-CategoriaArchivo -Extension $Archivo.Extension
        $CarpetaDestino = Join-Path $CarpetaRespaldo $Categoria
        
        if (-not $SoloSimular) {
            if (-not (Test-Path $CarpetaDestino)) {
                New-Item -ItemType Directory -Path $CarpetaDestino -Force | Out-Null
            }
            
            try {
                Copy-Item -Path $Archivo.FullName -Destination $CarpetaDestino -Force
                $ArchivosRespaldados++
                $TamanoTotal += $Archivo.Length
                Write-Log "Respaldado: $($Archivo.Name) -> $Categoria" -Nivel "SUCCESS"
            }
            catch {
                Write-Log "Error al respaldar '$($Archivo.Name)': $($_.Exception.Message)" -Nivel "ERROR"
            }
        }
        else {
            Write-Log "[SIMULACIÓN] Respaldaría: $($Archivo.Name) -> $Categoria" -Nivel "INFO"
            $ArchivosRespaldados++
            $TamanoTotal += $Archivo.Length
        }
    }
    
    return @{
        Exito = $true
        ArchivosRespaldados = $ArchivosRespaldados
        TamanoTotal = $TamanoTotal
    }
}

function Organizar-Carpeta {
    param(
        [string]$CarpetaOrigen,
        [string]$NombreCarpeta
    )
    
    Write-Log "Organizando archivos en '$NombreCarpeta'..."
    
    if (-not (Test-Path $CarpetaOrigen)) {
        Write-Log "La carpeta '$CarpetaOrigen' no existe. Omitiendo." -Nivel "WARN"
        return @{
            ArchivosOrganizados = 0
            CarpetasCreadas = @()
        }
    }
    
    $Archivos = Get-ChildItem -Path $CarpetaOrigen -File -ErrorAction SilentlyContinue
    $ArchivosOrganizados = 0
    $CarpetasCreadas = @()
    
    foreach ($Archivo in $Archivos) {
        $Categoria = Get-CategoriaArchivo -Extension $Archivo.Extension
        $CarpetaDestino = Join-Path $CarpetaOrigen "Organizado_$Categoria"
        
        if (-not $SoloSimular) {
            if (-not (Test-Path $CarpetaDestino)) {
                New-Item -ItemType Directory -Path $CarpetaDestino -Force | Out-Null
                if ($CarpetaDestino -notin $CarpetasCreadas) {
                    $CarpetasCreadas += $CarpetaDestino
                }
            }
            
            try {
                $NuevoNombre = $Archivo.Name
                $DestinoCompleto = Join-Path $CarpetaDestino $NuevoNombre
                
                # Si existe, agregar timestamp
                if (Test-Path $DestinoCompleto) {
                    $BaseName = [System.IO.Path]::GetFileNameWithoutExtension($Archivo.Name)
                    $Extension = $Archivo.Extension
                    $NuevoNombre = "${BaseName}_$FechaEjecucion$Extension"
                    $DestinoCompleto = Join-Path $CarpetaDestino $NuevoNombre
                }
                
                Move-Item -Path $Archivo.FullName -Destination $DestinoCompleto -Force
                $ArchivosOrganizados++
                Write-Log "Organizado: $($Archivo.Name) -> Organizado_$Categoria" -Nivel "SUCCESS"
            }
            catch {
                Write-Log "Error al organizar '$($Archivo.Name)': $($_.Exception.Message)" -Nivel "ERROR"
            }
        }
        else {
            Write-Log "[SIMULACIÓN] Organizaría: $($Archivo.Name) -> Organizado_$Categoria" -Nivel "INFO"
            $ArchivosOrganizados++
        }
    }
    
    return @{
        ArchivosOrganizados = $ArchivosOrganizados
        CarpetasCreadas = $CarpetasCreadas
    }
}

function Format-Tamano {
    param([long]$Bytes)
    
    if ($Bytes -ge 1GB) { return "{0:N2} GB" -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return "{0:N2} MB" -f ($Bytes / 1MB) }
    if ($Bytes -ge 1KB) { return "{0:N2} KB" -f ($Bytes / 1KB) }
    return "$Bytes Bytes"
}
#endregion

#region Ejecución Principal
Write-Log "====== INICIO DE ORGANIZACIÓN DE ARCHIVOS ======" -Nivel "INFO"
Write-Log "Fecha de ejecución: $FechaEjecucion"
Write-Log "Ruta de respaldo: $RutaRespaldo"
Write-Log "Modo simulación: $SoloSimular"

$ResumenTotal = @{
    TotalArchivosRespaldados = 0
    TotalArchivosOrganizados = 0
    TamanoTotalRespaldado = 0
    CarpetasProcesadas = @()
}

foreach ($NombreCarpeta in $CarpetasUsuario.Keys) {
    $RutaCarpeta = $CarpetasUsuario[$NombreCarpeta]
    
    Write-Log "---------- Procesando: $NombreCarpeta ----------"
    
    # Primero respaldar
    $ResultadoRespaldo = Backup-Archivos -CarpetaOrigen $RutaCarpeta -NombreCarpeta $NombreCarpeta
    $ResumenTotal.TotalArchivosRespaldados += $ResultadoRespaldo.ArchivosRespaldados
    $ResumenTotal.TamanoTotalRespaldado += $ResultadoRespaldo.TamanoTotal
    
    # Luego organizar
    $ResultadoOrganizacion = Organizar-Carpeta -CarpetaOrigen $RutaCarpeta -NombreCarpeta $NombreCarpeta
    $ResumenTotal.TotalArchivosOrganizados += $ResultadoOrganizacion.ArchivosOrganizados
    
    $ResumenTotal.CarpetasProcesadas += $NombreCarpeta
}

Write-Log "====== RESUMEN DE ORGANIZACIÓN ======"
Write-Log "Carpetas procesadas: $($ResumenTotal.CarpetasProcesadas -join ', ')"
Write-Log "Total archivos respaldados: $($ResumenTotal.TotalArchivosRespaldados)"
Write-Log "Total archivos organizados: $($ResumenTotal.TotalArchivosOrganizados)"
Write-Log "Tamaño total respaldado: $(Format-Tamano $ResumenTotal.TamanoTotalRespaldado)"
Write-Log "Archivo de log: $ArchivoLog"
Write-Log "====== FIN DE ORGANIZACIÓN DE ARCHIVOS ======" -Nivel "SUCCESS"

# Exportar resumen para uso por otros scripts
$ResumenTotal | Export-Clixml -Path "$RutaRespaldo\Logs\UltimoResumen_Organizacion.xml" -Force

return $ResumenTotal
#endregion
