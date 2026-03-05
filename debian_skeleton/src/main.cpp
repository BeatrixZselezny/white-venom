#include <iostream>
#include <string>
#include <csignal>
#include <atomic>
#include <thread>
#include <chrono>
#include <iomanip>
#include <map>
#include <regex>
#include <fstream>
#include <filesystem>
#include <vector>

#include "core/VenomBus.hpp"
#include "core/Scheduler.hpp"
#include "core/SocketProbe.hpp"
#include "core/ebpf/BpfLoader.hpp"
#include "core/VisualMemory.hpp"
#include "modules/InitSecurityModule.hpp"
#include "modules/FilesystemModule.hpp"

namespace fs = std::filesystem;

std::atomic<bool> keepRunning{true};
rxcpp::composite_subscription engine_lifetime;

// --- BLACK HAT DESIGN UTILS ---
void clearScreen() { std::cout << "\033[2J\033[H"; }
void neonGreen() { std::cout << "\033[38;5;82m"; }
void matrixRed() { std::cout << "\033[38;5;196m"; }
void stealthGray() { std::cout << "\033[38;5;240m"; }
void cyberCyan() { std::cout << "\033[38;5;51m"; }
void boldWhite() { std::cout << "\033[1;37m"; }
void resetColor() { std::cout << "\033[0m"; }

void drawHeader() {
    neonGreen();
    std::cout << "  __      __.__    .__  __             ____   ____                             " << std::endl;
    std::cout << " /  \\    /  \\  |__ |__|/  |_  ____     \\   \\ /   /____   ____   ____   _____   " << std::endl;
    std::cout << " \\   \\/\\/   /  |  \\|  \\   __\\/ __ \\     \\   Y   // __ \\ /    \\ /  _ \\ /     \\  " << std::endl;
    std::cout << "  \\        /|   Y  \\  ||  | \\  ___/      \\     /\\  ___/|   |  (  <_> )  Y Y  \\ " << std::endl;
    std::cout << "   \\__/\\  / |___|  /__||__|  \\___  >      \\___/  \\___  >___|  /\\____/|__|_|  / " << std::endl;
    std::cout << "        \\/       \\/              \\/                  \\/     \\/             \\/  " << std::endl;
    stealthGray();
    std::cout << " [ STATUS: STEALTH ] [ INTERFACE: WLO1 ] [ KERNEL-SPACE SHIELD ACTIVE ] " << std::endl;
    resetColor();
}

void signalHandler(int signum) {
    (void)signum;
    keepRunning = false;
    if (engine_lifetime.is_subscribed()) {
        engine_lifetime.unsubscribe();
    }
}

bool isValidMac(const std::string& mac) {
    const std::regex pattern("^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$");
    return std::regex_match(mac, pattern);
}

// ÚJ, PERMANENS LOGIKA: Megjegyzi a MAC-et bootolás után is
void secureSetupRouter(Venom::Core::BpfLoader& bpfLoader) {
    const std::string configPath = "/etc/venom";
    const std::string configFile = configPath + "/router.identity";
    std::string mac_input;

    // 1. Próbáljuk beolvasni a létező fájlt
    if (fs::exists(configFile)) {
        std::ifstream ifs(configFile);
        if (ifs >> mac_input && isValidMac(mac_input)) {
            cyberCyan();
            std::cout << "[+] AUTO-LOADED IDENTITY: " << mac_input << std::endl;
            resetColor();
            bpfLoader.setRouterMAC(mac_input);
            return; 
        }
    }

    // 2. Ha nincs meg, vagy hibás, csak akkor kérünk újat
    if (!fs::exists(configPath)) {
        fs::create_directories(configPath);
        fs::permissions(configPath, fs::perms::owner_all, fs::perm_options::replace);
    }

    neonGreen();
    std::cout << "\n[?] ENTER TRUSTED MAC (XX:XX:XX:XX:XX:XX): ";
    resetColor();
    std::cin >> mac_input;

    if (!isValidMac(mac_input)) {
        matrixRed();
        std::cerr << "[!] SECURITY ALERT: INVALID MAC FORMAT!" << std::endl;
        resetColor();
        return;
    }

    try {
        std::ofstream ofs(configFile, std::ios::trunc);
        if (ofs.is_open()) {
            ofs << mac_input;
            ofs.close();
            fs::permissions(configFile, fs::perms::owner_read | fs::perms::owner_write, fs::perm_options::replace);
            cyberCyan();
            std::cout << "[+] IDENTITY ANCHORED." << std::endl;
            resetColor();
        }
    } catch (const std::exception& e) {
        matrixRed();
        std::cerr << "[!] PERSISTENCE ERROR: " << e.what() << std::endl;
        resetColor();
    }

    bpfLoader.setRouterMAC(mac_input);
}

