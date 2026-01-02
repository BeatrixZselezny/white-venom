#include "utils/HardeningUtils.hpp"
#include <iostream>
#include <fstream>
#include <unistd.h>
#include <sys/wait.h>
#include <sys/ioctl.h>
#include <linux/fs.h>
#include <fcntl.h>
#include <vector>
#include <filesystem>

namespace fs = std::filesystem;

namespace VenomUtils {

    // A linker által hiányolt globális változó definíciója
    bool DRY_RUN = false;

    // --- ÚJ: A régi ütköző konfigurációk automatikus eltávolítása ---
    void cleanLegacyConfigs() {
        std::vector<std::string> legacyFiles = {
            "/etc/sysctl.d/99-venom.conf",
            "/etc/sysctl.d/99-venom-hardening.conf",
            "/etc/sysctl.d/99-security-ipv6.conf",
            "/etc/sysctl.d/04_sysctl_venom_ipv6.conf",
            "/etc/sysctl.d/99_whitevenom_final.conf"
        };

        for (const auto& file : legacyFiles) {
            if (fs::exists(file)) {
                pid_t pid = fork();
                if (pid == 0) {
                    char* args[] = {(char*)"/usr/bin/rm", (char*)"-f", (char*)file.c_str(), nullptr};
                    execv(args[0], args);
                    _exit(1);
                } else if (pid > 0) {
                    waitpid(pid, nullptr, 0);
                }
            }
        }
    }

    void checkLDSanity() {
        // LD Sanity Check implementáció
    }

    bool writeProtectedFile(const std::string& path, const std::vector<std::string>& content) {
        if (DRY_RUN) {
            std::cout << "[DRY-RUN] Writing to: " << path << std::endl;
            return true;
        }

        std::ofstream file(path);
        if (!file.is_open()) return false;

        for (const auto& line : content) {
            file << line << "\n";
        }
        file.close();
        return true;
    }

    bool setImmutable(const std::string& path, bool secure) {
        if (DRY_RUN) return true;
        
        int fd = open(path.c_str(), O_RDONLY);
        if (fd < 0) return false;

        int flags;
        if (ioctl(fd, FS_IOC_GETFLAGS, &flags) < 0) {
            close(fd);
            return false;
        }

        if (secure) flags |= FS_IMMUTABLE_FL;
        else flags &= ~FS_IMMUTABLE_FL;

        bool success = (ioctl(fd, FS_IOC_SETFLAGS, &flags) == 0);
        close(fd);
        return success;
    }

    bool smartUpdateFstab(const std::vector<std::string>& hardeningLines) {
        (void)hardeningLines;
        return true;
    }

    bool injectGrubKernelOpts(const std::string& opts) {
        (void)opts;
        return true;
    }

    bool secureExec(const std::string& binary, const std::vector<std::string>& args) {
        if (DRY_RUN) return true;

        pid_t pid = fork();
        if (pid == 0) {
            std::vector<char*> c_args;
            c_args.push_back((char*)binary.c_str());
            for (const auto& arg : args) {
                c_args.push_back((char*)arg.c_str());
            }
            c_args.push_back(nullptr);
            execv(binary.c_str(), c_args.data());
            _exit(1);
        } else if (pid > 0) {
            int status;
            waitpid(pid, &status, 0);
            return WIFEXITED(status) && WEXITSTATUS(status) == 0;
        }
        return false;
    }

    bool createBackup(const std::string& sourcePath) {
        if (!fs::exists(sourcePath)) return true;
        try {
            fs::copy(sourcePath, sourcePath + ".bak", fs::copy_options::overwrite_existing);
            return true;
        } catch (...) {
            return false;
        }
    }
}
