#!/usr/bin/env bash
# collect_forensic.sh
# Форензик-скрипт: собирает артефакты в /root/forensic и упаковывает их.
# Использование:
#   sudo ./collect_forensic.sh            # стандартный сбор (tcpdump, gcore опционально)
#   sudo ./collect_forensic.sh --no-tcpdump --no-gcore
#   sudo ./collect_forensic.sh --dump-pid 1234
set -euo pipefail
OUTDIR="/root/forensic"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
OUTTAR="/root/forensic-${TIMESTAMP}.tar.gz"
mkdir -p "$OUTDIR"
chmod 700 "$OUTDIR"

# Опции
DO_TCPDUMP=1
DO_GCORE=1
EXPLICIT_PID=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-tcpdump) DO_TCPDUMP=0; shift ;;
    --no-gcore) DO_GCORE=0; shift ;;
    --dump-pid) EXPLICIT_PID="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 2 ;;
  esac
done

log() { echo "[*] $*"; }
now() { date +%Y-%m-%dT%H:%M:%S; }

log "$(now) Starting forensic collection into $OUTDIR"

# Helper to safe-run commands and save output
safe_cmd() {
  local outfile="$1"; shift
  echo "[cmd] $*" > "${outfile}.cmd.txt" 2>/dev/null || true
  ( "$@" ) > "$outfile" 2>&1 || true
}

# 1) Basic system info
safe_cmd "$OUTDIR/hostname.txt" hostname
safe_cmd "$OUTDIR/uname.txt" uname -a
safe_cmd "$OUTDIR/uptime.txt" uptime
safe_cmd "$OUTDIR/df.txt" df -h
safe_cmd "$OUTDIR/free.txt" free -h
safe_cmd "$OUTDIR/lsblk.txt" lsblk

# 2) Processes / top
safe_cmd "$OUTDIR/top_processes.txt" ps -eo pid,ppid,user,%cpu,%mem,etimes,cmd --sort=-%cpu
safe_cmd "$OUTDIR/top_threads.txt" top -b -n 1 -H
safe_cmd "$OUTDIR/ps_aux.txt" ps aux

# 3) Автовыбор подозрительных процессов по именам (расширяемый список)
SUSPECT_NAMES="kdevtmpfsi kdevtmpfs kdevtmpi kworker minerd xmrig xmr-stak cryptonight cpuminer"
echo "$SUSPECT_NAMES" > "$OUTDIR/suspect_names.txt"
# поиск процессов
for name in $SUSPECT_NAMES; do
  pgrep -a -f "$name" 2>/dev/null || true
done > "$OUTDIR/suspects_found.txt" || true

# если явно передан PID, добавим его в suspects
if [[ -n "$EXPLICIT_PID" ]]; then
  echo "explicit pid: $EXPLICIT_PID" >> "$OUTDIR/suspects_found.txt"
fi

# 4) Сеть / соединения
safe_cmd "$OUTDIR/ss_tunap.txt" ss -tunap
safe_cmd "$OUTDIR/netstat.txt" netstat -plant 2>/dev/null || true
safe_cmd "$OUTDIR/lsof_network.txt" lsof -i -P -n || true

# 5) systemd, cron, ssh keys, apt logs
safe_cmd "$OUTDIR/systemd_units_enabled.txt" systemctl list-unit-files --state=enabled
( ls -la /etc/systemd/system /lib/systemd/system /usr/lib/systemd/system 2>/dev/null ) > "$OUTDIR/systemd_dirs.txt" || true
safe_cmd "$OUTDIR/root_cron.txt" crontab -l -u root || true
# user crons
( for u in $(cut -f1 -d: /etc/passwd); do echo "---- CRON of $u ----"; crontab -l -u "$u" 2>/dev/null || true; done ) > "$OUTDIR/user_crons.txt" || true
safe_cmd "$OUTDIR/ssh_authorized_keys.txt" grep -R "ssh-rsa\\|ssh-ed25519\\|ssh-dss" /root /home /etc/ssh -n || true
safe_cmd "$OUTDIR/apt_history.txt" cat /var/log/apt/history.log* /var/log/dpkg.log* 2>/dev/null || true

# 6) журналы
safe_cmd "$OUTDIR/journal_lastday.txt" journalctl --no-pager --since "24 hours ago" || true
safe_cmd "$OUTDIR/journal_2days.txt" journalctl --no-pager --since "48 hours ago" || true
safe_cmd "$OUTDIR/dmesg.txt" dmesg

# 7) найти исполняемые файлы в /tmp, /var/tmp, /dev/shm
( find /tmp /var/tmp /dev/shm -xdev -maxdepth 3 -type f -executable -ls 2>/dev/null || true ) > "$OUTDIR/tmp_execs.txt"

# 8) найти недавно изменённые файлы (последние 2 дня) - может быть тяжело, ограничим каталоги
( find /etc /var /usr/local /home -xdev -mtime -2 -type f -ls 2>/dev/null || true ) > "$OUTDIR/changed_last2days.txt"

# 9) детально для подозрительных PID'ов (pgrep из suspects_found)
PIDS_TO_DUMP=()
# из списка suspects_found возьмём PID'ы
while read -r line; do
  # pgrep -a output: PID cmd...
  pid=$(echo "$line" | awk '{print $1}' 2>/dev/null || true)
  if [[ "$pid" =~ ^[0-9]+$ ]]; then
    PIDS_TO_DUMP+=("$pid")
  fi
done < <(cat "$OUTDIR/suspects_found.txt" 2>/dev/null)

# если указали явно PID
if [[ -n "$EXPLICIT_PID" ]]; then
  PIDS_TO_DUMP+=("$EXPLICIT_PID")
