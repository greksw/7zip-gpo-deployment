# Развёртывание 7-Zip через GPO: проверяемый план

## Подготовка

1. В отдельной тестовой OU разместите рабочие станции; для RDS используйте **отдельное правило**, а не общую задачу, запускающую MSI при наличии пользователей.
2. Разместите доверенные MSI x64/x86 и `manifest.json` в защищённом репозитории с правом **чтения для учётных записей компьютеров** и строго ограниченной записью.
3. Посчитайте SHA256 по самим MSI, внесите правильные имена файлов и проверенные хеши в манифест. Публичный пример не содержит рабочих хешей.
4. Настройте GPP Scheduled Task от `NT AUTHORITY\SYSTEM`, с наивысшими привилегиями. Две задачи `Install-Now` и `AutoUpdate` могут вызывать **один и тот же** установщик. Для RDS используйте `Install-7Zip-RDS.ps1`.
5. Протестируйте дневное окно, отложенный запуск, запуск на выключавшихся ПК, сценарий занятого 7-Zip, перезапуск после ошибки и отложенную перезагрузку `3010`.

```text
Computer Configuration
  > Preferences
    > Control Panel Settings
      > Scheduled Tasks
```

Команда запуска на рабочей станции (пример, адаптируйте UNC-путь):

```text
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "\\ad.example.com\NETLOGON\Software\7Zip\Scripts\Install-7Zip.ps1"
```

Пилотное расписание: 03:00 ежедневно с разбросом до часа. Включите догоняющий запуск после пропуска по результатам тестирования. `ExecutionPolicy Bypass` сам по себе не является проверкой безопасности скрипта.

## Проверка клиента

```powershell
gpupdate /target:computer /force
gpresult /scope computer /r
Get-ScheduledTask -TaskName 'Example-7Zip-AutoUpdate' -ErrorAction SilentlyContinue
Get-ScheduledTaskInfo -TaskName 'Example-7Zip-AutoUpdate' -ErrorAction SilentlyContinue
Get-Item "$env:ProgramFiles\7-Zip\7z.exe" -ErrorAction SilentlyContinue |
  Select-Object FullName,@{N='Version';E={$_.VersionInfo.ProductVersion}}
```

Журналы: `deploy.log`, `msi.log`, на RDS `rds-deploy.log` в каталоге `$env:ProgramData\Example\7Zip` (в оригинальной системе иные пути). Task Scheduler `LastTaskResult = 0` может означать **отложенную** установку, поэтому сверяйте версии и журнал.

## Ошибки и интерпретация

| Признак | Проверить |
| --- | --- |
| Нет Scheduled Task | Привязку GPO к OU компьютеров, Security Filtering, `gpresult` |
| SHA256 mismatch | Файл MSI и манифест на том DC, который обслужил запрос; актуальность SYSVOL |
| `7-Zip running; defer upgrade` | Занятые процессы; ожидание следующего запуска |
| `DEFER: user session(s)` (RDS) | Состояние Active/Disconnected и следующее окно обслуживания |
| MSI 0 | Установка завершилась; отдельно проверьте версию |
| MSI 3010 | Завершено с требованием перезагрузки; скрипт не перезагружает |
| MSI 1618 | Параллельный Windows Installer вне mutex данного проекта |
| Следы 2 версий на DC | Хеш и размер скрипта на **каждом** DC; диагностика DFSR |

## Диагностика SYSVOL

Простой `repadmin /replsummary` относится к репликации AD, а не к самим файлам SYSVOL. Сравните исходники напрямую:

```powershell
.\Compare-SysvolFiles.ps1 -DomainControllers @('dc01.ad.example.com','dc02.ad.example.com') |
  Format-Table -AutoSize
```

Также изучите DFS Replication event log, состояние репликационной группы SYSVOL и возможные очереди/ошибки. Маркер `dfsr-test` из кейса **не доказывает завершённую репликацию**.
