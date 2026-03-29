# Normas para los Agentes en Better Control

## 1. Sincronización Automática con WoW
Cada vez que se realice un cambio en cualquier archivo del addon (Core, Modules, TOC, etc.), el agente **debe** refrescar (copiar) la carpeta del addon en la instalación de World of Warcraft correspondiente.

### Procedimiento:
1. Detectar el cambio.
2. Identificar la ruta de instalación de WoW.
3. Copiar el contenido de este repositorio a `World of Warcraft\_retail_\Interface\AddOns\BetterControl`.
4. (Opcional) Informar al usuario para que use el comando `/rl` (ya añadido al addon).

### Ruta Automatizada (Windows):
Si no se especifica lo contrario, la ruta por defecto será la detectada en el sistema o proporcionada por el usuario.
