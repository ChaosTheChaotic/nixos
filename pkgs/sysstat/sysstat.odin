package sysstat

import "core:fmt"
import "core:os"
import "core:strings"
import "core:sys/linux"
import "core:sys/posix"
import "core:time"

OUT_FILE :: "/dev/shm/sysstat.json"
TMP_FILE :: "/dev/shm/sysstat.json.tmp"
SAMPLE_INTERVAL :: 2 * time.Second
MAX_THERMAL_ZONES :: 16

prev_user, prev_nice, prev_system, prev_idle: u64
prev_iowait, prev_irq, prev_softirq, prev_steal: u64
prev_rx, prev_tx: u64

thermal_paths: [MAX_THERMAL_ZONES]cstring
thermal_count: int

main :: proc() {
	read_cpu_totals(
		&prev_user,
		&prev_nice,
		&prev_system,
		&prev_idle,
		&prev_iowait,
		&prev_irq,
		&prev_softirq,
		&prev_steal,
	)
	discover_thermal_zones()
	_, _ = get_net_rates()

	json_buf: [320]u8

	for {
		time.sleep(SAMPLE_INTERVAL)

		cpu_usage := get_cpu_usage()
		disk_percent := get_disk_usage()

		info: linux.Sys_Info
		ram_used, ram_total: int
		up_days, up_hours, up_minutes: int
		if linux.sysinfo(&info) == .NONE {
			ram_used, ram_total = ram_from_sysinfo(&info)
			up_days, up_hours, up_minutes = uptime_from_sysinfo(&info)
		} else {
			ram_used, ram_total = 0, 1
		}

		temp_milli := get_temp_millideg()
		net_rx, net_tx := get_net_rates()

		json: string
		if up_days > 0 {
			json = fmt.bprintf(
				json_buf[:],
				`{{"cpu":%d,"ram":%d,"ramMax":%d,"disk":%d,"temp":%d,"rx":%d,"tx":%d,"uptime":"%dd %dh"}}`,
				cpu_usage,
				ram_used,
				ram_total,
				disk_percent,
				temp_milli,
				net_rx,
				net_tx,
				up_days,
				up_hours,
			)
		} else {
			json = fmt.bprintf(
				json_buf[:],
				`{{"cpu":%d,"ram":%d,"ramMax":%d,"disk":%d,"temp":%d,"rx":%d,"tx":%d,"uptime":"%dh %dm"}}`,
				cpu_usage,
				ram_used,
				ram_total,
				disk_percent,
				temp_milli,
				net_rx,
				net_tx,
				up_hours,
				up_minutes,
			)
		}

		fd, err := linux.open(
			TMP_FILE,
			{.WRONLY, .CREAT, .TRUNC},
			{.IRUSR, .IWUSR, .IRGRP, .IROTH},
		)
		if err == .NONE {
			_, _ = linux.write(fd, transmute([]byte)json)
			linux.close(fd)
			_ = linux.rename(TMP_FILE, OUT_FILE)
		}
	}
}

discover_thermal_zones :: proc() {
	f, err := os.open("/sys/class/thermal")
	if err != nil do return
	defer os.close(f)

	infos, read_err := os.read_dir(f, -1, context.allocator)
	if read_err != nil do return
	defer delete(infos)

	for info in infos {
		if thermal_count >= MAX_THERMAL_ZONES do break
		if !strings.has_prefix(info.name, "thermal_zone") do continue

		type_path := fmt.ctprintf("/sys/class/thermal/%s/type", info.name)
		type_fd, type_err := linux.open(type_path, {})
		if type_err != .NONE do continue
		type_buf: [64]u8
		type_n, _ := linux.read(type_fd, type_buf[:])
		linux.close(type_fd)
		if type_n == 0 do continue

		type_str := string(type_buf[:type_n])
		is_cpu :=
			strings.contains(type_str, "x86_pkg_temp") ||
			strings.contains(type_str, "cpu_thermal") ||
			strings.contains(type_str, "cpu-thermal")

		temp_path := fmt.ctprintf("/sys/class/thermal/%s/temp", info.name)
		temp_fd, temp_err := linux.open(temp_path, {})
		if temp_err != .NONE do continue
		linux.close(temp_fd)

		if is_cpu {
			thermal_paths[thermal_count] = temp_path
			thermal_count += 1
		} else if thermal_count == 0 {
			// Keep first readable one as last resort
			thermal_paths[thermal_count] = temp_path
			thermal_count += 1
		}
	}
}

get_temp_millideg :: proc() -> u64 {
	for i := 0; i < thermal_count; i += 1 {
		fd, err := linux.open(thermal_paths[i], {})
		if err != .NONE do continue
		buf: [32]u8
		n, _ := linux.read(fd, buf[:])
		linux.close(fd)
		if n == 0 do continue
		pos := 0
		val := parse_u64_advance(buf[:n], &pos)
		if val > 1000 && val < 200000 do return val
	}
	return 0
}

