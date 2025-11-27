# 🛠️ Suite de Mantenimiento y Automatización para Windows

Suite completa de scripts PowerShell para el mantenimiento automatizado de sistemas Windows. Incluye organización de archivos, backups, limpieza del sistema, escaneo antivirus y configuración de biometría.

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue.svg)](https://docs.microsoft.com/en-us/powershell/)
[![Windows](https://img.shields.io/badge/Windows-10%2F11-0078D6.svg)](https://www.microsoft.com/windows)
[![License](https://img.shields.io/badge/License-BSL--1.0-green.svg)](LICENSE)

## 📋 Tabla de Contenidos

- [Características](#-características)
- [Requisitos](#-requisitos)
- [Instalación](#-instalación)
- [Scripts Disponibles](#-scripts-disponibles)
- [Uso Rápido](#-uso-rápido)
- [Configuración del Programador de Tareas](#-configuración-del-programador-de-tareas)
- [Estructura de Archivos](#-estructura-de-archivos)
- [Compatibilidad con Servicios de Nube](#-compatibilidad-con-servicios-de-nube)
- [Buenas Prácticas](#-buenas-prácticas)
- [Solución de Problemas](#-solución-de-problemas)
- [Licencia](#-licencia)

## ✨ Características

- **📁 Organización Automática de Archivos**: Clasifica y organiza archivos en Escritorio, Descargas, Documentos, Imágenes, Música y Videos con respaldo previo.
- **☁️ Backup a Nube Privada**: Copia estructurada compatible con Tresorit, Proton Drive, Nextcloud, Syncthing, etc.
- **🧹 Limpieza Avanzada del Sistema**: Elimina temporales, prefetch, caché de navegadores y ejecuta cleanmgr.
- **🛡️ Escaneo Antivirus**: Integración con Windows Defender para escaneos rápidos, completos o personalizados.
- **📊 Reportes Detallados**: Genera reportes en pantalla y archivos .txt con todas las acciones realizadas.
- **🔐 Biometría y Reconocimiento**: Configuración de cámara, micrófono, Windows Hello y reconocimiento de voz.

## 📦 Requisitos

### Mínimos
- Windows 10 (versión 1903 o superior) / Windows 11
- PowerShell 5.1 o superior
- 50 MB de espacio libre para logs y reportes

### Recomendados
- PowerShell 7.x para mejor rendimiento
- Privilegios de administrador para limpieza completa
- Windows Defender habilitado para escaneos antivirus
- Dispositivos biométricos compatibles con Windows Hello (opcional)

## 🚀 Instalación

### Opción 1: Clonar el repositorio
```powershell
git clone https://github.com/Melampe001/congenial-chainsaw.git
cd congenial-chainsaw/scripts
```

### Opción 2: Descarga directa
1. Descargue el repositorio como ZIP
2. Extraiga en una ubicación de su preferencia (ej: `C:\Scripts\Mantenimiento`)
3. Desbloquee los scripts si es necesario:
```powershell
Get-ChildItem -Path "C:\Scripts\Mantenimiento\scripts" -Filter "*.ps1" | Unblock-File
```

### Configurar política de ejecución
```powershell
# Como administrador
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

## 📜 Scripts Disponibles

### 1. 📁 01-OrganizarArchivos.ps1
Organiza y clasifica archivos automáticamente con respaldo previo.

```powershell
# Uso básico
.\01-OrganizarArchivos.ps1

# Con ruta de respaldo personalizada
.\01-OrganizarArchivos.ps1 -RutaRespaldo "E:\MisRespaldos"

# Solo simular (no realiza cambios)
.\01-OrganizarArchivos.ps1 -SoloSimular
```

**Categorías de clasificación:**
| Categoría | Extensiones |
|-----------|-------------|
| Documentos | .doc, .docx, .pdf, .txt, .rtf, .odt, .xls, .xlsx, .ppt, .pptx, .csv, .md |
| Imágenes | .jpg, .jpeg, .png, .gif, .bmp, .svg, .webp, .ico, .tiff, .raw, .psd |
| Videos | .mp4, .avi, .mkv, .mov, .wmv, .flv, .webm, .m4v, .mpeg, .mpg |
| Música | .mp3, .wav, .flac, .aac, .ogg, .wma, .m4a, .aiff |
| Comprimidos | .zip, .rar, .7z, .tar, .gz, .bz2, .xz |
| Ejecutables | .exe, .msi, .bat, .cmd, .ps1, .vbs, .jar |
| Código | .js, .py, .java, .cs, .cpp, .c, .h, .html, .css, .json, .xml, .sql, .php, .rb |

### 2. ☁️ 02-BackupNube.ps1
Crea backups estructurados para sincronización con servicios de nube privada.

```powershell
# Uso básico (destino por defecto: D:\NubePrivada\Backup)
.\02-BackupNube.ps1

# Con destino personalizado
.\02-BackupNube.ps1 -RutaDestino "E:\MiNube\Backup"

# Incluir carpetas adicionales
.\02-BackupNube.ps1 -IncluirCarpetas "C:\Proyectos","D:\Trabajo"
```

**Estructura del backup:**
```
D:\NubePrivada\Backup\
└── 2024-01-15\
    ├── MANIFIESTO_BACKUP.txt
    ├── Respaldos_Organizacion\
    │   ├── Documentos\
    │   ├── Imagenes\
    │   └── ...
    └── Usuario\
        ├── Documentos\
        ├── Imagenes\
        └── Escritorio\
```

### 3. 🧹 03-LimpiezaSistema.ps1
Realiza limpieza profunda del sistema Windows.

```powershell
# Limpieza básica
.\03-LimpiezaSistema.ps1

# Limpieza completa (incluye navegadores y papelera)
.\03-LimpiezaSistema.ps1 -LimpiarNavegadores -VaciarPapelera

# Solo simular
.\03-LimpiezaSistema.ps1 -SoloSimular
```

**Áreas que limpia:**
- Archivos temporales del usuario (`%TEMP%`)
- Archivos temporales del sistema (`%SystemRoot%\Temp`)
- Carpeta Prefetch (requiere admin)
- Caché de Windows
- Caché de miniaturas
- Caché de navegadores (Chrome, Firefox, Edge) - opcional
- Papelera de reciclaje - opcional
- Ejecuta cleanmgr (Liberador de espacio en disco)

### 4. 🛡️ 04-EscaneoAntivirus.ps1
Ejecuta escaneos con Windows Defender.

```powershell
# Escaneo rápido (por defecto)
.\04-EscaneoAntivirus.ps1

# Escaneo completo
.\04-EscaneoAntivirus.ps1 -TipoEscaneo Completo

# Escaneo personalizado con actualización de definiciones
.\04-EscaneoAntivirus.ps1 -TipoEscaneo Personalizado -RutasPersonalizadas "C:\Descargas","D:\Software" -ActualizarDefiniciones
```

**Tipos de escaneo:**
| Tipo | Descripción | Duración estimada |
|------|-------------|-------------------|
| Rápido | Áreas críticas del sistema | 5-15 minutos |
| Completo | Todo el sistema | 1-4 horas |
| Personalizado | Rutas específicas | Variable |

### 5. 📊 05-GenerarReporte.ps1
Genera un reporte completo de todas las operaciones de mantenimiento.

```powershell
# Generar reporte
.\05-GenerarReporte.ps1

# Generar y abrir automáticamente
.\05-GenerarReporte.ps1 -AbrirReporte
```

**Contenido del reporte:**
- Información del sistema (OS, CPU, RAM, discos)
- Estado de espacio en disco
- Resumen de organización de archivos
- Resumen de backup
- Resumen de limpieza
- Estado de escaneo antivirus y amenazas
- Logs generados
- Recomendaciones

### 6. 🔐 06-BiometriaYReconocimiento.ps1
Configura dispositivos biométricos y reconocimiento de voz.

```powershell
# Verificar estado de dispositivos
.\06-BiometriaYReconocimiento.ps1 -VerificarSolamente

# Habilitar reconocimiento de voz
.\06-BiometriaYReconocimiento.ps1 -HabilitarReconocimientoVoz

# Abrir configuración de Windows Hello
.\06-BiometriaYReconocimiento.ps1 -MostrarConfiguracionHello
```

**Funcionalidades:**
- Detección y activación de cámaras
- Detección y activación de micrófonos
- Verificación de Windows Hello (facial, huella, iris)
- Configuración de reconocimiento de voz
- Habilitar permisos de privacidad para cámara/micrófono

### 🎯 ScriptMaestro.ps1
Script coordinador que ejecuta todos los scripts de mantenimiento.

```powershell
# Ejecutar TODO el mantenimiento
.\ScriptMaestro.ps1 -EjecutarTodo

# Ejecutar scripts específicos
.\ScriptMaestro.ps1 -Organizar -Limpieza -Reporte

# Ejecutar todo en modo simulación
.\ScriptMaestro.ps1 -EjecutarTodo -SoloSimular

# Con opciones avanzadas
.\ScriptMaestro.ps1 -EjecutarTodo -LimpiarNavegadores -VaciarPapelera -ActualizarDefiniciones -TipoEscaneo Completo
```

## ⚡ Uso Rápido

### Mantenimiento completo (recomendado semanalmente)
```powershell
cd C:\Scripts\Mantenimiento\scripts
.\ScriptMaestro.ps1 -EjecutarTodo
```

### Mantenimiento rápido (recomendado diariamente)
```powershell
.\ScriptMaestro.ps1 -Organizar -Antivirus -Reporte
```

### Solo limpieza profunda
```powershell
# Como administrador
.\ScriptMaestro.ps1 -Limpieza -LimpiarNavegadores -VaciarPapelera
```

## ⏰ Configuración del Programador de Tareas

### Crear tarea programada (PowerShell como administrador)

#### Mantenimiento semanal completo
```powershell
$Accion = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Bypass -File `"C:\Scripts\Mantenimiento\scripts\ScriptMaestro.ps1`" -EjecutarTodo"
$Disparador = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 3:00AM
$Configuracion = New-ScheduledTaskSettingsSet -StartWhenAvailable -DontStopIfGoingOnBatteries
$Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

Register-ScheduledTask -TaskName "MantenimientoSemanal" -Action $Accion -Trigger $Disparador -Settings $Configuracion -Principal $Principal -Description "Mantenimiento completo semanal del sistema"
```

#### Escaneo antivirus diario
```powershell
$Accion = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Bypass -File `"C:\Scripts\Mantenimiento\scripts\04-EscaneoAntivirus.ps1`" -TipoEscaneo Rapido -ActualizarDefiniciones"
$Disparador = New-ScheduledTaskTrigger -Daily -At 12:00PM

Register-ScheduledTask -TaskName "EscaneoAntivirusDiario" -Action $Accion -Trigger $Disparador -Description "Escaneo rápido diario con Windows Defender"
```

#### Backup diario a nube
```powershell
$Accion = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Bypass -File `"C:\Scripts\Mantenimiento\scripts\02-BackupNube.ps1`""
$Disparador = New-ScheduledTaskTrigger -Daily -At 8:00PM

Register-ScheduledTask -TaskName "BackupDiarioNube" -Action $Accion -Trigger $Disparador -Description "Backup diario a carpeta de nube privada"
```

### Configuración manual vía GUI

1. Abra **Programador de tareas** (`taskschd.msc`)
2. Click en **Crear tarea básica...**
3. Configure:
   - **Nombre**: Mantenimiento Windows
   - **Descripción**: Suite de mantenimiento automatizado
   - **Desencadenador**: Semanal, Domingo 3:00 AM
   - **Acción**: Iniciar un programa
   - **Programa**: `PowerShell.exe`
   - **Argumentos**: `-ExecutionPolicy Bypass -File "C:\Scripts\Mantenimiento\scripts\ScriptMaestro.ps1" -EjecutarTodo`
4. En propiedades, marque **Ejecutar con los privilegios más altos**

## 📂 Estructura de Archivos

```
congenial-chainsaw/
├── scripts/
│   ├── 01-OrganizarArchivos.ps1      # Organización de archivos
│   ├── 02-BackupNube.ps1             # Backup a nube privada
│   ├── 03-LimpiezaSistema.ps1        # Limpieza del sistema
│   ├── 04-EscaneoAntivirus.ps1       # Escaneo antivirus
│   ├── 05-GenerarReporte.ps1         # Generación de reportes
│   ├── 06-BiometriaYReconocimiento.ps1 # Biometría y voz
│   └── ScriptMaestro.ps1             # Script coordinador
├── README.md                          # Esta documentación
├── LICENSE                            # Licencia BSL-1.0
└── .gitignore                         # Archivos ignorados
```

### Estructura de salida generada

```
%USERPROFILE%\Respaldos\
├── 2024-01-15_10-30-00\              # Respaldos por fecha
│   ├── Escritorio\
│   │   ├── Documentos\
│   │   ├── Imagenes\
│   │   └── ...
│   ├── Descargas\
│   └── ...
├── Logs\
│   ├── OrganizacionArchivos_*.log
│   ├── BackupNube_*.log
│   ├── LimpiezaSistema_*.log
│   ├── EscaneoAntivirus_*.log
│   ├── BiometriaReconocimiento_*.log
│   ├── ScriptMaestro_*.log
│   └── UltimoResumen_*.xml           # Resúmenes para reportes
└── Reportes\
    └── ReporteMantenimiento_*.txt

D:\NubePrivada\Backup\                 # Carpeta de sincronización
└── 2024-01-15\
    ├── MANIFIESTO_BACKUP.txt
    ├── Respaldos_Organizacion\
    └── Usuario\
```

## ☁️ Compatibilidad con Servicios de Nube

Los backups se estructuran para ser compatibles con cualquier servicio de sincronización:

| Servicio | Ruta recomendada | Notas |
|----------|------------------|-------|
| **Tresorit** | `D:\Tresorit\Backup` | Encriptación E2E |
| **Proton Drive** | `D:\ProtonDrive\Backup` | Privacidad suiza |
| **Nextcloud** | `D:\Nextcloud\Backup` | Self-hosted |
| **Syncthing** | `D:\Syncthing\Backup` | P2P, sin servidor |
| **OneDrive** | `%USERPROFILE%\OneDrive\Backup` | Integrado en Windows |
| **Google Drive** | `G:\Mi unidad\Backup` | Con Drive para PC |
| **Dropbox** | `D:\Dropbox\Backup` | Fácil compartir |

### Configurar ruta de nube personalizada
```powershell
.\02-BackupNube.ps1 -RutaDestino "D:\MiServicioNube\Backup"
# o
.\ScriptMaestro.ps1 -EjecutarTodo -RutaNube "D:\MiServicioNube\Backup"
```

## 💡 Buenas Prácticas

### Frecuencia recomendada de ejecución

| Script | Frecuencia | Modo |
|--------|------------|------|
| Organización | Semanal | Normal |
| Backup a nube | Diario | Normal |
| Limpieza básica | Semanal | Normal |
| Limpieza completa | Mensual | Admin |
| Escaneo rápido | Diario | Normal |
| Escaneo completo | Mensual | Admin |
| Reporte | Semanal | Normal |

### Recomendaciones de seguridad

1. **Ejecute primero en modo simulación** (`-SoloSimular`) para verificar acciones
2. **Revise los logs** después de cada ejecución automática
3. **Mantenga Windows Defender actualizado** antes de escaneos
4. **Verifique el espacio en disco** antes de backups grandes
5. **Configure exclusiones** en su antivirus para la carpeta de scripts

### Optimización de recursos

```powershell
# Para equipos con recursos limitados, ejecute en horarios de baja actividad
.\ScriptMaestro.ps1 -EjecutarTodo -TipoEscaneo Rapido

# Para servidores o equipos de alto rendimiento
.\ScriptMaestro.ps1 -EjecutarTodo -TipoEscaneo Completo -LimpiarNavegadores -VaciarPapelera -ActualizarDefiniciones
```

## 🔧 Solución de Problemas

### Error: "No se puede cargar el script porque la ejecución de scripts está deshabilitada"
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Error: "Acceso denegado" en limpieza de sistema
Ejecute PowerShell como administrador:
```powershell
Start-Process PowerShell -Verb RunAs -ArgumentList "-File", "C:\Scripts\ScriptMaestro.ps1", "-Limpieza"
```

### Windows Defender no disponible
Verifique que:
1. Windows Defender esté habilitado en Configuración > Seguridad de Windows
2. No haya otro antivirus activo que lo desactive
3. El servicio `WinDefend` esté en ejecución

### Backup a nube falla
1. Verifique que la unidad de destino esté disponible
2. Compruebe el espacio disponible
3. El script intentará usar `%USERPROFILE%\NubePrivada\Backup` como alternativa

### Los logs no se generan
```powershell
# Crear directorio de logs manualmente
New-Item -ItemType Directory -Path "$env:USERPROFILE\Respaldos\Logs" -Force
```

## 📄 Licencia

Este proyecto está licenciado bajo la [Boost Software License 1.0](LICENSE).

---

**Desarrollado con ❤️ para la comunidad Windows**

¿Preguntas o sugerencias? Abra un [issue](https://github.com/Melampe001/congenial-chainsaw/issues) en el repositorio.
