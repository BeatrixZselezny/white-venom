#include "SafeExecutor.hpp"
#include <unistd.h>
#include <sys/wait.h>
#include <vector>
#include <iostream>

namespace Venom::Core {

    bool SafeExecutor::execute(const std::string& binary, const std::vector<std::string>& args) {
        pid_t pid = fork();

        if (pid == -1) {
            return false; // Fork hiba
        }

        if (pid == 0) { // Gyerek folyamat
            // Argumentumok előkészítése az execv-hez (char* konverzió)
            std::vector<char*> c_args;
            c_args.push_back(const_cast<char*>(binary.c_str()));
            for (const auto& arg : args) {
                c_args.push_back(const_cast<char*>(arg.c_str()));
            }
            c_args.push_back(nullptr);

            // Tényleges futtatás shell nélkül
            execv(binary.c_str(), c_args.data());
            
            // Ha az execv visszatér, hiba történt
            _exit(127);
        } else { // Szülő folyamat
            int status;
            waitpid(pid, &status, 0);
            return (WIFEXITED(status) && WEXITSTATUS(status) == 0);
        }
    }
}
