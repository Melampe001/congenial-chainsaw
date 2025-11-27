<#
.SYNOPSIS
    Script de limpieza avanzada del sistema Windows.
    
.DESCRIPTION
    Este script realiza una limpieza profunda del sistema Windows incluyendo:
    - Archivos temporales del usuario
    - Archivos temporales del sistema
    - Carpeta Prefetch
    - Caché de navegadores (opcional)
    - Limpieza con cleanmgr (Liberador de espacio en disco)
    - Papelera de reciclaje (opcional)
    
.PARAMETER LimpiarNavegadores
    Si se especifica, también limpia la caché de navegadores comunes.
    
.PARAMETER VaciarPapelera
    Si se especifica, vacía la papelera de reciclaje.
    
.PARAMETER SoloSimular
    Si se especifica, solo muestra qué se haría sin realizar cambios.
    
.PARAMETER RutaLog
    Ruta donde se guardarán los logs. Por defecto: $env:USERPROFILE\Respaldos\Logs
    
.EXAMPLE
    .\03-LimpiezaSistema.ps1
    Ejecuta limpieza básica del sistema.
    
.EXAMPLE
    .\03-LimpiezaSistema.ps1 -LimpiarNavegadores -VaciarPapelera
    Ejecuta limpieza completa incluyendo navegadores y papelera.
    
.EXAMPLE
    .\03-LimpiezaSistema.ps1 -SoloSimular
    Simula la limpieza sin realizar cambios.
    
.NOTES
    Autor: Suite de Mantenimiento Windows
    Versión: 1.0
    Requiere: PowerShell 5.1 o superior, privilegios de administrador para limpieza completa
    Ejecución recomendada: Programador de Tareas (semanal, como administrador)
#>

[CmdletBinding()]
param(
    [Parameter()]
    [switch]$LimpiarNavegadores,
    
    [Parameter()]
    [switch]$VaciarPapelera,
    
    [Parameter()]
    [switch]$SoloSimular,
    
    [Parameter()]
    [string]$RutaLog = "$env:USERPROFILE\Respaldos\Logs"
)

#region Configuración
$ErrorActionPreference = "Continue"
$FechaEjecucion = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$ArchivoLog = "$RutaLog\LimpiezaSistema_$FechaEjecucion.log"

# Verificar privilegios de administrador
$EsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# Rutas de archivos temporales
$RutasTemporales = @{
    "TempUsuario"       = $env:TEMP
    "TempUsuarioAlt"    = "$env:USERPROFILE\AppData\Local\Temp"
    "TempWindows"       = "$env:SystemRoot\Temp"
    "Prefetch"          = "$env:SystemRoot\Prefetch"
    "CacheWindows"      = "$env:LOCALAPPDATA\Microsoft\Windows\INetCache"
    "ThumbnailCache"    = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
}