std::string getHeartbeat(int tick) {
    std::vector<std::string> frames = {"[ - ]", "[ ^ ]", "[ - ]", "[ v ]"};
    return frames[tick % 4];
}

int main(int argc, char* argv[]) {
    bool serviceMode = false;
    for (int i = 1; i < argc; ++i) {
        if (std::string(argv[i]) == "--service") serviceMode = true;
    }

    std::signal(SIGINT, signalHandler);
    std::signal(SIGTERM, signalHandler);

    Venom::Core::Scheduler scheduler;
    Venom::Core::VenomBus bus;
    Venom::Core::BpfLoader bpfLoader;
    Venom::Core::VisualMemory vMem; 
    Venom::Modules::FilesystemModule fsModule(bus);
    Venom::Core::SocketProbe socketProbe(bus, 8888, Venom::Core::LogLevel::SECURITY_ONLY);

    try {
        { Venom::Modules::InitSecurityModule initMod; initMod.execute(); }
        
        clearScreen();
        drawHeader();
        secureSetupRouter(bpfLoader);
        
        if (!bpfLoader.deploy("obj/core/ebpf/venom_shield.bpf.o", "wlo1")) {
            matrixRed();
            std::cerr << "[!] BPF DEPLOYMENT FAILED!" << std::endl;
            resetColor();
        }

        scheduler.start(bus, bpfLoader, vMem);
        bus.startReactive(engine_lifetime, scheduler);

        if (serviceMode) {
            socketProbe.start();
            int frameCounter = 0;
            uint64_t last_filtered = 0;

            while (keepRunning && engine_lifetime.is_subscribed()) {
                auto snap = bus.getTelemetrySnapshot();
                auto bpfStats = bpfLoader.getStats();

                if (snap.null_routed > last_filtered) {
                    std::string bad_ip = bus.getLastFilteredIP();
                    if (!bad_ip.empty()) {
                        bpfLoader.blockIP(bad_ip);
                    }
                    last_filtered = snap.null_routed;
                }

                clearScreen();
                drawHeader();
                
                std::cout << "\n 💀 "; matrixRed();
                std::cout << "TOTAL KERNEL DROPS: ";
                boldWhite();
                std::cout << bpfStats.dropped_packets << " PKTS" << std::endl;
                resetColor();

                std::cout << "\n 📡 "; cyberCyan();
                std::cout << "CORE TELEMETRY STREAM:" << std::endl;
                stealthGray();
                std::cout << "  > ACCEPTED_NODES: "; neonGreen(); std::cout << snap.accepted << std::endl;
                stealthGray();
                std::cout << "  > FILTERED_ENTRY: "; matrixRed(); std::cout << snap.null_routed << std::endl;
                resetColor();
                
                std::cout << "\n 💓 HEARTBEAT: "; neonGreen(); 
                std::cout << getHeartbeat(frameCounter++) << std::endl;
                resetColor();

                std::cout << "\n" << std::string(60, '-') << std::endl;
                stealthGray();
                std::cout << " [ ENGINE LULLED IN KERNEL SPACE - " << (bpfLoader.isActive() ? "PROTECTED" : "EXPOSED") << " ]" << std::endl;
                resetColor();

                std::this_thread::sleep_for(std::chrono::milliseconds(250));
            }

            socketProbe.stop();
            bpfLoader.detach();
        }
    } catch (const std::exception& e) {
        bpfLoader.detach();
    }
    scheduler.stop();
    return 0;
}
