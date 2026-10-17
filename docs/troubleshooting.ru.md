# Диагностика развёртывания 7-Zip

| Симптом | Проверить |
| --- | --- |
| Задачи нет | GPO link к OU компьютеров; Security Filtering; `gpresult /scope computer /r`; `gpupdate /target:computer /force` |
| `LastTaskResult = 267011` | Задание ещё не выполнялось; не считать это кодом возврата MSI |
| `LastTaskResult = 0`, но старая версия | Сообщения `Already current` / `7-Zip running; defer upgrade`; версии `7z.exe`; MSI-лог |
| `Invalid SHA256` или `Package hash mismatch` | Манифест и реальный хеш пакета, версия MSI и право записи на репозиторий |
| MSI `1618` | Другой экземпляр Windows Installer; mutex ограничивает только собственные две задачи |
| MSI `3010` | Требуется перезагрузка; повторная проверка версии после неё |
| Разное поведение клиентов | Файлы SYSVOL/NETLOGON и их хеши на **каждом** DC; DFSR; выбор контроллера клиентом |

Пример сравнения копий скрипта на DC (имена вымышленные):

```powershell
Get-Item '\\dc01.ad.example.com\NETLOGON\Software\7Zip\Scripts\Install-7Zip.ps1',
         '\\dc02.ad.example.com\NETLOGON\Software\7Zip\Scripts\Install-7Zip.ps1' |
  Select-Object FullName,Length,LastWriteTime

Get-FileHash '\\dc01.ad.example.com\NETLOGON\Software\7Zip\Scripts\Install-7Zip.ps1' -Algorithm SHA256
Get-FileHash '\\dc02.ad.example.com\NETLOGON\Software\7Zip\Scripts\Install-7Zip.ps1' -Algorithm SHA256
```

`repadmin /replsummary` сообщает о состоянии репликации AD. Файловую репликацию DFSR/SYSVOL **проверяют отдельно**; одинаковые метаданные AD не доказывают совпадение файлов.