fi

# Уникализируем
if [ "${#PIDS_TO_DUMP[@]}" -gt 0 ]; then
  # remove duplicates
  mapfile -t PIDS_TO_DUMP < <(printf "%s\n" "${PIDS_TO_DUMP[@]}" | sort -n -u)
fi

# Если не нашли, добавим топ CPU PID (первый)
if [ "${#PIDS_TO_DUMP[@]}" -eq 0 ]; then
  top_pid=$(ps -eo pid,%cpu --sort=-%cpu | awk 'NR==2{print $1}' || true)
  if [[ -n "$top_pid" ]]; then
    PIDS_TO_DUMP+=("$top_pid")
  fi
fi

log "PIDs to inspect: ${PIDS_TO_DUMP[*]:-(none)}"

for pid in "${PIDS_TO_DUMP[@]}"; do
  mkdir -p "$OUTDIR/pid_$pid"
  safe_cmd "$OUTDIR/pid_$pid/cmdline.txt" cat "/proc/$pid/cmdline" || true
  safe_cmd "$OUTDIR/pid_$pid/environ.txt" strings -n 1 "/proc/$pid/environ" || true
  safe_cmd "$OUTDIR/pid_$pid/fdlist.txt" ls -la "/proc/$pid/fd" 2>/dev/null || true
  safe_cmd "$OUTDIR/pid_$pid/lsof.txt" lsof -p "$pid" 2>/dev/null || true
  safe_cmd "$OUTDIR/pid_$pid/ppid.txt" ps -o pid,ppid,user,cmd -p "$pid" 2>/dev/null || true
  safe_cmd "$OUTDIR/pid_$pid/pstree.txt" pstree -sp "$pid" 2>/dev/null || true

  # где лежит бинарь
  exe=$(readlink -f "/proc/$pid/exe" 2>/dev/null || true)
  echo "exe: $exe" > "$OUTDIR/pid_$pid/exe_path.txt" || true
  if [[ -n "$exe" && -e "$exe" ]]; then
    cp "$exe" "$OUTDIR/pid_$pid/maybe_binary_$(basename "$exe")" 2>/dev/null || true
    sha256sum "$OUTDIR/pid_$pid/maybe_binary_$(basename "$exe")" > "$OUTDIR/pid_$pid/maybe_binary.sha256" 2>/dev/null || true
  else
    echo "binary not present on disk (deleted?)" >> "$OUTDIR/pid_$pid/exe_path.txt"
    if [[ $DO_GCORE -eq 1 ]]; then
      log "Attempting to gcore PID $pid (requires gdb) ..."
      if ! command -v gcore >/dev/null 2>&1; then
        log "Installing gdb for gcore (apt-get update/install). This may take time."
        apt-get update -y >/dev/null 2>&1 || true
        apt-get install -y gdb >/dev/null 2>&1 || true
      fi
      # gcore output file
      if command -v gcore >/dev/null 2>&1; then
        gcore -o "$OUTDIR/pid_$pid/core" "$pid" 2>/dev/null || true
        ls -lh "$OUTDIR/pid_$pid"/core* 2>/dev/null || true
      fi
    fi
  fi
done

# 10) копия важных конфигураций
( tar -czf - /etc/ssh /etc/passwd /etc/group /etc/shadow 2>/dev/null > /dev/null ) || true
# но не упаковываем сразу, сохраним выборочно
cp -a /etc/ssh "$OUTDIR/" 2>/dev/null || true
cp -a /etc/passwd "$OUTDIR/" 2>/dev/null || true
cp -a /etc/group "$OUTDIR/" 2>/dev/null || true
# НЕ копируем /etc/shadow на общедоступный сервер без защиты; но оставим локально
cp -a /etc/shadow "$OUTDIR/" 2>/dev/null || true

# 11) опционально tcpdump (по времени ограничим 5 минут)
if [[ $DO_TCPDUMP -eq 1 ]]; then
  if command -v tcpdump >/dev/null 2>&1; then
    log "Running tcpdump for 300s to $OUTDIR/tcpdump.pcap (may be large)"
    timeout 300 tcpdump -nn -w "$OUTDIR/tcpdump.pcap" || true
  else
    log "tcpdump not installed — installing (apt-get)."
    apt-get update -y >/dev/null 2>&1 || true
    apt-get install -y tcpdump >/dev/null 2>&1 || true
    timeout 300 tcpdump -nn -w "$OUTDIR/tcpdump.pcap" || true
  fi
fi

# 12) полезные вспомогательные списки
safe_cmd "$OUTDIR/iptables_rules.txt" iptables -L -n -v || true
safe_cmd "$OUTDIR/sysctl.txt" sysctl -a || true
safe_cmd "$OUTDIR/installed_packages.txt" dpkg -l || true

# 13) упаковка результатa
log "Packing results to $OUTTAR (may be large)"
tar -czf "$OUTTAR" -C /root "$(basename "$OUTDIR")" || true
log "Done. Archive at $OUTTAR"
ls -lh "$OUTTAR" || true

echo
echo "===== SUMMARY ====="
echo "Archive: $OUTTAR"
echo "Collected PIDs: ${PIDS_TO_DUMP[*]:-(none)}"
echo "Files in $OUTDIR: "
ls -la "$OUTDIR" | sed -n '1,200p'
echo "==================="
echo
echo "Next: securely download the archive to your workstation with:"
echo "  scp root@<server-ip>:$OUTTAR ./"
echo
echo "WARNING: archive contains sensitive data (keys, shadow etc). Store it securely and delete from untrusted places."