# Rutas de caché de navegadores
$RutasNavegadores = @{
    "Chrome"        = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache"
    "ChromeCode"    = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Code Cache"
    "Firefox"       = "$env:LOCALAPPDATA\Mozilla\Firefox\Profiles"
    "Edge"          = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache"
    "EdgeCode"      = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Code Cache"
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

function Format-Tamano {
    param([long]$Bytes)
    
    if ($Bytes -ge 1GB) { return "{0:N2} GB" -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return "{0:N2} MB" -f ($Bytes / 1MB) }
    if ($Bytes -ge 1KB) { return "{0:N2} KB" -f ($Bytes / 1KB) }
    return "$Bytes Bytes"
}

function Get-TamanoCarpeta {
    param([string]$Ruta)
    
    if (-not (Test-Path $Ruta)) { return 0 }
    
    try {
        $Tamano = (Get-ChildItem -Path $Ruta -Recurse -File -ErrorAction SilentlyContinue | 
                   Measure-Object -Property Length -Sum).Sum
        return [long]$Tamano
    }
    catch {
        return 0
    }
}

function Limpiar-Carpeta {
    param(
        [string]$Ruta,
        [string]$Nombre,
        [int]$DiasAntiguedad = 0
    )
    
    if (-not (Test-Path $Ruta)) {
        Write-Log "La carpeta '$Nombre' no existe: $Ruta" -Nivel "WARN"
        return @{
            ArchivosEliminados = 0
            EspacioLiberado = 0
            Errores = 0
        }
    }
    
    Write-Log "Limpiando '$Nombre': $Ruta"
    
    $TamanoAntes = Get-TamanoCarpeta $Ruta
    $ArchivosEliminados = 0
    $Errores = 0
    
    try {
        $Archivos = Get-ChildItem -Path $Ruta -Recurse -File -ErrorAction SilentlyContinue
        
        if ($DiasAntiguedad -gt 0) {
            $FechaLimite = (Get-Date).AddDays(-$DiasAntiguedad)
            $Archivos = $Archivos | Where-Object { $_.LastWriteTime -lt $FechaLimite }
        }
        
        foreach ($Archivo in $Archivos) {
            if (-not $SoloSimular) {
                try {
                    Remove-Item -Path $Archivo.FullName -Force -ErrorAction Stop
                    $ArchivosEliminados++
                }
                catch {
                    $Errores++
                    # No loguear cada error individual para evitar spam
                }
            }
            else {
                Write-Log "[SIMULACIÓN] Eliminaría: $($Archivo.Name)" -Nivel "INFO"
                $ArchivosEliminados++
            }
        }
        
        # Intentar eliminar carpetas vacías
        if (-not $SoloSimular) {
            Get-ChildItem -Path $Ruta -Recurse -Directory -ErrorAction SilentlyContinue |
                Sort-Object { $_.FullName.Length } -Descending |
                ForEach-Object {
                    if ((Get-ChildItem -Path $_.FullName -Force -ErrorAction SilentlyContinue).Count -eq 0) {
                        Remove-Item -Path $_.FullName -Force -ErrorAction SilentlyContinue
                    }
                }
        }
    }
    catch {
        Write-Log "Error procesando '$Nombre': $($_.Exception.Message)" -Nivel "ERROR"
        $Errores++
    }
    
    $TamanoDespues = Get-TamanoCarpeta $Ruta
    $EspacioLiberado = $TamanoAntes - $TamanoDespues
    
    if ($EspacioLiberado -lt 0) { $EspacioLiberado = 0 }
    
    Write-Log "$Nombre: $ArchivosEliminados archivos eliminados, $(Format-Tamano $EspacioLiberado) liberados" -Nivel "SUCCESS"
    
    return @{
        ArchivosEliminados = $ArchivosEliminados
        EspacioLiberado = $EspacioLiberado
        Errores = $Errores
    }
}

function Ejecutar-CleanMgr {
    Write-Log "Iniciando Liberador de espacio en disco (cleanmgr)..."
    
    if ($SoloSimular) {
        Write-Log "[SIMULACIÓN] Ejecutaría cleanmgr /d C: /sagerun:1" -Nivel "INFO"
        return $true
    }
    
    try {
        # Configurar limpieza automática (sageset)
        # Nota: Esto normalmente requiere interacción, usamos perfil predefinido
        $Proceso = Start-Process -FilePath "cleanmgr.exe" -ArgumentList "/d", "C:", "/verylowdisk" -Wait -PassThru -NoNewWindow
        
        if ($Proceso.ExitCode -eq 0) {
            Write-Log "cleanmgr completado exitosamente" -Nivel "SUCCESS"
            return $true
        }
        else {
            Write-Log "cleanmgr terminó con código: $($Proceso.ExitCode)" -Nivel "WARN"
            return $false
        }
    }
    catch {
        Write-Log "Error ejecutando cleanmgr: $($_.Exception.Message)" -Nivel "ERROR"
        return $false
    }
}

function Limpiar-CacheNavegadores {
    Write-Log "---------- Limpiando caché de navegadores ----------"
    
    $TotalLiberado = 0
    $TotalArchivos = 0
    
    foreach ($Navegador in $RutasNavegadores.Keys) {
        $Ruta = $RutasNavegadores[$Navegador]
        
        if ($Navegador -eq "Firefox") {
            # Firefox tiene estructura diferente con perfiles
            if (Test-Path $Ruta) {
                $Perfiles = Get-ChildItem -Path $Ruta -Directory -ErrorAction SilentlyContinue
                foreach ($Perfil in $Perfiles) {
                    $CacheFirefox = Join-Path $Perfil.FullName "cache2"
                    if (Test-Path $CacheFirefox) {
                        $Resultado = Limpiar-Carpeta -Ruta $CacheFirefox -Nombre "Firefox ($($Perfil.Name))"
                        $TotalLiberado += $Resultado.EspacioLiberado
                        $TotalArchivos += $Resultado.ArchivosEliminados
                    }
                }
            }
        }
        else {
            if (Test-Path $Ruta) {
                $Resultado = Limpiar-Carpeta -Ruta $Ruta -Nombre $Navegador
                $TotalLiberado += $Resultado.EspacioLiberado
                $TotalArchivos += $Resultado.ArchivosEliminados
            }
        }
    }
    
    return @{
        EspacioLiberado = $TotalLiberado
        ArchivosEliminados = $TotalArchivos
    }
}

function Vaciar-Papelera {
    Write-Log "Vaciando papelera de reciclaje..."
    
    if ($SoloSimular) {
        Write-Log "[SIMULACIÓN] Vaciaría la papelera de reciclaje" -Nivel "INFO"
        return @{ Exito = $true; EspacioLiberado = 0 }
    }
    
    try {
        # Obtener tamaño de papelera antes
        $Shell = New-Object -ComObject Shell.Application
        $Papelera = $Shell.NameSpace(0x0A)
        $ItemsPapelera = $Papelera.Items()
        $TamanoAntes = ($ItemsPapelera | ForEach-Object { $_.Size } | Measure-Object -Sum).Sum
        
        # Vaciar papelera
        Clear-RecycleBin -Force -ErrorAction SilentlyContinue
        
        Write-Log "Papelera vaciada. Espacio liberado: $(Format-Tamano $TamanoAntes)" -Nivel "SUCCESS"
        
        return @{
            Exito = $true
            EspacioLiberado = $TamanoAntes
        }
    }
    catch {
        Write-Log "Error vaciando papelera: $($_.Exception.Message)" -Nivel "ERROR"
        return @{
            Exito = $false
            EspacioLiberado = 0
        }
    }
}

function Get-EspacioDiscosAntes {
    $Discos = @{}
    Get-PSDrive -PSProvider FileSystem | ForEach-Object {
        $Discos[$_.Name] = $_.Free
    }
    return $Discos
}
#endregion

#region Ejecución Principal
Write-Log "====== INICIO DE LIMPIEZA DE SISTEMA ======" -Nivel "INFO"
Write-Log "Fecha de ejecución: $FechaEjecucion"
Write-Log "Ejecutando como administrador: $EsAdmin"
Write-Log "Limpiar navegadores: $LimpiarNavegadores"
Write-Log "Vaciar papelera: $VaciarPapelera"
Write-Log "Modo simulación: $SoloSimular"

if (-not $EsAdmin) {
    Write-Log "ADVERTENCIA: No se está ejecutando como administrador. Algunas limpiezas pueden fallar." -Nivel "WARN"
}

# Registrar espacio antes
$EspacioAntes = Get-EspacioDiscosAntes

$ResumenTotal = @{
    TotalArchivosEliminados = 0
    TotalEspacioLiberado = 0
    TotalErrores = 0
    AreasLimpiadas = @()
}

# Limpieza de temporales del usuario
Write-Log "---------- Limpiando archivos temporales del usuario ----------"
foreach ($Nombre in @("TempUsuario", "TempUsuarioAlt", "CacheWindows", "ThumbnailCache")) {
    if ($RutasTemporales.ContainsKey($Nombre)) {
        $Resultado = Limpiar-Carpeta -Ruta $RutasTemporales[$Nombre] -Nombre $Nombre -DiasAntiguedad 1
        $ResumenTotal.TotalArchivosEliminados += $Resultado.ArchivosEliminados
        $ResumenTotal.TotalEspacioLiberado += $Resultado.EspacioLiberado
        $ResumenTotal.TotalErrores += $Resultado.Errores
        $ResumenTotal.AreasLimpiadas += $Nombre
    }
}

# Limpieza de temporales del sistema (requiere admin)
if ($EsAdmin) {
    Write-Log "---------- Limpiando archivos temporales del sistema ----------"
    foreach ($Nombre in @("TempWindows", "Prefetch")) {
        if ($RutasTemporales.ContainsKey($Nombre)) {
            $Resultado = Limpiar-Carpeta -Ruta $RutasTemporales[$Nombre] -Nombre $Nombre
            $ResumenTotal.TotalArchivosEliminados += $Resultado.ArchivosEliminados
            $ResumenTotal.TotalEspacioLiberado += $Resultado.EspacioLiberado
            $ResumenTotal.TotalErrores += $Resultado.Errores
            $ResumenTotal.AreasLimpiadas += $Nombre
        }
    }
}
else {
    Write-Log "Omitiendo limpieza de sistema (requiere administrador)" -Nivel "WARN"
}

# Limpieza de navegadores
if ($LimpiarNavegadores) {
    $ResultadoNavegadores = Limpiar-CacheNavegadores
    $ResumenTotal.TotalArchivosEliminados += $ResultadoNavegadores.ArchivosEliminados
    $ResumenTotal.TotalEspacioLiberado += $ResultadoNavegadores.EspacioLiberado
    $ResumenTotal.AreasLimpiadas += "CacheNavegadores"
}

# Vaciar papelera
if ($VaciarPapelera) {
    $ResultadoPapelera = Vaciar-Papelera
    $ResumenTotal.TotalEspacioLiberado += $ResultadoPapelera.EspacioLiberado
    $ResumenTotal.AreasLimpiadas += "Papelera"
}

# Ejecutar cleanmgr
Write-Log "---------- Ejecutando Liberador de espacio en disco ----------"
$CleanMgrExito = Ejecutar-CleanMgr
if ($CleanMgrExito) {
    $ResumenTotal.AreasLimpiadas += "CleanMgr"
}

# Calcular espacio total liberado comparando con estado inicial
$EspacioDespues = Get-EspacioDiscosAntes
$EspacioTotalLiberado = 0
foreach ($Disco in $EspacioDespues.Keys) {
    if ($EspacioAntes.ContainsKey($Disco)) {
        $Diferencia = $EspacioDespues[$Disco] - $EspacioAntes[$Disco]
        if ($Diferencia -gt 0) {
            $EspacioTotalLiberado += $Diferencia
        }
    }
}

# Usar el máximo entre lo calculado incrementalmente y la diferencia real
if ($EspacioTotalLiberado -gt $ResumenTotal.TotalEspacioLiberado) {
    $ResumenTotal.TotalEspacioLiberado = $EspacioTotalLiberado
}

Write-Log "====== RESUMEN DE LIMPIEZA ======"
Write-Log "Áreas limpiadas: $($ResumenTotal.AreasLimpiadas -join ', ')"
Write-Log "Total archivos eliminados: $($ResumenTotal.TotalArchivosEliminados)"
Write-Log "Total espacio liberado: $(Format-Tamano $ResumenTotal.TotalEspacioLiberado)"
Write-Log "Total errores: $($ResumenTotal.TotalErrores)"
Write-Log "Archivo de log: $ArchivoLog"
Write-Log "====== FIN DE LIMPIEZA DE SISTEMA ======" -Nivel "SUCCESS"

# Exportar resumen para uso por otros scripts
$ResumenTotal | Export-Clixml -Path "$RutaLog\UltimoResumen_Limpieza.xml" -Force

return $ResumenTotal
#endregion
