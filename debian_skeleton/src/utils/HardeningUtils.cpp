#include "utils/HardeningUtils.hpp"
#include <fstream>
#include <sys/ioctl.h>
#include <linux/fs.h>
#include <fcntl.h>
#include <unistd.h>
#include <iostream>

namespace VenomUtils {
    bool setImmutable(const std::string& path, bool secure) {
        int fd = open(path.c_str(), O_RDONLY | O_NONBLOCK);
        if (fd == -1) return false;

        int flags;
        ioctl(fd, FS_IOC_GETFLAGS, &flags);
        if (secure) flags |= FS_IMMUTABLE_FL;
        else flags &= ~FS_IMMUTABLE_FL;

        int result = ioctl(fd, FS_IOC_SETFLAGS, &flags);
        close(fd);
        return result == 0;
    }

    bool writeProtectedFile(const std::string& path, const std::vector<std::string>& content) {
        // Először feloldjuk, ha véletlenül már le volt zárva
        setImmutable(path, false);

        std::ofstream file(path, std::ios::trunc);
        if (!file.is_open()) return false;

        for (const auto& line : content) {
            file << line << "\n";
        }
        file.close();

        // Visszazárjuk "sérthetetlenre"
        return setImmutable(path, true);
    }
}
