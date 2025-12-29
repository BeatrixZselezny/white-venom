#include "utils/HardeningUtils.hpp"
#include <fstream>
#include <sys/ioctl.h>
#include <linux/fs.h>
#include <fcntl.h>
#include <unistd.h>
#include <iostream>
#include <filesystem>
#include <chrono>
#include <iomanip>

namespace fs = std::filesystem;

namespace VenomUtils {

    // Alacsony szintű ioctl hívás a +i (immutable) flag kezeléséhez
    bool setImmutable(const std::string& path, bool secure) {
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

    // Biztonsági mentés készítése az /opt/whitevenom/backups mappába
    bool createBackup(const std::string& sourcePath) {
        if (!fs::exists(sourcePath)) return true; // Ha nincs mit menteni, nincs hiba

        try {
            std::string backupDir = "/opt/whitevenom/backups";
            if (!fs::exists(backupDir)) return false;

            // Időbélyeg generálása a fájlnévhez
            auto now = std::chrono::system_clock::now();
            auto in_time_t = std::chrono::system_clock::to_time_t(now);
            std::stringstream ss;
            ss << std::put_time(std::localtime(&in_time_t), "%Y%m%d_%H%M%S");

            fs::path p(sourcePath);
            std::string backupName = p.filename().string() + "_" + ss.str() + ".bak";
            fs::path targetPath = fs::path(backupDir) / backupName;

            fs::copy_file(sourcePath, targetPath, fs::copy_options::overwrite_existing);
            return true;
        } catch (...) {
            return false;
        }
    }

    // A megbeszélt zsilipelt írási folyamat: Backup -> Unlock -> Write -> Lock
    bool writeProtectedFile(const std::string& path, const std::vector<std::string>& content) {
        // 1. Biztonsági mentés (Zero-Trust fallback)
        if (!createBackup(path)) {
            std::cerr << "[WARN] Backup failed for: " << path << ". Proceeding with caution." << std::endl;
        }

        // 2. Zsilip nyitása (ha létezik a fájl és védett)
        if (fs::exists(path)) {
            setImmutable(path, false);
        }

        // 3. Írás
        std::ofstream file(path, std::ios::trunc);
        if (!file.is_open()) return false;

        for (const auto& line : content) {
            file << line << "\n";
        }
        file.close();

        // 4. Zsilip zárása (Visszatérés a védett állapotba)
        return setImmutable(path, true);
    }
}
