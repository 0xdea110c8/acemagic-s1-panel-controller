#pragma once

struct RamData {
    int ram_free_percent;
    int swap_free_percent;
    int uptime;
};

int get_cpu_usage_percent(); 
int get_cpu_temperature();
struct RamData get_ram_info();
int get_disk_usage();
int get_wifi_rssi(const char* interface_name);
char** get_awg_interfaces_sysfs(int* count);
void free_sysfs_interfaces(char** interfaces, int count); 