get_net_rates :: proc() -> (rx_rate, tx_rate: u64) {
	fd, err := linux.open("/proc/net/dev", {})
	if err != .NONE do return 0, 0
	defer linux.close(fd)

	buf: [8192]u8
	n, read_err := linux.read(fd, buf[:])
	if read_err != .NONE || n == 0 do return 0, 0

	total_rx, total_tx: u64
	pos := 0

	#no_bounds_check {
		// Skip the two header lines
		for i := 0; i < 2; i += 1 {
			for pos < n && buf[pos] != '\n' do pos += 1
			pos += 1
		}

		for pos < n {
			for pos < n && (buf[pos] == ' ' || buf[pos] == '\t') do pos += 1
			if pos >= n do break

			name_start := pos
			for pos < n && buf[pos] != ':' do pos += 1
			if pos >= n do break
			name := buf[name_start:pos]
			pos += 1

			should_count := len(name) > 0 && (name[0] == 'e' || name[0] == 'w')

			rx := parse_u64_advance(buf[:n], &pos)
			for i := 0; i < 7; i += 1 {
				_ = parse_u64_advance(buf[:n], &pos)
			}
			tx := parse_u64_advance(buf[:n], &pos)

			if should_count {
				total_rx += rx
				total_tx += tx
			}

			for pos < n && buf[pos] != '\n' do pos += 1
			pos += 1
		}
	}

	interval_sec := u64(SAMPLE_INTERVAL / time.Second)
	if interval_sec == 0 do interval_sec = 1

	if total_rx >= prev_rx {
		rx_rate = (total_rx - prev_rx) / interval_sec
	}
	if total_tx >= prev_tx {
		tx_rate = (total_tx - prev_tx) / interval_sec
	}
	prev_rx = total_rx
	prev_tx = total_tx
	return
}

get_cpu_usage :: proc() -> int {
	user, nice, system, idle, iowait, irq, softirq, steal: u64
	if !read_cpu_totals(&user, &nice, &system, &idle, &iowait, &irq, &softirq, &steal) {
		return 0
	}

	total := user + nice + system + idle + iowait + irq + softirq + steal
	prev_total :=
		prev_user +
		prev_nice +
		prev_system +
		prev_idle +
		prev_iowait +
		prev_irq +
		prev_softirq +
		prev_steal

	diff_total := total - prev_total
	diff_idle := idle - prev_idle

	prev_user = user; prev_nice = nice; prev_system = system; prev_idle = idle
	prev_iowait = iowait; prev_irq = irq; prev_softirq = softirq; prev_steal = steal

	if diff_total == 0 do return 0
	return int(100 * (diff_total - diff_idle) / diff_total)
}

read_cpu_totals :: proc(user, nice, system, idle, iowait, irq, softirq, steal: ^u64) -> bool {
	fd, err := linux.open("/proc/stat", {})
	if err != .NONE do return false
	defer linux.close(fd)

	buf: [512]u8
	n, read_err := linux.read(fd, buf[:])
	if read_err != .NONE || n == 0 do return false

	pos := 0
	#no_bounds_check {
		for pos < n && buf[pos] != ' ' do pos += 1
		user^ = parse_u64_advance(buf[:n], &pos)
		nice^ = parse_u64_advance(buf[:n], &pos)
		system^ = parse_u64_advance(buf[:n], &pos)
		idle^ = parse_u64_advance(buf[:n], &pos)
		iowait^ = parse_u64_advance(buf[:n], &pos)
		irq^ = parse_u64_advance(buf[:n], &pos)
		softirq^ = parse_u64_advance(buf[:n], &pos)
		steal^ = parse_u64_advance(buf[:n], &pos)
	}
	return true
}

ram_from_sysinfo :: #force_inline proc(info: ^linux.Sys_Info) -> (used_mb, total_mb: int) {
	unit := u64(info.mem_unit)
	total := u64(info.totalram) * unit
	free := u64(info.freeram) * unit
	return int((total - free) / (1024 * 1024)), int(total / (1024 * 1024))
}

uptime_from_sysinfo :: #force_inline proc(info: ^linux.Sys_Info) -> (days, hours, minutes: int) {
	total_sec := int(info.uptime)
	days = total_sec / 86400
	hours = (total_sec % 86400) / 3600
	minutes = (total_sec % 3600) / 60
	return
}

get_disk_usage :: proc() -> int {
	stat: posix.statvfs_t
	if posix.statvfs("/", &stat) != .OK do return 0

	total := u64(stat.f_blocks) * u64(stat.f_frsize)
	free := u64(stat.f_bfree) * u64(stat.f_frsize)
	if total == 0 do return 0
	used := total - free
	return int(100 * used / total)
}

skip_spaces :: #force_inline proc(buf: []u8, pos: ^int) {
	#no_bounds_check {
		for pos^ < len(buf) && (buf[pos^] == ' ' || buf[pos^] == '\t') {
			pos^ += 1
		}
	}
}

parse_u64_advance :: #force_inline proc(buf: []u8, pos: ^int) -> u64 {
	skip_spaces(buf, pos)
	result: u64 = 0
	#no_bounds_check {
		for pos^ < len(buf) && buf[pos^] >= '0' && buf[pos^] <= '9' {
			result = result * 10 + u64(buf[pos^] - '0')
			pos^ += 1
		}
	}
	return result
}
