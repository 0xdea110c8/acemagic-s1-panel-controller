#include "include/SysInfo.hpp"
#include <sys/sysinfo.h>
#include <sys/statvfs.h>
#include <fstream>
#include <string>
#include <cstring>

#include <filesystem>
#include <vector>
static bool read_cpu_ticks(long long& work, long long& total) {
    std::ifstream file("/proc/stat");
    if (!file.is_open()) return false;
    std::string cpu_label;
    long long user, nice, system, idle, iowait, irq, softirq, steal;
    if (file >> cpu_label >> user >> nice >> system >> idle >> iowait >> irq >> softirq >> steal) {
        work = user + nice + system + irq + softirq + steal;
        total = work + idle + iowait;
        return true;
    }
    return false;
}

int get_cpu_usage_percent() {
    static long long prev_work = 0;
    static long long prev_total = 0;
    long long current_work = 0;
    long long current_total = 0;
    if (!read_cpu_ticks(current_work, current_total)) return 0;
    long long work_delta = current_work - prev_work;
    long long total_delta = current_total - prev_total;
    int usage = 0;
    if (total_delta > 0) {
        usage = static_cast<int>((static_cast<double>(work_delta) / total_delta) * 100.0);
    }
    prev_work = current_work;
    prev_total = current_total;
    return usage;
}

int get_cpu_temperature() {
    std::ifstream file("/sys/class/thermal/thermal_zone0/temp");
    if (!file.is_open()) return 0;
    
    int raw_temp = 0;
    if (file >> raw_temp) {
        return raw_temp / 1000;
    }
    return 0;
}

RamData get_ram_info() {
    struct sysinfo info;
    RamData result{}; 
    
    if (sysinfo(&info) == 0) {
        double total_ram = static_cast<double>(info.totalram);
        double free_ram = static_cast<double>(info.freeram);
        double total_swap = static_cast<double>(info.totalswap);
        double free_swap = static_cast<double>(info.freeswap);
        result.ram_free_percent = (total_ram > 0) ? static_cast<int>((free_ram / total_ram) * 100.0) : 0;
        result.swap_free_percent = (total_swap > 0) ? static_cast<int>((free_swap/ total_swap) * 100.0) : 0;
        result.uptime = static_cast<int>(info.uptime);
    }
    
    return result;
}

int get_disk_usage() {
    struct statvfs vfs;
    if (statvfs("/", &vfs) == 0) {
        double total_blocks = static_cast<double>(vfs.f_blocks);   
        double available_blocks = static_cast<double>(vfs.f_bavail);
        return (total_blocks > 0) ? static_cast<int>((available_blocks / total_blocks) * 100.0) : 0;
    }
    return 0;
}

int get_wifi_rssi(const char* interface_name) {
    std::ifstream file("/proc/net/wireless");
    if (!file.is_open()) return 0;

    std::string line;
    std::getline(file, line);
    std::getline(file, line);

    while (std::getline(file, line)) {
        if (line.find(interface_name) != std::string::npos) {
            char iface[32];
            int status;
            double link, level, noise;
            
            if (sscanf(line.c_str(), "%s %d %lf %lf %lf", iface, &status, &link, &level, &noise) >= 4) {
                return static_cast<int>(level); 
            }
        }
    }
    return 0;
}

char** get_awg_interfaces_sysfs(int* count) {
    std::vector<std::string> awg_devices;
    *count = 0;

    const std::string net_path = "/sys/class/net";
    if (!std::filesystem::exists(net_path)) return nullptr;

    for (const auto& entry : std::filesystem::directory_iterator(net_path)) {
        std::string iface_name = entry.path().filename().string();
        
        if (iface_name == "lo") continue;

        std::filesystem::path type_path = entry.path() / "type";
        
        if (std::filesystem::exists(type_path)) {
            std::ifstream type_file(type_path);
            int device_type = 0;
            
            if (type_file >> device_type && device_type == 65534) {
                awg_devices.push_back(iface_name);
            }
        }
    }

    if (awg_devices.empty()) return nullptr;

    *count = static_cast<int>(awg_devices.size());
    char** result = new char*[*count];
    
    for (int i = 0; i < *count; ++i) {
        result[i] = new char[awg_devices[i].length() + 1];
        std::strcpy(result[i], awg_devices[i].c_str());
    }

    return result;
}

void free_sysfs_interfaces(char** interfaces, int count) {
    if (interfaces == nullptr) return;
    for (int i = 0; i < count; ++i) {
        delete[] interfaces[i];
    }
    delete[] interfaces; 
}
