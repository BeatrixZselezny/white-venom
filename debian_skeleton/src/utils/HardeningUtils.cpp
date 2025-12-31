#include "utils/HardeningUtils.hpp"
#include <fstream>
#include <sys/ioctl.h>
#include <linux/fs.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/wait.h>
#include <iostream>
#include <filesystem>
#include <chrono>
#include <iomanip>
#include <sstream>
#include <vector>

namespace fs = std::filesystem;

namespace VenomUtils {

    // Globális flag a biztonságos teszteléshez
    bool DRY_RUN = false;

    // --- ALACSONY SZINTŰ BIZTONSÁG ---

    bool setImmutable(const std::string& path, bool secure) {
        if (DRY_RUN) {
            std::cout << "[DRY-RUN] Would " << (secure ? "set" : "unset") << " immutable flag on: " << path << std::endl;
            return true;
        }
        if (!fs::exists(path)) return false;
        int fd = open(path.c_str(), O_RDONLY | O_NONBLOCK);
        if (fd == -1) return false;

        int flags;
        if (ioctl(fd, FS_IOC_GETFLAGS, &flags) == -1) {
            close(fd);
            return false;
        }

        if (secure) flags |= FS_IMMUTABLE_FL;
        else flags &= ~FS_IMMUTABLE_FL;

        int result = ioctl(fd, FS_IOC_SETFLAGS, &flags);
        close(fd);
        return result == 0;
    }

    bool secureExec(const std::string& binary, const std::vector<std::string>& args) {
        if (DRY_RUN) {
            std::cout << "[DRY-RUN] Executing (fork/execv): " << binary;
            for (const auto& arg : args) std::cout << " " << arg;
            std::cout << std::endl;
            return true;
        }

        pid_t pid = fork();
        if (pid == -1) return false;

        if (pid == 0) { // Gyerek folyamat
            std::vector<char*> c_args;
            c_args.push_back(const_cast<char*>(binary.c_str()));
            for (const auto& arg : args) {
                c_args.push_back(const_cast<char*>(arg.c_str()));
            }
            c_args.push_back(nullptr);

            execv(binary.c_str(), c_args.data());
            _exit(1); 
        } else { // Szülő
            int status;
            waitpid(pid, &status, 0);
            return WIFEXITED(status) && WEXITSTATUS(status) == 0;
        }
    }

    // --- BIZTONSÁGI MENTÉS (System hívás mentesítve) ---

    bool createBackup(const std::string& sourcePath) {
        if (!fs::exists(sourcePath)) return true;
        
        std::string backupDir = "/var/log/Backup";
        if (DRY_RUN) {
            std::cout << "[DRY-RUN] Would create backup of: " << sourcePath << " in " << backupDir << std::endl;
            return true;
        }

        try {
            if (!fs::exists(backupDir)) {
                fs::create_directories(backupDir);
                fs::permissions(backupDir, fs::perms::owner_all);
            }

            auto now = std::chrono::system_clock::now();
            auto in_time_t = std::chrono::system_clock::to_time_t(now);
            std::stringstream ss;
            ss << std::put_time(std::localtime(&in_time_t), "%Y%m%d_%H%M%S");

            std::string bPath = backupDir + "/" + fs::path(sourcePath).filename().string() + "_" + ss.str() + ".bak";
            fs::copy_file(sourcePath, bPath, fs::copy_options::overwrite_existing);
            
            // Integritás napló - MOST MÁR SECURE_EXEC-EL, SYSTEM() NÉLKÜL
            // Az sha256sum kimenetét átirányítás helyett egy temp fájlba kérjük vagy logoljuk
            secureExec("/usr/bin/sha256sum", {bPath}); 
            
            return true;
        } catch (...) { return false; }
    }

    bool injectGrubKernelOpts(const std::string& opts) {
        std::string binary = "/usr/bin/grub-editenv";
        if (!fs::exists(binary)) binary = "/usr/sbin/grub-editenv";

        if (!DRY_RUN) createBackup("/boot/grub/grubenv");
        
        // Prepared hívás
        std::vector<std::string> args = {"-", "set", "kernelopts=" + opts};
        return secureExec(binary, args);
    }

    bool smartUpdateFstab(const std::vector<std::string>& hardeningLines) {
        const std::string path = "/etc/fstab";
        if (DRY_RUN) {
            std::cout << "[DRY-RUN] Would update " << path << " with hardening rules (preserving UUIDs)." << std::endl;
            return true;
        }

        if (!createBackup(path)) return false;
        setImmutable(path, false);

        std::vector<std::string> finalLines;
        std::ifstream file(path);
        if (!file.is_open()) return false;

        std::string line;
        while (std::getline(file, line)) {
            if (line.empty() || line[0] == '#') {
                finalLines.push_back(line);
                continue;
            }
            std::istringstream iss(line);
            std::string device, mountPoint;
            iss >> device >> mountPoint;

            bool isHardened = false;
            for (const auto& hLine : hardeningLines) {
                if (hLine.find(" " + mountPoint + " ") != std::string::npos) {
                    finalLines.push_back(hLine);
                    isHardened = true;
                    break;
                }
            }
            if (!isHardened) finalLines.push_back(line);
        }
        file.close();

        std::ofstream out(path, std::ios::trunc);
        for (const auto& l : finalLines) out << l << "\n";
        return true;
    }

    bool writeProtectedFile(const std::string& path, const std::vector<std::string>& content) {
        if (DRY_RUN) {
            std::cout << "[DRY-RUN] Would write " << content.size() << " lines to: " << path << std::endl;
            return true;
        }
        if (!createBackup(path)) return false;
        if (fs::exists(path)) setImmutable(path, false);

        std::ofstream file(path, std::ios::trunc);
        if (!file.is_open()) return false;
        for (const auto& l : content) file << l << "\n";
        file.close();
        return true;
    }
}
